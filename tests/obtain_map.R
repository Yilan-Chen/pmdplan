library(pmdplan)
if (requireNamespace("MplusAutomation", quietly = TRUE)) local({
  file <- system.file("extdata", "ex9.31.out", package = "MplusAutomation")
  stopifnot(nzchar(file))
  folder <- file.path(tempfile("pmd-map-"), "nested")
  full <- obtain_map(file, path = folder)
  csv <- file.path(folder, "map.csv")
  roundtrip <- utils::read.csv(csv, colClasses = "character", check.names = FALSE)
  stopifnot(file.exists(csv), identical(full, roundtrip), nrow(full) == 22L,
    identical(names(full), c("parameter", "paramHeader", "param", "BetweenWithin")),
    all(full$parameter == ""),
    inherits(tryCatch(read_mplus_estimates(file, full, cutoff = 1.05), error = identity), "error"))
  map <- full
  chosen <- map$paramHeader == "SY.ON" & map$param == "W" & map$BetweenWithin == "Between"
  map$parameter[chosen] <- "beta"
  map$parameter[2] <- NA_character_
  map$parameter[3] <- "  "
  utils::write.csv(map, csv, row.names = FALSE, na = "")
  map <- utils::read.csv(csv, colClasses = "character", check.names = FALSE)
  got <- read_mplus_estimates(file, map, cutoff = 1.05)
  stopifnot(nrow(got) == 1L, got$parameter == "beta", got$estimate == .12,
    got$sd == .016, got$lower == .09, got$upper == .151)
  evaluated <- evaluate_pmd(c(file, file), data.frame(parameter = "beta", value = .12),
    source = "mplus", metadata = data.frame(design = "anchor", replication = 1:2),
    map = map, cutoff = 1.05, mc.cores = 1)
  stopifnot(evaluated$n_attempted == 2L, evaluated$n_converged == 2L,
    all(attr(evaluated, "estimates")$parameter == "beta"))
  duplicate <- map; duplicate$parameter[2] <- "beta"
  stopifnot(inherits(tryCatch(read_mplus_estimates(file, duplicate, cutoff = 1.05), error = identity), "error"))
  # The complete map's identifiers need no summaries/TECH8, no concatenation,
  # and preserve otherwise-identical rows from Within and Between.
  mock <- obtain_map
  env <- new.env(parent = environment(mock))
  pars <- data.frame(paramHeader = "F.BY", param = "Y1",
    BetweenWithin = c("Within", "Between"), Group = "G1", LatentClass = 1L,
    est = c(.5, .8), se = .1)
  env$parsed <- list(parameters = list(unstandardized = pars))
  env$`::` <- function(pkg, name) {
    if (identical(substitute(pkg), quote(utils)))
      return(getExportedValue("utils", as.character(substitute(name))))
    stopifnot(identical(substitute(pkg), quote(MplusAutomation)),
      identical(substitute(name), quote(readModels)))
    function(...) env$parsed
  }
  environment(mock) <- env
  two <- mock(file, path = folder)
  stopifnot(nrow(two) == 2L, all(two$parameter == ""),
    identical(names(two), c("parameter", "paramHeader", "param", "BetweenWithin")))
  env$parsed$parameters$unstandardized <- pars[1, c("paramHeader", "param")]
  one <- mock(file, path = folder)
  stopifnot(identical(names(one), c("parameter", "paramHeader", "param")))
  env$parsed$parameters$unstandardized <- pars[c(1, 1), ]
  stopifnot(inherits(tryCatch(mock(file, path = folder), error = identity), "error"))
  unlink(dirname(folder), recursive = TRUE)
})
