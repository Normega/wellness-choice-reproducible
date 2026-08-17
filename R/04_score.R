# 04_score.R ----------------------------------------------------------------
# Scores the questionnaire scales, builds the study-level well-being composite,
# and reshapes the booster data into the long (session x time) analysis frame.
#
# Input:  data/*_clean.csv                (from 03_clean.R)
# Output: data/prepost_long.csv           study-level, one row per id x Time
#         data/session_long.csv           session-level, one row per id x day x SesTime
#         data/preferences.csv            baseline preference composites per id
#         output/scale_reliabilities.csv  Cronbach's alpha for every scale

.scriptDir <- function() {
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", a[grep("^--file=", a)])
  if (length(f) > 0) return(dirname(normalizePath(f)))
  if (!is.null(sys.frame(1)$ofile)) return(dirname(normalizePath(sys.frame(1)$ofile)))
  getwd()
}
source(file.path(.scriptDir(), "00_config.R"))
loadPackages()

baseData <- read.csv(file.path(dataDir, "baseline_clean.csv"), colClasses = "character")
postData <- read.csv(file.path(dataDir, "post_clean.csv"),     colClasses = "character")
intData  <- read.csv(file.path(dataDir, "booster_clean.csv"),  colClasses = "character")
boosterCompletion <- read.csv(file.path(dataDir, "booster_completion.csv"))

## Scale definitions ---------------------------------------------------------
# No key carries psych's leading "-" reverse marker. BIPS_8, the study's only
# reverse-keyed item, is reversed explicitly in repairQualtricsCodes() rather
# than left to scoreItems(), which derives the reversal constant from the whole
# item frame and got it wrong here. See 00_config.R.
scaleKeys <- list(
  BIPS   = c("BIPS_1", "BIPS_2", "BIPS_3", "BIPS_4", "BIPS_5",
             "BIPS_6", "BIPS_7", "BIPS_8", "BIPS_9"),
  WHO5   = paste0("WHO5_", 1:5),
  Pos    = c("Joy", "Contentment", "Compassion", "Pride", "Love", "Awe", "Amusement"),
  Neg    = c("Anger", "Shame", "Worry", "Sadness", "Jealousy", "Guilty", "Selfish"),
  PHQ    = paste0("PHQ4_", 1:4),
  Belong = paste0("Belong", 1:3)
)

# Baseline-only: preference composites, one per candidate activity.
prefDims <- c("Ranking", "Comfort", "Benefit", "Practical", "LongTerm")
prefKeys <- list(
  MindfulPref     = paste0(prefDims, "_Mindful"),
  BreathPref      = paste0(prefDims, "_Breath"),
  JournallingPref = paste0(prefDims, "_Journalling"),
  NaturePref      = paste0(prefDims, "_Nature")
)

## Numeric conversion --------------------------------------------------------
scaleItemNames <- function(keys) unique(sub("^-", "", unlist(keys)))

toNumeric <- function(dat, cols) {
  cols <- intersect(cols, names(dat))
  dat[cols] <- lapply(dat[cols], function(x) suppressWarnings(as.numeric(x)))
  dat
}

visualScales <- c("ArousalVisual", "ValenceVisual", "StressVisual", "SatisfactionVisual")

baseData <- toNumeric(baseData, c(scaleItemNames(scaleKeys), scaleItemNames(prefKeys),
                                  visualScales, "Age", "YearofStudy", "SES", "Wbladder"))
postData <- toNumeric(postData, c(scaleItemNames(scaleKeys), visualScales))

## Repair non-contiguous / offset Qualtrics recode values ---------------------
# WHO-5 exports as 2,4,5,6,7,9 and PHQ-4 as 1-4; both are put on their
# instruments' own metrics here so that every downstream score, descriptive and
# threshold comparison is on a scale the published norms actually refer to.
# See 00_config.R for the mapping and the assertion that guards it.
message("\nQUALTRICS RECODE REPAIR")
baseData <- repairQualtricsCodes(baseData, "baseline")
postData <- repairQualtricsCodes(postData, "post")

## Score scales --------------------------------------------------------------
# NOTE ON A BUG IN THE ORIGINAL SCRIPT
# Line 488 built the POST scoring key from `baseData`:
#     postKeys = make.keys(baseData, list(...)); scoreItems(postKeys, postData)
# That happens to work because scoreItems() matches keys to items by NAME, not
# position -- but only as long as every keyed item exists in postData under the
# same name. It is silently wrong the moment the two surveys diverge. Here each
# key matrix is built from the frame it will actually score, and the resulting
# scores are asserted below to be identical to the original approach.

scoreScales <- function(dat, keys, label) {
  keyMatrix <- psych::make.keys(dat, keys)
  # impute = "none": the analysed sample has a complete outcome battery by
  # construction (03_clean.R), so imputation should never fire. Leaving the
  # psych default of median imputation would hide it if that ever stopped
  # being true.
  scored <- psych::scoreItems(keyMatrix, dat, impute = "none", min = NULL, max = NULL)
  message(sprintf("  %s: scored %d scales on %d rows", label, length(keys), nrow(dat)))
  scored
}

message("\nSCORING")
baseScales <- scoreScales(baseData, c(scaleKeys, prefKeys), "baseline")
postScales <- scoreScales(postData, scaleKeys,              "post")

# Verify the original's cross-frame key construction gives the same answer, so
# we know the published scores are not affected by that bug.
origPostKeys   <- psych::make.keys(baseData, scaleKeys)
origPostScores <- psych::scoreItems(origPostKeys, postData, impute = "none",
                                    min = NULL, max = NULL)$scores
stopifnot(all.equal(unname(postScales$scores), unname(origPostScores)))
message("  verified: post scores identical under the original's key construction")

# No imputation should have been required.
stopifnot(!any(is.na(baseScales$scores[, names(scaleKeys)])))
stopifnot(!any(is.na(postScales$scores)))

## Reliabilities -------------------------------------------------------------
# Reported on two samples, because which one the manuscript intends is currently
# ambiguous: the full eligible randomised sample, and the analysed subset with
# complete pre-post data. The alphas differ enough to matter at two decimals.
analysedIDsForAlpha <- as.numeric(readLines(file.path(dataDir, "analysed_ids.txt")))

alphaRow <- function(scored, wave, sample, n) {
  tibble::tibble(wave = wave, sample = sample, n = n,
                 scale = colnames(scored$alpha),
                 alpha = round(as.numeric(scored$alpha[1, ]), 3))
}

baseAnalysed <- baseData[as.numeric(baseData$pid) %in% analysedIDsForAlpha, ]
postAnalysed <- postData[as.numeric(postData$pid) %in% analysedIDsForAlpha, ]

reliabilities <- bind_rows(
  alphaRow(baseScales, "baseline", "all eligible", nrow(baseData)),
  alphaRow(postScales, "post",     "all with post survey", nrow(postData)),
  alphaRow(scoreScales(baseAnalysed, c(scaleKeys, prefKeys), "baseline (analysed)"),
           "baseline", "analysed", nrow(baseAnalysed)),
  alphaRow(scoreScales(postAnalysed, scaleKeys, "post (analysed)"),
           "post", "analysed", nrow(postAnalysed))
)

write.csv(reliabilities, file.path(outputDir, "scale_reliabilities.csv"), row.names = FALSE)

message("\nRELIABILITIES (Cronbach's alpha)")
print(as.data.frame(reliabilities %>%
  mutate(col = paste0(wave, " (", sample, ", n=", n, ")")) %>%
  dplyr::select(scale, col, alpha) %>%
  tidyr::pivot_wider(names_from = col, values_from = alpha)), row.names = FALSE)

## Assemble the study-level frame --------------------------------------------
buildWave <- function(dat, scores, waveLabel) {
  data.frame(scores[, names(scaleKeys)], check.names = FALSE) %>%
    mutate(
      id           = as.numeric(dat$pid),
      group        = dat$Condition,
      Arousal      = dat$ArousalVisual,
      Valence      = dat$ValenceVisual,
      Stress       = dat$StressVisual,
      Satisfaction = dat$SatisfactionVisual,
      Time         = waveLabel
    )
}

# The study-level frame is restricted to participants with BOTH waves plus
# adherence (analysedIDs); baseline scores for everyone else stay available for
# the session-level analyses via `preferences` below.
analysedIDs <- as.numeric(readLines(file.path(dataDir, "analysed_ids.txt")))

prepost <- bind_rows(
  buildWave(baseData, baseScales$scores, "Baseline"),
  buildWave(postData, postScales$scores, "Post")
) %>%
  filter(id %in% analysedIDs) %>%
  left_join(boosterCompletion, by = c("id" = "pid"))

stopifnot(nrow(prepost) == 2 * length(unique(prepost$id)))
stopifnot(length(unique(prepost$id)) == length(analysedIDs))
stopifnot(!any(is.na(prepost$group)))

## Well-being composite ------------------------------------------------------
# First unrotated principal component of the five study-level scales, fitted on
# baseline and post rows STACKED so the component is defined once across both
# waves rather than re-estimated per wave.
wbInputs <- c("BIPS", "WHO5", "PHQ", "Pos", "Neg")
wbPca <- psych::pca(prepost[, wbInputs], nfactors = 1)

# The sign of a principal component is arbitrary and depends on the sample, so
# the original script's hard-coded `-1 *` is not safe to carry over -- a change
# in the analysed sample could silently invert the outcome variable. Orient the
# component instead so that it correlates positively with WHO-5, i.e. higher
# always means better well-being.
wbScores  <- as.numeric(wbPca$scores[, 1])
wbLoading <- as.numeric(wbPca$loadings[, 1])
orientation <- if (cor(wbScores, prepost$WHO5, use = "complete.obs") < 0) -1 else 1
wbScores  <- orientation * wbScores
wbLoading <- orientation * wbLoading   # report loadings on the oriented component
prepost$WB <- wbScores

message(sprintf("\nWB composite: %.1f%% of variance; loadings %s",
                100 * wbPca$Vaccounted[2, 1],
                paste(sprintf("%s=%+.2f", wbInputs, wbLoading), collapse = ", ")))
stopifnot(cor(prepost$WB, prepost$WHO5, use = "complete.obs") > 0)
stopifnot(cor(prepost$WB, prepost$BIPS, use = "complete.obs") < 0)

# Baseline value of every study-level measure, attached to both rows, for the
# baseline-as-moderator analyses.
baselineValues <- prepost %>%
  filter(Time == "Baseline") %>%
  dplyr::select(id, all_of(c(wbInputs, "Belong", "WB",
                             "Arousal", "Valence", "Stress", "Satisfaction"))) %>%
  rename_with(~ paste0("base", .x), -id)

prepost <- left_join(prepost, baselineValues, by = "id")

## Session-level frame -------------------------------------------------------
# Which practice a participant did on a given day is recorded only implicitly,
# via which block's page-timing columns are populated.
trainingBlocks <- list(
  Mindfulness = c("Q533", "Q535", "Q537"),
  Breath      = c("Q539", "Q541", "Q543"),
  Nature      = c("Q478", "Q513", "Q515",   # campfire
                  "Q517", "Q520", "Q525",   # lake
                  "Q527", "Q529", "Q531")   # waterfall
)

blockSeen <- function(dat, prefixes) {
  cols <- paste0(prefixes, "_First.Click")
  cols <- intersect(cols, names(dat))
  if (length(cols) == 0) return(rep(FALSE, nrow(dat)))
  rowSums(!is.na(dat[cols]) & dat[cols] != "") > 0
}

seen <- sapply(trainingBlocks, function(p) blockSeen(intData, p))
seen <- cbind(seen, Journal = rowSums(
  !is.na(intData[paste0("journalprompt", 1:3)]) &
    intData[paste0("journalprompt", 1:3)] != "") > 0)

# The original assigned Training with a cascade of overwrites, so a row matching
# two blocks silently took whichever was assigned last. Check that never happens.
multi <- rowSums(seen) > 1
if (any(multi)) {
  warning(sprintf("%d session(s) match more than one training block; see output/training_conflicts.csv",
                  sum(multi)), call. = FALSE)
  write.csv(cbind(intData[multi, c("pid", "StudyDay", "Condition")], seen[multi, ]),
            file.path(outputDir, "training_conflicts.csv"), row.names = FALSE)
}

intData$Training <- NA_character_
for (nm in colnames(seen)) intData$Training[seen[, nm] & !multi] <- nm

message(sprintf("\nTraining classified for %d of %d sessions (%d unclassified)",
                sum(!is.na(intData$Training)), nrow(intData),
                sum(is.na(intData$Training))))
print(table(intData$Training, intData$Condition, useNA = "ifany"))

sessionVars <- c(Stress = "Stress", Arousal = "Arousal", Valence = "Valence")

sessionLong <- bind_rows(
  intData %>%
    transmute(id = as.numeric(pid), StudyDay = as.numeric(StudyDay),
              Condition, Training, SesTime = "Base",
              Stress = PreStress, Arousal = PreArousal, Valence = PreValence),
  intData %>%
    transmute(id = as.numeric(pid), StudyDay = as.numeric(StudyDay),
              Condition, Training, SesTime = "Post",
              Stress = poststress, Arousal = postenergy, Valence = postmood)
) %>%
  mutate(across(all_of(names(sessionVars)), ~ suppressWarnings(as.numeric(.x))),
         SesTime  = factor(SesTime, levels = c("Base", "Post")),
         Training = factor(Training)) %>%
  filter(!is.na(Condition))

# IMPORTANT: sessions with an unknown Training are NOT dropped here.
#
# On study days 24 and 25 the booster survey recorded no practice-selection data
# whatsoever -- no ChooseActiveVid/ChooseNatureVid, no per-video page timings,
# and none of the choice-week preference items -- although the pre- and
# post-session ratings came through intact. This is the same session on which
# the Condition field failed to pipe (see 01_assemble.R), so it looks like a
# survey-flow fault affecting one session of the choice week. It accounts for
# 106 of the 109 unclassifiable sessions.
#
# The original script filtered `!is.na(Training)` once, up front, which removed
# those sessions from EVERY downstream analysis. That is right for H2, which
# needs to know which practice was done -- but wrong for the study-phase
# comparisons, where phase is determined by StudyDay alone. Dropping them there
# discards roughly a third of the choice week for no reason.
#
# Training is therefore left as NA and each analysis filters on what it needs:
# H2 filters on !is.na(Pref); the phase models do not.

## Study phase (Wellness Choice arm) -----------------------------------------
sessionLong <- sessionLong %>%
  mutate(StudyPhase = case_when(
    StudyDay >= 1  & StudyDay <= 7  ~ "Mindfulness",
    StudyDay >= 8  & StudyDay <= 14 ~ "Breath",
    StudyDay >= 15 & StudyDay <= 21 ~ "Journal",
    StudyDay >  21                  ~ "Choice"
  ),
  StudyPhase = factor(StudyPhase,
                      levels = c("Mindfulness", "Breath", "Journal", "Choice")))

## Baseline preference composites --------------------------------------------
preferences <- data.frame(baseScales$scores[, names(prefKeys)], check.names = FALSE) %>%
  mutate(id = as.numeric(baseData$pid)) %>%
  dplyr::select(id, everything())

# Preference for the practice actually done that day, and the same score
# expressed relative to the mean preference for the other three practices.
prefLookup <- c(Mindfulness = "MindfulPref", Breath = "BreathPref",
                Journal = "JournallingPref", Nature = "NaturePref")

prefLong <- preferences %>%
  tidyr::pivot_longer(-id, names_to = "prefCol", values_to = "pref") %>%
  group_by(id) %>%
  mutate(prefRelative = pref - (sum(pref) - pref) / (n() - 1)) %>%
  ungroup() %>%
  mutate(Training = names(prefLookup)[match(prefCol, prefLookup)])

sessionLong <- sessionLong %>%
  left_join(prefLong %>% dplyr::select(id, Training, Pref = pref,
                                       PrefRelative = prefRelative),
            by = c("id", "Training"))

## Write ---------------------------------------------------------------------
write.csv(prepost,     file.path(dataDir, "prepost_long.csv"),  row.names = FALSE, na = "")
write.csv(sessionLong, file.path(dataDir, "session_long.csv"),  row.names = FALSE, na = "")
write.csv(preferences, file.path(dataDir, "preferences.csv"),   row.names = FALSE, na = "")

message(sprintf("\nWrote prepost_long (%d rows, %d participants) and session_long (%d rows)",
                nrow(prepost), length(unique(prepost$id)), nrow(sessionLong)))
