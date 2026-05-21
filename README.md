# Replication Materials

This directory contains the replication materials for the analysis of CRS rhetorical framing in *PLA Daily* presented in the article and its Appendix A.

## Contents

| File | Description |
|---|---|
| `README.md` | This file. |
| `CODEBOOK.md` | Variable-level documentation for `crs_mentions_dataset.csv`. |
| `crs_mentions_dataset.csv` | Mention-level coded dataset (3,054 rows × 17 columns). The primary analytical artifact. |
| `code_classifier.R` | R script implementing the classifier and producing `crs_mentions_dataset.csv` from a source *PLA Daily* corpus. |
| `figures_and_stats.R` | R script reproducing Figure 3 and Figure A.1 from `crs_mentions_dataset.csv`. |
| `validation_blind.csv` | The 120-mention validation sample with empty coding columns, for re-validation by a second coder. |
| `validation_key.csv` | Classifier outputs for the validation sample (do not consult before coding). |
| `validation_handcoded.csv` | The hand-coded validation file used to produce Table A.1. |
| `validation_agreement.R` | R script computing per-marker agreement statistics, reproducing Table A.1. |

## What you can reproduce

Without the source *PLA Daily* corpus:

- Figure 3 and Figure A.1 from `crs_mentions_dataset.csv` (run `figures_and_stats.R`).
- The yearly point estimates and 95% Wilson confidence intervals for each framing marker (output to `figure3_table.csv`).
- Table A.1 validation statistics (run `validation_agreement.R`).
- The list of validation cases where the classifier and hand coding disagree (output to `validation_disagreements.csv`).

To reproduce the full pipeline from raw articles to coded mentions, you will need access to the *PLA Daily* corpus referenced in Section A.1 of the appendix. Researchers with archive access can reconstruct it using the article identifiers (`date`, `page`, `title`) recorded in `crs_mentions_dataset.csv`. The corpus expected by `code_classifier.R` is a CSV file with at minimum these columns: `date` (YYYY-MM-DD), `year` (integer), `page` (integer), `title_clean` (string), `content` (string).

## How to run

All scripts are R scripts. Install dependencies (one-time) and run:

```bash
# Reproduce the figures and statistics
Rscript figures_and_stats.R

# Reproduce the validation results (Table A.1)
Rscript validation_agreement.R

# To re-run the classifier on a source corpus (advanced):
# 1. Place the source corpus as `jfjb_corpus.csv` in this directory
# 2. Run:
Rscript code_classifier.R
```

The scripts auto-install any missing R packages from CRAN. Required packages: `dplyr`, `tidyr`, `readr`, `purrr`, `stringr`, `glue`, `ggplot2`, `patchwork`.

## Notes on data structure

The dataset uses two identifier columns that are easy to confuse:

- `mention_id`: a unique identifier for each individual occurrence of the CRS term (3,054 unique values, format `M00001`–`M03054`).
- `article_id`: a unique identifier for each *article-page entry* (1,904 unique values, format `{date}_p{page}_{title}`).

Articles that span multiple newspaper pages appear as multiple `article_id` values sharing the same date and title. When `figures_and_stats.R` counts "articles" for Figure A.1, it collapses these to unique (date, title) pairs (1,581 unique articles), matching the count reported in Section A.1 of the appendix.

## Two coder caveats for re-validation

If a second coder wants to validate the classifier independently using `validation_blind.csv`:

1. Code without consulting `validation_key.csv` or `validation_handcoded.csv`. Open only the blind file in your editor.
2. Save your output as `validation_handcoded_secondcoder.csv` and modify the input path in `validation_agreement.R` to compute inter-coder agreement, or compute it directly against `validation_handcoded.csv` to compute coder-vs-coder agreement.

## Provenance and version

This replication set corresponds to the article as submitted to *Journal of Strategic Studies*. The `crs_mentions_dataset.csv` was produced by running `code_classifier.R` against a *PLA Daily* corpus covering 1 January 2018 through 31 December 2025.
