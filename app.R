library(shiny)
library(dplyr)
library(tidyr)
library(odbc)
library(DBI)
library(bslib)
library(ggplot2)
library(purrr)
library(forcats)
library(stringr)
library(tidyr)
source("create_nav_panel.r")
source("plot_funs.r")

# to-do ####
# split variables across pages programmatically; requires either variable set to be subdivided e.g. 'core-DD', 'core-tm' while modules remain 'civ', as subsets arent' necesarily by-question (there are orphans), or, a second variable to capture the variation within the core survey, only really used by core survey, or perhaps expanded upon as the "constructs" by or within each question.
# add FY/SR as radio button option? was in design but may not be needed
# flesh out summary tables (freq, stats)
# add placeholder for download/export buttons
# revise plot to be minimally appropriate for data
# add comparison group table(s) in db and transform groups to be checkbox input
# consider adding a condition to check-all with all selected by default so that if nothing is selected (and data would filter to nothing) everything shows/no filter applied

# prep ####
con <- dbConnect(RSQLite::SQLite(), "nsse.db")

# generate list via colnames for variable selection (will just use 1 for now)
valid_items <- tbl(con, "responses") |>
  pivot_wider(names_from = item, values_from = value) |>
  select(-id) |>
  head() |>
  collect()

# dictionary
dict <- tbl(con, "dictionary") |>
  filter(response_set == "NSOV")

# data - filter later
data <- left_join(tbl(con, "institutions") |>
                    select(unitid, name),
                  tbl(con, "respondents"), by = "unitid") |>
  left_join(tbl(con, "responses"), by = "id") |>
  filter(!is.na(value)) |>
  right_join(select(dict, item, survey_order, label, value, response),
             by = c("item", "value")) |>
  # for correctly ordering response/value labels
  arrange(item, value) |>
  collect() |>
  mutate(response = factor(value, labels = unique(response)),
         label = factor(survey_order, labels = unique(str_wrap(label, 40))),
         # simple comparison - institution vs all others
         # grp = if_else(unitid == input$unitid_i, "g0", "g1") |>
         #   factor(),
         # should cut size but will require some re-ordering for "unpaired" value-label sets
         across(where(is.character), factor),
         .by = item)
# drop unused cols  select(unitid, name, )

# pmap when n args expands; consider setting names for clarity and to avoid using plot1, table1, etc.
panels <- c("Collaborative Learning", "Sense of Belonging",
            "Higher-Order Learning") |>
  imap(create_nav_panel)

# UI #####
# each page should display a different item (sub)set
ui <- page_navbar(
  title = "Basic survey report",
  # see https://bslib.shinyapps.io/themer-demo/
  theme = bs_theme(bootswatch = "cerulean"),
  header = "page_navbar header (not CSS'd)",

  # page_navbar will use same sidebar on every page
  sidebar = sidebar(
    # your institution (passed via credential system or...)
    selectInput("unitid_i", "Unitid (test only)",
                choices = tbl(con, "institutions") |>
                  select(unitid) |>
                  collect() |>
                  pull(),
                selected = 1
    ),
    # choose student filters
    checkboxGroupInput("student_filter1",
                       "Choose students",
                       choices = unique(data$sex),
                       selected = unique(data$sex)
    ),
    # choose comparison group(s)
    radioButtons("group_var1",
                 label = "Choose a (comparison) group",
                 choices = pull(distinct(tbl(con, "institutions"), control)),
                 selected = NULL
    ),
    radioButtons("group_var2",
                 label = "Choose a (comparison) group",
                 choices = pull(distinct(tbl(con, "institutions"), region)),
                 selected = NULL
    ),
    radioButtons("plot_type",
                 label = "Show side-by-side bar plots or dumbells for distribution.",
                 choices = c("Distribution", "Differences", "Divergent"),
                 selected = "Distribution"
    ),
    # selectInput("useInstColors",
    #             "Try to use your institution's color palette (or pick one) and logo? (TBA)",
    #             choices = c(TRUE, FALSE)
    # ),
    actionButton("download", "Download (TBA)")
  ), # end sidebar


  panels[[1]],
  panels[[2]],
  panels[[3]],

  footer = HTML("<hr><small>Data notes: the data powering this app are fabricated and intended for demonstration purposes only.This note has literal HTML to make it small and add the HR above</small>")
  )

# server ####
server <- function(input, output) {

  data <- mutate(data, grp = if_else(unitid == 1, "g0", "g1") |>
                   factor())

  output$plot1 <- renderPlot({plot_fun("plot1", data, type = input$plot_type)})
  output$plot2 <- renderPlot({plot_fun("plot2", data, type = input$plot_type)})
  output$plot3 <- renderPlot({plot_fun("plot3", data, type = input$plot_type)})


  # repeating for each panel seems crazy!
  output$freq1 <- renderText("PLACEHOLDER A table with counts and ~weighted percentages")
  output$freq2 <- renderText("PLACEHOLDER A table with counts and ~weighted percentages")
  output$freq3 <- renderText("PLACEHOLDER A table with counts and ~weighted percentages")


}

# Run the application ####
shinyApp(ui = ui, server = server)
