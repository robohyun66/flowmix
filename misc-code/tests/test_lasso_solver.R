context("Test internal CVXR sparse lasso regression solver function.")

test_that("CVXR solver is solving the correct problem (by comparing to glmnet).", {

      ## Generate data
      seed = 2
      set.seed(seed)
      lambda = 0.03
      n = 10000
      p = 10
      x <- matrix(rnorm(n * p), n, p)
      y <- runif(n)
      N = 1

      ## No-intercept version is in agreement with CVX.
      res1 = cvxr_lasso(y, x, lambda, dimdat = 1, N = N)
      res2 = glmnet::glmnet(y = y, x = x, lambda = lambda / n,
                            intercept = FALSE, standardize = FALSE)
      mat = cbind(cvx = res1,
                  glmnet = as.numeric(coef(res2)[-1]))
      testthat::expect_true(max(abs(mat[,1] - mat[,2])) < 1E-4)

      ## In sum: we can use the glmnet with lambda/n to solve /our/ desired
      ## problem with lambda.

})
