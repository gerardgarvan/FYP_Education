# =============================================================================
# 00_config.R - the only place R paths are defined (CFG-02)
# Scripts run with the repo root as working directory (open FYP_Education.Rproj
# or run_pipeline.cmd) and start with source("R/00_config.R").
# =============================================================================

share       <- "P:/PeCAN Research/06 Individual Folders/Mackenzie Topper"
out_root    <- file.path(share, "FYP_Education")
dir_exports <- file.path(out_root, "exports")
dir_tables  <- file.path(out_root, "tables")
dir_figures <- file.path(out_root, "figures")
dir_qc      <- file.path(out_root, "qc")

for (d in c(out_root, dir_exports, dir_tables, dir_figures, dir_qc)) {
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
}

if (!dir.exists(share)) stop("Share not reachable: ", share)

uf_blue   <- "#0021A5"
uf_orange <- "#FA4616"
