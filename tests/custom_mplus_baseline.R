library(pmdplan)
local({
  root<-tempfile("custom-scripts-");dir.create(root,showWarnings=TRUE)
  on.exit(unlink(root,recursive=TRUE),add=TRUE)
  d<-expand.grid(id=1:3,time=1:4);d$y1<-seq_len(nrow(d));d$y2<-d$y1/3
  designs<-list(balanced=function(data,seed)
    pmd_occasions(data,id="id",time="time",pmd_item = c("y1","y2"),interval=1,seed=seed))
  base<-pmd_batch(list(d,d),designs=designs,seed=8)
  b<-pmd_batch(list(d,d),designs=designs,seed=8,include_complete=TRUE,directory=file.path(root,"batch"))
  stopifnot(length(b$data)==4L,identical(b$seeds,base$seeds),identical(b$data[names(base$data)],base$data),
    identical(b$data$r1_complete,d),identical(b$manifest$design,c("balanced","complete","balanced","complete")),
    all(is.na(b$manifest$seed[b$manifest$design=="complete"])),identical(readRDS(b$manifest$file[2]),d))
  scripts<-lapply(seq_len(nrow(b$manifest)),function(i)c(
    paste0("! task ",i,"; keep comments and spacing"),
    paste0("TITLE: ",b$manifest$design[i],";"),"DATA:",
    paste0('FILE = "data_rep',b$manifest$replication[i],'_',b$manifest$design[i],'.dat";'),
    "VARIABLE:","  NAMES = id time y1 y2;", "USEVARIABLES = y1 y2;", "MISSING = ALL(-9);",
    "ANALYSIS:","TYPE = GENERAL;", "ESTIMATOR = ML;", "MODEL:","y1 WITH y2;", "OUTPUT: SAMPSTAT;"))
  # Reordering b$data must not reorder manifest-position scripts.
  b$data<-rev(b$data)
  fit<-analyze_mplus(b,modelstring=scripts,missing=-9,mc.cores=2,path=file.path(root,"fit"),run=FALSE)
  stopifnot(all(fit$manifest$status=="prepared"),identical(fit$metadata$design,b$manifest$design),
    identical(fit$modelstring,scripts),is.null(fit$items))
  for(i in seq_along(scripts)) stopifnot(identical(readLines(fit$manifest$input[i]),scripts[[i]]))
  # File naming and baseline export match the corresponding script and manifest.
  stopifnot(basename(fit$manifest$dat[4])=="data_rep2_complete.dat",grepl("complete_rep2$",dirname(fit$manifest$input[4])),
    isTRUE(all.equal(unname(as.matrix(read.table(fit$manifest$dat[2]))),unname(as.matrix(d)))) )
  # Literal placeholders, repeated sections, long lines, indentation and blank lines
  # are all preserved: there is no parsing, replacement, or automatic wrapping.
  exact<-c("",paste0("!",strrep("x",150)),"TITLE: leave unchanged;", "DATA:",
    'FILE = "{data_file}";',"MODEL: y1;","MODEL: y2;","\t! user tab", "")
  shared<-analyze_mplus(c("not-looked-up-A.dat","not-looked-up-B.dat"),modelstring=exact,
    items=NULL,id=NULL,time=NULL,processors="ignored",biterations="ignored",missing="ignored",
    data_names=NULL,time_interval="ignored",path=file.path(root,"literal"),run=FALSE)
  for(file in shared$manifest$input) stopifnot(identical(readLines(file),exact))
  # Single multiline string is one shared script, not a script per character element.
  one<-paste(scripts[[1]],collapse="\n")
  sf<-analyze_mplus(list(d,d),modelstring=one,path=file.path(root,"shared"),run=FALSE)
  stopifnot(identical(readLines(sf$manifest$input[1]),scripts[[1]]),
    identical(readLines(sf$manifest$input[2]),scripts[[1]]))
  err<-function(code)stopifnot(inherits(tryCatch(force(code),error=identity),"error"))
  err(analyze_mplus(b,modelstring=scripts[1:3],path=tempfile(tmpdir=root),run=FALSE))
  err(analyze_mplus(b,modelstring=list(scripts[[1]]),path=tempfile(tmpdir=root),run=FALSE))
  for(bad in list(list(NULL,scripts[[1]],scripts[[1]],scripts[[1]]),rep(list(NA_character_),4),"   ",1))
    err(analyze_mplus(b,modelstring=bad,path=tempfile(tmpdir=root),run=FALSE))
  failed<-pmd_batch(list(NULL,d),list(bad=function(data,seed)stop("PMD failed")),include_complete=TRUE)
  ff<-suppressWarnings(analyze_mplus(failed,modelstring=scripts,path=file.path(root,"failed"),run=FALSE))
  stopifnot(identical(ff$manifest$status,c("analysis_error","analysis_error","analysis_error","prepared")),
    identical(readLines(ff$manifest$input[4]),scripts[[4]]))
  socket<-analyze_mplus;env<-new.env(parent=environment(socket));env$.replication_apply<-pmdplan:::.psock_apply;environment(socket)<-env
  ps<-socket(b,modelstring=scripts,missing=-9,mc.cores=2,path=file.path(root,"socket"),run=FALSE)
  for(i in seq_along(scripts))stopifnot(identical(readLines(ps$manifest$input[i]),scripts[[i]]))
  sb<-pmd_batch;env<-new.env(parent=environment(sb));env$.replication_apply<-pmdplan:::.psock_apply;environment(sb)<-env
  result<-sb(list(d,d),designs=designs,seed=8,include_complete=TRUE,mc.cores=2)
  stopifnot(identical(result$data,b$data[result$manifest$object]))
})
