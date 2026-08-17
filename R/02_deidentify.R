# 02_deidentify.R -----------------------------------------------------------
# THE RELEASE BOUNDARY. Everything upstream of this script is identifiable;
# everything downstream reads only what this script writes.
#
# Input:  private/tidy/{baseline,booster,post}.csv   (identifiable)
#         private/experimenter_emails.txt
# Output: data/{baseline,booster,post}.csv           (shareable)
#         data/dual_enrolled_ids.txt                 (shareable, remapped)
#         private/id_crosswalk.csv                   (the re-identification key)
#         output/deidentification_report.csv         (what was removed)
#
# What it does, in order:
#
#   1. Drops study-staff test responses. This must happen here because it is
#      keyed on email address, and this is the last step that can see one.
#   2. Drops direct identifiers outright (names, emails, IP, geolocation,
#      Qualtrics response GUIDs, external references).
#   3. Replaces the institutional participant number with an arbitrary study ID
#      drawn in a seeded random order, so the released IDs carry no information
#      -- not even enrolment order. The crosswalk is written to private/ only.
#   4. Redacts free-text while PRESERVING whether a response was given, because
#      04_score.R infers which practice a participant did from whether the
#      journalling prompts were filled in. Content goes; the presence bit stays.
#   5. Replaces submission timestamps with a dense submission-order rank. The
#      only downstream use of these timestamps is ordering duplicate
#      submissions, and a rank preserves that exactly while removing the clock.
#   6. Drops unused timestamp columns entirely.
#   7. Re-scans the result and FAILS if anything that looks identifying is left.
#
# The final scan is the point of the script. The drop lists are hand-written and
# could go stale if the survey changes; the scan is what actually guarantees the
# release, so it errors rather than warns.

.scriptDir <- function() {
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", a[grep("^--file=", a)])
  if (length(f) > 0) return(dirname(normalizePath(f)))
  if (!is.null(sys.frame(1)$ofile)) return(dirname(normalizePath(sys.frame(1)$ofile)))
  getwd()
}
source(file.path(.scriptDir(), "00_config.R"))
loadPackages()
requireRawInputs("02_deidentify.R")

## What counts as identifying -------------------------------------------------

# Dropped outright: direct identifiers and unused timestamps.
dropColumns <- c(
  # direct identifiers
  "IPAddress", "RecipientLastName", "RecipientFirstName", "RecipientEmail",
  "ExternalReference", "LocationLatitude", "LocationLongitude",
  "Email1", "Email2", "Emails", "ResponseId",
  # timestamps not used by any analysis (StartDate is handled separately).
  # CurrentDate and SumScore are Qualtrics embedded-data fields that both carry
  # the session's calendar date: CurrentDate as a full ISO stamp, SumScore --
  # despite its name -- as a plain date. Neither is read by any script from
  # 03_clean.R onwards (StudyDay is derived upstream in 01_assemble.R), so
  # dropping them costs nothing. They matter because a per-participant sequence
  # of exact session dates is a quasi-identifier: joined to the demographics in
  # baseline.csv it narrows a single-campus cohort quickly. They evaded the
  # scan below because an ISO stamp is 24 characters, under its 40-char
  # free-text threshold.
  "EndDate", "RecordedDate", "BaselineDate", "CurrentDate", "SumScore",
  # platform metadata of no analytic value
  "DistributionChannel", "UserLanguage"
)

# Redacted, not dropped: free-text. Empty stays empty, any content becomes a
# fixed token, so presence/absence survives and wording does not.
redactColumns <- c(
  # baseline / post
  "RatingReason", "ExpectStressReduction", "ExpectWellbeing",
  "Gender_Other_Content", "Other_Text", "ParentEduOther_Text",
  "FirstGenOther_Text", "ProgramOther_Text", "ContemplativeOtherText",
  "JournallingOtherText", "BreathOtherText", "Languages",
  # booster
  "PreRatingOpen", "journalprompt1", "journalprompt2", "journalprompt3",
  "OpenWhyTechnique", "CheckWhyOpen", "OpenHowModify", "ChallengeOtherText"
)
REDACTED <- "[text removed]"

# Seed for the ID permutation. Fixed so the release is reproducible; the
# mapping is still arbitrary with respect to anything in the data.
idSeed <- 20260728

## Load ----------------------------------------------------------------------
readTidy <- function(nm) {
  f <- file.path(tidyDir, paste0(nm, ".csv"))
  if (!file.exists(f)) {
    stop("Missing ", f, "\n  Run 01_assemble.R first.", call. = FALSE)
  }
  read.csv(f, colClasses = "character", check.names = FALSE)
}

waves <- list(baseline = readTidy("baseline"),
              booster  = readTidy("booster"),
              post     = readTidy("post"))

report <- list()
note <- function(stage, wave, detail, n = NA_integer_) {
  report[[length(report) + 1]] <<- data.frame(
    stage = stage, wave = wave, detail = detail, n = n)
}

## 1. Study-staff responses ---------------------------------------------------
staff <- experimenterEmails()
message("\nSTAFF RESPONSES")
for (nm in names(waves)) {
  d <- waves[[nm]]
  if (!"Emails" %in% names(d)) next
  drop <- d$Emails %in% staff
  waves[[nm]] <- d[!drop, ]
  message(sprintf("  %-9s removed %d staff row(s)", nm, sum(drop)))
  note("staff removal", nm, "rows matching private/experimenter_emails.txt", sum(drop))
}

## 2. Build the ID crosswalk --------------------------------------------------
# One mapping across all three waves, so a participant keeps one ID everywhere.
realIDs <- sort(unique(unlist(lapply(waves, function(d) {
  v <- suppressWarnings(as.numeric(d$sonaID))
  v[!is.na(v)]
}))))

set.seed(idSeed)
crosswalk <- data.frame(
  sonaID = realIDs,
  pid    = sample(seq_along(realIDs))     # arbitrary order, not enrolment order
)
crosswalk <- crosswalk[order(crosswalk$pid), ]

dir.create(privateDir, showWarnings = FALSE, recursive = TRUE)
write.csv(crosswalk, file.path(privateDir, "id_crosswalk.csv"), row.names = FALSE)
message(sprintf("\nID CROSSWALK\n  %d participant(s) -> arbitrary ids 1..%d",
                nrow(crosswalk), nrow(crosswalk)))
message("  key written to private/id_crosswalk.csv (never share this file)")
note("id mapping", "all", "participants assigned arbitrary study ids", nrow(crosswalk))

mapID <- function(x) {
  crosswalk$pid[match(suppressWarnings(as.numeric(x)), crosswalk$sonaID)]
}

## 3-6. Transform each wave ---------------------------------------------------
message("\nCOLUMN TREATMENT")
for (nm in names(waves)) {
  d <- waves[[nm]]

  # pid replaces sonaID, in the same column position
  d$sonaID <- mapID(d$sonaID)
  names(d)[names(d) == "sonaID"] <- "pid"

  # submission order replaces the timestamp
  if ("StartDate" %in% names(d)) {
    ts <- suppressWarnings(as.numeric(d$StartDate))
    # ties.method = "first" reproduces the stable ordering of the original
    # timestamps exactly; zero-padding keeps lexicographic order == numeric
    # order, because downstream arrange() sees these as character.
    ord <- rank(ts, ties.method = "first", na.last = "keep")
    d$StartDate <- ifelse(is.na(ord), "", sprintf("%06d", ord))
    names(d)[names(d) == "StartDate"] <- "SubmissionOrder"
  }

  dropped <- intersect(dropColumns, names(d))
  d <- d[, setdiff(names(d), dropped), drop = FALSE]

  redacted <- intersect(redactColumns, names(d))
  for (cl in redacted) {
    has <- !is.na(d[[cl]]) & trimws(d[[cl]]) != ""
    d[[cl]] <- ifelse(has, REDACTED, "")
  }

  message(sprintf("  %-9s dropped %2d column(s), redacted %2d, %d rows kept",
                  nm, length(dropped), length(redacted), nrow(d)))
  note("columns dropped", nm, paste(dropped, collapse = "; "), length(dropped))
  note("columns redacted", nm, paste(redacted, collapse = "; "), length(redacted))

  waves[[nm]] <- d
}

## 7. Verify before releasing -------------------------------------------------
# Hand-maintained lists go stale. This scan is what actually backs the release.
message("\nRELEASE SCAN")

emailLike <- "[[:alnum:]._%+-]+@[[:alnum:].-]+\\.[[:alpha:]]{2,}"
ipLike    <- "\\b([0-9]{1,3}\\.){3}[0-9]{1,3}\\b"
nameLike  <- "(?i)^(recipient|first|last)?name$"
# Calendar dates are short enough to pass the free-text check, so they need
# their own pattern. Any surviving yyyy-mm-dd or dd/mm/yyyy is a finding: the
# release is meant to carry a submission-order rank and a study day, never a
# clock. Caught CurrentDate and SumScore, which the drop list had missed.
dateLike  <- "\\b(20[0-9]{2}-[0-9]{2}-[0-9]{2}|[0-9]{1,2}/[0-9]{1,2}/20[0-9]{2})\\b"

problems <- character()
for (nm in names(waves)) {
  d <- waves[[nm]]
  for (cl in names(d)) {
    v <- d[[cl]]
    v <- v[!is.na(v) & v != ""]
    if (!length(v)) next
    if (any(grepl(emailLike, v)))
      problems <- c(problems, sprintf("%s$%s contains an email address", nm, cl))
    if (any(grepl(ipLike, v)))
      problems <- c(problems, sprintf("%s$%s contains an IP address", nm, cl))
    if (grepl(nameLike, cl, perl = TRUE))
      problems <- c(problems, sprintf("%s$%s is a name field", nm, cl))
    if (any(grepl(dateLike, v)))
      problems <- c(problems, sprintf("%s$%s contains a calendar date", nm, cl))
    # Any surviving long free text was not on the redact list.
    longest <- max(nchar(v))
    if (longest > 40 && !identical(unique(v), REDACTED))
      problems <- c(problems, sprintf(
        "%s$%s holds free text up to %d chars and is not redacted", nm, cl, longest))
  }
  if (any(grepl("^sonaID$", names(d))))
    problems <- c(problems, sprintf("%s still has a sonaID column", nm))
}

if (length(problems) > 0) {
  stop("De-identification scan FAILED -- nothing written:\n  ",
       paste(problems, collapse = "\n  "),
       "\n\nAdd these to dropColumns/redactColumns in 02_deidentify.R.",
       call. = FALSE)
}
message("  no emails, IPs, names, institutional ids or free text detected")

# The released IDs must not be reconstructible from the released files, and must
# cover every participant exactly once.
stopifnot(!any(duplicated(crosswalk$pid)),
          !any(duplicated(crosswalk$sonaID)),
          all(sort(crosswalk$pid) == seq_len(nrow(crosswalk))))

## Write ---------------------------------------------------------------------
for (nm in names(waves)) {
  write.csv(waves[[nm]], file.path(dataDir, paste0(nm, ".csv")),
            row.names = FALSE, na = "")
}

# Dual enrolments were recorded by real id upstream; remap for the release.
dualIn <- file.path(privateDir, "dual_enrolled_ids.txt")
if (file.exists(dualIn)) {
  dual <- trimws(readLines(dualIn, warn = FALSE))
  dual <- dual[nzchar(dual)]
  writeLines(as.character(sort(mapID(dual))),
             file.path(dataDir, "dual_enrolled_ids.txt"))
  message(sprintf("\n  dual_enrolled_ids.txt remapped (%d participant(s))", length(dual)))
  note("id mapping", "all", "dual-enrolment ids remapped for release", length(dual))
}

write.csv(bind_rows(report), file.path(outputDir, "deidentification_report.csv"),
          row.names = FALSE, na = "")

message("\nWrote the shareable dataset to data/")
message("  data/ is the entry point for 03_clean.R onwards and is safe to publish.")
message("  private/ must not be shared.")
