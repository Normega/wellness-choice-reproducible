# run_all.R -----------------------------------------------------------------
# Runs the pipeline end to end. Each script is standalone, so any one can also
# be run on its own provided the earlier steps have been run at least once.
#
#   "C:/Program Files/R/R-4.5.2/bin/Rscript.exe" run_all.R
#
# The pipeline has two stages separated by a release boundary:
#
#   STAGE 1  identifiable    01_assemble -> 02_deidentify
#            Needs RawData/ and private/. Produces data/.
#
#   STAGE 2  de-identified   03_clean onwards
#            Needs only data/. This is everything a third party requires to
#            reproduce every number, table and figure in the manuscript.
#
# Stage 1 is SKIPPED AUTOMATICALLY when RawData/ or private/ is absent, which is
# the case in any published copy of this project. That is not a degraded mode:
# data/ is exactly what stage 1 writes, so stage 2 alone reproduces the paper.
#
# To relocate the project, set the WC_PROJ_ROOT environment variable or define
# projRoot before sourcing.

scriptDir <- local({
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", a[grep("^--file=", a)])
  if (length(f) > 0) dirname(normalizePath(f)) else getwd()
})

source(file.path(scriptDir, "00_config.R"))

stage1 <- c(
  "01_assemble.R",       # raw Qualtrics exports -> private/tidy/
  "02_deidentify.R"      # private/tidy/ -> data/            <- release boundary
)

stage2 <- c(
  "03_clean.R",          # exclusions + CONSORT flow
  "04_score.R",          # scale scoring, WB composite, long frames
  "05_h1.R",             # Hypothesis 1
  "06_h2.R",             # Hypothesis 2
  "07_exploratory.R",    # exploratory analyses
  "08_descriptives.R",   # demographics + descriptive tables
  "09_consort_figure.R", # Figure 1
  "10_tables.R",         # appendix table cell contents (-> write_appendix_tables.py)
  "11_supplementary.R",  # completer comparison, WB parallel analysis, effect sizes
  "12_multiplicity.R",   # explicit Holm-Bonferroni correction
  "14_figure2_dissociation.R", # Figure 2: the three-timescale dissociation
  "13_release_audit.R"   # fails the build if anything identifying is publishable
)

if (hasRawInputs()) {
  message("Raw inputs present -- running the identifiable stage, then the analysis.")
  steps <- c(stage1, stage2)
} else {
  message("No RawData/ or private/ directory -- starting from the de-identified\n",
          "release in data/. This reproduces every published number.")
  missing <- setdiff(c("baseline.csv", "booster.csv", "post.csv"),
                     list.files(dataDir))
  if (length(missing) > 0) {
    stop("data/ is missing ", paste(missing, collapse = ", "),
         "\n  Without either RawData/ or a released data/ there is nothing to run.",
         call. = FALSE)
  }
  steps <- stage2
}

started <- Sys.time()

for (step in steps) {
  message("\n", strrep("=", 70), "\n== ", step, "\n", strrep("=", 70))
  # Run in a separate environment so no state leaks between steps -- if a script
  # only works because an earlier one left an object behind, that is a bug.
  result <- tryCatch({
    sys.source(file.path(scriptDir, step), envir = new.env(parent = globalenv()))
    "ok"
  }, error = function(e) conditionMessage(e))

  if (!identical(result, "ok")) {
    stop("Pipeline halted at ", step, ":\n  ", result, call. = FALSE)
  }
}

## Environment record --------------------------------------------------------
# The Methods section has to name the software that produced these numbers, and
# p-values here depend on package versions (lmerTest's Satterthwaite
# approximation in particular). Write the environment out so the claim in the
# paper can be checked against the run that produced it.
local({
  si  <- sessionInfo()
  pkg <- sort(names(c(si$otherPkgs, si$loadedOnly)))
  env <- data.frame(
    component = c("R version", "platform", "running", paste0("package: ", pkg)),
    version   = c(si$R.version$version.string, si$platform, si$running,
                  vapply(pkg, function(p) as.character(utils::packageVersion(p)),
                         character(1))),
    row.names = NULL
  )
  write.csv(env, file.path(outputDir, "session_info.csv"), row.names = FALSE)
  writeLines(capture.output(sessionInfo()),
             file.path(outputDir, "session_info.txt"))
  message("\nEnvironment written to output/session_info.{csv,txt}")
  message("  ", si$R.version$version.string)
  for (p in c("lme4", "lmerTest", "emmeans", "psych", "MASS", "ordinal")) {
    if (p %in% pkg) message(sprintf("  %-10s %s", p, utils::packageVersion(p)))
  }
})

message("\n", strrep("=", 70))
message(sprintf("Pipeline completed in %.1f seconds (%d steps).",
                as.numeric(difftime(Sys.time(), started, units = "secs")),
                length(steps)))
message("Tables and figures are in Reproducible/output/")
