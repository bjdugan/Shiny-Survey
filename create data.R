# create mock survey data and metadata, based loosely on NSSE

library(dplyr)
library(tidyr)
library(purrr)
library(tibble)
library(odbc)
library(DBI)
library(stringr)

# to do:
# - add peers tables similar to in RF
# - review creation of responses as it slows down considerably with higher n
# - consider extending set for core survey (e.g. "core-[EI]") to distinguish subsets based on constructs or adding a new variable "subset".

# instrument codebooks ####
# a table of each stem or question as it appears on the survey
questions = tibble(
  question_num = 1:7,
  question = c(
    "During the current school year, about how often have you done the following?",
    "During the current school year, how much has your coursework emphasized the following?",
    "To what extent do you agree or disagree with the following statements?",
    "Which of the following have you done while in college or do you plan to do before you graduate?",
    "About how many of your courses at this institution have included a community-based project (service-learning)?",
    "About how many hours do you spend in a typical 7-day week doing the following?",
    "Indicate the quality of your interactions with the following people at your institution."
    ),
  instrument = "NSSE",
  response_set = c("NSOV", "VSQV", "SDNAS", "HDPD", "NSMA", "HpW",
                   "poor_excellent")
)

# a table of each item, stem, wording, its module or set, and its response set
items <- tibble(
  question_num = c(rep(1, 4), rep(2, 4), rep(3, 3), rep(4, 6), 5, rep(6, 8),
                   rep(7, 5)),
  item = c("CLaskhelp", "CLexplain", "CLstudy", "CLproject",
           "HOapply", "HOanalyze", "HOevaluate", "HOform",
           "sbmyself", "sbvalued", "sbcommunity",
           "intern", "leader", "learncom", "abroad", "research", "capstone",
           "servcourse",
           "tmprep", "tmcocurr", "tmworkon", "tmworkoff", "tmservice", "tmrelax",
           "tmcare", "tmcommute",
           "QIstudent", "QIadvisor", "QIfaculty", "QIstaff", "QIadmin"),
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
    "I feel like a part of the community at this institution.",
    "Participate in an internship, co-op, field experience, student teaching, or clinical placement",
    "Hold a formal leadership role in a student organization or group",
    "Participate in a learning community or some other formal program where groups of students take two or more classes together",
    "Participate in a study abroad program",
    "Work with a faculty member on a research project",
    "Complete a culminating senior experience (capstone course, senior project or thesis, portfolio, recital, comprehensive exam, etc.)",
    # servcourse question is label - no subitems/matrix
    "About how many of your courses at this institution have included a community-based project (service-learning)?",
    "Preparing for class (studying, reading, writing, doing homework or lab work, analyzing data, rehearsing, and other academic activities)",
    "Participating in co-curricular activities (organizations, campus publications, student government, fraternity or sorority, intercollegiate or intramural sports, etc.)",
    "Working for pay on campus",
    "Working for pay off campus",
    "Doing community service or volunteer work",
    "Relaxing and socializing (time with friends, video games, TV or videos, keeping up with friends online, etc.)",
    "Providing care for dependents (children, parents, etc.)",
    "Commuting to campus (driving, walking, etc.)",
    "Students", "Academic advisors", "Faculty",
    "Student services staff (career services, student activities, housing, etc.)",
    "Other administrative staff and offices (registrar, financial aid, etc.)"
    ),
  # some short, unique code for response option labels
  response_set = c(rep("NSOV", 4), rep("VSQV", 4), rep("SDNAS", 3),
                   rep("HDPD", 6), "NSMA", rep("HpW", 8), rep("poor_excellent", 5))
  ) |>
  mutate(item_alpha = letters[row_number()],
         survey_order = paste0(question_num, item_alpha),
         .by = question_num) |>
  select(question_num, item_alpha, survey_order, item, label, response_set)

# a table of unique response option sets and their values
response_options <- tibble(
  response = c(
    # standard Likert items
    "Never", "Sometimes", "Often", "Very often",
    "Very little", "Some", "Quite a bit", "Very much",
    "Strongly disagree", "Disagree", "Neither agree nor disagree",
    "Agree", "Strongly agree",
    # HIP items
    "Have not decided", "Do not plan to do", "Plan to do", "Done or in progress",
    # service learning and similar items
    "None", "Some", "Most", "All",
    # time use
    "0 Hours per week", "1-5", "6-10", "11-15", "16-20", "21-25", "26-30",
    "More than 30",
    # range with endpoints labelled only, and N/A level
    # unfortunately these appear as Value=Response & vice versa, Response<br>Value, etc. Keeping value first should help with ordering.
    "1 Poor", 2:6, "7 Excellent", "Not applicable"),
  value = c(1:4, 1:4, 1:5, 1:4, 1:4, 1:8, 1:8),
  response_set = c(rep("NSOV", 4), rep("VSQV", 4), rep("SDNAS", 5),
                   rep("HDPD", 4), rep("NSMA", 4),
                   rep("HpW", 8),
                   rep("poor_excellent", 8))
  )

# a table of item grouping and audiences (for later)
item_groups <- tibble(
  item = c("CLaskhelp", "CLexplain", "CLstudy", "CLproject",
           "HOapply", "HOanalyze", "HOevaluate", "HOform",
           "sbmyself", "sbvalued", "sbcommunity",
           # hips
           "intern", "leader", "learncom", "abroad", "research", "capstone",
           "servcourse",
           # time use
           "tmprep", "tmcocurr", "tmworkon", "tmworkoff", "tmservice", "tmrelax",
           "tmcare", "tmcommute",
           # QI
           "QIstudent", "QIadvisor", "QIfaculty", "QIstaff", "QIadmin"
           ),
  grouping = c(rep("CL", 4), rep("HO", 4), rep("sb", 3),
               rep("HIP", 7), rep("tm", 8), rep("QI", 5)),
  grouping_label = c(rep("Collaborative Learning", 4),
                     rep("Higher-order Learning", 4),
                     rep("Sense of Belonging", 3),
                     rep("High-impact Practices", 7),
                     rep("Time use", 8),
                     rep("Quality of Interactions", 5)
                     ),
  audience = "Some audience"
)

# response_options are nested within items are nested within questions:
nest_join(items, response_options, by = "response_set")
nest_join(questions, items, by = "question_num")
nest_join(questions, response_options, by = "response_set")

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

# institutions receive defaults based on US/Canada, consortium participation, otherwise is ..., region-control (we could coerce Canada to this but they ~all do provincial consortium, ), and all standard admins within national context.
# implement here

# respondent data ####
# create random values for a small number of respondents, nested within institutions
# maybe drop a few at random to simulate non-response, and add missing values throughout
n_respondents <- 25000

set.seed(123)
responses <- left_join(items, response_options, by = "response_set",
                       relationship = "many-to-many") |>
  select(item, value) |>
  (\(x) replicate(n_respondents, x, simplify = FALSE))() |>
  # randomly select a response
  map(slice_sample, by = item) |>
  # create a small number of non-respondents: 10%
  map_at(sample(1:n_respondents, n_respondents * .1, replace = FALSE),
         mutate, value = NA_integer_) |>
  # add a little bit of itemwise missing values
  map(mutate,
      x = sample(c(FALSE, TRUE), nrow(items), replace = TRUE, prob = c(.1, .9)),
      value = if_else(x, value, NA_integer_)) |>
  # assign id from list position/index
  imap(mutate) |>
  map(select, id = last_col(), item, value) |>
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

tables <- list(institutions, respondents, responses, questions, items,
               response_options, item_groups) |>
  set_names(c("institutions", "respondents", "responses", "questions", "items",
              "response_options", "item_groupings"))

# add PK and FK constraints; SQLite tables can't have constraints added ex post facto
# write a set of create table queries
x <- map(tables, map, class) |>
  map(as_tibble) |>
  map(pivot_longer, everything()) |>
  imap(mutate) |>
  map(rename, col = name, type = value, table = last_col()) |>
  bind_rows() |>
  # coerce to SQL types: int, nvarchar (for text and factors), double,
  # add primary keys; may not support composite pks in create table - add constraint
  mutate(
    type = case_when(type %in% c("character", "factor") ~ "text",
                     type == "integer" ~ "int",
                     type == "numeric" ~ "num"),
    pk = if_else(
      (table == "institutions" & col == "unitid") |
        (table == "respondents" & col == "id") |
        (table == "items" & col == "item"),
      # does item_groupings need pk?...note ws before PRIMARY for sytnax
      " PRIMARY KEY", ""
    ),
  ) |>
  group_by(table) |>
  summarize(statement = paste0(col, " ", type, pk, ",", collapse = "\n")) |>
  # add composite pk's
  mutate(statement = case_when(
    table == "responses" ~ paste0(statement, "\nPRIMARY KEY (id, item)"),
    table == "question" ~ paste0(statement, "\nPRIMARY KEY (instrument, question_num)"),
    # not sure if needs pk...
    table == "response_options" ~ paste0(statement,
                                         "\nPRIMARY KEY (response, value, response_set)"),
    TRUE ~ statement)
    # could add fk here, e.g. for questions
    # FOREIGN KEY (response_set) REFERENCES response_options (response_set)
  ) |>
  transmute(statement = paste0("\nCREATE TABLE ", table, " (\n", statement, "\n);") |>
              str_squish() |>
              str_replace(", \\)", ")")
              )
cat(x[1, ]$statement)

# create tables
map(x$statement, \(x) dbExecute(con, x))

# populate tables
map2(names(tables), tables, \(x, y) dbAppendTable(con, x, y))

# confirm
tbl(con, "items")
tbl(con, "questions")

# add View for dictionary, perhaps others...
left_join(tbl(con, "items"),
          tbl(con, "questions"),
          by = c("question_num", "response_set")) |>
  left_join(tbl(con, "response_options"), by = "response_set") |>
  explain()

# if exists, drop then create
dbExecute(con, "DROP VIEW IF EXISTS dictionary;")
# adapted and tidied from show_query()/explain(); note `set` in back-tics as SET is reserved
dbExecute(con,
          "CREATE VIEW dictionary AS
          SELECT `items`.*, `question`, `instrument`, `response`, `value`
          FROM `items`
          LEFT JOIN `questions`
          ON (
          `items`.`question_num` = `questions`.`question_num` AND
          `items`.`response_set` = `questions`.`response_set`
          )
          LEFT JOIN `response_options`
          ON (`items`.`response_set` = `response_options`.`response_set`);")
# confirm
tbl(con, "dictionary")

# close connection and save
RSQLite::sqliteCopyDatabase(con, "nsse.db")

dbDisconnect(con)

