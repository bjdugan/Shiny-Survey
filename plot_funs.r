theme_nsse <- function(
    # default args, can be supplied to existing theme
  base_size = 16,
  base_family = "sans", # one of windowsFonts()
  base_line_size = base_size /  22,
  base_rect_size  = base_size / 22) {
  windowsFonts(`Calibri` = windowsFont("Calibri")) # adding fonts in session

  theme_minimal(
    base_size = base_size,
    base_family = "Calibri",
    base_line_size = base_line_size,
    base_rect_size = base_rect_size
  ) %+replace%
    theme(
      # below, what theme_minimal adds to theme_bw
      # axis.ticks = element_blank(),
      # legend.background = element_blank(),
      # legend.key = element_blank(),
      # panel.background = element_blank(),
      # panel.border = element_blank(),
      # strip.background = element_blank(),
      # plot.background = element_blank(),
      # complete = TRUE
      plot.title = element_text(colour = "#002D6D", hjust = 0), # text= to affect all
      plot.subtitle = element_text(colour = "#002D6D", hjust = 0, size = rel(.9)),
      plot.title.position = "plot",
      axis.text = element_text(size = rel(.8)),
      axis.text.x = element_text(color = "#A6A6A6"),
      panel.grid.minor = element_blank(),
      # for vert bars; x for horiz bars (reversed for coord_flip, regardless of order)
      panel.grid.major.x = element_line(linewidth = 1),
      panel.grid.major.y = element_blank(),
      panel.background = element_rect(#fill = "#CCCCCC",
        fill = "#D9D9D9",
        color = "white"),
      legend.position = "right", #looks better when flipped
      complete = TRUE
    )
}

plot_fun <- function(id, data, type = "Distribution", weight = FALSE) {
  # choose a plot type based on some user input

  # probably better to extract summarization to db if possible or as separate function
  # as summary data will be used e.g. in freqency table as well
  # for the sake of easy plotting now keep here
  d <- count(data, grp, label, response, value) |>
    mutate(p = n / sum(n) * 100, .by = c(grp, label))

  if (type == "Differences") {
    # collapse categories inwardly so we have dichotomous measure
    # collapsed levels could be added in dict instead of hard-coded, e.g. response_col = "Infrequently" for "Never" and "Sometimes"
    # ^ probably necessary as collapsing varies by response set
    d <- mutate(d,
                response = fct_collapse(response,
                                        Infrequently = c("Never", "Sometimes"),
                                        Frequently = c("Often", "Very often"))) |>
      summarize(p = sum(p), .by = c(grp, label, response)) |>
      # keep only "upper" RO
      filter(response == "Frequently")
  } else if (type == "Divergent") {
    d <- mutate(d,
                p = if_else(response %in% c("Never", "Sometimes"), p * -1, p),
                response = fct_relevel(response,
                                       c("Never", "Sometimes",
                                        "Very often", "Often"))
                )
  }

  # consider fct_rev(label) earlier as is common to all
  if (type == "Distribution") {
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
  } else if (type == "Differences") {
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
      geom_text(aes(x = p, y = fct_rev(label), label = paste0(round(p), "%")),
                nudge_y = .2)
    # scale according to diff?
  } else if (type == "Divergent") {
    # divergent bar plot
  plt <- ggplot(d[d$grp == "g0", ], aes(x = p, y = fct_rev(label),
                                        fill = response,
                                        color = grp
                                        )) +
      geom_col(position = "stack", width = .25, just = 1) +
      geom_col(data = d[d$grp == "g1", ],
               # aes is same, but need to offset y
               aes(y = fct_rev(label)),
               width = .25,
               just = -1) +
      theme_nsse() +
      scale_fill_brewer(type = "div")
      #geom_text(aes(label = paste0(round(p), "%")))
  }

  # constant styling and elements regardless of plot type
  # most of this could be kep inside a custom theme instead of calling theme_minimal() and then theme()
  plt <- plt + theme_nsse() +
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
# plot_fun(data, type = "dumbbell")
# plot_fun(data, type = "stacked_col")
# plot_fun(data = data, type = "Divergent")

