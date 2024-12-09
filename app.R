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

# dictionary
y <- left_join(
  filter(tbl(con, "items"), item %in% c("sbmyself", "sbvalued", "sbcommunity")), # input$compare_var
  tbl(con, "questions"),
  by = "question_num") |>
  collect()

# data - filter later
x <- tbl(con, "institutions") |>
  #filter(control == input$group_var1 & region == input$group_var2) |>
  left_join(
    tbl(con, "responses") |>
      filter(item %in% y$item & !is.na(value)) |> # input$compare_var
      left_join(
        tbl(con, "respondents") |>
          select(id, unitid, class),
        by = "id"),
    by = "unitid") |>
  left_join(tbl(con, "items") |>
              select(item, label, response_set),
            by = "item") |>
  left_join(tbl(con, "response_options"), by = c("response_set", "value")) |>
  collect()


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
                    selected = 1,
                    ),

        # choose item(s)
        varSelectInput(
          "compare_var",
          label = "Variable to compare (coming soon):",
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
    filter(x,
           unitid == input$unitid_i |
             (unitid != input$unitid_i &
                control == input$group_var1 & region == input$group_var2)) |>
      mutate(grp = if_else(unitid == input$unitid_i, 1, 0)) |>
      ggplot(aes(x = grp, y = value, fill = response)) +
      geom_col() +
      theme_minimal() +
      facet_wrap(~class) +
      labs(title = pull(y, "question"),
           subtitle = pull(y, "label"),
           x = "Class level",
           y = "Count")
  })

  #output$table1 <- renderTable()
  output$text1 <- renderText("PLACEHOLDER A table with various summary statistics.")

}

# Run the application ####
shinyApp(ui = ui, server = server)

# no such column
