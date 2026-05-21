# =============================================================================
# figures_and_stats.R
#
# Reproduces Figure 3 (CRS framing trajectories with Wilson confidence intervals)
# and Figure A.1 (yearly distribution of articles and mentions) from the
# coded mention-level dataset.
#
# Inputs:
#   - crs_mentions_dataset.csv
#
# Outputs:
#   - figure3.png      — Three-line plot of framing markers, 2018–2025
#   - figureA1.png     — Two-panel bar chart of articles and mentions by year
#   - figure3_table.csv  — Yearly point estimates and Wilson 95% CIs for each marker
#
# Usage:
#   Rscript figures_and_stats.R
#
# Dependencies: dplyr, tidyr, readr, ggplot2
# =============================================================================

suppressPackageStartupMessages({
  required <- c("dplyr", "tidyr", "readr", "ggplot2")
  missing <- setdiff(required, rownames(installed.packages()))
  if (length(missing) > 0) install.packages(missing, repos = "https://cloud.r-project.org")
  library(dplyr); library(tidyr); library(readr); library(ggplot2)
})

DATA_PATH  <- "crs_mentions_dataset.csv"
stopifnot(file.exists(DATA_PATH))

mentions <- read_csv(DATA_PATH, show_col_types = FALSE)

# ---- Wilson 95% confidence interval ----------------------------------------
wilson_ci <- function(k, n, z = 1.96) {
  if (n == 0) return(c(lo = NA_real_, hi = NA_real_))
  p <- k / n
  denom  <- 1 + z^2 / n
  centre <- (p + z^2 / (2 * n)) / denom
  half   <- z * sqrt(p * (1 - p) / n + z^2 / (4 * n^2)) / denom
  c(lo = max(0, centre - half), hi = min(1, centre + half))
}

# ---- Figure 3: yearly framing-marker shares with CIs -----------------------

markers <- tribble(
  ~marker_id,  ~marker_label,                                          ~color,    ~linetype, ~shape,
  "mantra",    "Mantra-binding (\"Two Upholds\" \u2192 CRS)",           "#993556", "solid",   16,
  "inst",      "Institutional embedding",                              "#185FA5", "solid",   17,
  "cmd",       "Direct Xi-personal command",                           "#888780", "dotted",  18
)

yearly <- mentions |>
  group_by(year) |>
  summarise(
    n        = n(),
    mantra_k = sum(mantra_binding),
    inst_k   = sum(institutional_embedding),
    cmd_k    = sum(personal_command),
    .groups  = "drop"
  )

# Reshape to long format with CIs
fig3_data <- yearly |>
  pivot_longer(
    cols = c(mantra_k, inst_k, cmd_k),
    names_to = "marker_id",
    values_to = "k"
  ) |>
  mutate(marker_id = sub("_k$", "", marker_id)) |>
  rowwise() |>
  mutate(
    p  = k / n,
    ci = list(wilson_ci(k, n)),
    lo = ci[["lo"]],
    hi = ci[["hi"]]
  ) |>
  ungroup() |>
  select(-ci) |>
  left_join(markers, by = "marker_id") |>
  mutate(marker_label = factor(marker_label, levels = markers$marker_label))

# Save the table of point estimates + CIs
write_csv(fig3_data |> select(year, marker_id, n, k, p, lo, hi),
          "figure3_table.csv")

p3 <- ggplot(fig3_data, aes(x = year, y = p * 100,
                            color = marker_label,
                            linetype = marker_label,
                            shape = marker_label,
                            group = marker_label)) +
  geom_line(linewidth = 0.9) +
  geom_point(size = 2.5) +
  geom_errorbar(aes(ymin = lo * 100, ymax = hi * 100),
                width = 0.18, linewidth = 0.5) +
  scale_color_manual(values = setNames(markers$color, markers$marker_label)) +
  scale_linetype_manual(values = setNames(markers$linetype, markers$marker_label)) +
  scale_shape_manual(values = setNames(markers$shape, markers$marker_label)) +
  scale_x_continuous(breaks = unique(fig3_data$year)) +
  scale_y_continuous(limits = c(0, 80), breaks = seq(0, 80, 10)) +
  labs(
    x = "Year",
    y = "% of CRS mentions in year (95% CI)",
    color = NULL, linetype = NULL, shape = NULL
  ) +
  theme_minimal(base_size = 11) +
  theme(
    panel.grid.minor   = element_blank(),
    panel.grid.major.x = element_blank(),
    panel.grid.major.y = element_line(linetype = "dotted",
                                       color = "gray70", linewidth = 0.3),
    axis.line          = element_line(color = "black", linewidth = 0.4),
    legend.position    = c(0.02, 0.98),
    legend.justification = c(0, 1),
    legend.background  = element_blank(),
    legend.key.width   = unit(1.2, "cm")
  )

ggsave("figure3.png", plot = p3, width = 10, height = 5.6, dpi = 200, bg = "white")
cat("Wrote figure3.png\n")

# ---- Figure A.1: yearly article and mention counts -------------------------

corpus_dist <- mentions |>
  group_by(year) |>
  summarise(
    # n_articles uses the (date, title) collapse to count unique articles,
    # since the same article spanning multiple newspaper pages appears as
    # multiple article-page entries (rows with distinct article_id values).
    # This matches the count reported in Appendix A.1.
    n_articles = n_distinct(paste(date, title, sep = "||")),
    n_mentions = n(),
    .groups = "drop"
  )

# Panel A
pA <- ggplot(corpus_dist, aes(x = factor(year), y = n_articles)) +
  geom_col(fill = "#5B7FA6", width = 0.62) +
  geom_text(aes(label = n_articles), vjust = -0.4, size = 3.2) +
  labs(x = "Year", y = "Number of articles",
       title = "(a) Articles containing CRS") +
  scale_y_continuous(limits = c(0, max(corpus_dist$n_articles) * 1.18)) +
  theme_minimal(base_size = 10) +
  theme(
    panel.grid.major.x = element_blank(),
    panel.grid.minor = element_blank(),
    plot.title = element_text(face = "bold", size = 11, hjust = 0)
  )

pB <- ggplot(corpus_dist, aes(x = factor(year), y = n_mentions)) +
  geom_col(fill = "#993556", width = 0.62) +
  geom_text(aes(label = n_mentions), vjust = -0.4, size = 3.2) +
  labs(x = "Year", y = "Number of CRS mentions",
       title = "(b) Individual CRS mentions") +
  scale_y_continuous(limits = c(0, max(corpus_dist$n_mentions) * 1.18)) +
  theme_minimal(base_size = 10) +
  theme(
    panel.grid.major.x = element_blank(),
    panel.grid.minor = element_blank(),
    plot.title = element_text(face = "bold", size = 11, hjust = 0)
  )

# Combine — requires patchwork or gridExtra; use gridExtra if available
if (!requireNamespace("patchwork", quietly = TRUE)) {
  install.packages("patchwork", repos = "https://cloud.r-project.org",
                   quiet = TRUE)
}
suppressPackageStartupMessages(library(patchwork))
pFA1 <- pA + pB + plot_layout(ncol = 2)

ggsave("figureA1.png", plot = pFA1, width = 10, height = 3.6, dpi = 200,
       bg = "white")
cat("Wrote figureA1.png\n")

cat("\nDone. Outputs: figure3.png, figureA1.png, figure3_table.csv\n")
