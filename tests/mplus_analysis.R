library(pmdplan)
local({
  root <- tempfile("analysis-tests-");dir.create(root,showWarnings=TRUE)
  on.exit(unlink(root,recursive=TRUE),add=TRUE)
  err <- function(code) stopifnot(inherits(tryCatch(force(code),error=identity),"error"))
  msg <- function(code) tryCatch(force(code),error=conditionMessage)
  obs <- c("y1","y2","y3","x1","x2","x3")
  d <- expand.grid(id=1:4,time=1:6)
  for (j in seq_along(obs)) d[[obs[j]]] <- seq_len(nrow(d))/10+j
  d$gender <- as.numeric(d$id %% 2);d$y2[c(1,4)]<-NA_real_
  d<-d[nrow(d):1,]
  a<-analyze_mplus(list(d,d),path=file.path(root,"default"),run=FALSE)
  stopifnot(all(a$manifest$status=="prepared"),
    !any(c("processors","biterations","max_iterations","mc.cores","path","usevariables","missing") %in% names(a)))
  syntax<-readLines(a$manifest$input[1])
  stopifnot(all(c("TYPE = TWOLEVEL RANDOM;","ESTIMATOR = BAYES;","PROCESSORS = 2;",
    "BITERATIONS = (1000);","TINTERVAL = time (1);","OUTPUT: TECH8;") %in% syntax),
    !any(grepl("MODEL PRIORS|MONTECARLO|FBITERATIONS",syntax)))
  exported<-read.table(a$manifest$dat[1],na.strings="-9999")
  expected<-d[order(d$id,d$time),];rownames(expected)<-NULL
  stopifnot(isTRUE(all.equal(unname(as.matrix(exported)),unname(as.matrix(expected)))))
  section<-function(x,start) x[(match(start,x)+1L):(match(";",x[(match(start,x)+1L):length(x)])+match(start,x)-1L)]
  stopifnot(identical(trimws(section(syntax,"NAMES ARE")),names(d)),
    identical(trimws(section(syntax,"USEVARIABLES ARE")),obs),
    basename(a$manifest$dat[1])=="data_rep1_analysis.dat")
  stopifnot(!any(c("usevariables","data_format") %in% names(formals(analyze_mplus))),
    !any(grepl("FORMAT =",syntax,fixed=TRUE)))
  small_items<-list(Sy="y1",Sx="y2",Ty="y1",Tx="y2")
  sel<-analyze_mplus(d,items=small_items,path=file.path(root,"selection"),run=FALSE)
  stopifnot(identical(trimws(section(readLines(sel$manifest$input),"USEVARIABLES ARE")),c("y1","y2")))
  for(flag in c(".","*","-9")) {
    sy<-analyze_mplus(d,missing=flag,path=tempfile(tmpdir=root),run=FALSE)
    stopifnot(sum(is.na(read.table(sy$manifest$dat,na.strings=flag)))==sum(is.na(d)),
      pmdplan:::.mplus_missing_flag(flag)$syntax %in% readLines(sy$manifest$input))
  }
  fixed<-file.path(root,"fixed.dat");writeLines(c("    1    1        1.00","    1    2  1.00  2.00"),fixed)
  fixed_script<-c("TITLE: Fixed-format input;", "DATA:",
    paste0('FILE = "',fixed,'";'), "FORMAT = (2F5.0,2F6.2);",
    "VARIABLE: NAMES = id time y1 y2; USEVARIABLES = y1 y2; MISSING = BLANK;",
    "ANALYSIS: ESTIMATOR = ML;", "MODEL: y1 WITH y2;")
  fx<-analyze_mplus(fixed,modelstring=fixed_script,path=tempfile(tmpdir=root),run=FALSE)
  stopifnot(fx$manifest$status=="prepared",identical(readLines(fx$manifest$input),fixed_script))
  err(analyze_mplus(fixed,data_names=c("id","time","y1","y2"),items=small_items,
    missing="BLANK",path=tempfile(tmpdir=root),run=FALSE))
  absent<-suppressWarnings(analyze_mplus(fixed,data_names=c("id","y1"),path=tempfile(tmpdir=root),run=FALSE))
  stopifnot(identical(absent$manifest$error,"Required names are missing from data_names: y2, y3, x1, x2, x3, time."))
  count_error<-"The number of metadata rows must equal the number of input datasets."
  stopifnot(identical(msg(analyze_mplus(list(d,d),metadata=data.frame(design="a",replication=1),
    path=tempfile(tmpdir=root),run=FALSE)),count_error))
  conflict<-d;conflict$phi1<-1
  cf<-suppressWarnings(analyze_mplus(conflict,path=tempfile(tmpdir=root),run=FALSE))
  stopifnot(grepl("Rename.*phi1",cf$manifest$error))
  nonnum<-d;nonnum$gender<-factor("female")
  nn<-suppressWarnings(analyze_mplus(nonnum,path=tempfile(tmpdir=root),run=FALSE))
  stopifnot(grepl("Recode.*gender",nn$manifest$error))
  gen<-generate_mplus_data(N=4,TT=6,replication=2,path=file.path(root,"generation"),run=FALSE)
  gs<-strsplit(gen$modelstring,"\n",fixed=TRUE)[[1L]]
  stopifnot(identical(gs[match("MODEL:",gs):length(gs)],syntax[match("MODEL:",syntax):length(syntax)]))
  gen$data<-list(d,d);gen$manifest$error<-""
  gf<-analyze_mplus(gen,path=file.path(root,"generation-input"),run=FALSE)
  stopifnot(all(gf$metadata$design=="complete"),all(gf$manifest$status=="prepared"))
  b<-pmd_batch(list(d,NULL),designs=list(occasions=function(data,seed)
    pmd_occasions(data,id="id",time="time",pmd_item = obs,interval=1,seed=seed)),
    metadata=data.frame(condition="scenario",replication=c(10,20)),directory=file.path(root,"batch"))
  b$data<-rev(b$data)
  fit<-suppressWarnings(analyze_mplus(b,path=file.path(root,"batch-fit"),run=FALSE,mc.cores=2,
    processors=3,biterations="80000 (2000)"))
  stopifnot(identical(fit$manifest$status,c("prepared","analysis_error")),
    identical(fit$metadata$replication,c(10,20)),length(fit$output)==2L,
    "BITERATIONS = 80000 (2000);" %in% readLines(fit$manifest$input[1]))
  rf<-suppressWarnings(analyze_mplus(b$manifest$file,metadata=b$manifest,path=file.path(root,"rds"),run=FALSE))
  stopifnot(identical(rf$manifest$status,c("prepared","analysis_error")))
  dat<-file.path(root,"external.dat");write.table(d,dat,row.names=FALSE,col.names=FALSE,na="-9999")
  txt<-analyze_mplus(dat,data_names=names(d),path=file.path(root,"external"),run=FALSE)
  stopifnot(txt$manifest$dat==normalizePath(dat),
    grepl(paste0('FILE = "',normalizePath(dat),'";'),paste(readLines(txt$manifest$input),collapse=""),fixed=TRUE),
    !any(grepl("[.]dat$",list.files(dirname(txt$manifest$input)))))
  bad<-d;bad$y1[1]<- -9999
  f<-suppressWarnings(analyze_mplus(list(bad,d),path=tempfile(tmpdir=root),run=FALSE))
  stopifnot(identical(f$manifest$status,c("analysis_error","prepared")))
  err(analyze_mplus(d,path=file.path(root,"default"),run=FALSE))
  for(value in c("1000; PROCESSORS=9","500 (2000)","(50001)","","-5","1.5","Inf"))
    err(analyze_mplus(d,biterations=value,path=tempfile(tmpdir=root),run=FALSE))
  for(value in c(0,1.5,NA_real_)) err(analyze_mplus(d,processors=value,path=tempfile(tmpdir=root),run=FALSE))
  socket<-analyze_mplus;env<-new.env(parent=environment(socket))
  env$.replication_apply<-pmdplan:::.psock_apply;environment(socket)<-env
  ps<-suppressWarnings(socket(list(d,NULL),path=file.path(root,"socket"),run=FALSE,mc.cores=2))
  stopifnot(identical(ps$manifest$status,c("prepared","analysis_error")),
    identical(readLines(ps$manifest$dat[1]),readLines(a$manifest$dat[1])))
  if(requireNamespace("MplusAutomation",quietly=TRUE)) {
    mock<-analyze_mplus;env<-new.env(parent=environment(mock))
    env$`::`<-function(pkg,name) {
      if(!identical(substitute(pkg),quote(MplusAutomation)))
        return(getExportedValue(as.character(substitute(pkg)),as.character(substitute(name))))
      function(target,...) {
        stopifnot(length(list(...))==0L,identical(getwd(),dirname(target)))
        if(startsWith(basename(dirname(target)),"fit1_")) writeLines("NORMAL",file.path(dirname(target),"analysis.out"))
        if(startsWith(basename(dirname(target)),"fit2_")) writeLines("*** ERROR",file.path(dirname(target),"analysis.out"))
      }
    }
    environment(mock)<-env;wd<-getwd()
    m<-suppressWarnings(mock(list(d,d,d),path=file.path(root,"mock")))
    stopifnot(identical(m$manifest$status,c("output_created","output_created","analysis_error")),identical(getwd(),wd))
  }
})
