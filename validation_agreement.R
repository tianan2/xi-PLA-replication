# =============================================================================
# validation_agreement.R
#
# Computes per-marker agreement statistics (raw agreement, Cohen's κ, precision,
# recall, F1) between the regex classifier and the blind hand-coded validation
# sample. Reproduces the numbers in Table A.1 of Appendix A.
#
# Inputs:
#   - validation_handcoded.csv  (hand-coded; coder fills in 0/1/?)
#   - validation_key.csv         (classifier output for the same 120 mentions)
#
# Outputs:
#   - Console report with per-marker agreement statistics
#   - validation_disagreements.csv (mention-level disagreements for inspection)
#
# Usage:
#   Rscript validation_agreement.R
#
# Dependencies: dplyr, tidyr, readr, purrr, stringr, glue
# =============================================================================

suppressPackageStartupMessages({
  required <- c("dplyr", "tidyr", "readr", "purrr", "stringr", "glue")
  missing <- setdiff(required, rownames(installed.packages()))
  if (length(missing) > 0) install.packages(missing, repos = "https://cloud.r-project.org")
  library(dplyr); library(tidyr); library(readr)
  library(purrr); library(stringr); library(glue)
})

# ---- Load -------------------------------------------------------------------
hand <- read_csv("validation_handcoded.csv", show_col_types = FALSE)
key  <- read_csv("validation_key.csv",        show_col_types = FALSE)

stopifnot(nrow(hand) == nrow(key))
stopifnot(all(hand$validation_id == key$validation_id))

# ---- Parse coder cells (handle "1", "0", "?", blank) ------------------------
parse_code <- function(x) {
  x_clean <- str_squish(as.character(x))
  case_when(
    x_clean == "1" ~ 1L,
    x_clean == "0" ~ 0L,
    TRUE           ~ NA_integer_
  )
}

# ---- Marker lookup ----------------------------------------------------------
marker_lookup <- tibble(
  marker      = c("Mantra-binding (B1)",
                  "Institutional embedding (C)",
                  "Personal command (A)"),
  hand_col    = c("hand_mantra_binding",
                  "hand_institutional",
                  "hand_xi_personal"),
  machine_col = c("machine_mantra_binding",
                  "machine_institutional",
                  "machine_xi_personal")
)

# ---- Reshape to one row per (validation_id, marker) -------------------------
hand_long <- hand |>
  mutate(across(all_of(marker_lookup$hand_col), parse_code)) |>
  select(validation_id, date, year, article_title, context_window, coder_notes,
         all_of(marker_lookup$hand_col)) |>
  pivot_longer(cols = all_of(marker_lookup$hand_col),
               names_to = "hand_col", values_to = "hand") |>
  left_join(marker_lookup |> select(marker, hand_col), by = "hand_col") |>
  select(-hand_col)

key_long <- key |>
  select(validation_id, date, year, all_of(marker_lookup$machine_col)) |>
  pivot_longer(cols = all_of(marker_lookup$machine_col),
               names_to = "machine_col", values_to = "machine") |>
  left_join(marker_lookup |> select(marker, machine_col), by = "machine_col") |>
  select(-machine_col)

merged <- hand_long |>
  inner_join(key_long, by = c("validation_id", "date", "year", "marker")) |>
  mutate(marker = factor(marker, levels = marker_lookup$marker))

# ---- Per-marker metrics -----------------------------------------------------
compute_metrics <- function(df) {
  coded     <- df |> filter(!is.na(hand) & !is.na(machine))
  ambiguous <- nrow(df) - nrow(coded)

  if (nrow(coded) == 0) {
    return(tibble(n_coded = 0L, n_ambiguous = ambiguous,
                  agreement = NA_real_, kappa = NA_real_,
                  precision = NA_real_, recall = NA_real_, f1 = NA_real_,
                  tp = 0L, fp = 0L, fn = 0L, tn = 0L))
  }

  cells <- coded |>
    count(hand, machine) |>
    complete(hand = c(0, 1), machine = c(0, 1), fill = list(n = 0))

  tn <- cells |> filter(hand == 0, machine == 0) |> pull(n)
  fp <- cells |> filter(hand == 0, machine == 1) |> pull(n)
  fn <- cells |> filter(hand == 1, machine == 0) |> pull(n)
  tp <- cells |> filter(hand == 1, machine == 1) |> pull(n)
  total <- tp + fp + fn + tn

  agreement <- (tp + tn) / total
  pe <- ((tp + fn) * (tp + fp) + (fp + tn) * (fn + tn)) / total^2
  kappa <- if (1 - pe == 0) NA_real_ else (agreement - pe) / (1 - pe)

  precision <- if ((tp + fp) > 0) tp / (tp + fp) else NA_real_
  recall    <- if ((tp + fn) > 0) tp / (tp + fn) else NA_real_
  f1 <- if (!is.na(precision) && !is.na(recall) && (precision + recall) > 0) {
    2 * precision * recall / (precision + recall)
  } else NA_real_

  tibble(n_coded = nrow(coded), n_ambiguous = ambiguous,
         agreement = agreement, kappa = kappa,
         precision = precision, recall = recall, f1 = f1,
         tp = tp, fp = fp, fn = fn, tn = tn)
}

results <- merged |>
  group_by(marker) |>
  group_modify(~ compute_metrics(.x)) |>
  ungroup()

# ---- Report -----------------------------------------------------------------
cat("##############################################\n")
cat("# CRS Validation Results\n")
cat(glue("# Total mentions in validation set: {n_distinct(merged$validation_id)}"), "\n",
    sep = "")
cat("##############################################\n")

walk(seq_len(nrow(results)), function(i) {
  r <- results[i, ]
  cat(glue("\n=== {r$marker} ==="), "\n")
  cat(glue("  N coded (excluding ?): {r$n_coded} ",
           "({r$n_ambiguous} ambiguous)"), "\n")
  cat(glue("  Agreement: {sprintf('%.1f%%', r$agreement * 100)}"), "\n")
  cat(glue("  Cohen's kappa: {sprintf('%.3f', r$kappa)}"), "\n")
  cat(glue("  Precision: {sprintf('%.1f%%', r$precision * 100)} ",
           "({r$tp} / {r$tp + r$fp})"), "\n")
  cat(glue("  Recall: {sprintf('%.1f%%', r$recall * 100)} ",
           "({r$tp} / {r$tp + r$fn})"), "\n")
  cat(glue("  F1: {sprintf('%.1f%%', r$f1 * 100)}"), "\n")
  cat("  Confusion matrix:\n")
  cm_print <- matrix(c(r$tn, r$fp, r$fn, r$tp), nrow = 2, byrow = TRUE,
                     dimnames = list(c("hand=0","hand=1"), c("mach=0","mach=1")))
  print(cm_print)
})

# ---- Save disagreements -----------------------------------------------------
disagreements <- merged |>
  filter(!is.na(hand), !is.na(machine), hand != machine) |>
  pivot_wider(
    id_cols     = c(validation_id, date, year, article_title, context_window,
                    coder_notes),
    names_from  = marker,
    values_from = c(hand, machine),
    names_glue  = "{.value}_{marker}"
  )

if (nrow(disagreements) > 0) {
  write_csv(disagreements, "validation_disagreements.csv")
  cat(glue("\nDisagreement cases saved: validation_disagreements.csv ",
           "(n = {nrow(disagreements)})"), "\n")
}
