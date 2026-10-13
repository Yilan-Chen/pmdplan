library(pmdplan)
local({
  data_env <- new.env(parent = emptyenv())
  data("affect", package = "pmdplan", envir = data_env)
  d <- data_env$affect
  stopifnot(
    identical(d, pmdplan::affect),
    identical(dim(d), c(9500L, 10L)),
    identical(names(d), c("N_index", paste0("x", 1:4), paste0("y", 1:4), "time")),
    length(unique(d$N_index)) == 125L,
    !anyNA(d), !anyDuplicated(d[c("N_index", "time")]),
    all(vapply(split(d$time, d$N_index), function(x) identical(x, seq_len(76)), logical(1))),
    all(as.matrix(d[2:9]) >= 0), all(as.matrix(d[2:9]) <= 100),
    identical(as.integer(d[1, ]), c(1L, 79L, 64L, 30L, 74L, 19L, 7L, 8L, 58L, 1L))
  )
  pmdplan:::.validate_panel(d, id = "N_index", time = "time", items = names(d)[2:9])
})
