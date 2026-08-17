# 11_supplementary.R --------------------------------------------------------
# Supporting analyses for the revised manuscript:
#   (a) completer vs. non-completer comparison on baseline characteristics
#   (b) parallel analysis / variance justification for the WB composite
#   (c) standardized effect sizes and CI bounds for the null H2 interactions
#
# Output: output/completer_comparison.csv
#         output/wb_parallel_analysis.csv
#         output/h2_effect_sizes.csv

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
analysedIDs <- as.numeric(readLines(file.path(dataDir, "analysed_ids.txt")))

## Score baseline scales for ALL eligible randomised participants ------------
# (baseline_clean.csv holds all 158 eligible, not just the analysed 120.)
# BIPS_8 is reversed explicitly in repairQualtricsCodes(), so no key carries
# psych's leading "-" marker here either. See 00_config.R.
scaleKeys <- list(
  BIPS   = c("BIPS_1", "BIPS_2", "BIPS_3", "BIPS_4", "BIPS_5",
             "BIPS_6", "BIPS_7", "BIPS_8", "BIPS_9"),
  WHO5   = paste0("WHO5_", 1:5),
  Pos    = c("Joy", "Contentment", "Compassion", "Pride", "Love", "Awe", "Amusement"),
  Neg    = c("Anger", "Shame", "Worry", "Sadness", "Jealousy", "Guilty", "Selfish"),
  PHQ    = paste0("PHQ4_", 1:4),
  Belong = paste0("Belong", 1:3)
)
items <- unique(sub("^-", "", unlist(scaleKeys)))
baseData[items] <- lapply(baseData[items], function(x) suppressWarnings(as.numeric(x)))
baseData$Age <- suppressWarnings(as.numeric(baseData$Age))

# Same WHO-5 / PHQ-4 recode repair applied in 04_score.R, so the completer
# comparison is on the same metric as everything else (see 00_config.R).
baseData <- repairQualtricsCodes(baseData, "baseline (supplementary)")

scores <- psych::scoreItems(psych::make.keys(baseData, scaleKeys), baseData,
                            impute = "none", min = NULL, max = NULL)$scores
base <- data.frame(scores, check.names = FALSE)
base$id        <- as.numeric(baseData$pid)
base$Condition <- baseData$Condition
base$Age       <- baseData$Age
base$Woman     <- as.integer(!is.na(baseData$Gender_Woman) & baseData$Gender_Woman != "")
base$completer <- ifelse(base$id %in% analysedIDs, "Completer", "Non-completer")

## (a) Completer vs non-completer --------------------------------------------
# Completers = analysed sample (adherent + both waves). Non-completers = all
# other randomised-eligible participants (did not begin / non-adherent / no post).
message(sprintf("Completers: %d | Non-completers: %d",
                sum(base$completer == "Completer"),
                sum(base$completer == "Non-completer")))

cohensD <- function(x, g) {
  a <- x[g == "Completer"]; b <- x[g == "Non-completer"]
  a <- a[!is.na(a)]; b <- b[!is.na(b)]
  sp <- sqrt(((length(a) - 1) * var(a) + (length(b) - 1) * var(b)) /
               (length(a) + length(b) - 2))
  (mean(a) - mean(b)) / sp
}

contVars <- c("BIPS", "WHO5", "PHQ", "Pos", "Neg", "Belong", "Age")
completerComparison <- lapply(contVars, function(v) {
  t <- t.test(base[[v]] ~ base$completer)
  data.frame(
    variable = v,
    completer_M  = round(mean(base[[v]][base$completer == "Completer"], na.rm = TRUE), 2),
    completer_SD = round(sd(base[[v]][base$completer == "Completer"], na.rm = TRUE), 2),
    noncomp_M    = round(mean(base[[v]][base$completer == "Non-completer"], na.rm = TRUE), 2),
    noncomp_SD   = round(sd(base[[v]][base$completer == "Non-completer"], na.rm = TRUE), 2),
    t = round(unname(t$statistic), 2),
    df = round(unname(t$parameter), 1),
    p = round(t$p.value, 3),
    d = round(cohensD(base[[v]], base$completer), 2)
  )
}) %>% bind_rows()

# Categorical: gender and condition
genderTab <- table(base$Woman, base$completer)
condTab   <- table(base$Condition, base$completer)
genderChi <- suppressWarnings(chisq.test(genderTab))
condChi   <- suppressWarnings(chisq.test(condTab))

catComparison <- data.frame(
  variable = c("Woman (%)", "Condition (% CN)"),
  completer_M = c(round(100 * mean(base$Woman[base$completer == "Completer"]), 1),
                  round(100 * mean(base$Condition[base$completer == "Completer"] == "Nature"), 1)),
  noncomp_M   = c(round(100 * mean(base$Woman[base$completer == "Non-completer"]), 1),
                  round(100 * mean(base$Condition[base$completer == "Non-completer"] == "Nature"), 1)),
  test = c(sprintf("chi2(%d)=%.2f", genderChi$parameter, genderChi$statistic),
           sprintf("chi2(%d)=%.2f", condChi$parameter, condChi$statistic)),
  p = c(round(genderChi$p.value, 3), round(condChi$p.value, 3))
)

message("\nCOMPLETER vs NON-COMPLETER (baseline)")
print(completerComparison, row.names = FALSE)
print(catComparison, row.names = FALSE)

write.csv(completerComparison, file.path(outputDir, "completer_comparison.csv"), row.names = FALSE)
write.csv(catComparison, file.path(outputDir, "completer_comparison_categorical.csv"), row.names = FALSE)

## (b) WB composite justification --------------------------------------------
# Parallel analysis on the five study-level scales, using the same stacked
# baseline+post data the composite is built from.
prepost <- read.csv(file.path(dataDir, "prepost_long.csv"))
wbInputs <- c("BIPS", "WHO5", "PHQ", "Pos", "Neg")

pa <- psych::fa.parallel(prepost[, wbInputs], fa = "pc", n.iter = 1000,
                         plot = FALSE)
pca1 <- psych::pca(prepost[, wbInputs], nfactors = 1)

message(sprintf("\nWB COMPOSITE: parallel analysis suggests %d component(s); PC1 explains %.1f%%",
                pa$ncomp, 100 * pca1$Vaccounted[2, 1]))

wbJustification <- data.frame(
  metric = c("components_suggested_parallel_analysis",
             "pc1_variance_explained_pct",
             paste0("loading_", wbInputs)),
  value  = c(pa$ncomp,
             round(100 * pca1$Vaccounted[2, 1], 1),
             round(as.numeric(pca1$loadings[, 1]), 2))
)
print(wbJustification, row.names = FALSE)
write.csv(wbJustification, file.path(outputDir, "wb_parallel_analysis.csv"), row.names = FALSE)

## (c) Standardized effect sizes for the null H2 interactions ----------------
# Refit the H2 models on standardized outcome and predictor so the interaction
# beta and its CI are interpretable as a small/medium/large effect. This lets
# the paper argue from the CI that the preference effect, if real, is small --
# rather than treating "n.s." as evidence of no effect.
session <- read.csv(file.path(dataDir, "session_long.csv")) %>%
  mutate(SesTime = factor(SesTime, levels = c("Base", "Post")))
h2 <- session %>% filter(!is.na(Pref))

stdEffect <- function(outcome, predictor) {
  d <- h2
  d$y <- scale(d[[outcome]])[, 1]
  d$x <- scale(d[[predictor]])[, 1]
  m <- lmer(y ~ x * SesTime + (1 | id), data = d)
  s <- summary(m)$coefficients
  row <- grep(":SesTimePost$", rownames(s), value = TRUE)
  est <- s[row, "Estimate"]; se <- s[row, "Std. Error"]
  data.frame(outcome = outcome, predictor = predictor,
             std_beta = round(est, 3),
             ci_lo = round(est - qnorm(.975) * se, 3),
             ci_hi = round(est + qnorm(.975) * se, 3),
             p = round(s[row, "Pr(>|t|)"], 3))
}

h2EffectSizes <- bind_rows(
  lapply(c("Stress", "Arousal", "Valence"), stdEffect, predictor = "Pref"),
  lapply(c("Stress", "Arousal", "Valence"), stdEffect, predictor = "PrefRelative")
)

message("\nH2 STANDARDIZED INTERACTION EFFECT SIZES (preference x session time)")
print(h2EffectSizes, row.names = FALSE)
message("  Interpretation: |std beta| ~ 0.1 = small; the largest CI upper bound quantifies")
message("  the biggest preference effect still compatible with the data.")

write.csv(h2EffectSizes, file.path(outputDir, "h2_effect_sizes.csv"), row.names = FALSE)

## (d) WHO-5 on its published metric -----------------------------------------
# With the recode applied, the WHO-5 can be expressed as the raw 0-25 total and
# the 0-100 percentage score (total x 4) that the published thresholds refer to:
# <= 50 indicates poor well-being warranting further assessment, <= 28 indicates
# likely depression. The manuscript's characterisation of the sample depends on
# this, so the numbers are computed rather than asserted.
prepostWho <- read.csv(file.path(dataDir, "prepost_long.csv"))

who5Summary <- prepostWho %>%
  group_by(Time) %>%
  summarise(
    n              = dplyr::n(),
    item_mean      = round(mean(WHO5), 2),
    item_sd        = round(sd(WHO5), 2),
    raw_total      = round(mean(WHO5) * 5, 2),
    raw_total_sd   = round(sd(WHO5 * 5), 2),
    pct_score      = round(mean(WHO5) * 20, 1),
    pct_sd         = round(sd(WHO5 * 20), 1),
    pct_below_50   = round(100 * mean(WHO5 * 20 <= 50), 1),
    pct_below_28   = round(100 * mean(WHO5 * 20 <= 28), 1),
    pct_at_ceiling = round(100 * mean(WHO5 * 20 >= 80), 1),
    .groups = "drop"
  )

message("\nWHO-5 ON ITS PUBLISHED METRIC (analysed sample)")
print(as.data.frame(who5Summary), row.names = FALSE)
message("  Thresholds: <=50 poor well-being / screen further; <=28 likely depression.")

write.csv(who5Summary, file.path(outputDir, "who5_clinical.csv"), row.names = FALSE)

## (e) Scale-by-scale pre-post change ----------------------------------------
# The study-level outcome is a single composite. A reader will reasonably ask
# whether it averages away divergent movement in its constituents, so each
# scale is modelled separately with the same random-intercept structure.
prepostWho <- prepostWho %>%
  mutate(Time  = factor(Time,  levels = c("Baseline", "Post")),
         group = factor(group, levels = c("Choice", "Nature")))

scaleDirections <- c(WHO5 = "higher = better well-being",
                     BIPS = "higher = more stress",
                     PHQ  = "higher = more anxiety/depression",
                     Pos  = "higher = more positive affect",
                     Neg  = "higher = more negative affect",
                     Belong = "higher = more belonging",
                     WB   = "higher = better well-being")

scaleByScale <- lapply(names(scaleDirections), function(v) {
  m <- lmer(as.formula(sprintf("%s ~ Time * group + (1 | id)", v)), data = prepostWho)
  s <- summary(m)$coefficients
  data.frame(
    scale      = v,
    direction  = unname(scaleDirections[v]),
    M_baseline = round(mean(prepostWho[[v]][prepostWho$Time == "Baseline"], na.rm = TRUE), 2),
    M_post     = round(mean(prepostWho[[v]][prepostWho$Time == "Post"], na.rm = TRUE), 2),
    b_time     = round(s["TimePost", "Estimate"], 3),
    p_time     = round(s["TimePost", "Pr(>|t|)"], 4),
    b_timexgrp = round(s["TimePost:groupNature", "Estimate"], 3),
    p_timexgrp = round(s["TimePost:groupNature", "Pr(>|t|)"], 4)
  )
}) %>% bind_rows()

# Holm correction across the six constituent scales (the composite is not a
# constituent of itself, so it is excluded from the family).
constituent <- scaleByScale$scale != "WB"
scaleByScale$p_time_holm <- NA_real_
scaleByScale$p_time_holm[constituent] <-
  round(p.adjust(scaleByScale$p_time[constituent], method = "holm"), 4)

message("\nSCALE-BY-SCALE PRE-POST CHANGE (does the composite mask divergence?)")
print(as.data.frame(scaleByScale), row.names = FALSE)

write.csv(scaleByScale, file.path(outputDir, "scale_by_scale_change.csv"), row.names = FALSE)

message("\nWrote supplementary analyses to output/")
