# =============================================================================
# 22_plot_died_by_edu.R  (DSC-01, DSC-02)
# Deck slides 5-7:
#   - histogram of years of education with normal curve      (slide 5)
#   - % died by single year of education, stacked by sex      (slide 6)
#   - % died by single year of education, stacked by surgery  (slide 7)
# Bar height = deaths / N at that year; segments sum to the bar total.
# Reads : exports/FIBRO_CLEAN.xlsx  (sas/01_import_clean.sas)
# Writes: figures/FYP_edu_histogram.png, FYP_died_by_edu_sex.png,
#         FYP_died_by_edu_surgery.png
# =============================================================================

source("R/00_config.R")
library(readxl)
library(dplyr)
library(ggplot2)
library(scales)

# ---- Settings ---------------------------------------------------------------
outcome  <- "Died_1yr"       # "Died_Any" for any recorded death (Q-08)
surg_var <- "Surgery_Type"   # not in fibro_clean yet (Q-10)
edu_max  <- 24               # x-axis 0..edu_max for the % died charts

# ---- Data -------------------------------------------------------------------
raw <- read_excel(file.path(dir_exports, "FIBRO_CLEAN.xlsx"))

df <- raw %>%
  mutate(edu  = round(as.numeric(Edu_Years_CWG)),
         died = as.integer(.data[[outcome]])) %>%
  filter(!is.na(edu), !is.na(died))

base_theme <- theme_minimal(base_size = 12) +
  theme(panel.grid.major.x = element_blank(),
        panel.grid.minor   = element_blank(),
        plot.title         = element_text(face = "bold", colour = uf_blue))

# ---- Slide 5: education histogram ------------------------------------------
m <- mean(df$edu); s <- sd(df$edu); bw <- 2
p_hist <- ggplot(df, aes(x = edu)) +
  geom_histogram(binwidth = bw, boundary = 0, fill = uf_blue, colour = "white") +
  stat_function(fun = function(x) dnorm(x, m, s) * nrow(df) * bw,
                colour = uf_orange, linewidth = 1.2) +
  labs(title = "Years of education",
       subtitle = sprintf("Mean = %.2f, SD = %.2f, range = %d-%d, N = %s",
                          m, s, min(df$edu), max(df$edu), comma(nrow(df))),
       x = "Years of education", y = "Frequency") +
  base_theme
print(p_hist)
ggsave(file.path(dir_figures, "FYP_edu_histogram.png"), p_hist, width = 7, height = 5, dpi = 300)

# ---- % died helpers ---------------------------------------------------------
df_bar <- df %>% filter(edu >= 0, edu <= edu_max)

died_by_edu <- function(data, group_var) {
  denom <- data %>% count(edu, name = "n_edu")
  data %>%
    filter(died == 1, !is.na(.data[[group_var]]), .data[[group_var]] != "") %>%
    count(edu, grp = .data[[group_var]], name = "deaths") %>%
    left_join(denom, by = "edu") %>%
    mutate(pct = deaths / n_edu)
}

x_scale <- scale_x_continuous(breaks = 0:edu_max, limits = c(-0.5, edu_max + 0.5), expand = c(0, 0))
y_scale <- scale_y_continuous(labels = percent_format(accuracy = 1),
                              expand = expansion(mult = c(0, 0.05)))

# ---- Slide 6: by sex --------------------------------------------------------
sex_tab <- died_by_edu(df_bar, "Sex") %>%
  filter(grp %in% c("Female", "Male")) %>%
  mutate(grp = factor(grp, levels = c("Female", "Male")))

p_sex <- ggplot(sex_tab, aes(x = edu, y = pct, fill = grp)) +
  geom_col(width = 0.8) +
  scale_fill_manual(values = c(Male = uf_blue, Female = uf_orange),
                    breaks = c("Male", "Female"), name = "Sex") +
  x_scale + y_scale +
  labs(title = "Percent died by years of education, by sex",
       x = "Years of education", y = "% died") +
  base_theme
print(p_sex)
ggsave(file.path(dir_figures, "FYP_died_by_edu_sex.png"), p_sex, width = 9, height = 6, dpi = 300)

# ---- Slide 7: by surgery type ----------------------------------------------
if (surg_var %in% names(df_bar)) {
  surg_levels <- c("Abdominal", "Cardiothoracovascular", "CNS",
                   "Head and Neck", "Musculoskeletalcutaneous", "OB")
  surg_tab <- died_by_edu(df_bar, surg_var) %>%
    mutate(grp = factor(grp, levels = surg_levels))
  surg_cols <- setNames(colorRampPalette(c("#00114F", uf_blue, "#C9D3F2"))(length(surg_levels)),
                        surg_levels)

  p_surg <- ggplot(surg_tab, aes(x = edu, y = pct, fill = grp)) +
    geom_col(width = 0.8) +
    scale_fill_manual(values = surg_cols, name = "Surgery type", drop = FALSE) +
    x_scale + y_scale +
    labs(title = "Percent died by years of education, by surgery type",
         x = "Years of education", y = "% died") +
    base_theme
  print(p_surg)
  ggsave(file.path(dir_figures, "FYP_died_by_edu_surgery.png"), p_surg, width = 10, height = 6, dpi = 300)
} else {
  message("Surgery type column '", surg_var, "' not in FIBRO_CLEAN - slide 7 chart skipped (Q-10).")
}

# ---- Counts behind the bars -------------------------------------------------
counts <- df_bar %>%
  group_by(edu) %>%
  summarise(n = n(), deaths = sum(died), .groups = "drop") %>%
  mutate(pct_died = round(100 * deaths / n, 1))
write.csv(counts, file.path(dir_qc, "22_died_by_edu_counts.csv"), row.names = FALSE)
print(counts, n = Inf)
