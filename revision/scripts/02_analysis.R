Sys.setlocale('LC_ALL','English_United States.utf8')
.libPaths(c('revision/R-library',.libPaths()))
library(mice)
library(survey)
set.seed(20260905)
d <- readRDS('revision/data/analysis_raw.rds')
out <- 'revision/results'
core <- c('MATHEFF','ESCS','FAMSUP','RELATST','MATHPERS','ANXMAT','BELONG','FEMALE','GRADE')
reps <- paste0('W_FSTURWT',1:80)
savecsv <- function(x,n) write.csv(x,file.path(out,paste0(n,'.csv')),row.names=FALSE)
summary_rows <- list(); missing_rows <- list(); flow <- list()
brr <- function(data,fun) {
 q <- fun(data$W_FSTUWT)
 rr <- matrix(vapply(reps,function(r) fun(data[[r]]),numeric(length(q))),nrow=length(q))
 delta <- sweep(rr,1,q)
 list(q=q,U=tcrossprod(delta)/20)
}
tabulate <- function(z,group,analysis) {
 se<-sqrt(diag(z$U)); q<-z$q
 data.frame(economy=group,analysis=analysis,term=names(q),estimate=as.numeric(q),se=se,lower=q-1.96*se,upper=q+1.96*se,p=2*pnorm(-abs(q/se)),row.names=NULL)
}
for(g in c('HKG','TAP')) {
 a<-d[d$CNT==g,]
 cc<-complete.cases(a[,core])
 flow[[g]]<-data.frame(economy=g,n=nrow(a),schools=length(unique(a$CNTSCHID)),outcome_observed=sum(!is.na(a$MATHEFF)),complete_case=sum(cc),complete_schools=length(unique(a$CNTSCHID[cc])),female_pct=100*weighted.mean(a$FEMALE,a$W_FSTUWT,na.rm=TRUE),mean_age=weighted.mean(a$AGE,a$W_FSTUWT,na.rm=TRUE))
 for(v in core) {
  ok<-!is.na(a[[v]]); av<-a[ok,]; x<-av[[v]]
  z<-brr(av,function(w) c(mean=weighted.mean(x,w)))
  summary_rows[[paste(g,v)]]<-data.frame(economy=g,variable=v,n=sum(ok),mean=z$q,se=sqrt(z$U[1,1]),sd=sqrt(weighted.mean((x-z$q)^2,av$W_FSTUWT)),lower=z$q-1.96*sqrt(z$U[1,1]),upper=z$q+1.96*sqrt(z$U[1,1]))
  missing_rows[[paste(g,v)]]<-data.frame(economy=g,variable=v,n_missing=sum(!ok),pct_missing=100*mean(!ok),weighted_pct=100*weighted.mean(!ok,a$W_FSTUWT))
 }
 pv<-lapply(1:10,function(i) brr(a,function(w) c(mean=weighted.mean(a[[paste0('PV',i,'MATH')]],w))))
 q<-mean(sapply(pv,function(x)x$q)); u<-mean(sapply(pv,function(x)x$U))+1.1*var(sapply(pv,function(x)x$q))
 summary_rows[[paste(g,'MATH')]]<-data.frame(economy=g,variable='MATH',n=nrow(a),mean=q,se=sqrt(u),sd=NA,lower=q-1.96*sqrt(u),upper=q+1.96*sqrt(u))
}
des<-do.call(rbind,summary_rows); savecsv(des,'descriptive');savecsv(do.call(rbind,flow),'sample_flow');savecsv(do.call(rbind,missing_rows),'missingness')
h<-des[des$economy=='HKG',];t<-des[des$economy=='TAP',]; stopifnot(identical(h$variable,t$variable))
se<-sqrt(h$se^2+t$se^2); diff<-h$mean-t$mean
savecsv(data.frame(variable=h$variable,difference_HKG_minus_TAP=diff,se=se,lower=diff-1.96*se,upper=diff+1.96*se,p=2*pnorm(-abs(diff/se))),'mean_differences')

# The same observed cases enter every equation and nested comparison.
forms<-list(
 support=MATHEFF~ESCS+FAMSUP+RELATST+FEMALE+GRADE,
 full=MATHEFF~ESCS+FAMSUP+RELATST+MATHPERS+ANXMAT+BELONG+FEMALE+GRADE,
 behaviour=MATHPERS~ESCS+FAMSUP+RELATST+FEMALE+GRADE,
 anxiety=ANXMAT~ESCS+FAMSUP+RELATST+FEMALE+GRADE,
 belonging=BELONG~ESCS+FAMSUP+RELATST+FEMALE+GRADE,
 family=FAMSUP~ESCS+FEMALE+GRADE,
 relationship=RELATST~ESCS+FEMALE+GRADE)
system_estimator<-function(a,alternate=FALSE) {
 ff<-forms
 if(alternate) {ff$full<-update(ff$full,MATHEF21~.);ff$support<-update(ff$support,MATHEF21~.)}
 xy<-lapply(ff,function(f){m<-model.frame(f,a);list(X=model.matrix(f,m),y=model.response(m))})
 function(w) {
  vals<-unlist(lapply(names(xy),function(n) {s<-xy[[n]];b<-lm.wfit(s$X,s$y,w)$coefficients;setNames(b,paste(n,names(b),sep=':'))}))
  at<-function(x)unname(vals[x])
  vals<-c(vals,ind_family_behaviour=at('behaviour:FAMSUP')*at('full:MATHPERS'),ind_relationship_anxiety=at('anxiety:RELATST')*at('full:ANXMAT'),ind_relationship_belonging=at('belonging:RELATST')*at('full:BELONG'),ind_SES_family_behaviour=at('family:ESCS')*at('behaviour:FAMSUP')*at('full:MATHPERS'),ind_SES_relationship_anxiety=at('relationship:ESCS')*at('anxiety:RELATST')*at('full:ANXMAT'))
  for(n in c('support','full')) {s<-xy[[n]]; b<-lm.wfit(s$X,s$y,w)$coefficients;r2<-1-sum(w*(s$y-s$X%*%b)^2)/sum(w*(s$y-weighted.mean(s$y,w))^2);vals<-c(vals,setNames(r2,paste0('R2:',n)))}
  vals
 }
}
ccfits<-list();mir<-list();alltabs<-list(); diagrows<-list()
for(g in c('HKG','TAP')) {
 cat('ECONOMY',g,'\n');flush.console()
 a<-d[d$CNT==g,];ac<-a[complete.cases(a[,core]),]
 z<-brr(ac,system_estimator(ac));ccfits[[g]]<-z
 alltabs[[paste0(g,'CC')]]<-tabulate(z,g,'Complete case')
 # Verification against the survey package for a representative regression.
 dd<-svrepdesign(data=ac,weights=~W_FSTUWT,repweights=ac[,reps],type='Fay',rho=.5,combined.weights=TRUE,mse=TRUE)
 chk<-svyglm(forms$full,design=dd)
 ix<-paste0('full:',names(coef(chk)))
 stopifnot(max(abs(z$q[ix]-coef(chk)))<1e-8,max(abs(sqrt(diag(z$U)[match(ix,names(z$q))])-sqrt(diag(vcov(chk)))) )<1e-7)
 # Achievement is an ancillary complete-case analysis with all ten PVs.
 pvs<-lapply(1:10,function(i) {
  x<-model.matrix(~MATHEFF+ESCS+FEMALE+GRADE,ac);y<-ac[[paste0('PV',i,'MATH')]]
  brr(ac,function(w){b<-lm.wfit(x,y,w)$coefficients;setNames(b,colnames(x))})
 })
 qs<-sapply(pvs,function(z)z$q);qp<-rowMeans(qs);up<-Reduce('+',lapply(pvs,function(z)z$U))/10+1.1*cov(t(qs))
 alltabs[[paste0(g,'PV')]]<-tabulate(list(q=qp,U=up),g,'Achievement 10 PV complete case')
 # Missing-covariate sensitivity, conditional on an observed self-efficacy outcome.
 ai<-a[!is.na(a$MATHEFF),]
 mi<-ai[,core];mi$PVaux<-rowMeans(ai[,paste0('PV',1:10,'MATH')]);mi$logweight<-log(ai$W_FSTUWT)
 for(v in core[1:7]) {
  sm<-ave(ai[[v]],ai$CNTSCHID,FUN=function(x)mean(x,na.rm=TRUE));sm[!is.finite(sm)]<-mean(ai[[v]],na.rm=TRUE)
  mi[[paste0('school_',v)]]<-sm
 }
 ini<-mice(mi,maxit=0,printFlag=FALSE)
 met<-ini$method;met[met!='']<-'pmm';met['MATHEFF']<-''
 pred<-ini$predictorMatrix;pred[met=='',]<-0
 imp<-mice(mi,m=20,maxit=10,method=met,predictorMatrix=pred,seed=20260905,printFlag=FALSE)
 saveRDS(imp,paste0('revision/data/imputation_',g,'.rds'))
 zs<-lapply(1:20,function(k){ak<-ai;ak[,core]<-complete(imp,k)[,core];brr(ak,system_estimator(ak))})
 qmat<-sapply(zs,function(x)x$q);qbar<-rowMeans(qmat);ubar<-Reduce('+',lapply(zs,function(x)x$U))/20;between<-cov(t(qmat));u<-ubar+1.05*between
 mir[[g]]<-list(q=qbar,U=u)
 tt<-tabulate(mir[[g]],g,'20 imputations')
 # Rubin degrees of freedom, rather than pretending MI uncertainty is known.
 riv<-1.05*diag(between)/pmax(diag(ubar),1e-20);dfmi<-19*(1+1/pmax(riv,1e-12))^2
 crit<-qt(.975,df=dfmi);tt$lower<-tt$estimate-crit*tt$se;tt$upper<-tt$estimate+crit*tt$se;tt$p<-2*pt(-abs(tt$estimate/tt$se),df=dfmi)
 alltabs[[paste0(g,'MI')]]<-tt
 events<-if(is.null(imp$loggedEvents))0 else nrow(imp$loggedEvents)
 diagrows[[g]]<-data.frame(economy=g,n=nrow(ai),imputations=20,iterations=10,logged_events=events)
 if(events)savecsv(imp$loggedEvents,paste0('MI_events_',g))
 cat('Finished',g,'\n');flush.console()
 savecsv(do.call(rbind,alltabs),'model_estimates')
}
savecsv(do.call(rbind,diagrows),'MI_diagnostics')
contrast<-function(fits,label){q<-fits$HKG$q-fits$TAP$q;u<-fits$HKG$U+fits$TAP$U;tabulate(list(q=q,U=u),'HKG minus TAP',label)}
cts<-rbind(contrast(ccfits,'Complete case'),contrast(mir,'20 imputations'))
key<-grepl('^full:(ESCS|FAMSUP|RELATST|MATHPERS|ANXMAT|BELONG)$',cts$term)
cts$p_holm<-NA; for(aa in unique(cts$analysis)){ix<-key&cts$analysis==aa;cts$p_holm[ix]<-p.adjust(cts$p[ix],'holm')}
savecsv(cts,'economy_contrasts')
saveRDS(list(complete=ccfits,imputed=mir),'revision/results/model_objects.rds')
capture.output(sessionInfo(),file='revision/audit/R_sessionInfo.txt')
cat('ANALYSIS COMPLETE\n')
