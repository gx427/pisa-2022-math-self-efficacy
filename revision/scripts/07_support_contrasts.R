# Complete-case estimates for the paired model changes and the six
# products reported in the article and Online Resource 1, Table S8.
# Run from the resource root after 01_prepare.R.
student <- readRDS("revision/data/analysis_raw.rds")
support <- c("FAMSUP", "RELATST")
experience <- c("MATHPERS", "ANXMAT", "BELONG")
initial <- c("ESCS", support, "FEMALE", "GRADE")
full <- c(initial, experience)
required <- c("MATHEFF", full)
replicate_weights <- paste0("W_FSTURWT", seq_len(80))
parts <- expand.grid(predictor=support, correlate=experience, stringsAsFactors=FALSE)
terms <- c(paste(support, "change"), paste(parts$predictor, parts$correlate))

estimate_system <- function(data) {
  x0 <- cbind(intercept=1, as.matrix(data[initial]))
  x1 <- cbind(x0, as.matrix(data[experience]))
  estimates <- function(weight) {
    initial_b <- lm.wfit(x0, data$MATHEFF, weight)$coefficients
    full_b <- lm.wfit(x1, data$MATHEFF, weight)$coefficients
    values <- unlist(lapply(experience, function(variable) {
      association <- lm.wfit(x0, data[[variable]], weight)$coefficients
      unname(association[support]) * unname(full_b[variable])
    }))
    setNames(c(unname(full_b[support]-initial_b[support]), values), terms)
  }
  q <- estimates(data$W_FSTUWT)
  rr <- vapply(replicate_weights, function(k) estimates(data[[k]]), numeric(length(q)))
  list(q=q, v=rowSums((rr-q)^2)/20)
}
fits <- lapply(c("HKG","TAP"), function(system) {
  eligible <- student$CNT==system & complete.cases(student[required])
  estimate_system(student[eligible,,drop=FALSE])
})
names(fits) <- c("HKG","TAP")
fits[["HKG-TAP"]] <- list(q=fits$HKG$q-fits$TAP$q, v=fits$HKG$v+fits$TAP$v)
result <- function(system, selected, keys) {
  q <- unname(fits[[system]]$q[selected])
  se <- sqrt(unname(fits[[system]]$v[selected]))
  data.frame(keys,system=system,estimate=q,se=se,lower=q-1.96*se,upper=q+1.96*se)
}
products <- do.call(rbind,lapply(names(fits),result,selected=3:8,keys=parts))
changes <- do.call(rbind,lapply(c("HKG","TAP"),result,selected=1:2,keys=data.frame(predictor=support)))
utils::write.csv(products,"revision/results/paths.csv",row.names=FALSE)
utils::write.csv(changes,"revision/results/support_changes.csv",row.names=FALSE)
