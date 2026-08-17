# 03_clean.R ----------------------------------------------------------------
# Applies every participant-level exclusion and emits an auditable CONSORT flow.
#
# Input:  data/baseline.csv, data/booster.csv, data/post.csv
#         (the de-identified release written by 02_deidentify.R)
# Output: data/baseline_clean.csv, data/booster_clean.csv, data/post_clean.csv
#         output/consort.csv  -- one row per exclusion step
#
# Every exclusion is routed through consortStep() so the flow diagram can be
# generated from code instead of transcribed by hand.

.scriptDir <- function() {
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", a[grep("^--file=", a)])
  if (length(f) > 0) return(dirname(normalizePath(f)))
  if (!is.null(sys.frame(1)$ofile)) return(dirname(normalizePath(sys.frame(1)$ofile)))
  getwd()
}
source(file.path(.scriptDir(), "00_config.R"))
loadPackages()

baseData <- read.csv(file.path(dataDir, "baseline.csv"), colClasses = "character")
intData  <- read.csv(file.path(dataDir, "booster.csv"),  colClasses = "character")
postData <- read.csv(file.path(dataDir, "post.csv"),     colClasses = "character")
dualEnrolled <- readLines(file.path(dataDir, "dual_enrolled_ids.txt"))

## CONSORT bookkeeping -------------------------------------------------------
consort <- list()

consortStep <- function(stage, step, before, after, idsBefore = NA, idsAfter = NA,
                        idVec = NULL) {
  # Passing idVec records the surviving participant count automatically, which
  # is what the CONSORT diagram needs -- row counts overstate attrition wherever
  # duplicate submissions are still present.
  if (!is.null(idVec)) idsAfter <- nId(idVec)
  consort[[length(consort) + 1]] <<- data.frame(
    stage = stage, step = step,
    rowsBefore = before, rowsAfter = after, rowsRemoved = before - after,
    idsBefore = idsBefore, idsAfter = idsAfter
  )
  message(sprintf("  [%s] %-42s %5d -> %5d  (-%d)%s",
                  stage, step, before, after, before - after,
                  if (!is.null(idVec)) sprintf("  [%d participants]", idsAfter) else ""))
}

nId <- function(x) length(unique(x[!is.na(x) & x != ""]))

## Outcome-battery completeness ----------------------------------------------
# Whether a survey is usable is decided by the outcome battery, not by the
# Qualtrics `Progress` field. Two participants (pid 4510, 3967) reached
# Progress = 89 by skipping a trailing debrief page but answered every scored
# item; excluding them on Progress alone would discard complete outcome data.
#
# Item-level missingness in these data is all-or-nothing -- across both the
# baseline and post surveys every respondent has either all 32 scored items or
# none of them -- so this criterion is unambiguous and needs no threshold.

batteryItems <- function(dat) {
  mood <- c("Anger", "Shame", "Worry", "Joy", "Contentment", "Compassion",
            "Pride", "Sadness", "Love", "Amusement", "Awe", "Jealousy",
            "Guilty", "Selfish")
  intersect(c(grep("^(BIPS_|WHO5_|PHQ4_)", names(dat), value = TRUE), mood),
            names(dat))
}

completedBattery <- function(dat) {
  items <- batteryItems(dat)
  blank <- is.na(dat[items]) | dat[items] == ""
  rowSums(blank) == 0
}

## --------------------------------------------------------------------------
## Baseline
## --------------------------------------------------------------------------
message("\nBASELINE")
n0 <- nrow(baseData)

# Study-staff test responses were removed at the release boundary
# (02_deidentify.R). That exclusion is keyed on email address, and the email
# column does not cross into the shareable dataset, so it cannot be repeated
# here. The counts are recorded in output/deidentification_report.csv.
n1 <- n0

# 2. Rows with no usable participant identifier cannot be linked to any other
#    survey, so they cannot contribute to a repeated-measures analysis.
baseData$pid <- suppressWarnings(as.numeric(baseData$pid))
n2 <- nrow(baseData <- baseData[!is.na(baseData$pid), ])
consortStep("baseline", "remove missing/invalid pid", n1, n2)

# 3. Dual enrolments (decision Q1): randomised into both arms, so no single
#    condition can be assigned. Excluded before any other participant filter.
#
#    Record how many participants completed the outcome battery BEFORE this
#    exclusion, so the CONSORT diagram can show a total enrolled figure that
#    the dual-enrolment exclusion is then subtracted from.
enrolledInclDual <- nId(baseData$pid[completedBattery(baseData)])

n3 <- nrow(baseData <- baseData[!baseData$pid %in% as.numeric(dualEnrolled), ])
consortStep("baseline", "remove dual-enrolled participants", n2, n3,
            idsBefore = length(dualEnrolled), idsAfter = 0)

# 4. Baseline surveys where the outcome battery was not completed.
baseData$Progress <- suppressWarnings(as.numeric(baseData$Progress))
n4 <- nrow(baseData <- baseData[completedBattery(baseData), ])
consortStep("baseline", "remove incomplete outcome battery", n3, n4,
            idVec = baseData$pid)

# 5. Attention checks: >= 3 of 4 correct.
#
#    ORDERING MATTERS. This runs BEFORE deduplication, because a failed
#    attention check invalidates a *submission*, not a *person*. pid 9907
#    submitted the baseline twice three minutes apart -- failing the checks the
#    first time (1 of 4) and passing the second (4 of 4). Deduplicating first
#    can retain the invalid attempt and then exclude a participant who has a
#    perfectly valid one. Filtering invalid rows first makes the outcome
#    independent of row order.
catchKey <- c(Catch1 = 2, Catch2 = 4, Catch3 = 4, Catch4 = 4)
passed <- rowSums(
  sapply(names(catchKey), function(q)
    suppressWarnings(as.numeric(baseData[[q]])) == catchKey[[q]]),
  na.rm = TRUE
) >= 3
n5 <- nrow(baseData <- baseData[passed, ])
consortStep("baseline", "remove failed attention checks (<3 of 4)", n4, n5,
            idVec = baseData$pid)

# 6. Repeat baseline submissions (decision Q2). Every surviving row is now a
#    valid submission, so we keep the earliest -- the one closest to
#    randomisation and to the start of the intervention.
idsBefore <- nId(baseData$pid)
baseData <- baseData %>%
  arrange(pid, SubmissionOrder) %>%
  distinct(pid, .keep_all = TRUE)
n6 <- nrow(baseData)
consortStep("baseline", "collapse repeat baseline submissions", n5, n6,
            idsBefore, nId(baseData$pid))

# 7. Participants with no condition assignment after recovery were never
#    randomised (no booster or post record to recover from).
n7 <- nrow(baseData <- baseData[!is.na(baseData$Condition) & baseData$Condition != "", ])
consortStep("baseline", "remove unrandomised (no condition)", n6, n7,
            idsBefore = NA, idsAfter = nId(baseData$pid))

message(sprintf("  Randomised and eligible: %d (%s)",
                nrow(baseData),
                paste(sprintf("%s=%d", names(table(baseData$Condition)),
                              table(baseData$Condition)), collapse = ", ")))

## --------------------------------------------------------------------------
## Post-intervention survey
## --------------------------------------------------------------------------
message("\nPOST")
p0 <- nrow(postData)

p1 <- p0

postData$pid <- suppressWarnings(as.numeric(postData$pid))
p2 <- nrow(postData <- postData[!is.na(postData$pid), ])
consortStep("post", "remove missing/invalid pid", p1, p2)

p3 <- nrow(postData <- postData[!postData$pid %in% as.numeric(dualEnrolled), ])
consortStep("post", "remove dual-enrolled participants", p2, p3)

postData$Progress <- suppressWarnings(as.numeric(postData$Progress))
p4 <- nrow(postData <- postData[completedBattery(postData), ])
consortStep("post", "remove incomplete outcome battery", p3, p4)

postData <- postData %>%
  arrange(pid, desc(Progress), SubmissionOrder) %>%
  distinct(pid, .keep_all = TRUE)
p5 <- nrow(postData)
consortStep("post", "collapse duplicate post submissions", p4, p5)

## --------------------------------------------------------------------------
## Booster sessions
## --------------------------------------------------------------------------
message("\nBOOSTER")
b0 <- nrow(intData)

b1 <- b0

intData$pid   <- suppressWarnings(as.numeric(intData$pid))
intData$StudyDay <- suppressWarnings(as.numeric(intData$StudyDay))
b2 <- nrow(intData <- intData[!is.na(intData$pid), ])
consortStep("booster", "remove missing/invalid pid", b1, b2)

b3 <- nrow(intData <- intData[!intData$pid %in% as.numeric(dualEnrolled), ])
consortStep("booster", "remove dual-enrolled participants", b2, b3)

# A session only counts if the participant reached the post-session ratings.
b4 <- nrow(intData <- intData[!is.na(intData$poststress) & intData$poststress != "", ])
consortStep("booster", "remove sessions not completed", b3, b4)

# One response per participant per study day.
intData <- intData %>%
  arrange(pid, StudyDay, SubmissionOrder) %>%
  distinct(pid, StudyDay, .keep_all = TRUE)
b5 <- nrow(intData)
consortStep("booster", "collapse duplicate sessions (same id x day)", b4, b5,
            idsBefore = NA, idsAfter = nId(intData$pid))

## --------------------------------------------------------------------------
## Adherence and complete-case linkage
## --------------------------------------------------------------------------
message("\nADHERENCE")

# Adherence is the number of DISTINCT study days completed. The duplicate-session
# collapse above must happen before this count.
#
# The original script computed adherence at line 216 but did not remove duplicate
# id x day sessions until line 523, so a participant who submitted the same study
# day twice was credited with two sessions. pid 9925 reaches the >= 8
# threshold that way on 7 distinct days, and is included in the published
# analysed sample as a result. Counting distinct days here excludes them.
boosterCompletion <- intData %>%
  count(pid, name = "boosterCompletions")

stopifnot(!any(duplicated(intData[c("pid", "StudyDay")])))

adherentIDs <- boosterCompletion %>%
  filter(boosterCompletions >= minBoosterSessions) %>%
  pull(pid)

message(sprintf("  Started boosters: %d participants", nrow(boosterCompletion)))
message(sprintf("  Adherent (>= %d sessions): %d participants",
                minBoosterSessions, length(adherentIDs)))

# The pre-post models require both waves, so the analysed sample is the
# intersection of: adherent, has baseline, has post.
analysedIDs <- Reduce(intersect, list(adherentIDs, baseData$pid, postData$pid))

message(sprintf("  Analysed sample (adherent + baseline + post): %d participants",
                length(analysedIDs)))

# NOTE ON WHAT EACH FILE CONTAINS
# The pre-post (study-level) models need both waves, so they run on
# `analysedIDs`. The session-level models (H1 daily, H2) do NOT need the
# post-intervention survey -- they only need baseline preferences and completed
# booster sessions. Restricting those analyses to `analysedIDs` would discard
# adherent participants for no reason and cost power on exactly the hypothesis
# the sessions were collected to test.
#
# So baseline_clean.csv keeps every eligible randomised participant, and each
# analysis script narrows it as required. analysed_ids.txt records the
# study-level sample.
baseClean <- baseData
postClean <- postData
intClean  <- intData[intData$pid %in% adherentIDs, ]

writeLines(as.character(sort(analysedIDs)), file.path(dataDir, "analysed_ids.txt"))

analysedConditions <- table(baseData$Condition[baseData$pid %in% analysedIDs])
message("  Analysed by condition: ",
        paste(sprintf("%s=%d", names(analysedConditions), analysedConditions),
              collapse = ", "))
stopifnot(sum(analysedConditions) == length(analysedIDs))

consortStep("final", "adherent + complete pre-post",
            length(unique(baseData$pid)), length(analysedIDs))

## Analysis samples ----------------------------------------------------------
# THE STUDY HAS TWO ANALYSIS SAMPLES, AND THE MANUSCRIPT MUST NAME BOTH.
#
# The session-level models (within-session change, H2 preference, study phase)
# need booster sessions and a baseline, but not the post-intervention survey, so
# they run on all 125 adherent participants. The study-level models need both
# waves, so they run on the 120 who also completed the post survey. Reporting
# only "120" leaves every session-level table showing N = 125 with no
# explanation.
#
# These counts are written out so the paper cites generated numbers rather than
# transcribed ones.
condOf <- setNames(baseData$Condition, baseData$pid)
sampleRow <- function(label, ids, use) {
  cc <- condOf[as.character(ids)]
  data.frame(sample = label,
             n  = length(ids),
             wc = sum(cc == "Choice", na.rm = TRUE),
             cn = sum(cc == "Nature", na.rm = TRUE),
             used_for = use)
}

analysisSamples <- bind_rows(
  sampleRow("randomised and eligible", baseData$pid, "CONSORT denominator"),
  sampleRow("began the intervention", startedBoosterIDs <- boosterCompletion$pid,
            "CONSORT"),
  sampleRow("adherent (>= 8 of 12 sessions)", adherentIDs,
            "session-level models: within-session change, H2, study phase"),
  sampleRow("adherent with post-intervention survey", analysedIDs,
            "study-level models: baseline-to-post change, baseline moderator"),
  sampleRow("adherent without post-intervention survey",
            setdiff(adherentIDs, analysedIDs),
            "in session-level models only")
)

message("\nANALYSIS SAMPLES")
print(as.data.frame(analysisSamples), row.names = FALSE)

# The two samples must differ by exactly the no-post group, or the paper's
# explanation of why the tables show two different Ns is wrong.
stopifnot(
  length(adherentIDs) - length(analysedIDs) ==
    length(setdiff(adherentIDs, analysedIDs)),
  all(analysedIDs %in% adherentIDs)
)

write.csv(analysisSamples, file.path(outputDir, "analysis_samples.csv"),
          row.names = FALSE)

## CONSORT flow broken down by condition -------------------------------------
# Mirrors the structure of Figure 1 so the diagram can be redrawn from code
# rather than transcribed. Each participant is assigned to exactly one exit
# reason, evaluated in order, so the branches sum to the randomised total.

startedIDs <- boosterCompletion$pid

flow <- baseData %>%
  transmute(pid, Condition) %>%
  mutate(
    exit = case_when(
      !pid %in% startedIDs      ~ "did not begin intervention",
      !pid %in% adherentIDs     ~ "non-adherent (< 8 sessions)",
      !pid %in% postData$pid ~ "no post-intervention survey",
      TRUE                         ~ "analysed"
    )
  )

consortByCondition <- flow %>%
  count(Condition, exit) %>%
  tidyr::pivot_wider(names_from = Condition, values_from = n, values_fill = 0) %>%
  mutate(total = rowSums(across(where(is.numeric))))

message("\nCONSORT BY CONDITION")
print(as.data.frame(consortByCondition), row.names = FALSE)

# The branches must sum to the randomised total, or the diagram will not balance.
stopifnot(sum(consortByCondition$total) == nrow(baseData))
stopifnot(sum(flow$exit == "analysed") == length(analysedIDs))

write.csv(consortByCondition, file.path(outputDir, "consort_by_condition.csv"),
          row.names = FALSE)

## Write ---------------------------------------------------------------------
write.csv(baseClean, file.path(dataDir, "baseline_clean.csv"), row.names = FALSE, na = "")
write.csv(postClean, file.path(dataDir, "post_clean.csv"),     row.names = FALSE, na = "")
write.csv(intClean,  file.path(dataDir, "booster_clean.csv"),  row.names = FALSE, na = "")
write.csv(boosterCompletion, file.path(dataDir, "booster_completion.csv"),
          row.names = FALSE, na = "")

consortTable <- bind_rows(
  consort,
  data.frame(stage = "baseline", step = "enrolled (completed battery, incl. dual)",
             rowsBefore = NA, rowsAfter = NA, rowsRemoved = NA,
             idsBefore = NA, idsAfter = enrolledInclDual)
)
write.csv(consortTable, file.path(outputDir, "consort.csv"), row.names = FALSE, na = "")

message("\nWrote cleaned data and output/consort.csv")
