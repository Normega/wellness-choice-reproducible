# 10_tables.R ---------------------------------------------------------------
# Generates the exact cell contents for every appendix table, in the layout the
# manuscript's tables already use (predictor rows, then a random-effects block).
#
# Output: output/table_cells.csv -- one row per table row, cells pipe-separated
#
# Consumed by write_appendix_tables.py, which writes them into the .docx.

.scriptDir <- function() {
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", a[grep("^--file=", a)])
  if (length(f) > 0) return(dirname(normalizePath(f)))
  if (!is.null(sys.frame(1)$ofile)) return(dirname(normalizePath(sys.frame(1)$ofile)))
  getwd()
}
source(file.path(.scriptDir(), "00_config.R"))
loadPackages()

prepost <- read.csv(file.path(dataDir, "prepost_long.csv")) %>%
  mutate(Time  = factor(Time,  levels = c("Baseline", "Post")),
         group = factor(group, levels = c("Choice", "Nature")))

session <- read.csv(file.path(dataDir, "session_long.csv")) %>%
  mutate(SesTime   = factor(SesTime,   levels = c("Base", "Post")),
         Condition = factor(Condition, levels = c("Choice", "Nature")))

h2Data <- session %>% filter(!is.na(Pref))

# Same difference-scaled contrasts as 07_exploratory.R, from 00_config.R, so the
# tables and the reported text can never disagree about the coding.
choiceArm <- session %>%
  filter(Condition == "Choice", !is.na(StudyPhase)) %>%
  withStudyPhaseContrasts()

## Formatting ----------------------------------------------------------------
fmtB  <- function(x) sprintf("%.2f", x)
fmtCI <- function(lo, hi) sprintf("[%.2f; %.2f]", lo, hi)
fmtP  <- function(p) ifelse(p < .001, "<0.001", sprintf("%.3f", p))

## Model summaries -----------------------------------------------------------
fixedRows <- function(model) {
  s   <- summary(model)$coefficients
  est <- s[, "Estimate"]; se <- s[, "Std. Error"]; p <- s[, "Pr(>|t|)"]
  data.frame(term = rownames(s),
             b    = fmtB(est),
             ci   = fmtCI(est - qnorm(.975) * se, est + qnorm(.975) * se),
             p    = fmtP(p), row.names = NULL, stringsAsFactors = FALSE)
}

# Variance components and Nakagawa R2 for a random-intercept model, computed
# directly so the tables do not depend on sjPlot's internals.
randomStats <- function(model) {
  vc    <- as.data.frame(VarCorr(model))
  tau00 <- vc$vcov[vc$grp != "Residual"][1]
  sigma2 <- vc$vcov[vc$grp == "Residual"]
  varF  <- var(as.vector(model.matrix(model) %*% lme4::fixef(model)))
  total <- varF + tau00 + sigma2
  list(sigma2 = sprintf("%.2f", sigma2),
       tau00  = sprintf("%.2f", tau00),
       icc    = sprintf("%.2f", tau00 / (tau00 + sigma2)),
       n      = as.character(ngrps(model)[[1]]),
       obs    = as.character(nobs(model)),
       r2     = sprintf("%.3f / %.3f", varF / total, (varF + tau00) / total))
}

## Table assembly ------------------------------------------------------------
rows <- list()
add <- function(table, kind, label, cells) {
  rows[[length(rows) + 1]] <<- data.frame(
    table = table, kind = kind, label = label,
    cells = paste(cells, collapse = "|"), stringsAsFactors = FALSE)
}

# Builds one table from a set of models sharing predictor terms.
buildTable <- function(tableName, models, termLabels) {
  fx <- lapply(models, fixedRows)
  rs <- lapply(models, randomStats)

  for (term in names(termLabels)) {
    cells <- unlist(lapply(fx, function(f) {
      i <- match(term, f$term)
      if (is.na(i)) c("", "", "") else c(f$b[i], f$ci[i], f$p[i])
    }))
    add(tableName, "predictor", termLabels[[term]], cells)
  }

  add(tableName, "section", "Random Effects", character(0))
  for (stat in c("sigma2", "tau00", "icc", "n", "obs", "r2")) {
    label <- c(sigma2 = "σ2", tau00 = "τ00 id", icc = "ICC",
               n = "N id", obs = "Observations",
               r2 = "Marginal R2 / Conditional R2")[[stat]]
    add(tableName, "random", label, vapply(rs, `[[`, character(1), stat))
  }
}

outcomes <- c("Stress", "Arousal", "Valence")
fitEach <- function(formulaTemplate, data) {
  setNames(lapply(outcomes, function(o)
    lmer(as.formula(sprintf(formulaTemplate, o)), data = data)), outcomes)
}

## Table 1 -- H1 study level -------------------------------------------------
buildTable("table1",
  list(WB = lmer(WB ~ Time * group + (1 | id), data = prepost)),
  list("(Intercept)"          = "Baseline",
       "TimePost"             = "Post-Intervention",
       "groupNature"          = "Condition (CN vs. WC)",
       "TimePost:groupNature" = "Time × Condition"))

## Table 2 -- H1 daily -------------------------------------------------------
buildTable("table2",
  fitEach("%s ~ Condition * SesTime + (1 | id)", session),
  list("(Intercept)"                 = "Baseline",
       "ConditionNature"             = "Condition (CN vs. WC)",
       "SesTimePost"                 = "Post-Session",
       "ConditionNature:SesTimePost" = "Condition × Session Time"))

## Table 3 -- H2 absolute preference -----------------------------------------
buildTable("table3",
  fitEach("%s ~ Pref * SesTime + (1 | id)", h2Data),
  list("(Intercept)"      = "Baseline",
       "Pref"             = "Preference",
       "SesTimePost"      = "Post-Session",
       "Pref:SesTimePost" = "Preference × Session Time"))

## Table 4 -- H2 relative preference -----------------------------------------
buildTable("table4",
  fitEach("%s ~ PrefRelative * SesTime + (1 | id)", h2Data),
  list("(Intercept)"              = "Baseline",
       "PrefRelative"             = "Relative Preference",
       "SesTimePost"              = "Post-Session",
       "PrefRelative:SesTimePost" = "Relative Preference × Session Time"))

## Table 5 -- study phase, session baseline scores ---------------------------
buildTable("table5",
  fitEach("%s ~ StudyPhase + (1 | id)", choiceArm %>% filter(SesTime == "Base")),
  list("(Intercept)"                   = "Baseline",
       "StudyPhaseFixedVsChoice"       = "Choice Week vs. Fixed Weeks",
       "StudyPhaseJournalVsMindBody"   = "Journaling vs. Mind-Body Practices",
       "StudyPhaseBreathVsMindfulness" = "Breathwork vs. Mindfulness"))

## Table 6 -- study phase x session time (pre-post change) -------------------
buildTable("table6",
  fitEach("%s ~ StudyPhase * SesTime + (1 | id)", choiceArm),
  list("(Intercept)"                               = "Baseline",
       "StudyPhaseFixedVsChoice"                   = "Choice Week vs. Fixed Weeks",
       "StudyPhaseJournalVsMindBody"               = "Journaling vs. Mind-Body Practices",
       "StudyPhaseBreathVsMindfulness"             = "Breathwork vs. Mindfulness",
       "SesTimePost"                               = "Post-Session",
       "StudyPhaseFixedVsChoice:SesTimePost"       = "Choice Week × Session Time",
       "StudyPhaseJournalVsMindBody:SesTimePost"   = "Journaling vs. Mind-Body × Session Time",
       "StudyPhaseBreathVsMindfulness:SesTimePost" = "Breathwork vs. Mindfulness × Session Time"))

## Table 7 -- baseline well-being as moderator -------------------------------
# Singular by construction (baseline WB appears on both sides); the table Note
# records the equivalent ANCOVA. See ANALYSIS_NOTES 10.4.
buildTable("table7",
  list(WB = lmer(WB ~ Time * baseWB + (1 | id), data = prepost)),
  list("(Intercept)"      = "Baseline",
       "TimePost"         = "Post-Intervention",
       "baseWB"           = "Baseline Well-Being",
       "TimePost:baseWB"  = "Time × Baseline Well-Being"))

result <- bind_rows(rows)
write.csv(result, file.path(outputDir, "table_cells.csv"), row.names = FALSE)

message("Wrote output/table_cells.csv")
for (tb in unique(result$table)) {
  sub <- result[result$table == tb, ]
  message(sprintf("  %s: %d predictor row(s), %d random-effects row(s)",
                  tb, sum(sub$kind == "predictor"), sum(sub$kind == "random")))
}
