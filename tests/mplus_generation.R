library(pmdplan)
local({
  pv <- list(within_loadings=c(x3=.6,y1=.8,x1=.8,y3=.6,y2=.6,x2=.6),
    between_loadings=.7,phi_mean=c(phi4=.05,phi2=.2,phi1=.2,phi3=.05),
    phi_variance=.001,mean_logerror=log(.3),var_logerror=.05,
    var_logre=.05,mean_logcov=log(.05),var_logcov=.01,
    intercepts=0,between_residual_variances=.2,latent_covariance=.2)
  items <- list(Sy=paste0("y",1:3), Sx=paste0("x",1:3),
    Ty=paste0("y",1:3), Tx=paste0("x",1:3))
  err <- function(code) stopifnot(inherits(tryCatch(force(code),error=identity),"error"))
  root <- tempfile("pmd-generation-test-")
  x <- generate_mplus_data(items, 10, 20, 2, population_values=pv, path=root, run=FALSE)
  stopifnot(file.exists(x$input), all(x$manifest$status=="not_run"), length(x$data)==2L,
    grepl("Sy BY y1@0.8(&1);", x$modelstring, fixed=TRUE),
    grepl("phi1@0.2",x$modelstring,fixed=TRUE),
    grepl("CSIZES = 10(20);",x$modelstring,fixed=TRUE),
    "NAMES ARE y1 y2 y3 x1 x2 x3;" %in% readLines(x$input),
    length(gregexpr("NREP =",x$modelstring,fixed=TRUE)[[1]])==1L)
  # Defaults are usable without a parameter-list preparation step.
  default <- generate_mplus_data(N=10,TT=20,replication=2,path=tempfile(),run=FALSE)
  stopifnot("TT" %in% names(formals(generate_mplus_data)),
    !"T" %in% names(formals(generate_mplus_data)), default$TT == 20, !"T" %in% names(default))
  shipped <- readLines(system.file("templates","default_dsem.inp",package="pmdplan"))
  stopifnot(identical(shipped, strsplit(default$modelstring,"\n",fixed=TRUE)[[1]]))
  default_items <- eval(formals(generate_mplus_data)$items)
  defaults <- eval(formals(generate_mplus_data)$population_values)
  stopifnot(length(default$items)==6L, identical(names(default_items),c("Sy","Sx","Ty","Tx")),
    !any(c("mean_logre","latent_means","latent_variances") %in% names(defaults)),
    !any(c("processors","fbiterations") %in% names(formals(generate_mplus_data))))
  for (constraint in c("[logVSy@0];","[logVSx@0];","[Ty@0];","[Tx@0];","Ty@1;","Tx@1;"))
    stopifnot(length(gregexpr(constraint, default$modelstring, fixed=TRUE)[[1]])==2L)
  stopifnot(grepl("PROCESSORS = 2;",default$modelstring,fixed=TRUE),
    grepl("FBITERATIONS = 100;",default$modelstring,fixed=TRUE),
    grepl("Sy BY y1*(&1);",default$modelstring,fixed=TRUE),
    !grepl("Ty BY y1@0.7(&1)",default$modelstring,fixed=TRUE))
  # No lower bound of three items: Mplus assesses feasibility.
  fewer <- list(Sy=c("y1","y2"),Sx=c("x1","x2"),Ty=c("y1","y2"),Tx=c("x1","x2"))
  pv_fewer <- pv; pv_fewer$within_loadings <- .7
  small <- generate_mplus_data(fewer,10,20,1,population_values=pv_fewer,path=tempfile(),run=FALSE)
  stopifnot(length(small$items)==4L)
  # Between assignments are read from Ty/Tx rather than inferred from Sy/Sx.
  switched <- items; switched$Ty <- items$Tx; switched$Tx <- items$Ty
  switched_input <- generate_mplus_data(switched,10,20,1,population_values=pv,path=tempfile(),run=FALSE)
  stopifnot(grepl("Ty BY x1@0.7;",switched_input$modelstring,fixed=TRUE))
  bad_fixed <- pv; bad_fixed$mean_logre <- .5
  err(generate_mplus_data(items,10,20,1,population_values=bad_fixed,path=tempfile(),run=FALSE))
  err(generate_mplus_data(items,10,20,2,population_values=pv,path=root,run=FALSE))
  bad <- pv; bad$phi_mean <- NULL
  err(generate_mplus_data(items,10,20,2,population_values=bad,path=tempfile(),run=FALSE))
  bad <- pv; bad$var_logerror <- -1
  err(generate_mplus_data(items,10,20,2,population_values=bad,path=tempfile(),run=FALSE))
  bad <- pv; bad$latent_covariance <- 2
  err(generate_mplus_data(items,10,20,2,population_values=bad,path=tempfile(),run=FALSE))
  custom <- c("ANALYSIS: TYPE = TWOLEVEL; ESTIMATOR = ML;", "MODEL POPULATION:",
    "%WITHIN%", "u1@1;", "%BETWEEN%", "u1@.2;", "MODEL:", "%WITHIN%", "u1;", "%BETWEEN%", "u1;")
  y <- generate_mplus_data("u1",2,2,2,modelstring=custom,path=tempfile(),run=FALSE)
  stopifnot(is.null(y$population_values),grepl("u1@.2;",y$modelstring,fixed=TRUE))
  err(generate_mplus_data("u1",2,2,2,modelstring=custom,population_values=pv,path=tempfile(),run=FALSE))
  err(generate_mplus_data("u1",2,2,2,modelstring=c("MONTECARLO: NREP=50;",custom),path=tempfile(),run=FALSE))
  err(generate_mplus_data(c("u1","U1"),2,2,2,modelstring=custom,path=tempfile(),run=FALSE))
  if (requireNamespace("MplusAutomation",quietly=TRUE)) {
    # Controlled external runner exercises reordered columns, missing replications,
    # and preserved metadata without requiring an Mplus licence in package tests.
    mock <- generate_mplus_data
    env <- new.env(parent=environment(mock))
    env$`::` <- function(pkg,name) {
      if (!identical(substitute(pkg),quote(MplusAutomation)))
        return(getExportedValue(as.character(substitute(pkg)),as.character(substitute(name))))
      function(target,...) {
        outdir <- dirname(target)
        stopifnot(length(list(...))==0L,identical(getwd(),outdir))
        writeLines(c("SAVEDATA INFORMATION","", "Order of variables","", "CLUSTER","U1","TIME","", "Save file","rep*.dat"),
          file.path(outdir,"generation.out"))
        utils::write.table(data.frame(id=c(1,1,2,2),u1=c(.1,.2,.3,.4),time=c(1,2,1,2)),
          file.path(outdir,"rep1.dat"),row.names=FALSE,col.names=FALSE)
      }
    }
    environment(mock) <- env
    wd <- getwd()
    z <- suppressWarnings(mock("u1",2,2,2,modelstring=custom,path=tempfile()))
    stopifnot(identical(getwd(),wd), identical(z$manifest$status,c("generated","generation_error")),
      identical(names(z$data[[1]]),c("id","time","u1")),
      identical(z$data[[1]]$u1,c(.1,.2,.3,.4)),is.null(z$data[[2]]),
      identical(readRDS(z$manifest$rds[1]),z$data[[1]]))
  }
})
