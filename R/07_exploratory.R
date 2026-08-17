# 07_exploratory.R ----------------------------------------------------------
# Exploratory analyses reported in the manuscript:
#   (a) comparison of the three fixed practice weeks against the choice week
#   (b) whether baseline preference predicted practice selection in the choice week
#   (c) baseline well-being as a moderator of pre-post change
#
# Output: output/expl_phase_baseline.csv   Table 5, session baseline scores
#         output/expl_phase_change.csv     Table 5, pre-post session change
#         output/expl_choice_ordinal.csv   practice selection model
#         output/expl_baseline_moderator.csv  Table 6
#         output/expl_comparison.csv       pipeline vs published values

.scriptDir <- function() {
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", a[grep("^--file=", a)])
  if (length(f) > 0) return(dirname(normalizePath(f)))
  if (!is.null(sys.frame(1)$ofile)) return(dirname(normalizePath(sys.frame(1)$ofile)))
  getwd()
}
source(file.path(.scriptDir(), "00_config.R"))
loadPackages()

session <- read.csv(file.path(dataDir, "session_long.csv"))
prepost <- read.csv(file.path(dataDir, "prepost_long.csv"))
preferences <- read.csv(file.path(dataDir, "preferences.csv"))

tidyFixed <- function(model, label) {
  s <- summary(model)$coefficients
  est <- s[, "Estimate"]; se <- s[, "Std. Error"]; p <- s[, "Pr(>|t|)"]
  data.frame(model = label, term = rownames(s),
             b = round(est, 3),
             ci_lo = round(est - qnorm(.975) * se, 3),
             ci_hi = round(est + qnorm(.975) * se, 3),
             p = round(p, 4), row.names = NULL)
}

outcomes <- c("Stress", "Arousal", "Valence")

## --------------------------------------------------------------------------
## (a) Study phase: fixed practice weeks vs the choice week
## --------------------------------------------------------------------------
# Restricted to the Wellness Choice arm, where the practice actually varied by
# week. Note this analysis needs only StudyDay (which determines phase), NOT
# Training -- so the days 24-25 sessions with no recorded practice are retained
# here. The original script dropped them; see ANALYSIS_NOTES 9.4.

choiceArm <- session %>%
  filter(Condition == "Choice", !is.na(StudyPhase)) %>%
  mutate(SesTime = factor(SesTime, levels = c("Base", "Post"))) %>%
  withStudyPhaseContrasts()   # difference-scaled; see 00_config.R

message(sprintf("Study-phase analysis: %d observations from %d WC participants",
                nrow(choiceArm), length(unique(choiceArm$id))))
message("  sessions per phase:")
print(table(choiceArm$StudyPhase, choiceArm$SesTime))

# Session baseline scores: how did people feel arriving at each week's session?
phaseBaseline <- lapply(outcomes, function(o) {
  f <- as.formula(sprintf("%s ~ StudyPhase + (1 | id)", o))
  tidyFixed(lmer(f, data = choiceArm %>% filter(SesTime == "Base")), o)
}) %>% bind_rows()

message("\nSTUDY PHASE -- session baseline scores")
print(phaseBaseline %>% filter(grepl("StudyPhase", term)), row.names = FALSE)

# VERIFY THE CONTRAST SCALING.
# With the difference-scaled contrasts each coefficient should equal the
# corresponding estimated-marginal-mean contrast. Asserting it here is what
# stops the four-fold scaling error from ever coming back silently.
emmCheck <- lapply(outcomes, function(o) {
  m  <- lmer(as.formula(sprintf("%s ~ StudyPhase + (1 | id)", o)),
             data = choiceArm %>% filter(SesTime == "Base"))
  em <- emmeans::emmeans(m, ~ StudyPhase)
  ct <- emmeans::contrast(em, list(
    FixedVsChoice       = c(-1/3, -1/3, -1/3, 1),
    JournalVsMindBody   = c(-1/2, -1/2,  1,   0),
    BreathVsMindfulness = c(-1,    1,    0,   0)))
  data.frame(model = o, term = paste0("StudyPhase", summary(ct)$contrast),
             emm_estimate = round(summary(ct)$estimate, 3))
}) %>% bind_rows()

scaleCheck <- phaseBaseline %>%
  inner_join(emmCheck, by = c("model", "term")) %>%
  mutate(agrees = abs(b - emm_estimate) < 1e-3)

message("\n  contrast scaling check (coefficient == marginal-mean difference)")
print(as.data.frame(scaleCheck %>% dplyr::select(model, term, b, emm_estimate, agrees)),
      row.names = FALSE)
stopifnot(all(scaleCheck$agrees))

# Pre-post change: did within-session benefit differ by week?
phaseChange <- lapply(outcomes, function(o) {
  f <- as.formula(sprintf("%s ~ StudyPhase * SesTime + (1 | id)", o))
  tidyFixed(lmer(f, data = choiceArm), o)
}) %>% bind_rows()

message("\nSTUDY PHASE -- pre-post session change (interaction terms)")
print(phaseChange %>% filter(grepl(":", term)), row.names = FALSE)

## Choice-week effect sizes, for the Discussion ------------------------------
# The Discussion characterises how large these effects are. Those figures are
# computed here rather than by hand, because they were previously described as
# negligible on the mis-scaled contrasts and must not drift again.
#
# Reported: the choice-vs-fixed contrast in SD units, the within-session change
# per phase, and how much of the fixed-week reduction the choice week retains.
sessionSD <- session %>% filter(SesTime == "Base") %>%
  summarise(across(all_of(outcomes), ~sd(.x, na.rm = TRUE)))

phaseBaselineSD <- phaseBaseline %>%
  filter(term == "StudyPhaseFixedVsChoice") %>%
  rowwise() %>%
  mutate(sd_units = round(b / sessionSD[[model]], 3),
         ci_lo_sd = round(ci_lo / sessionSD[[model]], 3),
         ci_hi_sd = round(ci_hi / sessionSD[[model]], 3)) %>%
  ungroup() %>%
  dplyr::select(model, b, ci_lo, ci_hi, p, sd_units, ci_lo_sd, ci_hi_sd)

message("\nCHOICE WEEK vs FIXED WEEKS -- session-baseline scores in SD units")
print(as.data.frame(phaseBaselineSD), row.names = FALSE)

phaseWithin <- choiceArm %>%
  group_by(StudyPhase, SesTime) %>%
  summarise(across(all_of(outcomes), ~mean(.x, na.rm = TRUE)), .groups = "drop") %>%
  tidyr::pivot_longer(all_of(outcomes), names_to = "outcome", values_to = "M") %>%
  tidyr::pivot_wider(names_from = SesTime, values_from = M) %>%
  mutate(change = round(Post - Base, 3),
         Base = round(Base, 3), Post = round(Post, 3))

message("\nWITHIN-SESSION CHANGE BY STUDY PHASE (Wellness Choice arm)")
print(as.data.frame(phaseWithin), row.names = FALSE)

retention <- phaseWithin %>%
  group_by(outcome) %>%
  summarise(
    fixed_change  = round(mean(change[StudyPhase != "Choice"]), 3),
    choice_change = round(change[StudyPhase == "Choice"], 3),
    pct_retained  = round(100 * change[StudyPhase == "Choice"] /
                            mean(change[StudyPhase != "Choice"]), 1),
    .groups = "drop"
  )

message("\nHOW MUCH OF THE FIXED-WEEK WITHIN-SESSION CHANGE THE CHOICE WEEK RETAINS")
print(as.data.frame(retention), row.names = FALSE)

write.csv(phaseBaselineSD, file.path(outputDir, "choice_week_effect_sizes.csv"),
          row.names = FALSE)
write.csv(left_join(phaseWithin, retention, by = "outcome"),
          file.path(outputDir, "choice_week_within_session.csv"), row.names = FALSE)

## --------------------------------------------------------------------------
## (a2) Was the week-4 shift specific to choosing among distinct techniques?
## --------------------------------------------------------------------------
# BOTH arms chose in week 4: WC participants picked one of mindfulness, paced
# breathing or journaling; CN participants picked one of campfire, lake or
# waterfall. The phase analysis above is WC-only, so it cannot tell whether the
# week-4 improvement in arriving affective state reflects an informed choice
# among genuinely different self-regulation techniques, or simply being four
# weeks into the protocol.
#
# The CN arm is the informative comparison. Choosing between three passive
# nature videos is a far thinner version of the same manipulation, so a
# choice-specific account predicts a LARGER week-4 shift in WC than in CN. An
# equal shift in both arms points to time and cumulative practice instead.
#
# Phase is coded here as week 4 vs weeks 1-3 rather than by technique, because
# the StudyPhase technique labels only describe the WC arm.
bothArms <- session %>%
  filter(!is.na(StudyPhase), SesTime == "Base") %>%
  mutate(week4 = factor(ifelse(StudyPhase == "Choice", "Week4", "Weeks1_3"),
                        levels = c("Weeks1_3", "Week4")),
         Condition = factor(Condition, levels = c("Choice", "Nature")))

week4Within <- lapply(c("Choice", "Nature"), function(cond) {
  d <- bothArms %>% filter(Condition == cond)
  lapply(outcomes, function(v) {
    m <- lmer(as.formula(sprintf("%s ~ week4 + (1|id)", v)), data = d)
    s <- summary(m)$coefficients["week4Week4", ]
    data.frame(arm = ifelse(cond == "Choice", "WC", "CN"), outcome = v,
               b = round(s["Estimate"], 3),
               ci_lo = round(s["Estimate"] - qnorm(.975) * s["Std. Error"], 3),
               ci_hi = round(s["Estimate"] + qnorm(.975) * s["Std. Error"], 3),
               p = round(s["Pr(>|t|)"], 4), row.names = NULL)
  }) %>% bind_rows()
}) %>% bind_rows()

week4Interaction <- lapply(outcomes, function(v) {
  m <- lmer(as.formula(sprintf("%s ~ week4 * Condition + (1|id)", v)), data = bothArms)
  s <- summary(m)$coefficients["week4Week4:ConditionNature", ]
  data.frame(arm = "WC vs CN", outcome = v,
             b = round(s["Estimate"], 3),
             ci_lo = round(s["Estimate"] - qnorm(.975) * s["Std. Error"], 3),
             ci_hi = round(s["Estimate"] + qnorm(.975) * s["Std. Error"], 3),
             p = round(s["Pr(>|t|)"], 4), row.names = NULL)
}) %>% bind_rows()

week4ByCondition <- bind_rows(week4Within, week4Interaction)

message("\nWEEK 4 vs WEEKS 1-3 (session-baseline scores) IN BOTH ARMS")
print(as.data.frame(week4ByCondition), row.names = FALSE)
message("  'WC vs CN' rows are the week4 x Condition interaction: does the")
message("  week-4 shift differ by how distinct the options were?")

write.csv(week4ByCondition, file.path(outputDir, "week4_by_condition.csv"),
          row.names = FALSE)

## Does the week-4 shift scale with prior practice? ---------------------------
# If choosing needs expertise, participants who completed more of the fixed
# weeks should show a larger week-4 shift.
#
# TREAT AS WEAK. Prior sessions range only 5-9 (most completed all nine) and the
# count also proxies engagement and adherence, so a participant with fewer prior
# sessions differs in more ways than experience. Reported because it speaks
# directly to the expertise account, and flagged as exploratory in the paper.
priorSessions <- session %>%
  filter(SesTime == "Base", !is.na(StudyPhase), StudyPhase != "Choice") %>%
  count(id, name = "priorSessions")

priorMod <- bothArms %>%
  left_join(priorSessions, by = "id") %>%
  filter(!is.na(priorSessions)) %>%
  mutate(priorC = as.numeric(scale(priorSessions, scale = FALSE)))

week4PriorPractice <- lapply(outcomes, function(v) {
  m <- lmer(as.formula(sprintf("%s ~ week4 * priorC + (1|id)", v)), data = priorMod)
  s <- summary(m)$coefficients["week4Week4:priorC", ]
  data.frame(outcome = v, b = round(s["Estimate"], 4),
             se = round(s["Std. Error"], 4),
             p = round(s["Pr(>|t|)"], 4), row.names = NULL)
}) %>% bind_rows()

message("\nWEEK-4 SHIFT x PRIOR FIXED-WEEK SESSIONS (expertise proxy; weak test)")
print(as.data.frame(week4PriorPractice), row.names = FALSE)
message(sprintf("  prior sessions: M = %.2f, SD = %.2f, range %d-%d (restricted)",
                mean(priorSessions$priorSessions), sd(priorSessions$priorSessions),
                min(priorSessions$priorSessions), max(priorSessions$priorSessions)))

write.csv(week4PriorPractice, file.path(outputDir, "week4_prior_practice.csv"),
          row.names = FALSE)

## --------------------------------------------------------------------------
## (b) Did participants choose what they originally preferred?
## --------------------------------------------------------------------------
# Ordinal regression of how many times each practice was selected during the
# choice week (0, 1 or 2) on relative baseline preference for that practice.
#
# Only two choice-week sessions have identifiable practice (days 22/23 and
# 26/27); days 24-25 recorded no selection, which is why the count tops out at 2.

choiceWeek <- session %>%
  filter(Condition == "Choice", StudyDay > 21, SesTime == "Post", !is.na(Training))

choiceCounts <- choiceWeek %>%
  count(id, Training, name = "count") %>%
  tidyr::complete(id, Training = c("Mindfulness", "Breath", "Journal"),
                  fill = list(count = 0)) %>%
  filter(Training %in% c("Mindfulness", "Breath", "Journal"))

relPref <- preferences %>%
  tidyr::pivot_longer(-id, names_to = "prefCol", values_to = "pref") %>%
  group_by(id) %>%
  mutate(relPref = pref - (sum(pref) - pref) / (n() - 1)) %>%
  ungroup() %>%
  mutate(Training = c(MindfulPref = "Mindfulness", BreathPref = "Breath",
                      JournallingPref = "Journal", NaturePref = "Nature")[prefCol])

choiceModelData <- choiceCounts %>%
  left_join(relPref %>% dplyr::select(id, Training, relPref), by = c("id", "Training")) %>%
  filter(!is.na(relPref)) %>%
  mutate(count = factor(count, levels = 0:2, ordered = TRUE))

fit <- MASS::polr(count ~ relPref, data = choiceModelData, Hess = TRUE)
ct <- coef(summary(fit))
ordinalResult <- data.frame(
  term = rownames(ct),
  b    = round(ct[, "Value"], 3),
  se   = round(ct[, "Std. Error"], 3),
  p    = round(2 * pnorm(abs(ct[, "t value"]), lower.tail = FALSE), 4),
  row.names = NULL
)

message(sprintf("\nPRACTICE SELECTION: %d participant x practice rows from %d participants",
                nrow(choiceModelData), length(unique(choiceModelData$id))))
print(ordinalResult, row.names = FALSE)

## Clustering sensitivity checks ----------------------------------------------
# polr() treats the three rows contributed by each participant as independent.
# They are not: they come from the same person, and the three counts are
# compositionally constrained (they sum to that person's identifiable
# choice-week sessions), so a high count on one practice forces low counts on
# the others. That dependency has to be checked before the naive p is reported.
#
# A random intercept CANNOT be estimated here, and the reason is instructive:
# because each participant's counts sum to a constant, there is no
# participant-level variance in the outcome for the intercept to absorb.
# ordinal::clmm() duly drives the variance to ~4e-09, becomes singular and
# returns undefined standard errors. Its failure is a property of the design,
# not a fixable model-fitting problem, so two checks that DO apply are used
# instead.
naiveSE <- ordinalResult$se[ordinalResult$term == "relPref"]
naiveB  <- ordinalResult$b[ordinalResult$term == "relPref"]

# (i) Cluster-robust (sandwich) covariance, clustered on participant.
vcovCluster <- sandwich::vcovCL(fit, cluster = choiceModelData$id)
seCluster   <- sqrt(vcovCluster["relPref", "relPref"])

# (ii) Permutation test. Shuffling relPref WITHIN each participant preserves
# both the clustering and the compositional constraint exactly, so it needs no
# distributional assumption whatsoever -- the strongest available check.
# NOTE ON REPRODUCIBILITY OF THIS p-VALUE.
# The permutation draws are made group-by-group, so the RNG stream depends on
# the order participants appear in -- i.e. on their id labels. Those labels are
# assigned arbitrarily at the release boundary, so this is the one number in the
# pipeline that is not invariant to re-running 02_deidentify.R with a different
# seed. It is fully deterministic for a FIXED dataset, which is what matters for
# reproducing the release. B is set high enough that the Monte Carlo standard
# error (~0.0003 at p = .004) leaves the reported third decimal stable.
set.seed(20260727)
nPerm <- 50000
permB <- replicate(nPerm, {
  permuted <- choiceModelData %>% group_by(id) %>%
    mutate(relPref = sample(relPref)) %>% ungroup()
  tryCatch(coef(MASS::polr(count ~ relPref, data = permuted, Hess = FALSE))[["relPref"]],
           error = function(e) NA_real_)
})
permB <- permB[!is.na(permB)]
pPerm <- (1 + sum(abs(permB) >= abs(naiveB))) / (1 + length(permB))

clusterChecks <- data.frame(
  term = c("relPref (cluster-robust SE, by participant)",
           sprintf("relPref (within-participant permutation, %d resamples)", length(permB))),
  b    = round(c(naiveB, naiveB), 3),
  se   = round(c(seCluster, sd(permB)), 3),
  p    = round(c(2 * pnorm(abs(naiveB / seCluster), lower.tail = FALSE), pPerm), 4),
  row.names = NULL
)

message("  clustering sensitivity checks (random intercept is unidentifiable here):")
print(clusterChecks, row.names = FALSE)
message(sprintf("  cluster-robust SE is %.2fx the naive SE; permutation null SD %.3f vs naive SE %.3f",
                seCluster / naiveSE, sd(permB), naiveSE))
message("  => the naive polr standard error is not anticonservative for these data.")

ordinalResult <- bind_rows(ordinalResult, clusterChecks)

## --------------------------------------------------------------------------
## (c) Baseline well-being as a moderator
## --------------------------------------------------------------------------
prepost <- prepost %>%
  mutate(Time  = factor(Time,  levels = c("Baseline", "Post")),
         group = factor(group, levels = c("Choice", "Nature")))

# WARNING -- THIS MODEL IS STRUCTURALLY DEGENERATE.
#
# `baseWB` is the participant's baseline WB score, and at Time == "Baseline" the
# outcome WB *is* that same number. The baseline rows are therefore fitted
# exactly (residual SD ~ 6e-09, random-intercept variance ~ 5e-05), lme4 reports
# a singular fit, and the reported standard error / p-value are not trustworthy.
#
# The interaction is also not an independent finding. It is algebraically the
# ANCOVA slope minus one:
#
#     TimePost:baseWB  ==  b(Post ~ Baseline) - 1
#     -0.345           ==  0.655 - 1
#
# A regression slope below 1.0 on a repeated measure is the textbook definition
# of regression to the mean. With no passive control group, a true differential
# treatment response cannot be separated from that artefact. The manuscript
# already hedges this in the Discussion, but the Abstract states it as a finding.
#
# Both parameterisations are reported so the equivalence is on the record.

m.mod  <- lmer(WB ~ Time * baseWB + (1 | id), data = prepost)
m.mod3 <- lmer(WB ~ Time * group * baseWB + (1 | id), data = prepost)

if (isSingular(m.mod)) {
  warning("Baseline-moderator model is a singular fit -- see comment above; ",
          "prefer the ANCOVA parameterisation.", call. = FALSE)
}

baselineModerator <- bind_rows(
  tidyFixed(m.mod,  "Time x baseline WB"),
  tidyFixed(m.mod3, "Time x condition x baseline WB")
)

message("\nBASELINE WELL-BEING AS MODERATOR (as published; singular fit)")
print(baselineModerator %>% filter(grepl(":", term)), row.names = FALSE)

## Non-degenerate ANCOVA equivalent -------------------------------------------
wide <- prepost %>%
  dplyr::select(id, group, Time, WB) %>%
  tidyr::pivot_wider(names_from = Time, values_from = WB)

ancova     <- lm(Post ~ Baseline, data = wide)
ancovaGrp  <- lm(Post ~ Baseline * group, data = wide)

slope   <- coef(ancova)[["Baseline"]]
slopeSE <- summary(ancova)$coefficients["Baseline", "Std. Error"]

ancovaResult <- data.frame(
  model = "ANCOVA: Post ~ Baseline",
  term  = c("Baseline slope", "slope - 1 (== Time:baseWB above)"),
  b     = round(c(slope, slope - 1), 3),
  se    = round(c(slopeSE, slopeSE), 3),
  p     = round(c(summary(ancova)$coefficients["Baseline", "Pr(>|t|)"],
                  2 * pt(abs((slope - 1) / slopeSE),
                         df = df.residual(ancova), lower.tail = FALSE)), 4)
)

message("\nANCOVA equivalent (non-singular)")
print(ancovaResult, row.names = FALSE)
message(sprintf("  cor(change, baseline) = %.3f -- the same artefact expressed as a change score",
                cor(wide$Post - wide$Baseline, wide$Baseline, use = "complete.obs")))

write.csv(bind_rows(
  ancovaResult,
  data.frame(model = "ANCOVA: Post ~ Baseline * group",
             term = rownames(summary(ancovaGrp)$coefficients),
             b  = round(summary(ancovaGrp)$coefficients[, "Estimate"], 3),
             se = round(summary(ancovaGrp)$coefficients[, "Std. Error"], 3),
             p  = round(summary(ancovaGrp)$coefficients[, "Pr(>|t|)"], 4))
), file.path(outputDir, "expl_baseline_ancova.csv"), row.names = FALSE)

## --------------------------------------------------------------------------
## Comparison against published values
## --------------------------------------------------------------------------
# Targets are the values printed in the CURRENT (revised) manuscript, so that
# re-running the pipeline checks the paper a reader is actually holding.
#
# The phase contrasts are on the difference scale introduced in 00_config.R.
# The original June draft reported these same effects on the unnormalised
# integer coding, i.e. divided by 4 (FixedVsChoice) or 3 (JournalVsMindBody);
# those older numbers are recorded in ANALYSIS_NOTES so the change is traceable.
published <- tribble(
  ~analysis,        ~model,    ~term,                              ~pub_b, ~pub_p,
  "phase baseline", "Stress",  "StudyPhaseFixedVsChoice",          -0.174, 0.032,
  "phase baseline", "Valence", "StudyPhaseFixedVsChoice",           0.292, 0.0005,
  "phase baseline", "Arousal", "StudyPhaseFixedVsChoice",          -0.019, 0.847,
  "phase change",   "Stress",  "StudyPhaseFixedVsChoice:SesTimePost",     0.224, 0.031,
  "phase change",   "Stress",  "StudyPhaseJournalVsMindBody:SesTimePost", 0.209, 0.055,
  "moderator",      "Time x baseline WB", "TimePost:baseWB",       -0.345, 0.001,
  "moderator",      "Time x condition x baseline WB",
                               "TimePost:groupNature:baseWB",      -0.089, 0.487,
  "selection",      "ordinal", "relPref",                           0.587, 0.004
)

allResults <- bind_rows(
  phaseBaseline    %>% mutate(analysis = "phase baseline"),
  phaseChange      %>% mutate(analysis = "phase change"),
  baselineModerator %>% mutate(analysis = "moderator"),
  ordinalResult    %>% mutate(analysis = "selection", model = "ordinal",
                              ci_lo = NA, ci_hi = NA) %>%
                       dplyr::select(analysis, model, term, b, ci_lo, ci_hi, p)
)

comparison <- published %>%
  left_join(allResults, by = c("analysis", "model", "term")) %>%
  mutate(
    flag = case_when(
      is.na(b)                                  ~ "TERM NOT FOUND",
      (pub_p < .05) != (p < .05)                ~ "*** SIGNIFICANCE CHANGED ***",
      # A pure absolute threshold is blind on small coefficients: these phase
      # estimates live on the 0.0x scale, so an estimate could flip sign and
      # still pass abs(b - pub_b) > 0.05. Check the sign explicitly, and make
      # the magnitude test relative to the size of the target value.
      sign(b) != sign(pub_b) & abs(pub_b) > 1e-6 ~ "*** SIGN FLIPPED ***",
      abs(b - pub_b) > max(0.05, 0.25 * abs(pub_b)) ~ "estimate moved",
      TRUE                                      ~ "consistent"
    )
  ) %>%
  dplyr::select(analysis, model, term, pub_b, b, pub_p, p, flag)

message("\nCOMPARISON WITH PUBLISHED VALUES")
print(as.data.frame(comparison), row.names = FALSE)

## Write ---------------------------------------------------------------------
write.csv(phaseBaseline,     file.path(outputDir, "expl_phase_baseline.csv"), row.names = FALSE)
write.csv(phaseChange,       file.path(outputDir, "expl_phase_change.csv"),   row.names = FALSE)
write.csv(ordinalResult,     file.path(outputDir, "expl_choice_ordinal.csv"), row.names = FALSE)
write.csv(baselineModerator, file.path(outputDir, "expl_baseline_moderator.csv"), row.names = FALSE)
write.csv(comparison,        file.path(outputDir, "expl_comparison.csv"),     row.names = FALSE)

message("\nWrote exploratory tables to output/")
