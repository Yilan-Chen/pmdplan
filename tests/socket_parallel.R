library(pmdplan)
(function() {
  # Exercise the real Windows branch on any host, using actual PSOCK processes.
  dispatch <- pmdplan:::.replication_apply
  environment(dispatch) <- list2env(list(.Platform = list(OS.type = "windows")),
    parent = asNamespace("pmdplan"))
  workflow_env <- list2env(list(.replication_apply = dispatch), parent = asNamespace("pmdplan"))
  socket_batch <- pmd_batch; environment(socket_batch) <- workflow_env
  socket_evaluate <- evaluate_pmd; environment(socket_evaluate) <- workflow_env
  sockets <- function() {
    z <- showConnections(all = TRUE)
    z[z[, "class"] == "sockconn", , drop = FALSE]
  }
  before_sockets <- sockets()
  original_options <- getOption("pmdplan.ask_install")
  probe <- dispatch(1:4, function(i) {
    stopifnot(identical(getOption("pmdplan.ask_install"), FALSE))
    if (i == 2L) stop("intentional replication failure")
    if (i == 3L) return(NULL)
    list(index = i, pid = Sys.getpid())
  }, mc.cores = 2)
  stopifnot(length(probe) == 4L, is.null(probe[[1]]$error),
    probe[[2]]$error == "intentional replication failure",
    is.null(probe[[3]]$value), is.null(probe[[3]]$error),
    probe[[1]]$value$pid != probe[[4]]$value$pid,
    probe[[1]]$value$pid != Sys.getpid(),
    identical(sockets(), before_sockets),
    identical(getOption("pmdplan.ask_install"), original_options))

  # A user's top-level function can refer to constants and another global helper.
  globals <- c(".pmdplan_socket_items_test", ".pmdplan_socket_subsets_test",
    ".pmdplan_socket_helper_test", ".pmdplan_socket_design_test")
  stopifnot(!any(vapply(globals, exists, logical(1), envir = globalenv(), inherits = FALSE)))
  on.exit(rm(list = globals, envir = globalenv()), add = TRUE)
  assign(globals[1], paste0("y", 1:4), globalenv())
  assign(globals[2], list(A = c("y1", "y2"), B = c("y3", "y4")), globalenv())
  assign(globals[3], eval(quote(function(data, seed) pmd_forms(data,
    "id", "time", items = .pmdplan_socket_items_test, subsets = .pmdplan_socket_subsets_test,
    subsets_per_form = 1, design = "matrix", seed = seed)), envir = globalenv()), globalenv())
  assign(globals[4], eval(quote(function(data, seed)
    .pmdplan_socket_helper_test(data, seed)), envir = globalenv()), globalenv())
  designs <- list(matrix = get(globals[4], globalenv()),
    balanced = function(data, seed) pmd_occasions(data, "id", "time", paste0("y", 1:4), seed = seed))
  d <- expand.grid(id = 1:6, time = 1:6)
  for (item in paste0("y", 1:4)) d[[item]] <- seq_len(nrow(d))/10
  d$gender <- factor(ifelse(d$time == 1, "female", NA_character_))
  datasets <- list(d, d[-1, ], NULL)
  metadata <- data.frame(condition = "c", replication = 1:3)
  set.seed(107); seed_before <- .Random.seed
  serial <- pmd_batch(datasets, designs, metadata, seed = 62, mc.cores = 1)
  for (cores in 1:2) {
    actual <- socket_batch(datasets, designs, metadata, seed = 62, mc.cores = cores)
    stopifnot(identical(serial, actual), identical(.Random.seed, seed_before))
  }
  old_kind <- RNGkind()
  on.exit(do.call(RNGkind, as.list(old_kind)), add = TRUE)
  RNGkind("L'Ecuyer-CMRG"); set.seed(107); seed_before <- .Random.seed
  stopifnot(identical(pmd_batch(datasets, designs, metadata, seed = 62),
    socket_batch(datasets, designs, metadata, seed = 62, mc.cores = 2)),
    identical(.Random.seed, seed_before))
  do.call(RNGkind, as.list(old_kind))

  estimates <- data.frame(condition = "c", design = "matrix", replication = 1:2,
    parameter = "theta", estimate = c(1, 3), sd = 1,
    lower = c(0, 2), upper = c(2, 4), max_psr = c(1.01, 1.2))
  population_value <- data.frame(condition = "c", parameter = "theta", value = 2)
  for (cores in 1:2) stopifnot(identical(evaluate_pmd(estimates, population_value, n_factors = 1),
    socket_evaluate(estimates, population_value, n_factors = 1, mc.cores = cores)))
  if (requireNamespace("coda", quietly = TRUE)) {
    draws <- coda::mcmc.list(coda::mcmc(cbind(theta = 1:4)), coda::mcmc(cbind(theta = 2:5)))
    meta <- data.frame(condition = "c", design = "matrix", replication = 1:2)
    stopifnot(identical(
      suppressWarnings(evaluate_pmd(list(draws, NULL), population_value, source = "mcmc", metadata = meta, n_factors = 1)),
      suppressWarnings(socket_evaluate(list(draws, NULL), population_value, source = "mcmc", metadata = meta, n_factors = 1, mc.cores = 2))))
  }
  if (requireNamespace("MplusAutomation", quietly = TRUE)) {
    fixture <- system.file("extdata", "ex9.31.out", package = "MplusAutomation")
    if (nzchar(fixture)) {
      map <- data.frame(parameter = "beta", paramHeader = "SY.ON", param = "W", BetweenWithin = "Between")
      meta <- data.frame(condition = "c", design = "matrix", replication = 1:2)
      population_value <- data.frame(condition = "c", parameter = "beta", value = .12)
      # A custom limit must reach the Mplus reader on real PSOCK workers.
      capped <- socket_evaluate(fixture, population_value, source = "mplus",
        metadata = meta[1, ], map = map, n_factors = 1,
        max_iterations = 1500, mc.cores = 2)
      stopifnot(capped$convergence_rate == 0,
        attr(capped, "diagnostics")[[1]]$last_iteration == 2000,
        attr(capped, "diagnostics")[[1]]$max_iterations == 1500,
        identical(capped, evaluate_pmd(fixture, population_value, source = "mplus",
          metadata = meta[1, ], map = map, n_factors = 1, max_iterations = 1500)))
      stopifnot(identical(
        suppressWarnings(evaluate_pmd(c(fixture, paste0(fixture, ".absent")), population_value,
          source = "mplus", metadata = meta, map = map, n_factors = 1)),
        suppressWarnings(socket_evaluate(c(fixture, paste0(fixture, ".absent")), population_value,
          source = "mplus", metadata = meta, map = map, n_factors = 1, mc.cores = 2))))
    }
  }
  stopifnot(identical(sockets(), before_sockets))
  cat("PSOCK Windows dispatch: 1/2 workers, global design dependencies, all evaluation sources, errors, RNG parity and socket cleanup passed.\n")
})()
