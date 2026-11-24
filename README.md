# Family support, perceived student–teacher relationships and mathematics self-efficacy in Hong Kong and Chinese Taipei

This repository contains the R and Python code, aggregate results and figures for a study using the OECD PISA 2022 student questionnaire. The seven figures and 19 tables can be reproduced from the included aggregate results. Re-estimating the models requires the public student questionnaire file.

## Reproduce the figures and tables

From the repository root, run the following commands in a Python environment.

```sh
python -m pip install -r requirements.txt
python revision/scripts/draw_figures.py
python revision/scripts/06_tables.py
```

The figure renderer reads `reference/figure_data/` and creates seven vector PDFs and 600 dpi PNG and TIFF files in `revision/figures/`. It uses locally installed Arial regular and bold. On macOS or Linux, pass `--font-dir "/path/to/font-directory"` to the figure command, pointing to the directory containing `arial.ttf` and `arialbd.ttf`. The reference rendering environment used Python 3.12.14, ReportLab 4.4.9, pypdfium2 5.13.0 and Pillow 13.0.0. Other font or graphics-library versions may change file hashes.

The table script uses only the Python standard library. It writes four main tables, 15 supplementary tables and a captions-and-notes CSV to `revision/tables/`. The table inputs are in `reference/results/` and `reference/table_layout.json`.

## Running the analyses from the public data

The underlying data are the OECD PISA 2022 student questionnaire distributed at https://www.oecd.org/en/data/datasets/pisa-2022-database.html. Download the student SPSS file and place it at `revision/data/CY08MSP_STU_QQQ.SAV` (create the directory if needed). R 4.4.2 was used for the original analysis. Original version information is in `reference/original_R_session.txt`. Install haven, dplyr, tidyr, survey, mice and lavaan with their dependencies. The full workflow invokes the Python renderer and uses the same Arial font files. For non-Windows installations, set APER_FONT_DIR to their directory before starting R. Set APER_PYTHON to the Python executable if needed. The validation uses the splines package included with R.

```r
install.packages(c("haven", "dplyr", "survey", "mice", "lavaan", "tidyr"))
```

Use a fresh checkout for a full rerun. The measurement code will reuse fitted-model caches if present. Intermediate files include participant-level records and imputation objects and are created locally.

```
Rscript run.R all
python revision/scripts/06_tables.py --computed
```

## Contents

| Script | Analysis or output |
|---|---|
| 01_prepare.R | Reads the public student file, selects the two education systems and constructs the analysis file. |
| 02_analysis.R | Sample counts; weighted means; Fay replicate-weight regressions and coefficient products; ten plausible values; 20 imputations; between-system contrasts and multiple-testing correction. Includes a check against a survey-design regression. |
| 03_measurement.R | Ordered-item models across systems, fit and loadings, and the two-factor self-efficacy sensitivity analysis. |
| 04_validation.R | Within-school models, alternative self-efficacy outcome and five-fold prediction with schools held out. |
| 05_figures.R | Prepares plotting CSVs from the full analysis, including chain means, and invokes the Python renderer. |
| draw_figures.py | Draws Figures 1–7 from the plotting CSVs. |
| 06_tables.py | Tabulates the primary and supplementary tables from the aggregate estimates. |
| 07_support_contrasts.R | Re-estimates paired changes in the two support coefficients and all six exploratory products under the final weight and all 80 Fay replicate weights. Produces support_changes.csv and paths.csv. |
| 08_sensitivity_checks.R | Calculates the task-domain contrast in the percentage of confident respondents and nine missing-outcome scenarios for the observed index using all 80 Fay replicate weights. Produces task_domain_contrasts.csv and missing_outcome_scenarios.csv. |

The artwork/ directory contains Fig1–Fig7 as vector PDFs with embedded fonts and as LZW-compressed 600 dpi TIFF masters. Figure width is 174 mm. Manuscript images are 600 dpi PNGs rendered from the same vector files. The `reference/results/` directory contains the aggregate result files used for the paper. `reference/figure_data/` contains the original seven plotted datasets, including the Figure 5 chain means. `SHA256SUMS.txt` lists checksums of the distributed files. For Windows, the scripts request an English UTF-8 locale. The questionnaire is read directly from SPSS by haven.

The four additional result files are under reference/results/. In support_changes.csv the change is the full-model coefficient minus the corresponding initial-model coefficient, on the same students. Figure 3 shows three of the six coefficient products in Table S8, where the products involving proactive mathematics study behaviour are positive for both support measures in both systems. For each support measure and education system, summing the three unrounded estimates in `paths.csv` reproduces the initial coefficient minus the full coefficient in Figure 2 (the negative of the change in `support_changes.csv`). In paths.csv, HKG-TAP subtracts the Chinese Taipei estimate from the Hong Kong (China) estimate and adds their independent sampling variances. Intervals are pointwise. In missing_outcome_scenarios.csv, delta is the assumed difference in mean self-efficacy between students in the participating sample with missing and observed index scores in the same education system, in published index units. In task_domain_contrasts.csv all estimates are in percentage points on the confidence response scale.

## Data and licensing

The MIT license in `LICENSE` applies to the project scripts and their accompanying software documentation. Aggregate research outputs and figure files are distributed separately from this software grant. The original PISA microdata are available from the OECD under its applicable terms. Cite the OECD PISA 2022 database when using its data. Fonts and third-party libraries retain their own licenses.

- [OECD PISA 2022 database](https://www.oecd.org/en/data/datasets/pisa-2022-database.html)
- [OECD terms and conditions, section 3 on data](https://www.oecd.org/en/about/terms-conditions.html)

Individual records, school and student identifiers, and imputation objects are generated locally during a full analysis. The repository excludes these files through the rules for `revision/data/` and `revision/audit/` in `.gitignore`. The checksums in `SHA256SUMS.txt` cover every distributed file except the checksum list itself.
