Sys.setlocale('LC_ALL','English_United States.utf8')
.libPaths(c('revision/R-library',.libPaths()))
library(splines)
d<-readRDS('revision/data/analysis_raw.rds')
vars<-c('MATHEFF','ESCS','FAMSUP','RELATST','MATHPERS','ANXMAT','BELONG','FEMALE','GRADE')
reps<-paste0('W_FSTURWT',1:80)
f<-MATHEFF~ESCS+FAMSUP+RELATST+MATHPERS+ANXMAT+BELONG+FEMALE+GRADE
res<-list();pr<-list();cvrows<-list()
for(g in c('HKG','TAP')) {
 a<-d[d$CNT==g & complete.cases(d[,vars]),]
 x<-model.matrix(f,a)[,-1];y<-a$MATHEFF
 fun<-function(w){xc<-x;yc<-y;for(j in seq_len(ncol(x)))xc[,j]<-x[,j]-ave(seq_along(y),a$CNTSCHID,FUN=function(ix)weighted.mean(x[ix,j],w[ix]));yc<-y-ave(seq_along(y),a$CNTSCHID,FUN=function(ix)weighted.mean(y[ix],w[ix]));lm.wfit(xc,yc,w)$coefficients}
 q<-fun(a$W_FSTUWT);rr<-sapply(reps,function(r)fun(a[[r]]));u<-tcrossprod(sweep(rr,1,q))/20;se<-sqrt(diag(u))
 res[[g]]<-data.frame(economy=g,analysis='School fixed effects',term=names(q),estimate=q,se=se,lower=q-1.96*se,upper=q+1.96*se)
 # Out-of-school validation uses identical complete cases and no model selection.
 set.seed(20260905);sch<-sample(unique(a$CNTSCHID));fold<-setNames(rep(1:5,length.out=length(sch)),sch);a$fold<-fold[as.character(a$CNTSCHID)]
 models<-list(Support=MATHEFF~ESCS+FAMSUP+RELATST+FEMALE+GRADE,Full=f,Nonlinear=MATHEFF~ns(ESCS,3)+ns(FAMSUP,3)+ns(RELATST,3)+ns(MATHPERS,3)+ns(ANXMAT,3)+ns(BELONG,3)+FEMALE+GRADE)
 for(n in names(models)) {
  yp<-rep(NA,nrow(a));for(k in 1:5){tr<-a[a$fold!=k,];te<-a[a$fold==k,];stopifnot(!any(unique(tr$CNTSCHID)%in%unique(te$CNTSCHID)));fit<-lm(models[[n]],data=tr,weights=W_FSTUWT);yp[a$fold==k]<-predict(fit,te)}
  w<-a$W_FSTUWT;err<-y-yp;r2<-1-sum(w*err^2)/sum(w*(y-weighted.mean(y,w))^2);rmse<-sqrt(weighted.mean(err^2,w));mae<-weighted.mean(abs(err),w)
  cvrows[[paste(g,n)]]<-data.frame(economy=g,model=n,n=nrow(a),schools=length(sch),folds=5,R2=r2,RMSE=rmse,MAE=mae)
  pr[[paste(g,n)]]<-data.frame(economy=g,model=n,school=a$CNTSCHID,fold=a$fold,observed=y,predicted=yp,weight=w)
 }
 # Alternate efficacy construct, all available cases; a separate sensitivity estimand.
 b<-a[!is.na(a$MATHEF21),];xx<-model.matrix(f,b);yy<-b$MATHEF21;fun2<-function(w)lm.wfit(xx,yy,w)$coefficients
 q<-fun2(b$W_FSTUWT);rr<-sapply(reps,function(r)fun2(b[[r]]));se<-sqrt(diag(tcrossprod(sweep(rr,1,q))/20))
 res[[paste0(g,'ALT')]]<-data.frame(economy=g,analysis='Reasoning self-efficacy',term=names(q),estimate=q,se=se,lower=q-1.96*se,upper=q+1.96*se)
}
write.csv(do.call(rbind,res),'revision/results/sensitivity_models.csv',row.names=FALSE)
write.csv(do.call(rbind,cvrows),'revision/results/school_validation.csv',row.names=FALSE)
write.csv(do.call(rbind,pr),'revision/results/heldout_predictions.csv',row.names=FALSE)
cat('VALIDATION COMPLETE\n')
