# From the extracted resource directory:
# Rscript run.R figures    or    Rscript run.R all
mode <- commandArgs(trailingOnly=TRUE)
if (length(mode) != 1L || !mode %in% c('all', 'figures')) {
    stop('Use Rscript run.R figures or Rscript run.R all')
}
for (path in c('revision/data','revision/audit','revision/results','revision/figures')) {
    dir.create(path, showWarnings=FALSE, recursive=TRUE)
}
if (mode == 'all' && !file.exists('revision/data/CY08MSP_STU_QQQ.SAV')) {
    stop('Place the OECD student file CY08MSP_STU_QQQ.SAV in revision/data')
}
Sys.setenv(APER_REPLAY_FIGURES=if (mode == 'figures') '1' else '0')
scripts <- if (mode == 'figures') '05_figures.R' else c(
    '01_prepare.R','02_analysis.R','03_measurement.R','04_validation.R','05_figures.R','07_support_contrasts.R','08_sensitivity_checks.R')
for (script in scripts) {
    message('Running ',script)
    source(file.path('revision','scripts',script), local=new.env(parent=globalenv()), encoding='UTF-8')
}
