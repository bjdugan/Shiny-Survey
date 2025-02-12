library(ggplot2)
library(odbc)
library(dplyr)
library(forcats)
library(stringr)
library(tidyr)

con <- dbConnect(RSQLite::SQLite(), "nsse.db")

dict <- tbl(con, "dictionary") |>
  filter(response_set == "NSOV")

data <- left_join(tbl(con, "institutions") |>
                    select(unitid, name),
                  tbl(con, "respondents"), by = "unitid") |>
  left_join(tbl(con, "responses"), by = "id") |>
  filter(!is.na(value)) |>
  right_join(select(dict, item, survey_order, label, value, response), by = c("item", "value")) |>
  # for correctly ordering response/value labels
  arrange(item, value) |>
  collect() |>
  mutate(response = factor(value, labels = unique(response)),
         #
         label = factor(survey_order, labels = unique(str_wrap(label, 40))),
         # simple comparison - institution vs all others
         grp = if_else(unitid == input$unitid_i, "g0", "g1") |>
           factor(),
         # should cut size but will require some re-ordering for "unpaired" value-label sets
         across(where(is.character), factor),
         .by = item)
  # drop unused cols  select(unitid, name, )



plot_fun <- function(data, type = "stacked_col", weight = FALSE) {
  # choose a plot type based on some user input

  # probably better to extract summarization to db if possible or as separate function
  # as summary data will be used e.g. in freqency table as well
  # for the sake of easy plotting now keep here
  d <- count(data, grp, label, response, value) |>
    mutate(p = n / sum(n) * 100, .by = c(grp, label))

  if (type == "dumbbell") {
    # collapse categories inwardly so we have dichotomous measure
    # collapsed levels could be added in dict instead of hard-coded, e.g. response_col = "Infrequently" for "Never" and "Sometimes"
    # ^ probably necessary as collapsing varies by response set
    d <- mutate(d, response = fct_collapse(response,
                                           Infrequently = c("Never", "Sometimes"),
                                           Frequently = c("Often", "Very often"))) |>
      summarize(p = sum(p), .by = c(grp, label, response)) |>
      # keep only "upper" RO
      filter(response == "Frequently")
  }

  if (type == "stacked_col") {
    # reverse factor order so earliest items appear at top
    plt <- ggplot(d, aes(x = p, y = fct_rev(label), fill = response)) +
      geom_col(position = "dodge") +
      # not sure if this is needed in shiny, might occur by default
      # could make a separate p used for x here that subtracts some value instead to place label on left (inside) column
      geom_text(aes(label = paste0(round(p), "%"),
                    x = p + 2.5),
                position = position_dodge(.9)) +
      facet_wrap(~grp) +
      scale_fill_brewer(type = "seq") +
      scale_x_continuous(limits = c(0, 100))
  } else if (type == "dumbbell") {
    # consider https://r-graph-gallery.com/web-extended-dumbbell-plot-ggplot2.html which has mean and sd as well
    # split data into g0, g1, where g0 provides base layer and g1 provides -ends.
    plt <- ggplot(d) +
      geom_segment(data = d[d$grp == "g0", ],
                   aes(x = p, y = fct_rev(label),
                       xend = d[d$grp == "g1", ]$p,
                       yend = fct_rev(d[d$grp == "g1", ]$label)),
                       linewidth = 2,
                   color = "grey") +
      geom_point(aes(x = p, y = fct_rev(label), color = grp, shape = grp),
                 size = 5) +
      geom_text(aes(x = p, y = fct_rev(label), label = paste(round(p), "%")),
                nudge_y = .2)
    # scale according to diff?
  }
  # constant styling and elements regardless of plot type
  # most of this could be kep inside a custom theme instead of calling theme_minimal() and then theme()
  plt <- plt + theme_minimal() +
    theme(legend.position = "bottom",
          panel.grid.major.y = element_blank(),
          panel.grid.minor.x = element_blank()
    ) +
    labs(title = unique(pull(dict, "question")),
         caption = "Filter conditions: [First-year|Senior]...",
         x = "[Percentage|Weighted Percentage] [Frequently|Substantially|Done...",
         y = NULL)

  return(plt)
}
# e.g.
plot_fun(data, type = "dumbbell")
plot_fun(data, type = "stacked_col")


