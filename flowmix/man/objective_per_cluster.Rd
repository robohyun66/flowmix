% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/mstep-admm.R
\name{objective_per_cluster}
\alias{objective_per_cluster}
\title{(Helper) calculates the per-cluster objective value for the ADMM. Super
inefficient right now.}
\usage{
objective_per_cluster(
  beta,
  ylist,
  Xa,
  resp,
  lambda,
  N,
  dimdat,
  iclust,
  sigma,
  iter,
  zerothresh,
  first_iter,
  sigma_eig_by_clust = NULL,
  rcpp = FALSE
)
}
\arguments{
\item{beta}{p x d matrix}

\item{ylist}{T-length list each containing response matrices of size (nt x
3), which contains coordinates of the 3-variate particles, organized over
time (T) and with (nt) particles at every time.}

\item{resp}{Responsibilities.}

\item{sigma}{(numclust x dimdat x dimdat) matrix.}

\item{zerothresh}{todo: fill in}

\item{first_iter}{\code{TRUE} if this is the first iteration}

\item{sigma_eig_by_clust}{Eigendecomposition of Sigma.}
}
\description{
(Helper) calculates the per-cluster objective value for the ADMM. Super
inefficient right now.
}
