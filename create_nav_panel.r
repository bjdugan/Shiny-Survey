# funs to create UI layout
# may need to be module?
create_nav_panel <- function(panel_title, i) {
  nav_panel(
    title = panel_title,
    card(
      card_header("Plot comparing data between {institution} and {some criteria} for {item set}"),
      plotOutput(paste0("plot", i))
    ),
    layout_columns(
      card(
        card_header("Freqencies table"),
        textOutput(paste0("freq", i))
      ),
      card(
        card_header("Statistical table"),
        textOutput(paste0("stat", i))
      )
    )
  )
}
