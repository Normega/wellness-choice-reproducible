# 01_assemble.R -------------------------------------------------------------
# Reads the three raw Qualtrics exports, applies analysis-friendly column names,
# removes structural (non-participant) rows, and recovers condition assignments
# that were lost when the email->condition merge was done in Qualtrics.
#
# Output: private/tidy/{baseline,booster,post}.csv
#
# IDENTIFIABLE STAGE. The output still carries names, emails, IP addresses,
# geolocation and free-text responses, so it is written to private/ and is not
# part of the release. 02_deidentify.R turns it into the shareable data/.
#
# This script performs NO participant exclusions -- every real response row that
# exists in the raw export survives to the CSVs. All exclusion logic lives in
# 03_clean.R so the CONSORT flow is auditable in one place. (The one exception
# is study-staff test responses, which 02_deidentify.R removes because it is
# keyed on email and that column does not survive the release boundary.)

# Locate this script's directory whether run via Rscript, source(), or RStudio.
.scriptDir <- function() {
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", a[grep("^--file=", a)])
  if (length(f) > 0) return(dirname(normalizePath(f)))
  if (!is.null(sys.frame(1)$ofile)) return(dirname(normalizePath(sys.frame(1)$ofile)))
  getwd()
}
source(file.path(.scriptDir(), "00_config.R"))
loadPackages()
requireRawInputs("01_assemble.R")

dir.create(tidyDir, showWarnings = FALSE, recursive = TRUE)

## Column names --------------------------------------------------------------
# The raw exports use Qualtrics question IDs (Q1, Q240_3, ...). These vectors
# rename them positionally, and are carried over verbatim from the original
# analysis script (WC_Analysis_March23_2026_Cleanup2.R) so that variable names
# match the ones used in the manuscript's results.
# Positional renaming is checked against the expected column count below.

baseNames <- c(
  "StartDate", "EndDate", "Status", "IPAddress", "Progress",
  "Duration", "Finished", "RecordedDate", "ResponseId",
  "RecipientLastName", "RecipientFirstName", "RecipientEmail",
  "ExternalReference", "LocationLatitude", "LocationLongitude",
  "DistributionChannel", "UserLanguage", "Screener1", "Screener2",
  "Screener3", "Consent1", "Consent2", "Consent3", "Consent4",
  "Email1", "Email2", "ArousalVisual", "ValenceVisual", "StressVisual",
  "SatisfactionVisual", "RatingReason",
  "Anger", "Shame", "Worry", "Joy",
  "Contentment", "Compassion", "Pride", "Sadness", "Love", "Amusement",
  "Awe", "Jealousy", "Catch1", "Guilty", "Selfish", "Catch2", "Belong1",
  "Belong2", "Belong3", "Wbladder", "BIPS_1", "BIPS_2", "BIPS_3", "Catch3",
  "BIPS_4", "BIPS_5", "BIPS_6", "BIPS_7", "BIPS_8", "BIPS_9", "PHQ4_1",
  "PHQ4_2", "PHQ4_3", "PHQ4_4", "WHO5_1", "WHO5_2", "WHO5_3", "WHO5_4",
  "WHO5_5", "ExpectStressReduction", "ExpectWellbeing", "Catch4", "Age",
  "YearofStudy", "Gender_Man", "Gender_Woman", "Gender_NB",
  "Gender_Transgender", "Gender_Other", "Gender_PreferNoAnswer",
  "Gender_Other_Content", "IndigenousID", "POC", "Arab", "Black",
  "Chinese", "Filipino", "Indigenous", "Japanese", "Korean", "LatinAmerican",
  "Mixed", "SoutAsian", "SouthEastAsian", "WestAsian", "White",
  "Third-Cultural Identity", "Other", "NoAnswer", "Other_Text",
  "SES", "Languages", "ParentEducation", "ParentEduOther_Text",
  "FirstGen", "FirstGenOther_Text", "Program", "ProgramOther_Text",
  "Ranking_Mindful", "Ranking_Breath", "Ranking_Journalling",
  "Ranking_Nature", "Comfort_Mindful", "Comfort_Breath",
  "Comfort_Journalling", "Comfort_Nature", "Benefit_Mindful",
  "Benefit_Breath", "Benefit_Journalling", "Benefit_Nature",
  "Practical_Mindful", "Practical_Breath", "Practical_Journalling",
  "Practical_Nature", "LongTerm_Mindful", "LongTerm_Breath",
  "LongTerm_Journalling", "LongTerm_Nature", "ContemplativeXP",
  "BreathworkYN", "MindfulnessYN", "YogaYN", "QiGongYN", "TaiChiYN",
  "MeditationYN", "ContemplativeOtherYN", "ContemplativeOtherText",
  "ContemplativeRoutine", "ContemplativeLength", "JournallingYN",
  "Gratitudejournaling", "ReflectiveJournaling", "Art/Visualjournaling",
  "Expressivewriting", "Mindfulnessjournaling", "Promptedjournaling",
  "Dreamjournaling", "Goaljournaling", "Streamofconsciousnessjournaling",
  "JournallingOther", "JournallingOtherText", "JournallingRegular",
  "JournallingLength", "Q244", "Pursedlip", "Diaphragm", "Boxbreath",
  "AltNostril", "PacedBreathing", "Breath478", "ResonanceBreath",
  "LongExhale", "BreathOther", "BreathOtherText", "BreathRoutine",
  "BreathLength", "likelyMindfulnessNP", "likelyMindfulness",
  "likelyJournallingNP", "likelyJournalling", "likelyBreathingNP",
  "likelyBreathing", "CatchSum", "SumPos", "SumNeg", "sonaID",
  "BaselineDate", "Emails", "CatchSumAgain", "Condition"
)

postNames <- c(
  "StartDate", "EndDate", "Status", "IPAddress", "Progress",
  "Duration", "Finished", "RecordedDate", "ResponseId",
  "RecipientLastName", "RecipientFirstName", "RecipientEmail",
  "ExternalReference", "LocationLatitude", "LocationLongitude",
  "DistributionChannel", "UserLanguage", "ArousalVisual", "ValenceVisual",
  "StressVisual", "SatisfactionVisual", "RatingReason",
  "Anger", "Shame", "Worry", "Joy", "Contentment", "Compassion", "Pride",
  "Sadness", "Love", "Amusement", "Awe", "Jealousy",
  "Catch1", "Guilty", "Selfish", "Catch2", "Belong1", "Belong2",
  "Belong3", "Wbladder", "BIPS_1", "BIPS_2", "BIPS_3", "Catch3",
  "BIPS_4", "BIPS_5", "BIPS_6", "BIPS_7", "BIPS_8", "BIPS_9", "PHQ4_1",
  "PHQ4_2", "PHQ4_3", "PHQ4_4", "WHO5_1", "WHO5_2", "WHO5_3", "WHO5_4",
  "WHO5_5", "ExpectStressReduction", "ExpectWellbeing", "Catch4", "CatchSum",
  "SumPos", "SumNeg",
  "SC6", "sonaID", "Condition", "Emails", "StudyDay", "CatchSumAgain"
)

intNames <- c(
  "StartDate", "EndDate", "Status", "IPAddress", "Progress", "Duration", "Finished",
  "RecordedDate", "ResponseId", "RecipientLastName", "RecipientFirstName",
  "RecipientEmail", "ExternalReference", "LocationLatitude", "LocationLongitude",
  "DistributionChannel", "UserLanguage",
  "CalculateDiff_First Click", "CalculateDiff_Last Click",
  "CalculateDiff_Page Submit", "CalculateDiff_Click Count",
  "PreStress", "PreArousal", "PreValence", "PreSatisfaction",
  "PreRatingOpen",
  "Q478_First Click", "Q478_Last Click", "Q478_Page Submit", "Q478_Click Count",
  "Q513_First Click", "Q513_Last Click", "Q513_Page Submit", "Q513_Click Count",
  "Q515_First Click", "Q515_Last Click", "Q515_Page Submit", "Q515_Click Count",
  "Q517_First Click", "Q517_Last Click", "Q517_Page Submit", "Q517_Click Count",
  "Q520_First Click", "Q520_Last Click", "Q520_Page Submit", "Q520_Click Count",
  "Q525_First Click", "Q525_Last Click", "Q525_Page Submit", "Q525_Click Count",
  "Q527_First Click", "Q527_Last Click", "Q527_Page Submit", "Q527_Click Count",
  "Q529_First Click", "Q529_Last Click", "Q529_Page Submit", "Q529_Click Count",
  "Q531_First Click", "Q531_Last Click", "Q531_Page Submit", "Q531_Click Count",
  "ChooseNatureVid",
  "Q533_First Click", "Q533_Last Click", "Q533_Page Submit", "Q533_Click Count",
  "Q535_First Click", "Q535_Last Click", "Q535_Page Submit", "Q535_Click Count",
  "Q537_First Click", "Q537_Last Click", "Q537_Page Submit", "Q537_Click Count",
  "Q539_First Click", "Q539_Last Click", "Q539_Page Submit", "Q539_Click Count",
  "Q541_First Click", "Q541_Last Click", "Q541_Page Submit", "Q541_Click Count",
  "Q543_First Click", "Q543_Last Click", "Q543_Page Submit", "Q543_Click Count",
  "journalprompt1", "journalprompt2", "journalprompt3",
  "ChooseActiveVid", "OpenWhyTechnique", "RateCompare", "RateEasy", "RateCalm",
  "RateManage", "RateFuture", "CheckWhyOverOthers", "CheckWhyOpen", "RateFit",
  "OpenHowModify", "ChallengeFocus", "ChallengeTime", "ChallengeComfort",
  "ChallengeNo", "ChallengeOther", "ChallengeOtherText", "RateRecommend",
  "RateMostNatural", "RateLasting", "RateFlexibility",
  "poststress", "postenergy", "postmood",
  "BaselineDate", "SumScore", "Condition", "Emails", "sonaID", "StudyDay",
  "CurrentDate"
)

## Read + rename -------------------------------------------------------------
# Qualtrics exports carry TWO header rows: row 1 is the variable name, row 2 is
# the full question text. read_excel() consumes row 1; we drop the question-text
# row explicitly below rather than relying on skip=, so the wording stays
# available for the codebook.

readQualtrics <- function(path, newNames, label) {
  raw <- read_excel(path, col_types = "text", .name_repair = "minimal")

  if (ncol(raw) != length(newNames)) {
    stop(sprintf(
      "%s: raw export has %d columns but %d names were supplied. The Qualtrics
       export has changed shape -- the positional rename is no longer safe.",
      label, ncol(raw), length(newNames)))
  }

  questionText <- as.character(raw[1, ])   # keep for the codebook
  dat <- raw[-1, ]                          # drop question-text row
  names(dat) <- newNames
  attr(dat, "questionText") <- setNames(questionText, newNames)
  dat
}

baseData <- readQualtrics(rawFiles$baseline, baseNames, "Baseline")
postData <- readQualtrics(rawFiles$post,     postNames, "Post")
intData  <- readQualtrics(rawFiles$booster,  intNames,  "Booster")

## Remove structural rows ----------------------------------------------------
# The Booster export contains one stray literal header row (sonaID == "sonaID"),
# an artefact of the manual email/condition merge. It is not a response.
strayRows <- which(intData$sonaID == "sonaID")
if (length(strayRows) > 0) {
  message(sprintf("Booster: dropping %d stray header row(s).", length(strayRows)))
  intData <- intData[-strayRows, ]
}

## Normalise unresolved Qualtrics placeholders -------------------------------
# Where piped embedded data failed to resolve, Qualtrics writes the literal
# reference instead of the value -- e.g. "${e://Field/Condition" or "%483%".
# These are missing values, not data. In the Booster export this affects 120
# rows, all in the final (choice) week, where Condition never resolved.
#
# This step is what the manual `intConditionFix` sheet in FullData.xlsx did by
# hand; performing it in code is what makes the pipeline reproducible.

isPlaceholder <- function(x) {
  grepl("^\\$\\{[ef]://", x) | grepl("^%[0-9]+%$", x)
}

blankPlaceholders <- function(dat, cols, label) {
  n <- 0
  for (cl in intersect(cols, names(dat))) {
    hit <- isPlaceholder(dat[[cl]]) & !is.na(dat[[cl]])
    if (any(hit)) {
      message(sprintf("  %s$%s: blanking %d unresolved placeholder(s).",
                      label, cl, sum(hit)))
      dat[[cl]][hit] <- NA_character_
      n <- n + sum(hit)
    }
  }
  dat
}

placeholderCols <- c("sonaID", "Emails", "Condition", "StudyDay", "BaselineDate")
message("Normalising Qualtrics placeholders:")
baseData <- blankPlaceholders(baseData, placeholderCols, "Baseline")
postData <- blankPlaceholders(postData, placeholderCols, "Post")
intData  <- blankPlaceholders(intData,  placeholderCols, "Booster")

## Recover missing condition assignments -------------------------------------
# Condition was merged into each export from an external roster keyed on email.
# Where the email field is blank the merge failed, leaving Condition = NA even
# though the participant is validly randomised. Because randomisation is at the
# PERSON level, condition is recoverable by sonaID from any export that has it.
#
# This replaces the hard-coded reassignments in the original script
# (two hand-coded postReady[id == ...] <- "Nature" / "Choice" lines),
# which produced the same result but were not traceable to a data source.

conditionRoster <- bind_rows(
  baseData %>% dplyr::select(sonaID, Condition),
  intData  %>% dplyr::select(sonaID, Condition),
  postData %>% dplyr::select(sonaID, Condition)
) %>%
  filter(!is.na(sonaID), !is.na(Condition)) %>%
  distinct(sonaID, Condition)

# A sonaID mapping to BOTH conditions means that person was randomised twice --
# i.e. they enrolled in the study on two separate occasions (in one case using
# two different email addresses). These are genuine dual enrolments, not merge
# errors, and how to handle them is an analytic decision, not a cleaning one.
#
# We therefore do NOT auto-fill condition for these participants; we record them
# for review and let 03_clean.R apply the documented exclusion rule.
dualEnrolled <- conditionRoster %>%
  count(sonaID, name = "nConditions") %>%
  filter(nConditions > 1) %>%
  pull(sonaID)

if (length(dualEnrolled) > 0) {
  warning(sprintf(
    "%d participant(s) randomised into BOTH conditions (dual enrolment): %s\n  See private/dual_enrolments.csv (contains emails) -- handled in 03_clean.R.",
    length(dualEnrolled), paste(dualEnrolled, collapse = ", ")), call. = FALSE)

  dualReport <- bind_rows(
    baseData %>% transmute(source = "baseline", sonaID, Condition, Emails,
                           StartDate, StudyDay = NA_character_),
    intData  %>% transmute(source = "booster",  sonaID, Condition, Emails,
                           StartDate, StudyDay),
    postData %>% transmute(source = "post",     sonaID, Condition, Emails,
                           StartDate, StudyDay)
  ) %>%
    filter(sonaID %in% dualEnrolled) %>%
    arrange(sonaID, source, StartDate)

  write.csv(dualReport, file.path(privateDir, "dual_enrolments.csv"),
            row.names = FALSE, na = "")
}

# Unambiguous roster: only participants with exactly one condition. The dual
# enrolments are excluded outright in 03_clean.R (decision Q1), so leaving their
# Condition blank here is deliberate -- there is no correct value to fill in.
conditionRoster <- conditionRoster %>% filter(!sonaID %in% dualEnrolled)

# Record the dual-enrolled IDs so 03_clean.R excludes exactly these, rather than
# re-deriving the list and risking drift between the two scripts.
writeLines(dualEnrolled, file.path(privateDir, "dual_enrolled_ids.txt"))

fillCondition <- function(dat, label) {
  before <- sum(is.na(dat$Condition) & !is.na(dat$sonaID))
  dat <- dat %>%
    left_join(conditionRoster, by = "sonaID", suffix = c("", ".roster")) %>%
    mutate(Condition = coalesce(Condition, Condition.roster)) %>%
    dplyr::select(-Condition.roster)
  after <- sum(is.na(dat$Condition) & !is.na(dat$sonaID))
  message(sprintf("%s: recovered condition for %d row(s); %d still missing.",
                  label, before - after, after))
  dat
}

baseData <- fillCondition(baseData, "Baseline")
postData <- fillCondition(postData, "Post")
intData  <- fillCondition(intData,  "Booster")

## Write ---------------------------------------------------------------------
write.csv(baseData, file.path(tidyDir, "baseline.csv"), row.names = FALSE, na = "")
write.csv(intData,  file.path(tidyDir, "booster.csv"),  row.names = FALSE, na = "")
write.csv(postData, file.path(tidyDir, "post.csv"),     row.names = FALSE, na = "")

message(sprintf("\nAssembled: baseline %d rows | booster %d rows | post %d rows",
                nrow(baseData), nrow(intData), nrow(postData)))
