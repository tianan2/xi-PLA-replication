# Codebook: `crs_mentions_dataset.csv`

This dataset contains every occurrence of the term 军委主席负责制 (Chairman Responsibility System, CRS) in *PLA Daily* (解放军报) body text between 1 January 2018 and 31 December 2025, with the rhetorical-framing classifier outputs described in Appendix A of the article.

- **Unit of analysis**: one row per mention (3,054 rows). An article that invokes the CRS three times contributes three rows.
- **Encoding**: UTF-8.
- **Boolean columns**: encoded as integers (`1` = present, `0` = absent), not as TRUE/FALSE.
- **Date format**: ISO 8601 (YYYY-MM-DD).

## Columns

### Identifiers

| Column | Type | Description |
|---|---|---|
| `mention_id` | string | Unique identifier for each mention. Format: `M00001`–`M03054`, zero-padded. Stable across reruns of the extraction code. |
| `article_id` | string | Identifier for the article-page entry from which the mention was extracted. Format: `{date}_p{page}_{title-first-30-chars}`. Articles spanning multiple newspaper pages have one `article_id` per page. |

### Article metadata

| Column | Type | Description |
|---|---|---|
| `date` | string (YYYY-MM-DD) | Publication date. |
| `year` | integer | Calendar year, 2018–2025. |
| `page` | integer | Newspaper page on which the mention appears. *PLA Daily* is typically 12 pages; CRS mentions concentrate on pages 1–4. |
| `title` | string | Article title, normalized (whitespace collapsed, control characters removed). |
| `mention_idx_in_article` | integer | Zero-indexed position of this mention within its source article-page. `0` for the first occurrence, `1` for the second, etc. Useful for de-duplicating to article-level analysis. |

### Text

| Column | Type | Description |
|---|---|---|
| `window` | string | 400-character context window: 200 characters preceding the term, the term itself (军委主席负责制), and 200 characters following. Truncated at article boundaries. This is the text on which all classifier rules operate. |

### Primary markers (composite)

| Column | Type | Description |
|---|---|---|
| `mantra_binding` | 0/1 | The 'Two Upholds → CRS' chain. `1` if the window contains 两个维护 in conjunction with a CRS-implementation verb (贯彻 or 落实) such that the two are syntactically linked. Validated κ = 0.98. See Appendix A.2 for full regex. |
| `institutional_embedding` | 0/1 | The CRS appears alongside institutional-framework vocabulary describing Party leadership over the military as a fundamental institution. Constructed by combining `inst_narrow`, `inst_broader`, and `inst_constitutional` disjunctively, with an exclusion for cases where the institutional vocabulary appears only as part of a Two Upholds mantra recital (see Appendix A.2). Validated κ = 0.79. |
| `personal_command` | 0/1 | Direct Xi-personal command formulas in the window. `1` if any of `cmd_listen`, `cmd_responsible`, or `cmd_at_ease` is `1`. Validated κ = 0.53; precision = 92%, recall = 44%. Should be read as a lower bound on personal-command framing. |

### Constituent layers (for transparency and re-analysis)

| Column | Type | Description |
|---|---|---|
| `inst_narrow` | 0/1 | Layer 1 of `institutional_embedding`: the CRS itself described as a foundational institution (根本制度, 根本实现形式, 党章规定, 宪法规定, 最高层次, 统领地位, etc.). |
| `inst_broader` | 0/1 | Layer 2 of `institutional_embedding`: the CRS embedded within institutional descriptions of Party leadership over the military (党对军队绝对领导的根本原则和制度, 制度体系, 政治建军方略, 军事政策制度体系, etc.). |
| `inst_constitutional` | 0/1 | Layer 3 of `institutional_embedding`: codification in the Party Charter or Constitution (写入党章, 写入宪法, 党的根本大法, etc.). |
| `cmd_listen` | 0/1 | Personal command sub-pattern: 听/向 习主席/习近平 + 指挥/号令/看齐. |
| `cmd_responsible` | 0/1 | Personal command sub-pattern: 对/为 习主席/习近平 + 负责. |
| `cmd_at_ease` | 0/1 | Personal command sub-pattern: 让 习主席/习近平 + 放心/满意. |

## Notes for re-analysis

- The three constituent layers of `institutional_embedding` are reported separately to support sensitivity analyses. A reader who disagrees with the v3 specification can construct an alternative composite from the layer indicators.
- `institutional_embedding` is *not* the simple OR of the three `inst_*` layers because of the mantra-recital exclusion. Specifically: if `inst_broader = 1` but `inst_narrow = 0` and `inst_constitutional = 0`, and the window also satisfies the mantra-binding pattern, then `institutional_embedding = 0`. The full logic is reproduced in `code_classifier.R`.
- The CRS term itself (军委主席负责制) is not delimited or marked in the `window` column. The term appears at a position determined by the window construction: text up to 200 characters before, then the term, then up to 200 characters after. Use string search to locate the term within the window if needed for further analysis.
- Articles spanning multiple newspaper pages appear in this dataset as separate rows (one per page-entry) sharing publication date and title but with distinct `page` values and `article_id`s. Researchers wishing to collapse to article-level analysis should aggregate over `(date, title)` pairs.

## Provenance

Extracted from the digitized *PLA Daily* archive. Source corpus: 1,937 article-page entries flagged by the digitization pipeline as containing the term; 1,904 of these confirmed to contain the term in body text; from which 3,054 individual mentions were extracted with 200-character windows on each side. The article-page entries collapse to 1,581 unique articles when same-date-same-title rows are merged.

## Replication

To reproduce this dataset from the source *PLA Daily* corpus, run `code_classifier.R`. To reproduce the analyses and figures from this dataset, run `figures_and_stats.R`. See `README.md` for full instructions.
