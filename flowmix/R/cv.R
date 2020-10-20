## Synopsis: contains the main CV wrapper, and all helper functions related to
## cross-validations.

##' CV wrapper for flowmix().
##'
##' @param nsplit Number of CV splits. Defaults to 5.
##' @param ... default arguments to flowmix().
##'
##' @return List containing (1) the set of coefficients
##'
cv.flowmix <- function(ylist, X, mean_lambdas = NULL,
                       pie_lambdas = NULL,
                       max_mean_lambda = NULL,
                       max_pie_lambda = NULL,
                       gridsize = 5,
                       nsplit = 5,
                       verbose = FALSE,
                       refit = FALSE,
                       multicore.cv = FALSE,
                       ...){
  ## Basic checks
  stopifnot(length(mean_lambdas) == length(pie_lambdas))
  if(is.null(mean_lambdas)){
    assertthat::assert_that(!is.null(max_mean_lambda))
    mean_lambdas = c(exp(seq(from = -8, to = log(max_mean_lambda), length = gridsize)))
  }
  if(is.null(pie_lambdas)){
    assert_that(!is.null(max_pie_lambda))
    pie_lambdas = c(exp(seq(from = -8, to = log(max_pie_lambda), length = gridsize)))
  }

  ## Create CV split indices
  assert_that(nsplit >= 2)
  mysplits = cvsplit(ylist, nsplit = nsplit)

  ## Empty containers
  meanmat = sdmat = matrix(NA, ncol = gridsize, nrow = gridsize)
  cvscoremat = array(NA, dim = c(gridsize,gridsize, nsplit))

  reslist = list()
  start.time = Sys.time()
  for(ii in gridsize:1){
    for(jj in gridsize:1){
      if(verbose){
        print(c(ii,jj))
        print(Sys.time() - start.time)
        print("progressed")
      }

      ## Set warm starts.
      if(jj == gridsize){
        if(ii == gridsize)  warmstart_mn = NULL
        if(ii != gridsize)  warmstart_mn = reslist[[paste0(ii+1, "-", jj)]]$mn
      } else {
        warmstart_mn = reslist[[paste0(ii, "-", jj+1)]]$mn
      }

      ## Do CV to get score
      cvres = get_cv_score(ylist, X, mysplits, nsplit,
                           mean_lambda = mean_lambdas[ii],
                           pie_lambda = pie_lambdas[jj],
                           mn = warmstart_mn,
                           refit = refit,
                           multicore.cv = multicore.cv,
                           ...)

      ## Get the fitted results on the entire data
      res = flowmix(ylist = ylist, X = X,
                    mean_lambda = mean_lambdas[ii],
                    pie_lambda = pie_lambdas[jj],
                    mn = warmstart_mn, ...)

      ## Store the results
      reslist[[paste0(ii, "-", jj)]] = res

      ## Record CV score
      meanmat[ii, jj] = cvres$mean
      sdmat[ii, jj] = stats::sd(cvres$all)
      cvscoremat[ii,jj,] = cvres$all
    }
  }
  return(list(reslist = reslist,
              meanmat = meanmat,
              sdmat = sdmat,
              cvscoremat = cvscoremat))
}

##' Makes all cross-validation cytogram indices, by splitting the code{TT}
##' cytograms. Five groups of datasets are made according to the cytograms
##' holding the following indices: $\{(1,6,11,..), (2,7,12,...)  ...,
##' (5,10,15,...)\}$. Then for cross validation, pick one "test" group out of
##' the five, fit the data on the 4 other groups combined ("training" group),
##' and assess the likelihood of the model on the test group.
##' @param ylist ylist.
##' @param nsplit Defaults to 5.
##' @return \code{nsplit}-lengthed list, each containing groups of indices for
##'   cytograms.
cvsplit2 <- function(ylist, nsplit = 5){
  TT = 100
  lapply(1:nsplit, function(isplit){
    (1:(TT/nsplit)) * nsplit + isplit
  })
}


##' Makes all cross-validation indices, by splitting each cytogram's \eqn{n_t}
##' particles 5 ways, and storing the 5 splitted indices into a TT-lengthed
##' list.
##' @param ylist ylist.
##' @param nsplit Defaults to 5.
##' @return \code{TT}-lengthed list, each containing 5 groups of indices split
##'   \code{nsplit}-ways -- these are the folds to be used during cross
##'   validation.
cvsplit<- function(ylist, nsplit = 5){
  TT = length(ylist)
  all.cv.inds = lapply(1:TT, function(tt){
    flds <- caret::createFolds(ylist[[tt]][,1], k = nsplit, list = TRUE, returnTrain = FALSE)
    names(flds)[1] <- "train"
    return(flds)
  })
}

##' Getting cross-validated test likelihood, averaged over train/test
##' splits. Uses \code{parallel::mclapply()} if \code{is.true(multicore.cv)}, otherwise
##' uses \code{lapply()}.
##' @param splits TT-lengthed list of indices.
##' @param ylist List of responses.
##' @param ... arguments to flowmix.
#' @return Cross validated test likelihood, scalar-valued.
get_cv_score <- function(ylist, X, splits, nsplit, refit,
                         multicore.cv = FALSE,
                         ...){

  ## stopifnot(length(splits[[1]])!=nsplit) ## good check but only works if TT>1

  if(multicore.cv){
    ## Cycle through splits, and calculate CV score
    all.scores = parallel::mclapply(1:nsplit, function(test.isplit){
      get_cv_score_onesplit(test.isplit, splits, ylist, X, refit,
                            ...)
    }, mc.cores = nsplit)
  } else {
    all.scores = lapply(1:nsplit, function(test.isplit){
      get_cv_score_onesplit(test.isplit, splits, ylist, X, refit,
                            ...)
    })
  }
  all.scores = do.call(c, all.scores)
  return(list(mean = mean(all.scores), all = all.scores))
}


##' Getting cross-validated test likelihood, averaged over train/test
##' splits. Uses \code{mclapply()} if \code{is.true(multicore.cv)}, otherwise
##' uses \code{lapply()}.
##' @param splits TT-lengthed list of indices.
##' @param ylist List of responses.
##' @param ... arguments to flowmix.
#' @return Cross validated test likelihood, scalar-valued.
get_cv_score_prebinned <- function(ylist, X, splits, nsplit, refit,
                                   counts_list,
                                   train_ybin_list_by_split,
                                   train_counts_list_by_split,
                                   ylist_orig,
                                   ...){

  ## stopifnot(length(splits[[1]])!=nsplit) ## good check but only works if TT>1
  all.scores = lapply(1:nsplit, function(test.isplit){
    get_cv_score_onesplit_prebinned(test.isplit, splits, ylist, X, refit,
                                    counts_list,
                                    train_ybin_list_by_split,
                                    train_counts_list_by_split,
                                    ylist_orig,
                                    ...)
  })

  all.scores = do.call(c, all.scores)
  return(list(mean = mean(all.scores), all = all.scores))
}


##' (For prebinned data) Inner function for calculating cross-validated test
##' likelihood for one train/test split.  Specifically, it takes the set of
##' splitted indices for all times in 1:TT, trains on (1:nsplit)[-isplit], tests
##' on splits
##'
##' @param splits TT-lengthed list of indices.
##' @param test.split The split (out of 1:nsplit) to use for test.
##' @param ylist List of BINNED responses.
##' @param counts_list List of BINNED counts.
##' @param train_ybin_list_by_split nsplit lengthed list of binend responses of
##'   the training data.
##' @param train_counts_list_by_split Same but with counts.
##' @param refit (experimental), defaults to FALSE. If TRUE, then the refitted
##'   non-regularized solutions (with only a user-specified set of active
##'   coefficients) are calculated.
##' @param ... arguments to flowmix.
##'
##' @return One split's test likelihood.
get_cv_score_onesplit_prebinned <- function(test.isplit, splits, ylist, X, refit,
                                            counts_list,
                                            train_ybin_list_by_split,
                                            train_counts_list_by_split,
                                            ylist_orig,
                                            ...){##, refit = FALSE,...){

  TT = length(ylist)
  dimdat = ncol(ylist[[1]])
  myargs = list(...)
  numclust = myargs$numclust ## might work, might not.

  ## Obtain train and test data according to test split
  ylist.test = lapply(1:TT, function(tt){
    ind = splits[[tt]][[test.isplit]]
    ylist_orig[[tt]][ind,]
  })

  ## Run algorithm on training BINNED data, evaluate on test data.
  res.train = flowmix(ylist = train_ybin_list_by_split[[test.isplit]],
                      X = X,
                      countslist_overwrite = train_counts_list_by_split[[test.isplit]],
                      refit = FALSE, ...)
  assertthat::assert_that(!refit)
  sel_coef = NULL

  ## Assign mn and pie
  pred = predict.flowmix(res.train)
  stopifnot(all(pred$newpie >= 0))

  ## Calculate objective (penalized likelihood)
  objective(pred$newmn,
            pred$newpie,
            pred$sigma,
            ylist.test,
            pie_lambda = 0,
            mean_lambda = 0,
            alpha = res.train$alpha,
            beta = res.train$beta)
}

##' Inner  function  for calculating  cross-validated  test  likelihood for  one
##' train/test split.   Specifically, it takes  the set of splitted  indices for
##' all times in 1:TT, trains on (1:nsplit)[-isplit], tests on splits
##' @param splits TT-lengthed list of indices.
##' @param test.split The split (out of 1:nsplit) to use for test.
##' @param ylist List of responses.
##' @param refit (experimental), defaults to FALSE. If TRUE, then the refitted
##'   non-regularized solutions (with only a user-specified set of active
##'   coefficients) are calculated.
##' @param ... arguments to flowmix
##' @return One split's test likelihood.
get_cv_score_onesplit <- function(test.isplit, splits, ylist, X, refit, ...){##, refit = FALSE,...){

  TT = length(ylist)
  dimdat = ncol(ylist[[1]])
  myargs = list(...)
  numclust = myargs$numclust ## might work, might not.

  ## Obtain train and test data according to test split
  ylist.test = lapply(1:TT, function(tt){
    ind = splits[[tt]][[test.isplit]]
    ylist[[tt]][ind,]
  })
  ylist.train = lapply(1:TT, function(tt){
    ind = splits[[tt]][[test.isplit]]
    ylist[[tt]][-ind,]
  })


  ## Run algorithm on training data, evaluate on test data.
  res.train = flowmix(ylist.train, X,  refit = FALSE, ...)

  ## If applicable, unregularized refit on the sparsity pattern
  if(refit){
    sel_coef = get_sparsity_pattern(res.train)
    res.train = flowmix(ylist.train, X,  refit = TRUE,
                        sel_coef = sel_coef, ...)
  } else {
    sel_coef = NULL
  }

  ## Assign mn and pie
  pred = predict.flowmix(res.train)
  stopifnot(all(pred$newpie >= 0))

  ## Calculate objective (penalized likelihood)
  objective(pred$newmn,
            pred$newpie,
            pred$sigma,
            ylist.test,
            pie_lambda = 0,
            mean_lambda = 0,
            alpha = res.train$alpha,
            beta = res.train$beta)
}


##' Helper to get sparsity pattern of fitted coefficients.
##'
##' @param res |flowmix| class object.
##' @param thresh Sparsity pattern is obtained by zero-thresholding at a value.
##'
##' @return list containing two objects (alpha and beta) that are the same
##'   structure as \code{res$alpha} and \code{beta}, but are boolean
##'   matrices. Entries are TRUE if they are to be selected, and FALSE they are
##'   zero.
get_sparsity_pattern <- function(res, thresh = 1E-8){

  list(beta = lapply(res$beta, function(onebeta){as.matrix(abs(onebeta) <= thresh)}),
       alpha = as.matrix(abs(res$alpha) <= thresh))
}