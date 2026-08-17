# 00_config.R ---------------------------------------------------------------
# Shared paths, package loading, and constants for the Wellness Choice pipeline.
# Sourced by every numbered script; contains no analysis logic.

## Paths ---------------------------------------------------------------------
# Set projRoot before sourcing this file to relocate the project; otherwise the
# default below is used. Everything else is derived from it.
# Derived from this file's own location (<projRoot>/Reproducible/R/00_config.R)
# rather than hard-coded, so a cloned copy works anywhere with no configuration.
# run_all.R sets `scriptDir`; the individual scripts define `.scriptDir()`.
if (!exists("projRoot")) {
  rDir <- if (exists("scriptDir", inherits = TRUE) && is.character(scriptDir)) {
    scriptDir
  } else if (exists(".scriptDir", mode = "function", inherits = TRUE)) {
    .scriptDir()
  } else {
    getwd()
  }
  projRoot <- dirname(dirname(normalizePath(rDir, winslash = "/", mustWork = FALSE)))
}
if (nzchar(Sys.getenv("WC_PROJ_ROOT"))) projRoot <- Sys.getenv("WC_PROJ_ROOT")

rawDir     <- file.path(projRoot, "RawData")
repoDir    <- file.path(projRoot, "Reproducible")
privateDir <- file.path(repoDir, "private")     # NEVER SHARED
tidyDir    <- file.path(privateDir, "tidy")     # NEVER SHARED
dataDir    <- file.path(repoDir, "data")        # shareable, de-identified
outputDir  <- file.path(repoDir, "output")

for (d in c(dataDir, outputDir)) dir.create(d, showWarnings = FALSE, recursive = TRUE)

## Two entry points ----------------------------------------------------------
# STAGE 1 (identifiable, runs only where RawData/ and private/ exist):
#   01_assemble.R    raw Qualtrics exports -> private/tidy/
#   02_deidentify.R  private/tidy/         -> data/          <- the release
#
# STAGE 2 (de-identified; everything a third party needs):
#   03_clean.R onwards, reading only data/
#
# A published copy of this project ships R/, data/, output/ and the docs. It
# does NOT ship RawData/ or private/, so stage 1 cannot run there -- and does
# not need to, because data/ is exactly what stage 1 produces.
hasRawInputs <- function() {
  dir.exists(rawDir) && dir.exists(privateDir)
}

# Guard for stage-1 scripts: fail with an explanation rather than a missing-file
# error when someone runs them against a released copy.
requireRawInputs <- function(script) {
  if (!hasRawInputs()) {
    stop(script, " is part of the identifiable stage and needs RawData/ and\n",
         "  private/, which are not distributed. Start from 03_clean.R instead;\n",
         "  data/ already contains the de-identified output of this stage.",
         call. = FALSE)
  }
}

## Raw source files ----------------------------------------------------------
rawFiles <- list(
  baseline = file.path(rawDir, "Baseline+(WC)_March+13,+2025_09.45.xlsx"),
  booster  = file.path(rawDir, "Intervention+(WC)_March+13,+2025_09.46.xlsx"),
  post     = file.path(rawDir, "Post-intervention_Debrief+(WC)_March+13,+2025_09.46.xlsx")
)

## Packages ------------------------------------------------------------------
packages <- c(
  "readxl", "writexl",          # excel io
  "dplyr", "tidyr", "tibble",   # data wrangling
  "psych",                      # questionnaire scoring, pca
  "lme4", "lmerTest",           # multilevel models
  "emmeans",                    # marginal means / contrasts
  "ggplot2", "ggforce", "ggpubr", # graphing
  "sjPlot",                     # model tables
  "MASS",                       # ordinal regression (polr)
  "ordinal",                    # mixed-effects ordinal regression (clmm)
  "sandwich"                    # cluster-robust covariance
)

loadPackages <- function(pkgs = packages) {
  missing <- setdiff(pkgs, rownames(installed.packages()))
  if (length(missing) > 0) {
    stop("Missing packages: ", paste(missing, collapse = ", "),
         "\nInstall them with install.packages().")
  }
  invisible(lapply(pkgs, library, character.only = TRUE,
                   quietly = TRUE, warn.conflicts = FALSE))
}

## Study constants -----------------------------------------------------------
# Study staff whose test responses are excluded. Read from private/ rather than
# hard-coded, so publishing this file does not publish three real addresses.
# Only 02_deidentify.R needs them -- it is the last step that sees an email
# address at all, so it performs this exclusion before dropping the column.
experimenterEmails <- function() {
  f <- file.path(privateDir, "experimenter_emails.txt")
  if (!file.exists(f)) {
    stop("Missing ", f, "\n  One address per line; used to drop study-staff ",
         "test responses.", call. = FALSE)
  }
  e <- trimws(readLines(f, warn = FALSE))
  e[nzchar(e)]
}

# Adherence threshold: participants must complete >= 8 of 12 booster sessions.
# (Preregistered as "at least two-thirds of the study"; 8/12 = 0.667.)
minBoosterSessions <- 8

## Qualtrics recode repair -----------------------------------------------------
# Qualtrics stores each answer choice's internal recode VALUE, not its display
# position. Deleting and re-adding choices during survey construction leaves the
# survivors holding their original IDs, so a perfectly ordinary six-point item
# can come out of the export with a non-contiguous code set.
#
# A sweep of all 268 questions in Baseline_WC.qsf flagged 38 with non-contiguous
# or label-offset recodes. Most are unused or nominal, where the coding is
# irrelevant. Four touch scored, analysed variables:
#
#   WHO-5               stored 2,4,5,6,7,9  displayed 1-6   NON-CONTIGUOUS
#   PHQ-4               stored 1,2,3,4      displayed 0-3   offset
#   ComfortPref         stored 1,2,4,5      displayed 1-4   NON-CONTIGUOUS
#   LongTermBenefitPref stored 5,6,7,8      displayed 1-4   offset
#
# All four are repaired here.
#
# The WHO-5's five items all store the same six codes:
#
#     2, 4, 5, 6, 7, 9      gaps: 2, 1, 1, 1, 2
#
# Averaging those as though they were an interval scale treats the step from
# "At no time" to "Some of the time" as twice the step in the middle of the
# scale.
#
# VERIFIED AGAINST THE SURVEY DEFINITION (Baseline_WC.qsf, 2026-07-28), not
# inferred from the exported data. The WHO-5 matrix carries AnswerRecodeValues
# 2,4,5,6,7,9 over ColumnLabels in this display order:
#
#   pos 1  "At No Time"               stored 2 -> 0
#   pos 2  "Some of the time"         stored 4 -> 1
#   pos 3  "Less than half the time"  stored 5 -> 2
#   pos 4  "More than half the time"  stored 6 -> 3
#   pos 5  "Most of the time"         stored 7 -> 4
#   pos 6  "All of the time"          stored 9 -> 5
#
# These are the instrument's standard verbal anchors, so the resulting 0-5 item
# metric, 0-25 raw total and 0-100 percentage score (total x 4) are directly
# comparable with the published <=50 and <=28 thresholds.
#
# This is the same artefact already repaired for YearofStudy (ANALYSIS_NOTES Q8).
who5Codes  <- c(2, 4, 5, 6, 7, 9)
who5Items  <- paste0("WHO5_", 1:5)

# PHQ-4 exports contiguously but on 1-4, whereas the instrument is scored 0-3.
# The .qsf confirms it: displayed ColumnLabels are "0","1","2","3" over
# AnswerRecodeValues 1,2,3,4. That is a pure translation -- it cannot affect a
# correlation, an alpha, a standardized component or any model coefficient --
# but it does mean the reported mean cannot be read against the published 0-12
# severity bands.
phq4Codes <- 1:4
phq4Items <- paste0("PHQ4_", 1:4)

# Baseline activity-preference composites. All five dimensions were presented on
# an identical 1-4 scale, but two of them export on different code sets (.qsf,
# verified 2026-07-28):
#
#   RankingPref          displayed 1-4  stored 1,2,3,4   clean
#   ComfortPref          displayed 1-4  stored 1,2,4,5   NON-CONTIGUOUS
#   BenefitPref          displayed 1-4  stored 1,2,3,4   clean
#   PracticalityPref     displayed 1-4  stored 1,2,3,4   clean
#   LongTermBenefitPref  displayed 1-4  stored 5,6,7,8   offset by +4
#
# Averaging the five as they stand mixes three metrics. The LongTerm offset is a
# constant and therefore harmless to any model, but the Comfort gap is a genuine
# nonlinearity: it scores the step from option 2 to option 3 as twice every
# other step. Each dimension is mapped back onto the 1-4 scale participants
# actually saw.
prefActivities <- c("Mindful", "Breath", "Journalling", "Nature")
prefCodeMap <- list(
  Ranking   = 1:4,
  Comfort   = c(1, 2, 4, 5),
  Benefit   = 1:4,
  Practical = 1:4,
  LongTerm  = 5:8
)

# Maps stored codes onto 0-based scale positions, failing loudly on any value
# that is not in the expected set. A future export that changes shape must stop
# the pipeline rather than silently produce a differently-scaled variable.
recodeToScalePosition <- function(x, expected, label) {
  x <- suppressWarnings(as.numeric(x))
  seen <- sort(unique(x[!is.na(x)]))
  unexpected <- setdiff(seen, expected)
  if (length(unexpected) > 0) {
    stop(sprintf("%s: unexpected stored code(s) %s; expected only %s. ",
                 label, paste(unexpected, collapse = ", "),
                 paste(expected, collapse = ", ")),
         "The Qualtrics export has changed shape -- the recode is no longer safe.")
  }
  match(x, expected) - 1L
}

# Reverse-keyed items -----------------------------------------------------
# BIPS_8 is the only reverse-keyed item in the study.
#
# THIS MUST BE DONE EXPLICITLY, NOT LEFT TO psych::scoreItems(). With
# min = NULL / max = NULL, scoreItems reverses an item as (min + max) - x where
# min and max are taken from the ENTIRE item frame it is handed, not from the
# scale the item belongs to. The frames here carry items on 1-5, 1-6, 1-8 and
# (before repair) 2-9 scales at once, so the constant it derived had nothing to
# do with the BIPS response scale:
#
#   published scoring : reversed as 10 - x  (max 9 came from the WHO-5 codes)
#   correct           : reversed as  6 - x  (BIPS is scored 1-5)
#
# That inflated every BIPS score by a constant 4/9 = 0.444; the published
# baseline mean of 3.81 should read 3.36. Because the offset is identical for
# every person and both waves, no correlation, alpha, component loading or model
# coefficient is affected -- only the reported descriptive.
#
# It was, however, correct only by accident: both frames happened to reach max 9
# because of the un-recoded WHO-5. Repairing the WHO-5 drops the baseline frame
# to max 8 and the post frame to max 6, so the two waves would be reversed with
# DIFFERENT constants -- manufacturing a spurious 0.23-point pre-post "decrease"
# in perceived stress at p = .001. Reversing explicitly removes the dependence
# on the rest of the frame entirely.
bipsReverseItem <- "BIPS_8"
bipsScaleRange  <- c(1, 5)

reverseKeyedItems <- function(dat, label) {
  if (!bipsReverseItem %in% names(dat)) return(dat)
  x <- suppressWarnings(as.numeric(dat[[bipsReverseItem]]))
  seen <- x[!is.na(x)]
  if (length(seen) && (min(seen) < bipsScaleRange[1] || max(seen) > bipsScaleRange[2])) {
    stop(sprintf("%s %s: values outside the expected %d-%d response scale.",
                 label, bipsReverseItem, bipsScaleRange[1], bipsScaleRange[2]))
  }
  dat[[bipsReverseItem]] <- sum(bipsScaleRange) - x
  message(sprintf("  %s: %s reverse-scored as %d - x", label, bipsReverseItem,
                  sum(bipsScaleRange)))
  dat
}

# Applies both repairs to a baseline or post data frame.
repairQualtricsCodes <- function(dat, label) {
  for (spec in list(list(items = who5Items, codes = who5Codes, nm = "WHO-5"),
                    list(items = phq4Items, codes = phq4Codes, nm = "PHQ-4"))) {
    present <- intersect(spec$items, names(dat))
    if (length(present) == 0) next
    dat[present] <- lapply(present, function(it)
      recodeToScalePosition(dat[[it]], spec$codes,
                            sprintf("%s %s [%s]", label, spec$nm, it)))
    message(sprintf("  %s: %s recoded to 0-%d scale positions (%d items)",
                    label, spec$nm, length(spec$codes) - 1L, length(present)))
  }

  # Preference dimensions (baseline only) -> the 1-4 scale as displayed.
  for (dim in names(prefCodeMap)) {
    items   <- paste(dim, prefActivities, sep = "_")
    present <- intersect(items, names(dat))
    if (length(present) == 0) next
    dat[present] <- lapply(present, function(it)
      recodeToScalePosition(dat[[it]], prefCodeMap[[dim]],
                            sprintf("%s preference [%s]", label, it)) + 1L)
    if (!identical(as.numeric(prefCodeMap[[dim]]), as.numeric(seq_len(4)))) {
      message(sprintf("  %s: %sPref remapped from %s to 1-4 (%d items)",
                      label, dim, paste(prefCodeMap[[dim]], collapse = ","),
                      length(present)))
    }
  }

  reverseKeyedItems(dat, label)
}

# Study phase mapping (Wellness Choice condition).
# Weeks 1-3 are fixed practice; week 4 is participant choice.
studyPhaseBreaks <- list(
  Mindfulness = c(1, 7),
  Breath      = c(8, 14),
  Journal     = c(15, 21),
  Choice      = c(22, Inf)
)

# Orthogonal contrasts for StudyPhase, defined once here because 07_exploratory.R
# and 10_tables.R both need them and must not drift apart.
#
# SCALING MATTERS AND IS EASY TO GET WRONG. For a contrast column c, the fitted
# coefficient is sum(c_i * mu_i) / sum(c_i^2). The original script used integer
# codes c(-1,-1,-1,3), for which sum(c^2) = 12, so the printed coefficient was
# the choice-vs-fixed difference divided by FOUR -- an effect size four times
# smaller than the mean difference a reader would assume it to be.
#
# Each contrast is therefore divided by its own sum(c^2)/<the difference it
# encodes>, so that every coefficient reads directly as a difference in scale
# points:
#
#   FixedVsChoice       b = mean(Choice) - mean(Mindfulness, Breath, Journal)
#   JournalVsMindBody   b = mean(Journal) - mean(Mindfulness, Breath)
#   BreathVsMindfulness b = mean(Breath) - mean(Mindfulness)
#
# The contrasts stay mutually orthogonal, so t and p are IDENTICAL to the
# integer coding; only the estimates and their CIs are rescaled.
studyPhaseContrasts <- cbind(
  FixedVsChoice       = c(-1, -1, -1, 3) / 4,
  JournalVsMindBody   = c(-1, -1,  2, 0) / 3,
  BreathVsMindfulness = c(-1,  1,  0, 0) / 2
)
studyPhaseLevels <- c("Mindfulness", "Breath", "Journal", "Choice")

# Applies the levels and contrasts above to a data frame's StudyPhase column.
withStudyPhaseContrasts <- function(dat) {
  dat$StudyPhase <- factor(dat$StudyPhase, levels = studyPhaseLevels)
  contrasts(dat$StudyPhase) <- studyPhaseContrasts
  dat
}
