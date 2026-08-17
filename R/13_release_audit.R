# 13_release_audit.R --------------------------------------------------------
# Audits everything that would be published, and fails the pipeline if anything
# identifying is present.
#
# Input:  data/, output/  (the entire release surface)
# Output: output/release_audit.csv
#
# WHY THIS EXISTS SEPARATELY FROM 02_deidentify.R.
# That script guarantees the files it writes. It cannot guarantee the directory
# they land in. A real example from this project's own history: an earlier
# version of 01_assemble.R wrote a dual-enrolment audit report containing five
# participant email addresses to output/. When that write was moved to private/,
# the already-written file simply stayed where it was -- correct code, stale
# artefact, live PII sitting in the directory intended for publication.
#
# So this runs last, over the whole release surface rather than over one script's
# outputs, and treats anything it finds as a build failure. Scanning the
# artefacts is the only check that survives the code changing underneath them.

.scriptDir <- function() {
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", a[grep("^--file=", a)])
  if (length(f) > 0) return(dirname(normalizePath(f)))
  if (!is.null(sys.frame(1)$ofile)) return(dirname(normalizePath(sys.frame(1)$ofile)))
  getwd()
}
source(file.path(.scriptDir(), "00_config.R"))
loadPackages()

## Patterns ------------------------------------------------------------------
patterns <- list(
  email       = "[[:alnum:]._%+-]+@[[:alnum:].-]+\\.[[:alpha:]]{2,}",
  ipv4        = "\\b(25[0-5]|2[0-4][0-9]|1?[0-9]?[0-9])(\\.(25[0-5]|2[0-4][0-9]|1?[0-9]?[0-9])){3}\\b",
  postal_ca   = "\\b[A-Z][0-9][A-Z] ?[0-9][A-Z][0-9]\\b",
  phone       = "\\b\\(?[0-9]{3}\\)?[ .-][0-9]{3}[ .-][0-9]{4}\\b",
  latlong     = "\\b-?[0-9]{1,3}\\.[0-9]{4,}\\b",
  # A Qualtrics response GUID is a direct identifier: it keys straight into the
  # raw export. 02_deidentify.R drops the ResponseId column, but one can still
  # reach the release by being quoted in prose -- which is how two of them sat
  # in ANALYSIS_NOTES.md, a file this audit did not used to read.
  responseId  = "\\bR_[A-Za-z0-9]{15,}\\b",
  # The release carries a submission-order rank and a study day, never a clock.
  # Any surviving calendar date is a finding: a per-participant sequence of
  # session dates is a quasi-identifier against the released demographics.
  date        = "\\b(20[0-9]{2}-[0-9]{2}-[0-9]{2}|[0-9]{1,2}/[0-9]{1,2}/20[0-9]{2})\\b",
  # Local part with no domain: still a name. See mdPatterns below.
  partialEmail = "[[:alnum:]][[:alnum:]._%+-]*@"
)

# Column names that must never appear in a released file.
forbiddenCols <- c("sonaID", "Emails", "Email1", "Email2", "RecipientEmail",
                   "RecipientFirstName", "RecipientLastName", "IPAddress",
                   "ExternalReference", "LocationLatitude", "LocationLongitude",
                   "ResponseId", "StartDate", "EndDate", "RecordedDate",
                   # Qualtrics embedded-data fields that both hold the session's
                   # calendar date -- SumScore despite its name. Unused from
                   # 03_clean.R onwards.
                   "CurrentDate", "SumScore", "BaselineDate")

# Free text longer than this, outside the redaction token, is treated as a leak.
maxFreeTextChars <- 40
REDACTED <- "[text removed]"

## Scan ----------------------------------------------------------------------
releaseFiles <- c(
  list.files(dataDir,   pattern = "\\.(csv|txt)$", full.names = TRUE),
  list.files(outputDir, pattern = "\\.(csv|txt)$", full.names = TRUE)
)

# This script's own report would otherwise re-flag every string it quotes.
releaseFiles <- releaseFiles[basename(releaseFiles) != "release_audit.csv"]

# Dotted-quad and high-precision-decimal patterns match software version strings
# ("ordinal 2023.12.4.1"), so the numeric heuristics are not applied to the
# environment record. Emails and forbidden column names still are, because those
# cannot false-positive on a version number.
numericExempt <- c("session_info.csv", "session_info.txt")

# The documentation and the scripts are published too, so they are part of the
# release surface even though they hold no participant rows. They get a narrow
# pattern set: prose legitimately cites calendar dates and quotes column names
# like sonaID, but an email address or a response GUID in a published file is a
# leak wherever it appears. Two GUIDs in ANALYSIS_NOTES.md were invisible to
# this audit until it started reading these files.
docPatterns <- c("email", "responseId")
# Prose gets one extra rule. A truncated address -- "zaryab.khan@", quoted to
# explain a duplicate enrolment -- carries the participant's name but has no
# domain, so the full email pattern slides straight past it. One was sitting in
# ANALYSIS_NOTES.md. Applied only to .md, because the R scripts legitimately
# contain "@" inside their own email regexes.
mdPatterns <- c(docPatterns, "partialEmail")
docFiles <- c(
  list.files(repoDir, pattern = "\\.md$", full.names = TRUE),
  list.files(file.path(repoDir, "R"), pattern = "\\.R$", full.names = TRUE),
  list.files(repoDir, pattern = "\\.py$", full.names = TRUE)
)
# Files .gitignore keeps out of the published repository are not release
# surface: private/README.md documents what is withheld, PEER_REVIEW.md is
# internal, and the .py scripts edited the manuscript rather than the analysis.
docFiles <- docFiles[!grepl("[/\\\\]private[/\\\\]", docFiles)]
docFiles <- docFiles[basename(docFiles) != "PEER_REVIEW.md"]
docFiles <- docFiles[!grepl("\\.py$", docFiles)]

findings <- list()
flag <- function(file, kind, detail) {
  findings[[length(findings) + 1]] <<- data.frame(
    file = basename(file), kind = kind, detail = detail)
}

message(sprintf("\nRELEASE AUDIT: %d file(s) under data/ and output/",
                length(releaseFiles)))

for (f in releaseFiles) {
  txt <- readLines(f, warn = FALSE)
  blob <- paste(txt, collapse = "\n")

  for (nm in names(patterns)) {
    # latlong is a heuristic: high-precision decimals also occur in legitimate
    # model output, so only treat it as a hit in files that carry raw responses.
    if (nm == "latlong" && !grepl("^(baseline|booster|post)", basename(f))) next
    if (nm != "email" && basename(f) %in% numericExempt) next
    m <- regmatches(blob, gregexpr(patterns[[nm]], blob))[[1]]
    if (length(m) > 0) {
      flag(f, nm, sprintf("%d match(es), first: %s", length(m),
                          substr(m[1], 1, 30)))
    }
  }

  if (grepl("\\.csv$", f)) {
    d <- tryCatch(read.csv(f, colClasses = "character", check.names = FALSE,
                           nrows = -1),
                  error = function(e) NULL)
    if (!is.null(d) && ncol(d) > 0) {
      bad <- intersect(forbiddenCols, names(d))
      for (b in bad) flag(f, "forbidden column", b)

      # Long free text in the released response files.
      if (grepl("^(baseline|booster|post)\\.csv$", basename(f))) {
        for (cl in names(d)) {
          v <- d[[cl]]; v <- v[!is.na(v) & v != ""]
          if (!length(v)) next
          if (max(nchar(v)) > maxFreeTextChars && !identical(unique(v), REDACTED)) {
            flag(f, "unredacted free text",
                 sprintf("%s (up to %d chars)", cl, max(nchar(v))))
          }
        }
      }
    }
  }
}

message(sprintf("RELEASE AUDIT: %d documentation/script file(s)", length(docFiles)))

for (f in docFiles) {
  blob <- paste(readLines(f, warn = FALSE), collapse = "\n")
  for (nm in if (grepl("\\.md$", f)) mdPatterns else docPatterns) {
    m <- regmatches(blob, gregexpr(patterns[[nm]], blob))[[1]]
    if (length(m) > 0) {
      flag(f, nm, sprintf("%d match(es), first: %s", length(m),
                          substr(m[1], 1, 30)))
    }
  }
}

## Report --------------------------------------------------------------------
audit <- if (length(findings) > 0) bind_rows(findings) else
  data.frame(file = character(), kind = character(), detail = character())

write.csv(audit, file.path(outputDir, "release_audit.csv"), row.names = FALSE)

if (nrow(audit) > 0) {
  message("\n!! RELEASE AUDIT FAILED")
  print(as.data.frame(audit), row.names = FALSE)
  stop(sprintf("%d identifying item(s) found in data/ or output/. ", nrow(audit)),
       "Do not publish. See output/release_audit.csv.\n  ",
       "If a finding is a stale artefact from an earlier code version, delete ",
       "the file and re-run.", call. = FALSE)
}

message("  no emails, IP addresses, postal codes, phone numbers,")
message("  identifying columns or unredacted free text found")
message("  data/ and output/ are safe to publish; private/ is not")
message("\nWrote output/release_audit.csv")
