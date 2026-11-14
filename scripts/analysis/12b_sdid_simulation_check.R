# 12b_sdid_simulation_check.R: checks the hand-written synthetic DiD in 12_synthetic_did.R on simulated data
# (factor model, treated unit with an unusual loading, true effect 0.5; 300 replications).
# Result 12 Nov 2026: SDID mean 0.535 (sd 0.10), SC 0.595 (0.36), DiD 1.135 (0.44).
setwd(here::here())
suppressMessages(library(tidyverse))
source("scripts/analysis/sdid_functions.R")
set.seed(1)
res <- replicate(300, {
  N0 <- 40; Tn <- 20; T0 <- 14
  f <- cumsum(rnorm(Tn, 0.1, 0.3)); load <- runif(N0 + 1, 0, 2); load[N0 + 1] <- 1.6
  a <- rnorm(N0 + 1, 0, 2); tt <- cumsum(rnorm(Tn, 0, 0.2))
  Y <- outer(a, rep(1, Tn)) + outer(rep(1, N0 + 1), tt) + outer(load, f) + matrix(rnorm((N0 + 1) * Tn, 0, 0.1), N0 + 1)
  Y[N0 + 1, (T0 + 1):Tn] <- Y[N0 + 1, (T0 + 1):Tn] + 0.5
  rownames(Y) <- c(paste0("c", 1:N0), "TR"); colnames(Y) <- 2000:(1999 + Tn)
  c(sdid = sdid_fit(Y, T0, "sdid")$tau, sc = sdid_fit(Y, T0, "sc")$tau, did = sdid_fit(Y, T0, "did")$tau)
})
print(round(rbind(mean = rowMeans(res), sd = apply(res, 1, sd), rmse = sqrt(rowMeans((res - 0.5)^2))), 3))
