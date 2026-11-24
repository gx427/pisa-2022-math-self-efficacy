# Descriptive checks on the published self-efficacy index and its task items.
# Run from the Online Resource 2 root after 01_prepare.R.
students <- readRDS("revision/data/analysis_raw.rds")
weights <- c("W_FSTUWT", paste0("W_FSTURWT", seq_len(80)))
items <- sprintf("ST290Q%02dWA", seq_len(9))
equations <- c(5L, 7L, 9L)

system_estimates <- function(data) {
  w <- as.matrix(data[weights])
  weighted_means <- function(x) {
    available <- !is.na(x)
    as.numeric(crossprod(x[available], w[available, , drop=FALSE])) /
      colSums(w[available, , drop=FALSE])
  }
  confidence <- vapply(items, function(item) {
    response <- data[[item]]
    stopifnot(all(is.na(response) | response %in% 1:4))
    weighted_means(as.numeric(response >= 3)) * 100
  }, numeric(length(weights)))
  list(mean=weighted_means(data$MATHEFF),
       missing=weighted_means(as.numeric(is.na(data$MATHEFF))),
       equations=rowMeans(confidence[, equations, drop=FALSE]),
       applied=rowMeans(confidence[, -equations, drop=FALSE]))
}
fits <- lapply(c("HKG", "TAP"), function(code) {
  system_estimates(students[students$CNT == code, , drop=FALSE])
})
names(fits) <- c("HKG", "TAP")
contrast <- function(hk, tp) {
  var_brr <- function(values) sum((values[-1] - values[1]) ^ 2) / 20
  estimate <- unname(hk[1] - tp[1])
  se <- sqrt(var_brr(hk) + var_brr(tp))
  data.frame(HKG=hk[1], TAP=tp[1], difference=estimate, se=se,
             lower=estimate-1.96*se, upper=estimate+1.96*se)
}
offsets <- expand.grid(delta_HKG=c(-0.5, 0, 0.5), delta_TAP=c(-0.5, 0, 0.5))
rows <- lapply(seq_len(nrow(offsets)), function(i) {
  h <- fits$HKG
  t <- fits$TAP
  contrast(h$mean + h$missing * offsets$delta_HKG[i],
           t$mean + t$missing * offsets$delta_TAP[i])
})
utils::write.csv(cbind(offsets, do.call(rbind, rows)),
                 "revision/results/missing_outcome_scenarios.csv", row.names=FALSE)
domains <- rbind(contrast(fits$HKG$equations, fits$TAP$equations),
                 contrast(fits$HKG$applied, fits$TAP$applied),
                 contrast(fits$HKG$equations - fits$HKG$applied,
                          fits$TAP$equations - fits$TAP$applied))
domains$domain <- c("Equation tasks", "Applied tasks", "Equation minus applied tasks")
utils::write.csv(domains, "revision/results/task_domain_contrasts.csv", row.names=FALSE)
