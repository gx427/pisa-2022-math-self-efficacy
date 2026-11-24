Sys.setlocale('LC_ALL','English_United States.utf8')
.libPaths(c('revision/R-library',.libPaths()))
library(lavaan)
d<-readRDS('revision/data/analysis_raw.rds')
sets<-list(MATHEFF=paste0('ST290Q0',1:9,'WA'),ANXMAT=paste0('ST292Q0',1:6,'JA'),BELONG=paste0('ST034Q0',1:6,'TA'),RELATST=paste0('ST267Q0',1:8,'JA'),FAMSUP=sprintf('ST300Q%02dJA',1:10))
rev4<-c('ST034Q01TA','ST034Q04TA','ST034Q06TA','ST267Q04JA','ST267Q08JA')
for(n in rev4)d[[n]]<-5-d[[n]]
results<-list();loadingrows<-list();itemrows<-list()
for(n in names(sets)) {
 items<-sets[[n]]
 for(g in c('HKG','TAP'))for(v in items){a<-d[d$CNT==g,];itemrows[[paste(n,g,v)]]<-data.frame(scale=n,economy=g,item=v,missing_pct=100*mean(is.na(a[[v]])),n=sum(!is.na(a[[v]])))}
 for(spec in c('configural','loadings','thresholds')) {
  cat(n,spec,'\n');flush.console()
  eq<-switch(spec,configural=character(0),loadings='loadings',thresholds=c('loadings','thresholds'))
  cache<-paste0('revision/results/CFA_',n,'_',spec,'.rds')
  fit<-if(file.exists(cache))readRDS(cache) else tryCatch(cfa(paste('f =~',paste(items,collapse='+')),data=d,group='CNT',group.equal=eq,ordered=items,estimator='WLSMV',missing='pairwise',sampling.weights='W_FSTUWT',std.lv=TRUE),error=function(e){cat(conditionMessage(e),'\n');NULL})
  if(is.null(fit))next
  fm<-fitMeasures(fit,c('cfi.scaled','tli.scaled','rmsea.scaled','srmr','df.scaled'))
  results[[paste(n,spec)]]<-data.frame(scale=n,model=spec,converged=lavInspect(fit,'converged'),CFI=fm[1],TLI=fm[2],RMSEA=fm[3],SRMR=fm[4],df=fm[5],row.names=NULL)
  if(spec=='configural'){p<-standardizedSolution(fit);p<-p[p$op=='=~',];p$scale<-n;loadingrows[[n]]<-p}
  saveRDS(fit,paste0('revision/results/CFA_',n,'_',spec,'.rds'))
  write.csv(do.call(rbind,results),'revision/results/measurement_fit.csv',row.names=FALSE)
 }
}
write.csv(do.call(rbind,loadingrows),'revision/results/measurement_loadings.csv',row.names=FALSE)
write.csv(do.call(rbind,itemrows),'revision/results/item_missingness.csv',row.names=FALSE)
# A content-based two-factor sensitivity for efficacy; not substituted for the OECD WLE.
model2<-'applied =~ ST290Q01WA+ST290Q02WA+ST290Q03WA+ST290Q04WA+ST290Q06WA+ST290Q08WA
algebra =~ ST290Q05WA+ST290Q07WA+ST290Q09WA'
fit2<-cfa(model2,data=d,group='CNT',ordered=sets$MATHEFF,estimator='WLSMV',missing='pairwise',sampling.weights='W_FSTUWT',std.lv=TRUE)
fm2<-fitMeasures(fit2,c('cfi.scaled','tli.scaled','rmsea.scaled','srmr'))
write.csv(data.frame(CFI=as.numeric(fm2[1]),TLI=as.numeric(fm2[2]),RMSEA=as.numeric(fm2[3]),SRMR=as.numeric(fm2[4])),'revision/results/efficacy_twofactor.csv',row.names=FALSE)
saveRDS(fit2,'revision/results/CFA_efficacy_twofactor.rds')
cat('MEASUREMENT COMPLETE\n')
