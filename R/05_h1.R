# 05_h1.R -------------------------------------------------------------------
# Hypothesis 1: relative to Connection with Nature (CN), Wellness Choice (WC)
# produces greater well-being improvement over the training period, at both the
# study level and the session level.
#
# Input:  data/prepost_long.csv, data/session_long.csv   (from 04_score.R)
# Output: output/h1_study_level.csv    Table 1
#         output/h1_session_level.csv  Table 2
#         output/h1_comparison.csv     pipeline vs published values
#
# Every model reported in the manuscript is reproduced here and placed beside
# the value currently printed in the paper, so any change is visible rather
# than quietly substituted.

.scriptDir <- function() {
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", a[grep("^--file=", a)])
  if (length(f) > 0) return(dirname(normalizePath(f)))
  if (!is.null(sys.frame(1)$ofile)) return(dirname(normalizePath(sys.frame(1)$ofile)))
  getwd()
}
source(file.path(.scriptDir(), "00_config.R"))
loadPackages()

prepost <- read.csv(file.path(dataDir, "prepost_long.csv"))
session <- read.csv(file.path(dataDir, "session_long.csv"))

## Factor coding -------------------------------------------------------------
# Treatment coding throughout, matching the original. Reference levels are the
# alphabetically first, i.e. group = Choice (WC) and Time = Baseline, so a
# "group" coefficient is Nature-vs-Choice and a "Time" coefficient is
# Post-vs-Baseline.
prepost <- prepost %>%
  mutate(Time  = factor(Time,  levels = c("Baseline", "Post")),
         group = factor(group, levels = c("Choice", "Nature")))

session <- session %>%
  mutate(SesTime   = factor(SesTime,   levels = c("Base", "Post")),
         Condition = factor(Condition, levels = c("Choice", "Nature")))

## Tidy model output ---------------------------------------------------------
# Wald CIs, to match sjPlot::tab_model()'s default for merMod objects, which is
# what produced the numbers currently in the manuscript.
tidyFixed <- function(model, label) {
  s  <- summary(model)$coefficients
  est <- s[, "Estimate"]
  se  <- s[, "Std. Error"]
  p   <- s[, "Pr(>|t|)"]
  data.frame(
    model = label,
    term  = rownames(s),
    b     = round(est, 3),
    ci_lo = round(est - qnorm(.975) * se, 3),
    ci_hi = round(est + qnorm(.975) * se, 3),
    p     = round(p, 4),
    row.names = NULL
  )
}

## --------------------------------------------------------------------------
## H1 study level -- Table 1
## --------------------------------------------------------------------------
message("\nH1 STUDY LEVEL: WB ~ Time * group + (1|id)")

m.h1 <- lmer(WB ~ Time * group + (1 | id), data = prepost)
h1Study <- tidyFixed(m.h1, "WB")
print(h1Study, row.names = FALSE)

message(sprintf("  n = %d participants, %d observations",
                length(unique(prepost$id)), nrow(prepost)))

## --------------------------------------------------------------------------
## H1 session level -- Table 2
## --------------------------------------------------------------------------
# Within-session change, and whether it differs by condition. The manuscript's
# Table 2 reports the simplified model (no StudyDay term).
message("\nH1 SESSION LEVEL: outcome ~ Condition * SesTime + (1|id)")

sessionOutcomes <- c(Stress = "Stress", Arousal = "Arousal", Valence = "Valence")

h1Session <- lapply(names(sessionOutcomes), function(outcome) {
  f <- as.formula(sprintf("%s ~ Condition * SesTime + (1 | id)", outcome))
  tidyFixed(lmer(f, data = session), outcome)
}) %>% bind_rows()

print(h1Session, row.names = FALSE)

message(sprintf("  %d sessions from %d participants",
                nrow(session) / 2, length(unique(session$id))))

## --------------------------------------------------------------------------
## H1 across-session level
## --------------------------------------------------------------------------
# The third of the three levels named in the manuscript's Data Analysis section.
# NOTE: the model actually fitted is the full three-way
#   outcome ~ StudyDay * Condition * SesTime + (1 | id)
# not the two-way "Well-being ~ Time x Group" the Methods text describes with
# Time = study day. The Methods description must match this.
#
# StudyDay is the linear trend across the 28-day protocol:
#   StudyDay                     -- drift in how people felt ARRIVING at sessions
#   StudyDay:SesTime             -- change in the size of within-session benefit
#   StudyDay:Condition           -- divergence between arms over time
#   StudyDay:Condition:SesTime   -- H1 at the across-session level
message("\nH1 ACROSS-SESSION LEVEL: outcome ~ StudyDay * Condition * SesTime + (1|id)")

h1SessionDay <- lapply(names(sessionOutcomes), function(outcome) {
  f <- as.formula(sprintf("%s ~ StudyDay * Condition * SesTime + (1 | id)", outcome))
  tidyFixed(lmer(f, data = session), paste0(outcome, " (with StudyDay)"))
}) %>% bind_rows()

acrossSession <- h1SessionDay %>%
  filter(term %in% c("StudyDay", "StudyDay:SesTimePost", "StudyDay:ConditionNature",
                     "StudyDay:ConditionNature:SesTimePost")) %>%
  mutate(model = sub(" \\(with StudyDay\\)", "", model))
print(as.data.frame(acrossSession), row.names = FALSE)

## Marginal across-session trend ---------------------------------------------
# CAREFUL: in the three-way model above, treatment coding makes the `StudyDay`
# coefficient the simple slope at the REFERENCE levels -- WC, pre-session -- not
# the trend in the sample as a whole. For arousal the two differ materially
# (WC-only b = 0.001, p = .82; pooled b = 0.008, p = .06), so quoting the
# three-way coefficient as "the" across-session trend misdescribes the sample.
#
# The sample-wide trend in the state participants ARRIVE in is therefore fitted
# directly, on pre-session rows only, and it is this model the manuscript and
# Figure 2 report. The condition interaction is fitted alongside to confirm the
# trend does not differ by arm.
preSession <- session %>% filter(SesTime == "Base", !is.na(StudyDay))

acrossMarginal <- lapply(names(sessionOutcomes), function(outcome) {
  m  <- lmer(as.formula(sprintf("%s ~ StudyDay + (1 | id)", outcome)), data = preSession)
  mi <- lmer(as.formula(sprintf("%s ~ StudyDay * Condition + (1 | id)", outcome)),
             data = preSession)
  s  <- summary(m)$coefficients["StudyDay", ]
  si <- summary(mi)$coefficients["StudyDay:ConditionNature", ]
  data.frame(
    model = outcome,
    b_per_day  = round(s["Estimate"], 4),
    ci_lo      = round(s["Estimate"] - qnorm(.975) * s["Std. Error"], 4),
    ci_hi      = round(s["Estimate"] + qnorm(.975) * s["Std. Error"], 4),
    p          = round(s["Pr(>|t|)"], 4),
    change_over_28d = round(28 * s["Estimate"], 3),
    p_condition_interaction = round(si["Pr(>|t|)"], 4),
    row.names = NULL
  )
}) %>% bind_rows()

message("\nMARGINAL ACROSS-SESSION TREND (pre-session rows, pooled across arms)")
print(as.data.frame(acrossMarginal), row.names = FALSE)
message("  This is the trend the manuscript reports; the three-way coefficients")
message("  above are WC-only simple slopes and are not interchangeable with it.")

write.csv(acrossMarginal, file.path(outputDir, "across_session_marginal.csv"),
          row.names = FALSE)

## The same trend, per arm ---------------------------------------------------
# Pooling is justified for stress and valence, whose slopes are near-parallel,
# but it conceals a divergence in arousal: CN participants arrive progressively
# more alert across the protocol while WC participants do not (interaction
# p = .076). That is sub-threshold and must not be over-read, but it is real
# enough that a pooled line misdescribes it, so both arms are reported and
# Figure 2 draws them separately.
acrossByArm <- lapply(names(sessionOutcomes), function(outcome) {
  m  <- lmer(as.formula(sprintf("%s ~ StudyDay * Condition + (1 | id)", outcome)),
             data = preSession)
  co <- summary(m)$coefficients
  wcSlope <- co["StudyDay", "Estimate"]
  cnSlope <- wcSlope + co["StudyDay:ConditionNature", "Estimate"]
  data.frame(
    model = outcome,
    wc_per_day = round(wcSlope, 4), wc_over_28d = round(28 * wcSlope, 3),
    cn_per_day = round(cnSlope, 4), cn_over_28d = round(28 * cnSlope, 3),
    interaction_b = round(co["StudyDay:ConditionNature", "Estimate"], 4),
    interaction_p = round(co["StudyDay:ConditionNature", "Pr(>|t|)"], 4),
    row.names = NULL
  )
}) %>% bind_rows()

message("\nACROSS-SESSION TREND BY ARM")
print(as.data.frame(acrossByArm), row.names = FALSE)

write.csv(acrossByArm, file.path(outputDir, "across_session_by_arm.csv"),
          row.names = FALSE)

message("  Note: the across-session trend is reportable in its own right --")
message("  a StudyDay term significant at p < .05 means session-baseline state")
message("  drifted systematically over the four weeks.")

## --------------------------------------------------------------------------
## Comparison against the published values
## --------------------------------------------------------------------------
# Values transcribed from manuscript_June19.docx, Results.
published <- tribble(
  ~model,    ~term,                      ~pub_b, ~pub_lo, ~pub_hi, ~pub_p,
  "WB",      "TimePost",                  -0.01,  -0.20,   0.18,   0.911,
  "WB",      "groupNature",                0.06,  -0.30,   0.41,   0.750,
  "WB",      "TimePost:groupNature",       0.16,  -0.12,   0.44,   0.257,
  "Stress",  "SesTimePost",               -0.38,  -0.47,  -0.28,   0.001,
  "Arousal", "SesTimePost",                0.26,   0.14,   0.37,   0.001,
  "Valence", "SesTimePost",                0.33,   0.24,   0.43,   0.001,
  "Arousal", "ConditionNature:SesTimePost", -0.21, -0.39,  -0.04,  0.014
)

comparison <- published %>%
  left_join(bind_rows(h1Study, h1Session), by = c("model", "term")) %>%
  mutate(
    b_shift    = round(b - pub_b, 3),
    sig_pub    = pub_p < .05,
    sig_new    = p < .05,
    flag = case_when(
      is.na(b)                                  ~ "TERM NOT FOUND",
      sig_pub != sig_new                        ~ "*** SIGNIFICANCE CHANGED ***",
      sign(b) != sign(pub_b) & abs(pub_b) > 1e-6 ~ "*** SIGN FLIPPED ***",
      abs(b - pub_b) > max(0.05, 0.25 * abs(pub_b)) ~ "estimate moved",
      TRUE                                      ~ "consistent"
    )
  ) %>%
  dplyr::select(model, term, pub_b, b, b_shift, pub_p, p, flag)

message("\nCOMPARISON WITH PUBLISHED VALUES")
print(as.data.frame(comparison), row.names = FALSE)

changed <- comparison %>% filter(grepl("CHANGED|NOT FOUND", flag))
if (nrow(changed) > 0) {
  message("\n!! ", nrow(changed), " result(s) changed inferential status -- review before writing up.")
} else {
  message("\nAll H1 conclusions unchanged.")
}

## Write ---------------------------------------------------------------------
write.csv(h1Study,      file.path(outputDir, "h1_study_level.csv"),   row.names = FALSE)
write.csv(bind_rows(h1Session, h1SessionDay),
          file.path(outputDir, "h1_session_level.csv"), row.names = FALSE)
write.csv(acrossSession, file.path(outputDir, "h1_across_session.csv"), row.names = FALSE)
write.csv(comparison,   file.path(outputDir, "h1_comparison.csv"),    row.names = FALSE)

message("\nWrote H1 tables to output/")
