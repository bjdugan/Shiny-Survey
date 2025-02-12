# funs to create UI layout
# may need to be module?
create_nav_panel <- function(panel_title, i) {
  nav_panel(
    title = panel_title,

    # basic info
    p("p(): This is a sample dashboard permitting users to explore NSSE data using R Shiny and other packages. The sidebar panel contains UI elements that interact with the server, i.e., allow a user to query the data. The pages will be generated functionally to capture known sets (EIs, HIPs, modules) and further interact with data, e.g., select a set of variables from a list to use dynamically as filters or variables on either side of the equation (DV or IV). Note that curly braces signify some will-be variable value. Comparison groups will be implemented in place of 'Choose a group,' which will have proper titles. This section might otherwise contain a {description} of item {set} and how it pertains to student engagement, with links to resources."),

    # plot and resources card
    layout_columns(
      col_widths = c(9, 3), # max 12
      card(
        card_header("card_header: Plots comparing data between {institution} and {some criteria} for {item set} OR {question}?"),
        plotOutput(paste0("plot", i))
      ),
      card(
        card_body(
          h2("H2: Resources"),
          p("Here's some resources listed in <p> w/in card_body(). Pull out of card() (advised?) to reclaim padding and remove borders",
            "Column layout at 9:3.",
            "All w/in same <p>",
            "Might add more detail to plots, or additional plot via gridExtra to show EI/scales, or perhaps 'Differences' plot as 3rd panel instead?"
          ),
          hr(),
          br(),
          p("Another <p>", "with several items",
            "beneath a line and forced break"),
          tags$li("list item 1"),
          tags$li("list item 2"),
          tags$li("list item 2"),
        )
      ),
    ),

    # tables and download stuff
    layout_columns(
      col_widths = c(9, 3),
      card(
        h3("h3 lower card 1 table placeholder")
      ),
      card_body(
        #card_header("Card2"),
        h3("H3 lower card 2"),
        p("Some other static content in another container")
      ),
    )
  )
}
