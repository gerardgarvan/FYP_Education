# =============================================================================
# 21_plot_mt_stacked_bars.R  (DSC-03)
# Stacked bars of MT_ASA, MT_Frailty_Score and Mortality_1Y by MT_EDUC_GROUP.
# Reads : exports/MT_educ_stacked_bars.csv  (sas/20_mt_stacked_bars_data.sas)
# Writes: figures/MT_educ_stacked_<variable>.png
# =============================================================================

source("R/00_config.R")
library(ggplot2)
library(dplyr)

df <- read.csv(file.path(dir_exports, "MT_educ_stacked_bars.csv"), stringsAsFactors = FALSE) %>%
  mutate(educ_group  = factor(educ_group),
         category    = as.character(category),
         highlighted = as.logical(highlighted))

# Legend labels per variable: category value -> display name
# The order listed here is the order shown in the legend
legend_labels <- list(
  MT_ASA           = c("1"  = "MT_ASA = 1",           "2"   = "MT_ASA = 2"),
  MT_Frailty_Score = c("1"  = "MT_Frailty_Score = 1", "2"   = "MT_Frailty_Score = 2"),
  Mortality_1Y     = c("No" = "Mortality_1Y = No",    "Yes" = "Mortality_1Y = Yes")
)

plot_titles <- c(
  MT_ASA           = "ASA Group by Education Group",
  MT_Frailty_Score = "Frailty Score by Education Group",
  Mortality_1Y     = "Mortality (1 Year) by Education Group"
)

make_plot <- function(var) {
  d <- df %>% filter(variable == var)

  hi_cat   <- unique(d$category[d$highlighted])
  ref_cat  <- unique(d$category[!d$highlighted])
  labs_map <- legend_labels[[var]]

  # Highlighted level stacked on the bottom
  d <- d %>%
    mutate(fill_key = factor(unname(labs_map[category]),
                             levels = unname(labs_map[c(ref_cat, hi_cat)])))

  # Colors assigned by name: reference = UF blue, highlighted = UF orange
  fill_vals <- c(uf_blue, uf_orange)
  names(fill_vals) <- unname(labs_map[c(ref_cat, hi_cat)])

  # Labels inside tall segments, just above short ones
  lab <- d %>%
    filter(highlighted) %>%
    mutate(small   = row_pct < 12,
           label_y = ifelse(small, row_pct + 1.5, row_pct / 2),
           vjust   = ifelse(small, 0, 0.5))

  ggplot(d, aes(x = educ_group, y = row_pct, fill = fill_key)) +
    geom_col(width = 0.8) +
    geom_text(data = lab,
              aes(x = educ_group, y = label_y,
                  label = sprintf("%.1f", row_pct), vjust = vjust),
              inherit.aes = FALSE,
              colour = "white", size = 3.5, fontface = "bold") +
    scale_fill_manual(values = fill_vals,
                      breaks = unname(labs_map)) +
    scale_y_continuous(limits = c(0, 100.01), expand = c(0, 0)) +
    labs(title = plot_titles[[var]],
         x = "Education Group", y = "Percent (%)", fill = NULL) +
    theme_minimal(base_size = 12) +
    theme(legend.position = "bottom",
          panel.grid.major.x = element_blank(),
          plot.title = element_text(face = "bold", colour = uf_blue))
}

for (v in names(legend_labels)) {
  p <- make_plot(v)
  print(p)
  ggsave(file.path(dir_figures, paste0("MT_educ_stacked_", v, ".png")), p,
         width = 7, height = 5, dpi = 300)
}
