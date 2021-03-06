% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/plot3d-extra.R
\name{one_2d_plot}
\alias{one_2d_plot}
\title{Plot a single cytogram.}
\usage{
one_2d_plot(
  y,
  counts = NULL,
  xlim = NULL,
  ylim = NULL,
  xlab = NULL,
  ylab = NULL,
  cex = 0.5,
  pt_col = rgb(0, 0, 1, 0.1),
  cex_fac = 1,
  axes = TRUE,
  x_ticks = NULL,
  y_ticks = NULL
)
}
\arguments{
\item{y}{(nt x 2) matrix.}

\item{counts}{multiplicity of each point in y.}

\item{cex_fac}{Only active when \code{!is.null(counts)}; user-supplier
multiplier onto the point size \code{cex==sqrt(counts)}.}
}
\description{
Plot a single cytogram.
}
