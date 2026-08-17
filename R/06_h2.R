# 06_h2.R -------------------------------------------------------------------
# Hypothesis 2: baseline interest in a technique predicts well-being improvement
# when practising that technique, at the session level.
#
# Two operationalisations of preference, both reported in the manuscript:
#   Pref         -- absolute baseline preference composite for the practice done
#   PrefRelative -- that score minus mean preference for the other three
#
# Input:  data/session_long.csv        (from 04_score.R)
# Output: output/h2_absolute.csv       Table 3
#         output/h2_relative.csv       Table 4
#         output/h2_comparison.csv     pipeline vs published values

.scriptDir <- function() {
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", a[grep("^--file=", a)])
  if (length(f) > 0) return(dirname(normalizePath(f)))
  if (!is.null(sys.frame(1)$ofile)) return(dirname(normalizePath(sys.frame(1)$ofile)))
  getwd()
}
source(file.path(.scriptDir(), "00_config.R"))
loadPackages()

session <- read.csv(file.path(dataDir, "session_long.csv")) %>%
  mutate(SesTime   = factor(SesTime,   levels = c("Base", "Post")),
         Condition = factor(Condition, levels = c("Choice", "Nature")))

# H2 requires knowing which practice was done, so the sessions with no recorded
# practice (study days 24-25, see 04_score.R) necessarily drop out here. This is
# the one analysis where that exclusion is correct.
h2Data <- session %>% filter(!is.na(Pref))

message(sprintf("H2 sample: %d session-observations, %d sessions, %d participants",
                nrow(h2Data), nrow(h2Data) / 2, length(unique(h2Data$id))))
message(sprintf("  excluded for unknown practice: %d observations",
                nrow(session) - nrow(h2Data)))

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

fitH2 <- function(prefVar) {
  lapply(outcomes, function(outcome) {
    f <- as.formula(sprintf("%s ~ %s * SesTime + (1 | id)", outcome, prefVar))
    tidyFixed(lmer(f, data = h2Data), outcome)
  }) %>% bind_rows()
}

message("\nH2 ABSOLUTE PREFERENCE: outcome ~ Pref * SesTime + (1|id)")
h2Absolute <- fitH2("Pref")
print(h2Absolute %>% filter(grepl(":", term)), row.names = FALSE)

message("\nH2 RELATIVE PREFERENCE: outcome ~ PrefRelative * SesTime + (1|id)")
h2Relative <- fitH2("PrefRelative")
print(h2Relative %>% filter(grepl(":", term)), row.names = FALSE)

## Comparison against published values ---------------------------------------
# The manuscript's H2 sentence does not name the outcome for its significant
# effect; from the code and the Discussion it is arousal (see ANALYSIS_NOTES 5.3).
published <- tribble(
  ~set,        ~model,    ~term,                 ~pub_b, ~pub_p,
  "absolute",  "Arousal", "Pref:SesTimePost",           0.11, 0.042,
  "absolute",  "Stress",  "Pref:SesTimePost",          -0.04, 0.310,
  "absolute",  "Valence", "Pref:SesTimePost",           0.02, 0.671,
  "relative",  "Arousal", "PrefRelative:SesTimePost",   0.09, 0.097,
  "relative",  "Stress",  "PrefRelative:SesTimePost",  -0.04, 0.356,
  "relative",  "Valence", "PrefRelative:SesTimePost",   0.03, 0.521
)

comparison <- published %>%
  left_join(bind_rows(mutate(h2Absolute, set = "absolute"),
                      mutate(h2Relative, set = "relative")),
            by = c("set", "model", "term")) %>%
  mutate(
    sig_pub = pub_p < .05,
    sig_new = p < .05,
    # The manuscript preregistered Holm-Bonferroni for two a priori tests,
    # giving an adjusted threshold of .025 for the primary comparison.
    survives_correction = p < .025,
    flag = case_when(
      is.na(b)           ~ "TERM NOT FOUND",
      sig_pub != sig_new ~ "*** SIGNIFICANCE CHANGED ***",
      TRUE               ~ "consistent"
    )
  ) %>%
  dplyr::select(set, model, pub_b, b, pub_p, p, flag, survives_correction)

message("\nCOMPARISON WITH PUBLISHED VALUES")
print(as.data.frame(comparison), row.names = FALSE)

changed <- comparison %>% filter(grepl("CHANGED|NOT FOUND", flag))
if (nrow(changed) > 0) {
  message("\n!! ", nrow(changed), " H2 result(s) changed inferential status.")
} else {
  message("\nAll H2 conclusions unchanged at alpha = .05.")
}

write.csv(h2Absolute, file.path(outputDir, "h2_absolute.csv"),   row.names = FALSE)
write.csv(h2Relative, file.path(outputDir, "h2_relative.csv"),   row.names = FALSE)
write.csv(comparison, file.path(outputDir, "h2_comparison.csv"), row.names = FALSE)

message("\nWrote H2 tables to output/")
