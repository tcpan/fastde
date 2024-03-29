#' Write 10X hdf5 file
#'
#' Write count matrix to 10X CellRanger hdf5 file.
#' This can be used to write both scATAC-seq and scRNA-seq matrices.
#' Both standard R compressed sparse column matrix (dgCMatrix) or 
#' FastDe large sparse matrix (fastde::dgCMatrix64) are supported as input
#'
#' @rdname Write10X_h5
#' @param data either a dgCMatrix or a fastde::dgcMatrix64 sparse matrix object
#' @param filename Path to h5 file
#' @param use.names Label row names with feature names rather than ID numbers.
#'
#' @importFrom hdf5r H5File
#' @return nothing
#'
#' @name Write10X_h5
#' @export
#' @concept preprocessing
#'
Write10X_h5 <- function(data, filename, use.names = TRUE) {
  if (!requireNamespace('hdf5r', quietly = TRUE)) {
    stop("Please install hdf5r to read HDF5 files")
  }
  # message("filename ", filename)
  outfile <- hdf5r::H5File$new(filename = filename, mode = 'w')
  # create groupfeature_slot
  genome <- outfile$create_group("rna")
  genome[["data"]] <- data@x
  genome[["indices"]] <- data@i
  if (is(data, 'dgCMatrix64')) {
    genome[["indptr"]] <- as.numeric(data@p)
  } else {
    genome[["indptr"]] <- as.integer(data@p)
  }
  genome[["shape"]] <- as.integer(data@Dim)
  if (use.names) {
    feature_slot <- 'gene_names'
  } else {
    feature_slot <- 'genes'
  }
  genome[[feature_slot]] <- rownames(x = data)
  genome[["barcodes"]] <- colnames(x = data)

  outfile$close_all()
}


#' Read 10X hdf5 file
#'
#' Read count matrix from 10X CellRanger hdf5 file.
#' This can be used to read both scATAC-seq and scRNA-seq matrices.
#' modified from Seurat's version to allow for very large sparse matrix,
#' which are represented as FastDe large sparse matrix (fastde::dgCMatrix64)
#'
#' @rdname Read10X_h5_big
#' @param filename Path to h5 file
#' @param use.names Label row names with feature names rather than ID numbers.
#' @param unique.features Make feature names unique (default TRUE)
#'
#' @importFrom hdf5r H5File
#' @importFrom hdf5r existsGroup 
#'
#' @return Returns a compressed sparse column matrix with rows and columns labeled. 
#' If multiple  genomes are present, returns a list of sparse matrices (one per genome).
#' If large matrix (more than 2 billion non-zeros), fastde::dgCMatrix64 is returned.
#'
#' @name Read10X_h5_big
#' @export
#' @concept preprocessing
#'
Read10X_h5_big <- function(filename, use.names = TRUE, unique.features = TRUE) {
  if (!requireNamespace('hdf5r', quietly = TRUE)) {
    stop("Please install hdf5r to read HDF5 files")
  }
  if (!file.exists(filename)) {
    stop("File not found")
  }
  infile <- hdf5r::H5File$new(filename = filename, mode = 'r')
  genomes <- names(x = infile)
  output <- list()
  if (hdf5r::existsGroup(infile, 'matrix')) {
    # cellranger version 3
    if (use.names) {
      feature_slot <- 'features/name'
    } else {
      feature_slot <- 'features/id'
    }
  } else {
    if (use.names) {
      feature_slot <- 'gene_names'
    } else {
      feature_slot <- 'genes'
    }
  }

  for (genome in genomes) {
    counts <- infile[[paste0(genome, '/data')]]
    indices <- infile[[paste0(genome, '/indices')]]
    indptr <- infile[[paste0(genome, '/indptr')]]
    shp <- infile[[paste0(genome, '/shape')]]
    features <- infile[[paste0(genome, '/', feature_slot)]][]
    barcodes <- infile[[paste0(genome, '/barcodes')]][]
    # TCP: using dgCMatrix64 for sparse matrix.
    print(shp)

    if (unique.features) {
      features <- make.unique(names = features)
    }

    sparse.mat <- new("dgCMatrix64", 
      x = as.numeric(x = counts[]),
      i = as.integer(x = indices[]), 
      p = as.numeric(x = indptr[]),
      Dim = as.integer(x = shp[]),   # must have Dim to be able to set row/col names.
      Dimnames = list(features, barcodes)
    )

    # # TCP: dgCMatrix64 has no support for col and row name (dimanmes for non arrays.)
    # rownames(x = sparse.mat) <- features
    # colnames(x = sparse.mat) <- barcodes
    # below is not needed?
    #sparse.mat <- as(object = sparse.mat, Class = 'dgCMatrix64')

    # TCP:  this is not yet tested, but should be okay...
    # Split v3 multimodal
    if (infile$exists(name = paste0(genome, '/features'))) {
      types <- infile[[paste0(genome, '/features/feature_type')]][]
      types.unique <- unique(x = types)
      if (length(x = types.unique) > 1) {
        message("Genome ", genome, " has multiple modalities, returning a list of matrices for this genome")
        sparse.mat <- sapply(
          X = types.unique,
          FUN = function(x) {
            return(sparse.mat[which(x = types == x), ])
          },
          simplify = FALSE,
          USE.NAMES = TRUE
        )
      }
    }
    output[[genome]] <- sparse.mat
  }
  infile$close_all()
  if (length(x = output) == 1) {
    return(output[[genome]])
  } else{
    return(output)
  }
}