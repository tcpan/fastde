
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Functions
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

#' @importFrom future availableCores
#' @importFrom future nbrOfWorkers
get_num_threads <- function() {
  message("setting max ", future::availableCores(), " requested ", future::nbrOfWorkers())
  nthreads = pmin(future::nbrOfWorkers(), future::availableCores())
  return(nthreads)
}

#' 
#' Gene expression markers for all identity classes
#'
#' Finds all markers (differentially expressed genes) for each of the identity classes in a dataset
#' Follows Seurat's FindAllMarkers function signature, and will delegate to Seurat's version
#'
#' @inheritParams FastFindMarkers
#' @param idents.clusters cell labels, integer cluster ids for each cell.
#' @param test.use Denotes which test to use. 
#' Available options are:
#' \itemize{
#'  \item{"fastwmw"} : sparse matrix based fast Wilcoxon Rank Sum test (default)
#'  \item{"fast-t"} : sparse matrix based fast student's t-test
#' }
#' @param return.thresh Only return markers that have a p-value < return.thresh, or a power > return.thresh (if the test is ROC)
#' @param node A node to find markers for and all its children; requires
#' \code{\link{BuildClusterTree}} to have been run previously; replaces \code{FindAllMarkersNode}
#'
#' @return Matrix containing a ranked list of putative markers, and associated
#' statistics (p-values, ROC score, etc.)
#'
#' @importFrom stats setNames
#' @importFrom Seurat Idents
#' @importFrom Seurat FindAllMarkers
#'
#' @name FastFindAllMarkers64
#' @export
#'
#' @concept differential_expression
#'
# @examples
# data("pbmc_small")
# # Find markers for all clusters
# all.markers <- FastFindAllMarkers64(object = pbmc_small)
# head(x = all.markers)
# \dontrun{
# # Pass a value to node as a replacement for FindAllMarkersNode
# pbmc_small <- BuildClusterTree(object = pbmc_small)
# all.markers <- FastFindAllMarkers64(object = pbmc_small, node = 4)
# head(x = all.markers)
# }
#
FastFindAllMarkers64 <- function(
  object,
  idents.clusters,
  assay = NULL,
  features = NULL,
  logfc.threshold = 0.25,
  test.use = 'fastwmw',
  slot = 'data',
  min.pct = 0.1,
  min.diff.pct = -Inf,
  node = NULL,
  verbose = FALSE,
  only.pos = FALSE,
  pseudocount.use = 1,
  fc.name = NULL,
  base = 2,
  return.thresh = 1e-2,
  ...
) {
  # call ours if possible.  conditiions:
  #   node is null
  #   test.use = "fastwmw"
  tictoc::tic("FastFindAllMarkers64")
  # what does this do?
  if ((test.use == "fastwmw") || (test.use == 'fast_t') ) {
  

    # compute for all rows/cols
    messages <- list()
    if (verbose) {
      idents.all <- sort(x = unique(x = idents.clusters))
      # message("Calculating all clusters ", idents.all)
    }
    # genes.de dim = cluster as rows, genes as columns
    gde.all <- FastFindMarkers(
      object = object,
      cells.clusters = idents.clusters,
      assay = assay,
      features = features,
      logfc.threshold = logfc.threshold,
      test.use = test.use,
      slot = slot,
      min.pct = min.pct,
      min.diff.pct = min.diff.pct,
      verbose = verbose,
      only.pos = only.pos,
      pseudocount.use = pseudocount.use,
      fc.name = fc.name,
      base = base,
      return.dataframe = TRUE,
      ...
    )

    if ((test.use == "fastroc") && (return.thresh == 1e-2)) {
      return.thresh <- 0.7
    }
    # message("FASTDE number of rows for gde.all ", nrow(x = gde.all))
    # output should be less than p_val thresh, and has columns cluster and gene.
    gde.all <- subset(x = gde.all, subset = gde.all$p_val < return.thresh)
    # also already filtered by p val > 0 if only.pos.
    # message("FASTDE number of rows for gde.all thresholded ", nrow(x = gde.all))
    print.data.frame(head(gde.all))
    print.data.frame(tail(gde.all))
    # write.csv(gde.all, "~/fastde_t.csv", row.names=FALSE)

    # this hsould not happen
    # rownames(x = gde.all) <- make.unique(names = as.character(x = gde.all$gene))
    
    # print error messgaes.
    if (nrow(x = gde.all) == 0) {
      warning("FASTDE 64 No DE genes identified", call. = FALSE, immediate. = TRUE)
    }
    if (length(x = messages) > 0) {
      warning("FASTDE 64 The following tests were not performed: ", call. = FALSE, immediate. = TRUE)
      for (i in 1:length(x = messages)) {
        if (!is.null(x = messages[[i]])) {
          warning("When testing ", idents.all[i], " versus all:\n\t", messages[[i]], call. = FALSE, immediate. = TRUE)
        }
      }
    }
  }
  tictoc::toc()
  return(gde.all)

}

#' 
#' Gene expression markers for all identity classes
#'
#' Finds markers (differentially expressed genes) for each of the identity classes in a dataset
#'
#' @inheritParams FastFindMarkers
#' @param test.use Denotes which test to use. All tests except for fastwmw and fast-t
#' are passed through to Seurat's FindMarkers function
#' Available options are:
#' \itemize{
#'  \item{"fastwmw"} : sparse matrix based fast Wilcoxon Rank Sum test (default)
#'  \item{"fast-t"} : sparse matrix based fast student's t-test
#'  \item{"wilcox"} : Identifies differentially expressed genes between two
#'  groups of cells using a Wilcoxon Rank Sum test 
#'  \item{"bimod"} : Likelihood-ratio test for single cell gene expression,
#'  (McDavid et al., Bioinformatics, 2013)
#'  \item{"roc"} : Identifies 'markers' of gene expression using ROC analysis.
#'  For each gene, evaluates (using AUC) a classifier built on that gene alone,
#'  to classify between two groups of cells. An AUC value of 1 means that
#'  expression values for this gene alone can perfectly classify the two
#'  groupings (i.e. Each of the cells in cells.1 exhibit a higher level than
#'  each of the cells in cells.2). An AUC value of 0 also means there is perfect
#'  classification, but in the other direction. A value of 0.5 implies that
#'  the gene has no predictive power to classify the two groups. Returns a
#'  'predictive power' (abs(AUC-0.5) * 2) ranked matrix of putative differentially
#'  expressed genes.
#'  \item{"t"} : Identify differentially expressed genes between two groups of
#'  cells using the Student's t-test.
#'  \item{"negbinom"} : Identifies differentially expressed genes between two
#'   groups of cells using a negative binomial generalized linear model.
#'   Use only for UMI-based datasets
#'  \item{"poisson"} : Identifies differentially expressed genes between two
#'   groups of cells using a poisson generalized linear model.
#'   Use only for UMI-based datasets
#'  \item{"LR"} : Uses a logistic regression framework to determine differentially
#'  expressed genes. Constructs a logistic regression model predicting group
#'  membership based on each feature individually and compares this to a null
#'  model with a likelihood ratio test.
#'  \item{"MAST"} : Identifies differentially expressed genes between two groups
#'  of cells using a hurdle model tailored to scRNA-seq data. Utilizes the MAST
#'  package to run the DE testing.
#'  \item{"DESeq2"} : Identifies differentially expressed genes between two groups
#'  of cells based on a model using DESeq2 which uses a negative binomial
#'  distribution (Love et al, Genome Biology, 2014).This test does not support
#'  pre-filtering of genes based on average difference (or percent detection rate)
#'  between cell groups. However, genes may be pre-filtered based on their
#'  minimum detection rate (min.pct) across both cell groups. To use this method,
#'  please install DESeq2, using the instructions at
#'  https://bioconductor.org/packages/release/bioc/html/DESeq2.html
#' }
#' @param return.thresh Only return markers that have a p-value < return.thresh, or a power > return.thresh (if the test is ROC)
#' @param node A node to find markers for and all its children; requires
#' \code{\link{BuildClusterTree}} to have been run previously; replaces \code{FindAllMarkersNode}
#'
#' @return Matrix containing a ranked list of putative markers, and associated
#' statistics (p-values, ROC score, etc.)
#'
#' @importFrom stats setNames
#' @importFrom Seurat Idents
#' @importFrom Seurat FindAllMarkers
#'
#' @name FastFindAllMarkers
#' @export
#'
#' @concept differential_expression
#'
# @examples
# data("pbmc_small")
# # Find markers for all clusters
# all.markers <- FastFindAllMarkers(object = pbmc_small)
# head(x = all.markers)
# \dontrun{
# # Pass a value to node as a replacement for FindAllMarkersNode
# pbmc_small <- BuildClusterTree(object = pbmc_small)
# all.markers <- FastFindAllMarkers(object = pbmc_small, node = 4)
# head(x = all.markers)
# }
#
FastFindAllMarkers <- function(
  object,
  assay = NULL,
  features = NULL,
  logfc.threshold = 0.25,
  test.use = 'fastwmw',
  slot = 'data',
  min.pct = 0.1,
  min.diff.pct = -Inf,
  node = NULL,
  verbose = FALSE,
  only.pos = FALSE,
  pseudocount.use = 1,
  fc.name = NULL,
  base = 2,
  return.thresh = 1e-2,
  ...
) {
  # call ours if possible.  conditiions:
  #   node is null
  #   test.use = "fastwmw"
  # what does this do?
  if ((test.use == "fastwmw") || (test.use == 'fast_t') ) {
    tictoc::tic("FindAllMarkers")
  
    # Idents get the cell identity (not name), which correspond to cluster ids? 
    idents.clusters = Seurat::Idents(object = object)
    

    # compute for all rows/cols
    messages <- list()
    if (verbose) {
      idents.all <- sort(x = unique(x = idents.clusters))
      # message("Calculating all clusters ", idents.all)
    }
    # genes.de dim = cluster as rows, genes as columns
    gde.all <- FastFindMarkers(
      object = object,
      cells.clusters = idents.clusters,
      assay = assay,
      features = features,
      logfc.threshold = logfc.threshold,
      test.use = test.use,
      slot = slot,
      min.pct = min.pct,
      min.diff.pct = min.diff.pct,
      verbose = verbose,
      only.pos = only.pos,
      pseudocount.use = pseudocount.use,
      fc.name = fc.name,
      base = base,
      return.dataframe = TRUE,
      ...
    )

    if ((test.use == "fastroc") && (return.thresh == 1e-2)) {
      return.thresh <- 0.7
    }
    # message("FASTDE number of rows for gde.all ", nrow(x = gde.all))
    # output should be less than p_val thresh, and has columns cluster and gene.
    gde.all <- subset(x = gde.all, subset = gde.all$p_val < return.thresh)
    # also already filtered by p val > 0 if only.pos.
    # message("FASTDE number of rows for gde.all thresholded ", nrow(x = gde.all))
    print.data.frame(head(gde.all))
    print.data.frame(tail(gde.all))
    # write.csv(gde.all, "~/fastde_t.csv", row.names=FALSE)

    # this hsould not happen
    # rownames(x = gde.all) <- make.unique(names = as.character(x = gde.all$gene))
    
    # print error messgaes.
    if (nrow(x = gde.all) == 0) {
      warning("FASTDE No DE genes identified", call. = FALSE, immediate. = TRUE)
    }
    if (length(x = messages) > 0) {
      warning("FASTDE The following tests were not performed: ", call. = FALSE, immediate. = TRUE)
      for (i in 1:length(x = messages)) {
        if (!is.null(x = messages[[i]])) {
          warning("When testing ", idents.all[i], " versus all:\n\t", messages[[i]], call. = FALSE, immediate. = TRUE)
        }
      }
    }
    tictoc::toc()
    return(gde.all)

  } else {
    return(Seurat::FindAllMarkers(
        object = object,
        assay = assay,
        features = features,
        logfc.threshold = logfc.threshold,
        test.use = test.use,
        slot = slot,
        min.pct = min.pct,
        min.diff.pct = min.diff.pct,
        node = node,
        verbose = verbose,
        only.pos = only.pos,
        pseudocount.use = pseudocount.use,
        fc.name = fc.name,
        base = base,
        return.thresh = return.thresh,
        ...
      ))
  }
}



#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Methods for Seurat-defined generics
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

#' @rdname FastFindMarkers
#' @param slot Slot to pull data from; note that if \code{test.use} is "negbinom", "poisson", or "DESeq2",
#' \code{slot} will be set to "counts"
#' @param counts Count matrix if using scale.data for DE tests. This is used for
#' computing pct.1 and pct.2 and for filtering features based on fraction
#' expressing
#' @param cells.clusters cell labels, integer cluster ids for each cell.
#' @param features Genes to test. Default is to use all genes
#' @param logfc.threshold Limit testing to genes which show, on average, at least
#' X-fold difference (log-scale) between the two groups of cells. Default is 0.25
#' Increasing logfc.threshold speeds up the function, but can miss weaker signals.
#' @param test.use Denotes which test to use. Available options are:
#' \itemize{
#'  \item{"fastwmw"} : sparse matrix based fast Wilcoxon Rank Sum test (default)
#'  \item{"fast-t"} : sparse matrix based fast student's t-test
#' }
#' @param min.pct  only test genes that are detected in a minimum fraction of
#' min.pct cells in either of the two populations. Meant to speed up the function
#' by not testing genes that are very infrequently expressed. Default is 0.1
#' @param min.diff.pct  only test genes that show a minimum difference in the
#' fraction of detection between the two groups. Set to -Inf by default
#' @param verbose Print a progress bar once expression testing begins
#' @param only.pos Only return positive markers (FALSE by default)
#' @param pseudocount.use Pseudocount to add to averaged expression values when
#' calculating logFC. 1 by default.
#' @param fc.name Name of the fold change, average difference, or custom function column
#' in the output data.frame. If NULL, the fold change column will be named
#' according to the logarithm base (eg, "avg_log2FC"), or if using the scale.data
#' slot "avg_diff".
#' @param base The base with respect to which logarithms are computed.
#' @param return.dataframe  if True, return a data frame instead of a matrix.
#' 
#' @return returns a data frame or a matrix of p-values. 
#'
#' @importFrom stats p.adjust
#' @importFrom utils str
#' 
#' @concept differential_expression
#' 
#' @name FastFindMarkers
#' @export
#' @method FastFindMarkers default
FastFindMarkers.default <- function(
  object,
  slot = "data",
  counts = numeric(),
  cells.clusters = NULL,
  features = NULL,
  logfc.threshold = 0.25,
  test.use = 'fastwmw',
  min.pct = 0.1,
  min.diff.pct = -Inf,
  verbose = FALSE,
  only.pos = FALSE,
  pseudocount.use = 1,
  fc.name = NULL,
  base = 2,
  return.dataframe = TRUE,
  ...
) {
  if (verbose) { print("TCP FASTDE: FastFindMarkers.default") }

  if (verbose) { tictoc::tic("FastFindMarkers.default FastFoldChange")  }

  if (! is.null(features)) {
    data <- object[features, , drop=FALSE]
  } else {
    data <- object
  }

  # need to do this first - results will be used to filter.
  fc.results <- FastFoldChange(
    object = data,
    cells.clusters = cells.clusters,
    slot = slot,
    pseudocount.use = pseudocount.use,
    base = base,
    fc.name = fc.name,
    return.dataframe = return.dataframe,
    verbose = verbose,
    ...
  )
  # str(fc.results)
  colidx <- which(! colnames(fc.results) %in% c("cluster", "gene", "pct.1", "pct.2"))[1]
  fc.name <- colnames(fc.results)[colidx]

  if (verbose) { tictoc::toc() }
  if (verbose) { print(fc.results[[fc.name]][1:20]) }


  if (verbose) { tictoc::tic("FinMarkers.default load") }
  # reform to data frame.

  # reset parameters so no feature filtering is performed

  # Compute a set of features for each cluster, 
  # and only compute using those features when wmwtest.
  # get the baseline mask  - this is uniform for all clusters
  # get the full mask - this may vary per cluster, so fc_mask is 2D.
  if (is.null(features)) {
    imask <- NULL
  } else {
    imask <- fc.results$gene %in% features
  }

  # message("FASTFindMarkers.default min_pct ", min.pct, " diff pct ", min.diff.pct, " log tr ", logfc.threshold, " pos ", only.pos)
  tictoc::tic("FastFindMarkers.default FilterFoldChange")
  fc_mask <- FilterFoldChange(
    fc = fc.results[[colidx]], pct1 = fc.results$pct.1, pct2 = fc.results$pct.2,
    init_mask = imask,
    min_pct = min.pct, min_diff_pct = min.diff.pct,
    logfc_threshold = logfc.threshold, only_pos = only.pos,
    not_count = (slot != "scale.data"),
    threads = get_num_threads())
  # mask the dataframe or matrix.
  tictoc::toc()
  if (verbose) { print(fc_mask[1:20]) }

  # NO subsample cell groups if they are too large

  if (verbose) { tictoc::toc() }

  # because fc_mask is 2D, we compute the DE for all specified features.
  if (verbose) { tictoc::tic("FastFindMarkers.default performDE") }
  de.results <- FastPerformDE(
    object = data,
    cells.clusters = cells.clusters,
    features.as.rows = TRUE,
    test.use = test.use,
    verbose = verbose,
    return.dataframe = return.dataframe,
    ...
  )
  if (verbose) { tictoc::toc() }

  if (verbose) { tictoc::tic("FastFindMarkers.default post DE") }

  #append avg_diff to de.results.  both should have same row assignments.
  de.results <- cbind(de.results, fc.results[, c(fc.name, "pct.1", "pct.2")])

  # select de.results USING FC_MASK
  de.results <- de.results[fc_mask, , drop = FALSE]

  # sort.  first order by cluster, then by p_val, and finally by avg_diff.
  #TODO:  eed to handle DEmethods_nocorrect() - this is just roc.
  if (test.use == "fastroc") {
    de.results <- de.results[order(de.results$cluster, de.results$power, -de.results[, fc.name]), ]
  } else {
    de.results <- de.results[order(de.results$cluster, de.results$p_val, -de.results[, fc.name]), ]
    # Bonferroni correction in R is just multiplication by n then clampped to 1.  p.adjust require n >= length(p)
    # note that the total number of results may be more than n since we collect all features and clusters.  Do this ourselve.
    n <- nrow(x=object)
    de.results$p_val_adj <- pmin(1, n * de.results$p_val)
    # de.results$p_val_adj = p.adjust(
    #   p = de.results$p_val,
    #   method = "bonferroni",
    #   n = nrow(x = object)
    # )
  }

  if (verbose) { tictoc::toc() }
  if (verbose) { print("TCP FASTDE: FastFindMarkers.default DONE") }
  return(de.results)
}

## FastFindMarkers.default should be okay for dgCMatrix64.


#' @rdname FastFindMarkers
#' @param slot Slot to pull data from; note that if \code{test.use} is "negbinom", "poisson", or "DESeq2",
#' \code{slot} will be set to "counts"
#' @param cells.clusters cell labels, integer cluster ids for each cell.
#' @param features Genes to test. Default is to use all genes
#' @param logfc.threshold Limit testing to genes which show, on average, at least
#' X-fold difference (log-scale) between the two groups of cells. Default is 0.25
#' Increasing logfc.threshold speeds up the function, but can miss weaker signals.
#' @param test.use Denotes which test to use. Available options are:
#' \itemize{
#'  \item{"fastwmw"} : sparse matrix based fast Wilcoxon Rank Sum test (default)
#'  \item{"fast-t"} : sparse matrix based fast student's t-test
#' }

#' @param min.pct  only test genes that are detected in a minimum fraction of
#' min.pct cells in either of the two populations. Meant to speed up the function
#' by not testing genes that are very infrequently expressed. Default is 0.1
#' @param min.diff.pct  only test genes that show a minimum difference in the
#' fraction of detection between the two groups. Set to -Inf by default
#' @param only.pos Only return positive markers (FALSE by default)
#' @param verbose Print a progress bar once expression testing begins
#' @param pseudocount.use Pseudocount to add to averaged expression values when
#' calculating logFC. 1 by default.
#' @param fc.name Name of the fold change, average difference, or custom function column
#' in the output data.frame. If NULL, the fold change column will be named
#' according to the logarithm base (eg, "avg_log2FC"), or if using the scale.data
#' slot "avg_diff".
#' @param base The base with respect to which logarithms are computed.
#' @param return.dataframe  if True, return a data frame instead of a matrix.
#'
#' @importFrom Seurat GetAssayData
#' @importFrom Seurat Idents
#' 
#' @concept differential_expression
#' 
#' @name FastFindMarkers
#' @export
#' @method FastFindMarkers Assay
FastFindMarkers.Assay <- function(
  object,
  slot = "data",
  cells.clusters = NULL,
  features = NULL,
  logfc.threshold = 0.25,
  test.use = 'fastwmw',
  min.pct = 0.1,
  min.diff.pct = -Inf,
  verbose = FALSE,
  only.pos = FALSE,
  pseudocount.use = 1,
  fc.name = NULL,
  base = 2,
  return.dataframe = TRUE,
  ...
) {
  if (verbose) { print("TCP FASTDE: FastFindMarkers.assay") }

  if (verbose) { tictoc::tic("FastFindMarkers.assay load") }
  data.use <- Seurat::GetAssayData(object = object, slot = slot)
  counts <- switch(
    EXPR = slot,
    'scale.data' = Seurat::GetAssayData(object = object, slot = "counts"),
    numeric()
  )

  # using the passed in seurat object to get cluster ids.
  if ( is.null(x = cells.clusters) ) {
    clusters <- Seurat::Idents(object = object)
  } else {
    clusters <- cells.clusters
  }
  # clusters <- cells.clusters %||% Seurat::Idents(object = object)
  if (verbose) { tictoc::toc() }

  if (verbose) { tictoc::tic("FastFindMarkers.assay dispatch FastFindMarkers") }
  de.results <- FastFindMarkers(
    object = data.use,
    cells.clusters = clusters,
    features = features,
    slot = slot,
    counts = counts,
    logfc.threshold = logfc.threshold,
    test.use = test.use,
    min.pct = min.pct,
    min.diff.pct = min.diff.pct,
    verbose = verbose,
    only.pos = only.pos,
    pseudocount.use = pseudocount.use,
    base = base,
    fc.name = fc.name,
    return.dataframe = return.dataframe,
    ...
  )
  if (verbose) { tictoc::toc() }
  if (verbose) { print("TCP FASTDE: FastFindMarkers.assay DONE") }
  return(de.results)
}

#' @rdname FastFindMarkers
#' @param cells.clusters cell labels, integer cluster ids for each cell.
#' @param features Genes to test. Default is to use all genes
#' @param test.use Denotes which test to use. Available options are:
#' \itemize{
#'  \item{"fastwmw"} : sparse matrix based fast Wilcoxon Rank Sum test (default)
#'  \item{"fast-t"} : sparse matrix based fast student's t-test
#' }
#' @param only.pos Only return positive markers (FALSE by default)
#' @param verbose Print a progress bar once expression testing begins
#' @param fc.name Name of the fold change, average difference, or custom function column
#' in the output data.frame. If NULL, the fold change column will be named
#' according to the logarithm base (eg, "avg_log2FC"), or if using the scale.data
#' slot "avg_diff".
#' @param return.dataframe  if True, return a data frame instead of a matrix.
#'
#' @importFrom Seurat Embeddings
#' @importFrom Seurat Idents
#' @importFrom methods is
#' 
#' @concept differential_expression
#' 
#' @name FastFindMarkers
#' @export
#' @method FastFindMarkers DimReduc
FastFindMarkers.DimReduc <- function(
  object,
  cells.clusters = NULL,
  features = NULL,
  test.use = "fastwmw",
  verbose = FALSE,
  only.pos = FALSE,
  fc.name = NULL,
  return.dataframe = TRUE,
  ...

) {
  if (verbose) { print("TCP FASTDE: FastFindMarkers.DimReduc") }


  if (verbose) { tictoc::tic("FastFindMarkers.DimReduc load") }
  if ( is.null(x = fc.name) ) {
    fc.name <- "avg_diff"
  }
  # fc.name <- fc.name %||% "avg_diff"
  data <- Seurat::Embeddings(object = object)
  if (! is.null(x = features) ) {
    data <- data[, features, drop=FALSE]
  }
  # does the size match?
  if ( is.null(x = cells.clusters) ) {
    clusters <- Seurat::Idents(object = object)
  } else {
    clusters <- cells.clusters
  }
  # clusters <- cells.clusters %||% Seurat::Idents(object = object)  

  if (verbose) { tictoc::toc() }

  # NOT subsample cell groups if they are too large

  # Calculate avg difference.  This is just rowMeans.
  tictoc::tic("FastFindMarkers.DimReduc FastPerformFC")
  
  PerformFCFunc <- if (is(data, 'dgCMatrix') | is(data, 'dgCMatrix64') )  {
    FastPerformSparseFC
  } else {
    FastPerformFC
  }

  fc.results <- PerformFCFunc(data, clusters,
    features_as_rows = FALSE,
    calc_percents = FALSE, fc_name = fc.name,
    use_expm1 = FALSE, min_threshold = 0.0, 
    use_log = FALSE, log_base = 2, use_pseudocount = FALSE,
    as_dataframe = return.dataframe,
    threads = get_num_threads())
  tictoc::toc()

  if (verbose) { tictoc::tic("FastFindMarkers.DimReduc PerformDE") }

  de.results <- FastPerformDE(
    object = data,
    cells.clusters = clusters,
    features.as.rows = FALSE,
    test.use = test.use,
    verbose = verbose,
    return.dataframe = return.dataframe,
    ...
  )
  if (verbose) { tictoc::toc() }

  if (verbose) { tictoc::tic("FastFindMarkers.DimReduc Post DE") }


  #append avg_diff to de.results.  both should have same row assignments.
  de.results <- cbind(de.results, fc.results$avg_diff)
  # filter for positive entries.
  if (only.pos) {
    de.results <- de.results[de.results$avg_diff > 0, , drop = FALSE]
  }
  # sort.  first order by cluster, then by p_val, and finally by avg_diff.
  de.results <- de.results[order(de.results$cluster, de.results$p_val, -de.results$avg_diff), ]
  # Bonferroni correction is just division by n.  p.adjust require n >= length(p)
  # so we will just do division directly.
  corr_factor = 1.0 / nrow(x = object)
  de.results$p_val_adj <- de.results$p_val * corr_factor
  # de.results$p_val_adj = p.adjust(
  #   p = de.results$p_val,
  #   method = "bonferroni",
  #   n = nrow(x = object)
  # )
  if (verbose) { tictoc::toc() }
  if (verbose) { print("TCP FASTDE: FastFindMarkers.DimReduc DONE") }
  return(de.results)
}

#' @rdname FastFindMarkers
#' @param cells.clusters cell labels, integer cluster ids for each cell.
#' @param group.by Regroup cells into a different identity class prior to performing differential expression (see example)
#' @param subset.ident Subset a particular identity class prior to regrouping. Only relevant if group.by is set (see example)
#' @param assay Assay to use in differential expression testing
#' @param slot Slot to pull data from; note that if \code{test.use} is "negbinom", "poisson", or "DESeq2",
#' \code{slot} will be set to "counts"
#' @param reduction Reduction to use in differential expression testing - will test for DE on cell embeddings
#' @param features Genes to test. Default is to use all genes
#' @param logfc.threshold Limit testing to genes which show, on average, at least
#' X-fold difference (log-scale) between the two groups of cells. Default is 0.25
#' Increasing logfc.threshold speeds up the function, but can miss weaker signals.
#' @param test.use Denotes which test to use. Available options are:
#' \itemize{
#'  \item{"fastwmw"} : sparse matrix based fast Wilcoxon Rank Sum test (default)
#'  \item{"fast-t"} : sparse matrix based fast student's t-test
#' }
#' @param min.pct  only test genes that are detected in a minimum fraction of
#' min.pct cells in either of the two populations. Meant to speed up the function
#' by not testing genes that are very infrequently expressed. Default is 0.1
#' @param min.diff.pct  only test genes that show a minimum difference in the
#' fraction of detection between the two groups. Set to -Inf by default
#' @param only.pos Only return positive markers (FALSE by default)
#' @param verbose Print a progress bar once expression testing begins
#' @param pseudocount.use Pseudocount to add to averaged expression values when
#' calculating logFC. 1 by default.
#' @param fc.name Name of the fold change, average difference, or custom function column
#' in the output data.frame. If NULL, the fold change column will be named
#' according to the logarithm base (eg, "avg_log2FC"), or if using the scale.data
#' slot "avg_diff".
#' @param base The base with respect to which logarithms are computed.
#' @param return.dataframe  if True, return a data frame instead of a matrix.
#'
#' @importFrom Seurat DefaultAssay
#' @importFrom Seurat Idents
#' 
#' @concept differential_expression
#' 
#' @name FastFindMarkers
#' @export 
#' @method FastFindMarkers Seurat
FastFindMarkers.Seurat <- function(
  object,
  cells.clusters = NULL,
  group.by = NULL,
  subset.ident = NULL,
  assay = NULL,
  slot = 'data',
  reduction = NULL,
  features = NULL,
  logfc.threshold = 0.25,
  test.use = "fastwmw",
  min.pct = 0.1,
  min.diff.pct = -Inf,
  verbose = FALSE,
  only.pos = FALSE,
  pseudocount.use = 1,
  fc.name = NULL,
  base = 2,
  return.dataframe = TRUE,
  ...
) {
  if (verbose) { print("TCP FASTDE: FastFindMarkers.Seurat") }
  if (verbose) { tictoc::tic("FastFindMarkers.Seurat setup") }

  if (!is.null(x = group.by)) {
    if (!is.null(x = subset.ident)) {
      object <- subset(x = object, idents = subset.ident)
    }
    Seurat::Idents(object = object) <- group.by
  }
  if (!is.null(x = assay) && !is.null(x = reduction)) {
    stop("Please only specify either assay or reduction.")
  }
  # select which data to use
  if (is.null(x = reduction)) {
    if ( is.null(x = assay) ) {
      assay <- Seurat::DefaultAssay(object = object)
    }
    # assay <- assay %||% Seurat::DefaultAssay(object = object)
    data.use <- object[[assay]]
    cellnames.use <-  colnames(x = data.use)
  } else {
    data.use <- object[[reduction]]
    cellnames.use <- rownames(data.use)
  }

  if ( is.null(cells.clusters) ) {
    clusters <- Seurat::Idents(object = object)
  } else {
    clusters = cells.clusters
  }

  if (verbose) { tictoc::toc() }
  if (verbose) { tictoc::tic("FastFindMarkers.Seurat dispatch FastFindMarkers") }
  de.results <- FastFindMarkers(
    object = data.use,
    slot = slot,
    cells.clusters = clusters,
    features = features,
    logfc.threshold = logfc.threshold,
    test.use = test.use,
    min.pct = min.pct,
    min.diff.pct = min.diff.pct,
    verbose = verbose,
    only.pos = only.pos,
    pseudocount.use = pseudocount.use,
    base = base,
    fc.name = fc.name,
    return.dataframe = return.dataframe,
    ...
  )
  if (verbose) { tictoc::toc() }
  if (verbose) { print("TCP FASTDE: FastFindMarkers.Seurat DONE") }
  return(de.results)
}

#' Gene expression markers of identity classes
#'
#' Finds markers (differentially expressed genes) for identity classes
#'
#' @param object An object
#' @param ... Arguments passed to other methods and to specific DE methods
#'
#' @return data.frame with a ranked list of putative markers as rows, and associated
#' statistics as columns (p-values, ROC score, etc., depending on the test used 
#'(\code{test.use})). The following columns are always present:
#' \itemize{
#'   \item \code{avg_logFC}: log fold-chage of the average expression between the two groups. Positive values indicate that the gene is more highly expressed in the first group
#'   \item \code{pct.1}: The percentage of cells where the gene is detected in the first group
#'   \item \code{pct.2}: The percentage of cells where the gene is detected in the second group
#'   \item \code{p_val_adj}: Adjusted p-value, based on bonferroni correction using all genes in the dataset
#' }
#'
#' @details p-value adjustment is performed using bonferroni correction based on
#' the total number of genes in the dataset. Other correction methods are not
#' recommended, as Seurat pre-filters genes using the arguments above, reducing
#' the number of tests performed. Lastly, as Aaron Lun has pointed out, p-values
#' should be interpreted cautiously, as the genes used for clustering are the
#' same genes tested for differential expression.
#'
#' @references McDavid A, Finak G, Chattopadyay PK, et al. Data exploration,
#' quality control and testing in single-cell qPCR-based gene expression experiments.
#' Bioinformatics. 2013;29(4):461-467. doi:10.1093/bioinformatics/bts714
#' @references Trapnell C, et al. The dynamics and regulators of cell fate
#' decisions are revealed by pseudotemporal ordering of single cells. Nature
#' Biotechnology volume 32, pages 381-386 (2014)
#' @references Andrew McDavid, Greg Finak and Masanao Yajima (2017). MAST: Model-based
#' Analysis of Single Cell Transcriptomics. R package version 1.2.1.
#' https://github.com/RGLab/MAST/
#' @references Love MI, Huber W and Anders S (2014). "Moderated estimation of
#' fold change and dispersion for RNA-seq data with DESeq2." Genome Biology.
#' https://bioconductor.org/packages/release/bioc/html/DESeq2.html
#'
#' @export
#'
# @examples
# data("pbmc_small")
# # Find markers for cluster 2
# markers <- FastFindMarkers(object = pbmc_small, ident.1 = 2)
# head(x = markers)
#
# # Take all cells in cluster 2, and find markers that separate cells in the 'g1' group (metadata
# # variable 'group')
# markers <- FastFindMarkers(pbmc_small, ident.1 = "g1", group.by = 'groups', subset.ident = "2")
# head(x = markers)
#
# # Pass 'clustertree' or an object of class phylo to ident.1 and
# # a node to ident.2 as a replacement for FindMarkersNode
# pbmc_small <- BuildClusterTree(object = pbmc_small)
# markers <- FastFindMarkers(object = pbmc_small, ident.1 = 'clustertree', ident.2 = 5)
# head(x = markers)
#
#' @rdname FastFindMarkers
#' @export FastFindMarkers
#'
#' @seealso \code{FastFoldChange}
#'
FastFindMarkers <- function(object, ...) {
  UseMethod(generic = 'FastFindMarkers', object = object)
}


# ============================================


#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Internal
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


# Check the existence of a package.  FROM Seurat utilities.R
#
# @param ... Package names
# @param error If true, throw an error if the package doesn't exist
# @importFrom methods is
#
# @return Invisibly returns boolean denoting if the package is installed
#
fastDEPackageCheck <- function(..., error = TRUE) {
  pkgs <- unlist(x = c(...), use.names = FALSE)
  package.installed <- vapply(
    X = pkgs,
    FUN = requireNamespace,
    FUN.VALUE = logical(length = 1L),
    quietly = TRUE
  )
  if (error && any(!package.installed)) {
    stop(
      "Cannot find the following packages: ",
      paste(pkgs[!package.installed], collapse = ', '),
      ". Please install"
    )
  }
  invisible(x = package.installed)
}

# perform differential expression computation based on test selected.
FastPerformDE <- function(
  object,
  cells.clusters,
  features.as.rows = FALSE,
  features = NULL,
  test.use = "fastwmw",
  verbose = FALSE,
  return.dataframe = TRUE,
  ...
) {
  if (verbose) {
    print("TCP FASTDE: PerformDE")
  }
  tictoc::tic("FastPerformDE")

  if (! is.null(features)) {
    if (features.as.rows == TRUE) {
      data <- object[features, , drop = FALSE]
    } else {
      data <- object[, features, drop = FALSE]
    }
  } else {
    data <- object
  }
  DEFunc <- switch(
    EXPR = test.use,
    'fastwmw' = if (is(data, 'dgCMatrix') | is(data, 'dgCMatrix64') )  {
      FastSparseWilcoxDETest
    } else {
      FastWilcoxDETest
    },
    'fast_t' = if (is (data, 'dgCMatrix') | is(data, 'dgCMatrix64') ) {
      FastSparseDiffTTest
    } else {
      FastDiffTTest
    },
    stop("fastDE Unknown test: ", test.use)
  )

  de.results <- DEFunc(
      data.use = data,
      cells.clusters = cells.clusters,
      features.as.rows = features.as.rows,
      verbose = verbose,
      return.dataframe = return.dataframe,
      ...
  )
  tictoc::toc()
  if (verbose) {
    print("TCP FASTDE: PerformDE DONE")
  }
  return(de.results)
}
