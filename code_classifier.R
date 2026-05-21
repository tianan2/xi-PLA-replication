# =============================================================================
# code_classifier.R
#
# Applies the rhetorical-framing classifier described in Appendix A of the
# article to a source corpus of *PLA Daily* articles. Produces the
# mention-level dataset (`crs_mentions_dataset.csv`).
#
# Inputs:
#   - A CSV of *PLA Daily* articles with at minimum the columns:
#       date (YYYY-MM-DD), year (integer), page (integer),
#       title_clean (string), content (string)
#     Set the path in CORPUS_PATH below.
#
# Output:
#   - crs_mentions_dataset.csv (3,054 rows × 17 columns, see CODEBOOK.md)
#
# Usage:
#   Rscript code_classifier.R
#
# Dependencies: dplyr, tidyr, stringr, readr, purrr
# =============================================================================

suppressPackageStartupMessages({
  required <- c("dplyr", "tidyr", "stringr", "readr", "purrr")
  missing <- setdiff(required, rownames(installed.packages()))
  if (length(missing) > 0) install.packages(missing, repos = "https://cloud.r-project.org")
  library(dplyr); library(tidyr); library(stringr); library(readr); library(purrr)
})

# ---- Configuration ----------------------------------------------------------
CORPUS_PATH <- "jfjb_corpus.csv"        # source *PLA Daily* corpus
OUTPUT_PATH <- "crs_mentions_dataset.csv"

TERM   <- "军委主席负责制"
WINDOW <- 200L  # characters on each side of the term

# ---- Load source corpus -----------------------------------------------------
stopifnot(file.exists(CORPUS_PATH))
corpus <- read_csv(CORPUS_PATH, show_col_types = FALSE) |>
  mutate(content = ifelse(is.na(content), "", as.character(content)))

cat(sprintf("Loaded %d article-page entries from %s\n",
            nrow(corpus), CORPUS_PATH))

# ---- Filter to articles where the term appears in body ----------------------
in_body <- corpus |>
  filter(str_detect(content, fixed(TERM)))

cat(sprintf("Article-page entries with term in body: %d\n", nrow(in_body)))

# ---- Construct stable article identifier (date + page + title-first-30) -----
in_body <- in_body |>
  mutate(
    article_id = paste0(
      as.character(date),
      "_p", str_pad(as.character(page), width = 2, pad = "0"),
      "_", str_sub(coalesce(title_clean, ""), 1, 30)
    )
  )

# ---- Extract every CRS occurrence with its 400-character window -------------
extract_windows <- function(text, term = TERM, window = WINDOW) {
  if (is.na(text) || nchar(text) == 0) return(character(0))
  hits <- str_locate_all(text, fixed(term))[[1]]
  if (nrow(hits) == 0) return(character(0))
  starts <- pmax(1L, hits[, "start"] - window)
  ends   <- pmin(nchar(text), hits[, "end"] + window)
  str_sub(text, starts, ends)
}

mentions <- in_body |>
  mutate(.windows = map(content, extract_windows)) |>
  filter(lengths(.windows) > 0) |>
  select(article_id, date, year, page, title = title_clean, .windows) |>
  mutate(.windows = map(.windows, ~ tibble(window = .x,
                                            mention_idx_in_article = seq_along(.x) - 1L))) |>
  unnest(.windows)

mentions <- mentions |>
  mutate(mention_id = sprintf("M%05d", row_number())) |>
  relocate(mention_id, .before = article_id)

cat(sprintf("Extracted %d mentions across %d article-page entries\n",
            nrow(mentions), n_distinct(mentions$article_id)))

# ---- Classifier rules -------------------------------------------------------
# All regular expressions follow ICU/PCRE syntax as implemented in stringr.

# --- Personal command (A) — three sub-patterns ---
re_cmd_listen      <- "(?:听|向)习(?:主席|近平).{0,4}(?:指挥|号令|看齐)"
re_cmd_responsible <- "(?:对|为)习(?:主席|近平).{0,3}负责"
re_cmd_at_ease     <- "让习(?:主席|近平).{0,3}(?:放心|满意)"

# --- Mantra-binding (B1) — two-direction Two Upholds → CRS chain ---
re_mantra_forward  <- "两个维护[^。]{0,40}(?:贯彻|落实).{0,10}军委主席负责制"
re_mantra_backward <- "(?:贯彻|落实).{0,10}军委主席负责制[^。]{0,40}两个维护"

# --- Institutional embedding (C, v3) — three layers ---
re_inst_narrow <- paste0(
  "(?:根本(?:实现形式|遵循|性的)|党章.{0,5}规定|宪法.{0,5}规定|",
  "最高(?:层次|领导)|统领(?:地位|作用)|",
  "根本制度.{0,15}(?:军委主席负责制|实现形式)|",
  "(?:军委主席负责制).{0,10}.{0,5}根本制度)"
)
re_inst_broader <- paste0(
  "根本原则.{0,5}(?:和|与).{0,5}制度|",
  "党对军队.{0,8}(?:绝对领导|领导).{0,15}(?:根本|制度|原则)|",
  "党指挥枪.{0,10}(?:根本原则|制度)|",
  "党(?:领导|建设)军队.{0,10}(?:制度体系|制度安排|根本)|",
  "(?:领导|建军|强军|军队建设).{0,3}(?:法治保障|制度优势)|",
  "军事(?:政策)?制度体系|",
  "政治建军.{0,5}(?:方略|制度)|",
  "(?:中国特色)?(?:社会主义)?军事(?:政策|领导)?制度"
)
re_inst_constitutional <- paste0(
  "写入.{0,3}(?:党章|宪法)|",
  "(?:党章|宪法).{0,8}(?:确立|规定|载入|写入)|",
  "(?:确立|写入|载入).{0,8}(?:党章|宪法)|",
  "(?:党章和宪法|宪法和党章)|",
  "党的根本大法"
)

# Mantra-recital exclusion pattern: the broader-framework formula embedded
# inside a Two Upholds recital functions as part of the mantra, not as
# independent institutional framing.
re_mantra_recital <- paste0(
  "党对军队.{0,15}绝对领导.{0,10}根本原则.{0,5}和.{0,5}制度.{0,30}",
  "(?:增强.{0,5}四个意识|做到.{0,5}两个维护|贯彻.{0,10}军委主席负责制)"
)

# ---- Apply rules ------------------------------------------------------------
coded <- mentions |>
  mutate(
    # Personal command sub-patterns
    cmd_listen       = as.integer(str_detect(window, re_cmd_listen)),
    cmd_responsible  = as.integer(str_detect(window, re_cmd_responsible)),
    cmd_at_ease      = as.integer(str_detect(window, re_cmd_at_ease)),
    personal_command = pmax(cmd_listen, cmd_responsible, cmd_at_ease),

    # Mantra-binding
    mantra_binding   = as.integer(
      str_detect(window, re_mantra_forward) |
      str_detect(window, re_mantra_backward)
    ),

    # Institutional embedding — three layers
    inst_narrow         = as.integer(str_detect(window, re_inst_narrow)),
    inst_broader        = as.integer(str_detect(window, re_inst_broader)),
    inst_constitutional = as.integer(str_detect(window, re_inst_constitutional)),

    # Composite with mantra-recital exclusion
    .inst_raw      = pmax(inst_narrow, inst_broader, inst_constitutional),
    .is_mantra     = as.integer(str_detect(window, re_mantra_forward)),
    .recital_excl  = as.integer(
      .inst_raw == 1 & inst_narrow == 0 & inst_constitutional == 0 &
      .is_mantra == 1 & str_detect(window, re_mantra_recital)
    ),
    institutional_embedding = as.integer(.inst_raw == 1 & .recital_excl == 0)
  ) |>
  select(
    mention_id, article_id, date, year, page, title,
    mention_idx_in_article, window,
    mantra_binding,
    institutional_embedding,
    inst_narrow, inst_broader, inst_constitutional,
    personal_command,
    cmd_listen, cmd_responsible, cmd_at_ease
  )

# ---- Write output -----------------------------------------------------------
write_csv(coded, OUTPUT_PATH)
cat(sprintf("Wrote %s: %d rows × %d columns\n",
            OUTPUT_PATH, nrow(coded), ncol(coded)))

# ---- Sanity check: yearly marker shares -------------------------------------
yearly <- coded |>
  group_by(year) |>
  summarise(
    n_mentions   = n(),
    mantra_pct   = round(mean(mantra_binding) * 100, 1),
    inst_pct     = round(mean(institutional_embedding) * 100, 1),
    cmd_pct      = round(mean(personal_command) * 100, 1),
    .groups = "drop"
  )
cat("\nYearly marker shares (sanity check vs Figure 3):\n")
print(yearly)
