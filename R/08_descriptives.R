# 08_descriptives.R ---------------------------------------------------------
# Sample demographics and descriptive statistics for the Participants section,
# the CONSORT diagram, and the supplementary descriptive tables.
#
# Output: output/demographics.csv         demographics by condition and overall
#         output/descriptives_prepost.csv Table S1
#         output/descriptives_session.csv Table S2

.scriptDir <- function() {
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", a[grep("^--file=", a)])
  if (length(f) > 0) return(dirname(normalizePath(f)))
  if (!is.null(sys.frame(1)$ofile)) return(dirname(normalizePath(sys.frame(1)$ofile)))
  getwd()
}
source(file.path(.scriptDir(), "00_config.R"))
loadPackages()

baseData    <- read.csv(file.path(dataDir, "baseline_clean.csv"), colClasses = "character")
prepost     <- read.csv(file.path(dataDir, "prepost_long.csv"))
session     <- read.csv(file.path(dataDir, "session_long.csv"))
analysedIDs <- as.numeric(readLines(file.path(dataDir, "analysed_ids.txt")))
# Needed to describe the adherent sample as well as the analysed one.
boosterCompletion <- read.csv(file.path(dataDir, "booster_completion.csv"))

demo <- baseData %>%
  mutate(pid = as.numeric(pid)) %>%
  filter(pid %in% analysedIDs) %>%
  mutate(Age = suppressWarnings(as.numeric(Age)),
         YearNum = suppressWarnings(as.numeric(YearofStudy)))

## Year of study -------------------------------------------------------------
# The item offered five options in order: first, second, third, fourth, and
# fifth-or-more (confirmed by NF, 2026-07-19). Qualtrics did NOT store them as
# 1-5, however: the raw export contains the recode values 1, 4, 5, 6 and 7
# (choices 2 and 3 having presumably been deleted and re-added during survey
# construction, which shifts the retained choice IDs). Five stored codes for
# five options, in ascending display order, gives the mapping below; the
# observed frequencies (122, 41, 10, 3, 2 across the full export) match the
# expected distribution for a first-year-heavy undergraduate sample.
yearLabels <- c("1" = "First year",  "4" = "Second year", "5" = "Third year",
                "6" = "Fourth year", "7" = "Fifth year or more")

demo$YearLabel <- factor(yearLabels[as.character(demo$YearNum)],
                         levels = unname(yearLabels))

# Any code outside the known set means the survey was edited again and the
# mapping needs revisiting -- fail rather than silently drop people.
unmapped <- setdiff(unique(na.omit(demo$YearNum)), as.numeric(names(yearLabels)))
if (length(unmapped) > 0) {
  stop("Unrecognised YearofStudy code(s): ", paste(unmapped, collapse = ", "),
       " -- the Qualtrics recode values have changed.")
}

## Gender --------------------------------------------------------------------
# Checkbox items: "1" if selected, blank otherwise. Not mutually exclusive, so
# these are counts of selections rather than a partition of the sample.
genderCols <- c(Man = "Gender_Man", Woman = "Gender_Woman",
                NonBinary = "Gender_NB", Transgender = "Gender_Transgender",
                Other = "Gender_Other", PreferNoAnswer = "Gender_PreferNoAnswer")

genderCounts <- sapply(genderCols, function(cl)
  sum(!is.na(demo[[cl]]) & demo[[cl]] != ""))

## Summary by condition ------------------------------------------------------
byCondition <- demo %>%
  group_by(Condition) %>%
  summarise(
    n        = n(),
    age_M    = round(mean(Age, na.rm = TRUE), 2),
    age_SD   = round(sd(Age,   na.rm = TRUE), 2),
    # Median and IQR as well as mean and SD: the WC mean and SD are inflated by
    # a few mature students, so the mean alone misdescribes both arms.
    age_median = median(Age, na.rm = TRUE),
    age_q1   = quantile(Age, .25, na.rm = TRUE, names = FALSE),
    age_q3   = quantile(Age, .75, na.rm = TRUE, names = FALSE),
    age_min  = min(Age, na.rm = TRUE),
    age_max  = max(Age, na.rm = TRUE),
    woman_n  = sum(!is.na(Gender_Woman) & Gender_Woman != ""),
    woman_pc = round(100 * woman_n / n(), 1),
    .groups  = "drop"
  )

overall <- demo %>%
  summarise(
    Condition = "Overall", n = n(),
    age_M   = round(mean(Age, na.rm = TRUE), 2),
    age_SD  = round(sd(Age,   na.rm = TRUE), 2),
    age_median = median(Age, na.rm = TRUE),
    age_q1  = quantile(Age, .25, na.rm = TRUE, names = FALSE),
    age_q3  = quantile(Age, .75, na.rm = TRUE, names = FALSE),
    age_min = min(Age, na.rm = TRUE), age_max = max(Age, na.rm = TRUE),
    woman_n = sum(!is.na(Gender_Woman) & Gender_Woman != ""),
    woman_pc = round(100 * woman_n / n(), 1)
  )

demographics <- bind_rows(byCondition, overall)

message("DEMOGRAPHICS (analysed sample)")
print(as.data.frame(demographics), row.names = FALSE)

message("\nGender selections (not mutually exclusive):")
print(genderCounts)

message("\nYear of study:")
print(table(demo$YearLabel, demo$Condition, useNA = "ifany"))

# The manuscript reports Mage = 19.33, SD = 4.08. Age ranges to 60 in this
# sample, so the SD is sensitive to a small number of mature students; report
# the range alongside the SD.
message(sprintf("\nAge range %g-%g; %d participant(s) over 30",
                min(demo$Age, na.rm = TRUE), max(demo$Age, na.rm = TRUE),
                sum(demo$Age > 30, na.rm = TRUE)))

## Age by condition, for every sample, with robust statistics ----------------
# The arms look badly imbalanced on age when described by mean and SD (WC
# SD = 6.28 vs CN SD = 1.05), but that is the work of a handful of mature
# students in the WC arm rather than a difference in the typical participant:
# medians are 19 vs 18 and the interquartile range is 18-19 in BOTH arms.
#
# Mean and SD are reported alongside median, IQR and a count of participants
# over 25 so the source of the apparent imbalance is visible, and a
# leave-the-k-oldest-out table quantifies how concentrated it is.
#
# Ages are also reported per sample, because the CONSORT boxes describe the
# randomised arms while the study-level descriptives describe the analysed
# subset -- pairing one sample's n with another's age is an easy error.
allBase <- baseData %>%
  mutate(pid = as.numeric(pid), Age = suppressWarnings(as.numeric(Age)))
adherentIDsForAge <- boosterCompletion$pid[
  boosterCompletion$boosterCompletions >= minBoosterSessions]

ageRows <- function(dat, sampleLabel) {
  dat %>%
    filter(!is.na(Age), Condition %in% c("Choice", "Nature")) %>%
    group_by(Condition) %>%
    summarise(
      sample   = sampleLabel,
      n        = dplyr::n(),
      M        = round(mean(Age), 2),
      SD       = round(sd(Age), 2),
      median   = median(Age),
      q1       = quantile(Age, .25, names = FALSE),
      q3       = quantile(Age, .75, names = FALSE),
      min      = min(Age),
      max      = max(Age),
      n_over25 = sum(Age > 25),
      .groups  = "drop"
    ) %>%
    dplyr::select(sample, Condition, everything())
}

ageBySample <- bind_rows(
  ageRows(allBase, "randomised and eligible"),
  ageRows(allBase %>% filter(pid %in% adherentIDsForAge), "adherent"),
  ageRows(allBase %>% filter(pid %in% analysedIDs), "analysed")
)

message("\nAGE BY CONDITION AND SAMPLE")
print(as.data.frame(ageBySample), row.names = FALSE)
write.csv(ageBySample, file.path(outputDir, "age_by_condition.csv"), row.names = FALSE)

# How concentrated is the WC spread? Recompute after removing the k oldest.
wcAge <- sort(allBase$Age[allBase$pid %in% analysedIDs &
                            allBase$Condition == "Choice" & !is.na(allBase$Age)])
cnAge <- allBase$Age[allBase$pid %in% analysedIDs &
                       allBase$Condition == "Nature" & !is.na(allBase$Age)]
ssTotal <- sum((wcAge - mean(wcAge))^2)

ageSensitivity <- lapply(0:4, function(k) {
  a <- head(wcAge, length(wcAge) - k)
  data.frame(oldest_removed = k, n = length(a),
             M = round(mean(a), 2), SD = round(sd(a), 2), max = max(a),
             pct_of_wc_variance_explained =
               round(100 * (1 - sum((a - mean(a))^2) / ssTotal), 1))
}) %>% bind_rows()

message("\nWC AGE SPREAD: effect of removing the k oldest participants (analysed sample)")
print(as.data.frame(ageSensitivity), row.names = FALSE)
message(sprintf("  CN reference: n = %d, M = %.2f, SD = %.2f",
                length(cnAge), mean(cnAge), sd(cnAge)))

write.csv(ageSensitivity, file.path(outputDir, "age_outlier_sensitivity.csv"),
          row.names = FALSE)

## Arm comparison on age, per sample -----------------------------------------
# Baseline balance is a property of the RANDOMISED sample, so that is the row
# the manuscript should quote. Both are emitted because it is otherwise very
# easy to pair one sample's descriptives with another's test -- which is exactly
# the error this table now prevents. On the randomised sample the difference is
# not significant even by t test.
ageArmTest <- lapply(c("randomised and eligible", "adherent", "analysed"),
                     function(lab) {
  d <- switch(lab,
    "randomised and eligible" = allBase,
    "adherent"                = allBase %>% filter(pid %in% adherentIDsForAge),
    "analysed"                = allBase %>% filter(pid %in% analysedIDs))
  w <- sort(d$Age[d$Condition == "Choice" & !is.na(d$Age)])
  c_ <- d$Age[d$Condition == "Nature" & !is.na(d$Age)]
  w1 <- head(w, length(w) - 1)
  data.frame(
    sample = lab,
    wc_n = length(w), cn_n = length(c_),
    wc_M = round(mean(w), 2), wc_SD = round(sd(w), 2),
    cn_M = round(mean(c_), 2), cn_SD = round(sd(c_), 2),
    welch_p = round(t.test(w, c_)$p.value, 4),
    wilcoxon_p = round(suppressWarnings(wilcox.test(w, c_))$p.value, 4),
    oldest_pct_of_wc_variance =
      round(100 * (1 - sum((w1 - mean(w1))^2) / sum((w - mean(w))^2)), 1)
  )
}) %>% bind_rows()

message("\nAGE: ARM COMPARISON BY SAMPLE (quote the randomised row for balance)")
print(as.data.frame(ageArmTest), row.names = FALSE)

write.csv(ageArmTest, file.path(outputDir, "age_arm_comparison.csv"), row.names = FALSE)

## Descriptive statistics ----------------------------------------------------
studyVars <- c("BIPS", "WHO5", "Pos", "Neg", "PHQ", "Belong",
               "Arousal", "Valence", "Stress", "Satisfaction",
               "boosterCompletions", "WB")

descPrepost <- prepost %>%
  tidyr::pivot_longer(all_of(studyVars), names_to = "variable", values_to = "value") %>%
  group_by(variable, Time) %>%
  summarise(n = sum(!is.na(value)),
            M = round(mean(value, na.rm = TRUE), 3),
            SD = round(sd(value, na.rm = TRUE), 3), .groups = "drop")

descSession <- session %>%
  tidyr::pivot_longer(c("Stress", "Arousal", "Valence"),
                      names_to = "variable", values_to = "value") %>%
  group_by(variable, SesTime) %>%
  summarise(n = sum(!is.na(value)),
            M = round(mean(value, na.rm = TRUE), 3),
            SD = round(sd(value, na.rm = TRUE), 3), .groups = "drop")

yearTable <- demo %>%
  count(YearLabel, Condition, .drop = FALSE) %>%
  tidyr::pivot_wider(names_from = Condition, values_from = n, values_fill = 0) %>%
  mutate(total = rowSums(across(where(is.numeric))))

write.csv(yearTable, file.path(outputDir, "demographics_year.csv"), row.names = FALSE)
write.csv(demographics, file.path(outputDir, "demographics.csv"), row.names = FALSE)
write.csv(data.frame(gender = names(genderCounts), n = as.integer(genderCounts)),
          file.path(outputDir, "demographics_gender.csv"), row.names = FALSE)
write.csv(descPrepost, file.path(outputDir, "descriptives_prepost.csv"), row.names = FALSE)
write.csv(descSession, file.path(outputDir, "descriptives_session.csv"), row.names = FALSE)

message("\nWrote descriptives to output/")
