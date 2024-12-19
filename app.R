library(shiny)
library(dplyr)
library(tidyr)
library(odbc)
library(DBI)
library(bslib)
library(ggplot2)

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

# dictionary; until pages are functionally generated filter to sb* items
dict <- tbl(con, "dictionary") |>
  filter(response_set == "SDNAS")

# data - filter later
data <- left_join(tbl(con, "institutions"),
                         tbl(con, "respondents"), by = "unitid") |>
  left_join(tbl(con, "responses"), by = "id") |>
  filter(!is.na(value) ) |>
  # could hold off and join after summarizing? right_ to keep only sb* items
  right_join(select(dict, item, value, response), by = c("item", "value")) |>
  # for correctly ordering response/value labels
  arrange(item, value) |>
  collect() |>
  mutate(response = factor(value, labels = unique(response)),
         # should cut size but will require some re-ordering for "unpaired" value-label sets
         across(where(is.character), factor),
       .by = item)

# this maintains values as numeric (e.g. for statistical ops) and response as factor (plotting, lightweight)
# count(data, item, value, response)

# UI #####
# each page should display a different item (sub)set

ui <- page_navbar(
  title = "Basic survey report",
  # see https://bslib.shinyapps.io/themer-demo/
  theme = bs_theme(bootswatch = "cerulean"),

  # page 1 item comparison
  nav_panel(
    title = "{some item set}",
    layout_sidebar(
      # side bar with input selection
      sidebar = sidebar(
        # your institution (passed via credential system or...)
        selectInput("unitid_i", "Unitid (hidden)",
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
        radioButtons("plot_type1",
                     label = "Show side-by-side bar plots or dumbells for distribution. (TBA)",
                     choices = c("Distribution", "Differences"),
                     selected = NULL
                     ),
        selectInput("useInstColors",
                    "Try to use your institution's color palette (or pick one) and logo? (TBA)",
                    choices = c(TRUE, FALSE)
                    ),
        actionButton("download", "Download (TBA)")

      ), # end sidebar

      # containers for output
      card(
        card_header("Your student responses"),
        p("This is a sample dashboard permitting users to explore NSSE data using R Shiny and many other packages. Each 'card' contains and organizes some HTML elements. The sidebar panel contains UI elements that interact with the server, i.e., allow a user to query the data. The pages ('{some item set}' tabs) will be generated functionally to capture known sets (EIs, HIPs, modules) and further interact with data, e.g., select a set of variables from a list to use dynamically as filters or variables on either side of the equation (DV or IV). Note that curly braces signify some will-be variable value. Comparison groups will be implemented in place of 'Choose a group,' which will have proper titles. This section might otherwise contain a {description} of item {set} and how it pertains to student engagement, with links to resources.")
      ),
      card(
        card_header("Plot comparing data between {institution} and {some criteria} for {item set}"),
        plotOutput("plot1")
      ),
      layout_columns(
        card(
          card_header("Freqencies table"),
          textOutput("text1")
          #tableOutput("table1")
        ),
        card(
          card_header("Statistical table"),
          textOutput("text2")
        )
      ),
      card(
        p("<small>Data notes: the data powering this app are fabricated and intended for demonstration purposes only. See create data.R at LINK[https://github.com/bjdugan/Shiny-Survey] for the R code. OMIT SCROLLBOX MAKE SMALL</small>")
      )
    )
  )
)

# server ####
server <- function(input, output) {

  output$plot1 <- renderPlot({
    filter(data,
           # this institution or all others in comp group/comp group stand-in
           (unitid == input$unitid_i |
             (unitid != input$unitid_i &
                control == input$group_var1 & region == input$group_var2)) &
             sex %in% input$student_filter1) |>
      mutate(grp = if_else(unitid == input$unitid_i, "Institution", "Comparison Group") |>
               factor(levels = c("Institution", "Comparison Group"))) |>
      ggplot(aes(x = grp, y = value, fill = response)) +
      geom_col() +
      theme_minimal() +
      facet_wrap(~class) +
      labs(title = pull(dict, "question"),
           subtitle = pull(dict, "label"),
           x = "Class level",
           y = "Count")
  })

  #output$table1 <- renderTable()
  output$text1 <- renderText("PLACEHOLDER A table with counts and ~weighted percentages")
  output$text2 <- renderText("PLACEHOLDER A table with statistical data")

}

# Run the application ####
shinyApp(ui = ui, server = server)
