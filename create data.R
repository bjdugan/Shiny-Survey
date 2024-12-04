# create mock survey data and metadata, based loosely on NSSE

library(dplyr)
library(tidyr)
library(tibble)
library(odbc)
library(DBI)

# to do:
# - add peers tables similar to in RF,
# - review creation of responses as it slows down considerably with higher n

# instrument codebooks ####
# a table of each stem or question as it appears on the survey
questions = tibble(
  question_num = 1:3,
  question = c(
  "During the current school year, about how often have you done the following?",
  "During the current school year, how much has your coursework emphasized the following?",
  "To what extent do you agree or disagree with the following statements?"),
  set = "core")

# a table of each item, stem, wording, its module or set, and its response set
items <- tibble(
  question_num = c(1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3),
  item = c("CLaskhelp", "CLexplain", "CLstudy", "CLproject",
           "HOapply", "HOanalyze", "HOevaluate", "HOform",
           "sbmyself", "sbvalued", "sbcommunity"),
  label = c(
    "Asked another student to help you understand course material",
    "Explained course material to one or more students",
    "Prepared for exams by discussing or working through course material with other students",
    "Worked with other students on course projects or assignments",
    "Applying facts, theories, or methods to practical problems or new situations",
    "Analyzing an idea, experience, or line of reasoning in depth by examining its parts",
    "Evaluating a point of view, decision, or information source",
    "Forming a new idea or understanding from various pieces of information",
    "I feel comfortable being myself at this institution.",
    "I feel valued by this institution.",
    "I feel like a part of the community at this institution."),
  # some short, unique code for response option labels
  response_set = c(rep("NSOV", 4), rep("VSQV", 4), rep("SDNAS", 3)) ) |>
  mutate(item_alpha = letters[row_number()],
         survey_order = paste0(question_num, item_alpha),
         .by = question_num) |>
  select(question_num, item_alpha, survey_order, item, label, response_set)

# a table of unique response option sets and their values
response_options <- tibble(
  response = c("Never", "Sometimes", "Often", "Very often",
               "Very little", "Some", "Quite a bit", "Very much",
               "Strongly disagree", "Disagree", "Neither agree nor disagree",
               "Agree", "Strongly agree"),
  value = c(1:4, 1:4, 1:5),
  response_set = c(rep("NSOV", 4), rep("VSQV", 4), rep("SDNAS", 5)))

# response_options are nested within items are nested within questions:
nest_join(items, response_options, by = "response_set")
nest_join(questions, items, by = "question_num")

# institutional information ####
# create some basic, IPEDS-like information for a handful of institutions
set.seed(123)
institutions <- tibble(
  unitid = 1:20,
  name = paste("University of", letters[1:20]),
  control = c(rep("Private", 12), rep("Public", 8)),
  # not OBEREG but will do
  region = sample(state.region, size = 20, replace = TRUE)
)

# respondent data ####
# create random values for a small number of respondents, nested within institutions
# maybe drop a few at random to simulate non-response, and add missing values throughout
n_respondents <- 25000

set.seed(123)
responses <- nest_join(items, response_options, by = "response_set") |>
  (\(x) replicate(n_respondents, x, simplify = FALSE))() |>
  map(unnest, response_options) |>
  # assign id from list position/index
  imap(mutate) |>
  map(select, id = last_col(), item, value) |>
  # randomly select a response
  map(slice_sample, by = item) |>
  # create a small number of non-respondents: 10%
  map_at(sample(1:n_respondents, n_respondents * .1, replace = FALSE),
         mutate, value = NA_integer_) |>
  # add a little bit of itemwise missing values
  map(mutate,
      x = sample(c(FALSE, TRUE), nrow(items), replace = TRUE, prob = c(.1, .9)),
      value = if_else(x, value, NA_integer_),
      x = NULL) |>
  bind_rows()

# respondent information, assuming census administration
set.seed(123)
respondents <- tibble(
  id = 1:n_respondents,
  unitid = sample(institutions$unitid, size = n_respondents, replace = TRUE),
  sex = sample(c("Male", "Female"), size = n_respondents, prob = c(.4, .6),
               replace = TRUE),
  class = sample(c("First-year", "Senior"), size = n_respondents, prob = c(.6, .4),
                 replace = TRUE))

# responses are tied to respondents who are nested in institutions
nest_join(respondents, responses, by = "id")
nest_join(institutions, respondents, by = "unitid")


# create SQLite database ####
con <- dbConnect(RSQLite::SQLite(), ":memory:")

# very lazy, will not work with any other objects present
tables <- list(institutions, respondents, responses, questions, items,
               response_options) |>
  set_names(c("institutions", "respondents", "responses", "questions", "items",
              "response_options"))

map2(names(tables), tables, \(x, y) dbWriteTable(con, x, y))

# confirm
tbl(con, "items")

tbl(con, "responses")
# close connection and save
RSQLite::sqliteCopyDatabase(con, "nsse.db")

dbDisconnect(con)
