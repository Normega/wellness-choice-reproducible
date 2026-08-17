# 12_multiplicity.R ---------------------------------------------------------
# Makes the multiple-comparison correction explicit and checkable.
#
# The manuscript states that "the Holm-Bonferroni method corrected for the two
# a priori comparisons" but never names the family or prints an adjusted
# p-value, so a reader cannot verify which test was compared against which
# threshold. This script writes that out.
#
# Input:  output/h1_session_level.csv, output/h2_absolute.csv
# Output: output/holm_correction.csv
#
# THE FAMILY. The preregistration declares two a priori comparisons -- H1 and
# H2 -- giving a first Holm threshold of alpha/2 = .025 (this matches the
# ".025 per test" in the manuscript's power analysis). Each hypothesis was
# tested on three session outcomes (stress, arousal, valence), so the two-test
# family necessarily represents each hypothesis by its strongest outcome. That
# is the correction the paper actually applied, and it is reproduced below as
# `preregistered`.
#
# Selecting the best of three outcomes and then correcting as though one test
# had been run is anticonservative. The stricter `all_outcomes` family (3
# outcomes x 2 hypotheses = 6 tests) is therefore also reported. Both families
# reach the same conclusion here, which is worth stating in the paper.

.scriptDir <- function() {
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", a[grep("^--file=", a)])
  if (length(f) > 0) return(dirname(normalizePath(f)))
  if (!is.null(sys.frame(1)$ofile)) return(dirname(normalizePath(sys.frame(1)$ofile)))
  getwd()
}
source(file.path(.scriptDir(), "00_config.R"))
loadPackages()

alpha <- 0.05

h1 <- read.csv(file.path(outputDir, "h1_session_level.csv"))
h2 <- read.csv(file.path(outputDir, "h2_absolute.csv"))

# The a priori interaction terms, one per hypothesis per outcome.
# h1_session_level.csv also holds the across-session models, whose rows carry
# the same term name; those are not a priori tests, so exclude them explicitly.
apriori <- bind_rows(
  h1 %>% filter(term == "ConditionNature:SesTimePost",
                !grepl("StudyDay", model)) %>%
    transmute(hypothesis = "H1 (condition x session time)", outcome = model, p),
  h2 %>% filter(term == "Pref:SesTimePost") %>%
    transmute(hypothesis = "H2 (preference x session time)", outcome = model, p)
)
stopifnot(nrow(apriori) == 6)

message("\nA PRIORI INTERACTION TESTS")
print(as.data.frame(apriori), row.names = FALSE)

## Family 1 -- as preregistered: two tests --------------------------------------
# Each hypothesis contributes its smallest p.
preregistered <- apriori %>%
  group_by(hypothesis) %>%
  slice_min(p, n = 1, with_ties = FALSE) %>%
  ungroup() %>%
  arrange(p) %>%
  mutate(
    family    = "preregistered (2 tests)",
    rank      = row_number(),
    threshold = alpha / (n() - rank + 1),
    p_holm    = round(p.adjust(p, method = "holm"), 4),
    significant = p_holm < alpha
  )

## Family 2 -- every outcome: six tests -----------------------------------------
allOutcomes <- apriori %>%
  arrange(p) %>%
  mutate(
    family    = "all outcomes (6 tests)",
    rank      = row_number(),
    threshold = alpha / (n() - rank + 1),
    p_holm    = round(p.adjust(p, method = "holm"), 4),
    significant = p_holm < alpha
  )

holm <- bind_rows(preregistered, allOutcomes) %>%
  dplyr::select(family, hypothesis, outcome, rank, p, threshold, p_holm, significant) %>%
  mutate(p = round(p, 4), threshold = round(threshold, 4))

message("\nHOLM-BONFERRONI CORRECTION")
print(as.data.frame(holm), row.names = FALSE)

# Holm is a step-down procedure: testing stops at the first non-rejection, so
# the smallest p in the family decides whether anything survives at all.
smallest <- preregistered %>% slice_min(p, n = 1, with_ties = FALSE)
message(sprintf(
  "\n  Smallest a priori p = %.4f (%s, %s) vs first Holm threshold %.4f -> %s",
  smallest$p, smallest$hypothesis, smallest$outcome, alpha / 2,
  if (smallest$p < alpha / 2) "rejected" else "NOT rejected; testing stops"))

if (!any(preregistered$significant) && !any(allOutcomes$significant)) {
  message("  Neither a priori hypothesis survives correction under either family.")
}

write.csv(holm, file.path(outputDir, "holm_correction.csv"), row.names = FALSE)
message("\nWrote output/holm_correction.csv")
