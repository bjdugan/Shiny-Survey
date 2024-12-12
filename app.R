library(shiny)
library(dplyr)
library(tidyr)
library(odbc)
library(DBI)
library(bslib)
library(ggplot2)

# to-do ####
# plot should split items (3 included) reactively
# add values in titles based on selections
# add summary table appropriate to data

# prep ####
con <- dbConnect(RSQLite::SQLite(), "nsse.db")

# generate list via colnames for variable selection (will just use 1 for now)
valid_items <- tbl(con, "responses") |>
  pivot_wider(names_from = item, values_from = value) |>
  select(-id) |>
  head() |>
  collect()

these_items <- c("sbmyself", "sbvalued", "sbcommunity")

# dictionary - could be unfiltered view?
dict <- left_join(
  filter(tbl(con, "items"), item %in% these_items), # input$compare_var
  tbl(con, "questions"),
  by = "question_num") |>
  left_join(tbl(con, "response_options"), by = "response_set")

# data - filter later
data <- left_join(tbl(con, "institutions"),
                         tbl(con, "respondents"), by = "unitid") |>
  left_join(tbl(con, "responses"), by = "id") |>
  filter(!is.na(value) & item %in% these_items ) |>
  # could hold off and join after summarizing?
  left_join(select(dict, item, value, response), by = c("item", "value")) |>
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
# mutipage where each page displays a different view and each nav_panel a different comparison group?
# 1st page can be simple barplot for item, both classes, and 1 group

# maybe create table for selection here instead of querying constantly

ui <- page_navbar(
  title = "Basic survey report",
  theme = bs_theme(bootswatch = "vapor"),  # see https://bslib.shinyapps.io/themer-demo/

  # page 1 item comparison
  nav_panel(
    title = "page 1 title",
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
        # choose item(s)
        varSelectInput(
          "compare_var",
          label = "Variable(s or set) to compare (TBA):",
          data = valid_items,
          selected = NULL,
          multiple = FALSE
        ),
        # choose comparison group(s)
        radioButtons("group_var1",
                     label = "Choose a group",
                     choices = pull(distinct(tbl(con, "institutions"), control)),
                     selected = NULL
        ),
        radioButtons("group_var2",
                     label = "Choose a group",
                     choices = pull(distinct(tbl(con, "institutions"), region)),
                     selected = NULL
        )
      ),
      # containers for output
      card(
        card_header("Plot comparing data between {institution} and {some criteria}"),
        plotOutput("plot1")
      ),
      card(
        card_header("Summary table"),
        textOutput("text1")
        #tableOutput("table1")
      )
    )
  )
  # page 2 etc.
)

# server ####
server <- function(input, output) {

  output$plot1 <- renderPlot({
    filter(data,
           unitid == input$unitid_i |
             (unitid != input$unitid_i &
                control == input$group_var1 & region == input$group_var2)) |>
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
  output$text1 <- renderText("PLACEHOLDER A table with various summary statistics.")

}

# Run the application ####
shinyApp(ui = ui, server = server)

# # for testing...keep wokring on this to match what i want
# input <- list()
# input$unitid_i <- 1
# input$group_var1 <- "Public"
# input$group_var2 <- "West"
#
# filter(data,
#        unitid == input$unitid_i |
#          (unitid != input$unitid_i &
#             control == input$group_var1 & region == input$group_var2)) |>
#   mutate(grp = if_else(unitid == input$unitid_i, "Institution", "Comparison Group") |>
#            factor(levels = c("Institution", "Comparison Group"))) |>
#   count(grp, class, item, value) |>
#   mutate(n = n / sum(n) * 100, .by = c(grp, class, item)) |>
#   ggplot(aes(x = grp, y = n)) +
#   geom_col(position = "dodge") +
#   theme_minimal() +
#   coord_flip() +
#   facet_wrap(~class) +
#   labs(title = pull(dict, "question"),
#        subtitle = pull(dict, "label"),
#        x = "Class level",
#        y = "Count")
