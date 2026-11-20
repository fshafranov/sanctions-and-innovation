# sdid_functions.R: synthetic DiD, synthetic control and DiD estimators with placebo inference, shared by
# 12_synthetic_did.R, 12b_sdid_simulation_check.R and 12d_sdid_covariates.R (method description: header of 12).
suppressPackageStartupMessages(library(quadprog))

# minimise |A w - b|^2 + r |w|^2 over the simplex (intercept handled by centring A and b beforehand)
simplex_ls <- function(A, b, r) {
  k <- ncol(A)
  D <- crossprod(A) + diag(r + 1e-10 * max(1, mean(diag(crossprod(A)))), k)
  sol <- solve.QP(Dmat = 2 * D, dvec = 2 * drop(crossprod(A, b)), Amat = cbind(1, diag(k)), bvec = c(1, rep(0, k)),
                  meq = 1)$solution
  pmax(sol, 0) / sum(pmax(sol, 0))
}

# Y: matrix, rows = units (treated LAST), cols = years; T0 = number of pre years
sdid_fit <- function(Y, T0, method = "sdid") {
  N0 <- nrow(Y) - 1; Tn <- ncol(Y); pre <- 1:T0; post <- (T0 + 1):Tn
  Yc <- Y[1:N0, , drop = FALSE]; ytr <- Y[N0 + 1, ]
  sig <- sd(as.vector(t(apply(Yc[, pre, drop = FALSE], 1, diff))))
  if (method == "did") {
    w <- rep(1 / N0, N0); l <- rep(1 / T0, T0)
  } else if (method == "sc") {
    w <- simplex_ls(t(Yc[, pre, drop = FALSE]), ytr[pre], 0); l <- rep(0, T0)
  } else {
    zeta <- (1 * length(post))^(1 / 4) * sig
    A <- t(Yc[, pre, drop = FALSE]); A <- sweep(A, 2, colMeans(A)); b <- ytr[pre] - mean(ytr[pre])
    w <- simplex_ls(A, b, zeta^2 * T0)
    B <- Yc[, pre, drop = FALSE]; B <- sweep(B, 2, colMeans(B)); d <- rowMeans(Yc[, post, drop = FALSE])
    l <- simplex_ls(B, d - mean(d), (1e-6 * sig)^2 * N0)
  }
  synth <- drop(crossprod(w, Yc))
  gap <- ytr - synth
  base <- if (method == "sc") 0 else sum(l * gap[pre])
  list(tau = mean(gap[post]) - base, w = setNames(w, rownames(Y)[1:N0]), l = setNames(l, colnames(Y)[pre]),
       path = tibble(year = as.integer(colnames(Y)), treated = ytr, synthetic = synth + base, gap = gap - base),
       pre_rmse = sqrt(mean((gap[pre] - base)^2)))
}

placebo <- function(Y, T0, method) {
  N0 <- nrow(Y) - 1
  map_dbl(1:N0, function(j) sdid_fit(Y[c(setdiff(1:N0, j), j), , drop = FALSE], T0, method)$tau)
}
