# 14_figure2_dissociation.R -------------------------------------------------
# Figure 2: the paper's central finding, which until now had no figure.
#
# The argument is a dissociation across three nested timescales, so the figure
# puts them side by side using ONE visual idiom -- estimated marginal means
# joined by a line -- at each scale. Steep slopes in panel A and flat ones in
# panel C make the dissociation visible without reading a number.
#
#   A  within session   pre -> post, by condition        (the reliable effect)
#   B  across sessions  session-baseline vs study day    (mood drifts up)
#   C  study level      baseline -> post composite       (nothing accumulates)
#
# Output: output/Figure2_Dissociation.png   (300 dpi, for submission)
#         output/Figure2_Dissociation.pdf   (vector, for production)
#
# DESIGN NOTES
# Condition is encoded three ways at once -- hue, point shape, and line type --
# so the figure survives greyscale printing and colour-vision deficiency. The
# hues are the Okabe-Ito blue/vermillion pair, validated for CVD separation
# (worst adjacent dE 21.9 protan, 31.2 normal vision) rather than chosen by eye.
# Estimates are model-based (emmeans on the same models the tables report), not
# raw means, so the figure cannot disagree with Tables 1-2.

.scriptDir <- function() {
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", a[grep("^--file=", a)])
  if (length(f) > 0) return(dirname(normalizePath(f)))
  if (!is.null(sys.frame(1)$ofile)) return(dirname(normalizePath(sys.frame(1)$ofile)))
  getwd()
}
source(file.path(.scriptDir(), "00_config.R"))
loadPackages()
library(patchwork)

session <- read.csv(file.path(dataDir, "session_long.csv")) %>%
  mutate(SesTime   = factor(SesTime, levels = c("Base", "Post"),
                            labels = c("Pre-session", "Post-session")),
         Condition = factor(Condition, levels = c("Choice", "Nature"),
                            labels = c("Wellness Choice", "Connection with Nature")))
prepost <- read.csv(file.path(dataDir, "prepost_long.csv")) %>%
  mutate(Time  = factor(Time, levels = c("Baseline", "Post"),
                        labels = c("Baseline", "Post-intervention")),
         group = factor(group, levels = c("Choice", "Nature"),
                        labels = c("Wellness Choice", "Connection with Nature")))

## Shared visual language ----------------------------------------------------
condCols   <- c("Wellness Choice" = "#0072B2", "Connection with Nature" = "#D55E00")
condShapes <- c("Wellness Choice" = 16,        "Connection with Nature" = 17)
condLines  <- c("Wellness Choice" = "solid",   "Connection with Nature" = "22")

outcomeLabels <- c(Stress = "Stress", Valence = "Mood", Arousal = "Arousal")

apaTheme <- theme_classic(base_size = 9) +
  theme(
    text            = element_text(colour = "grey15"),
    axis.text       = element_text(colour = "grey25", size = 8),
    axis.line       = element_line(colour = "grey35", linewidth = 0.3),
    axis.ticks      = element_line(colour = "grey35", linewidth = 0.3),
    strip.background = element_blank(),
    strip.text      = element_text(face = "bold", size = 9, hjust = 0),
    panel.grid.major.y = element_line(colour = "grey92", linewidth = 0.3),
    legend.position = "bottom",
    legend.title    = element_blank(),
    legend.key.width = unit(14, "pt"),
    legend.margin   = margin(t = -2),
    plot.title      = element_text(face = "bold", size = 10, hjust = 0),
    plot.title.position = "plot",
    plot.subtitle   = element_text(size = 8, colour = "grey35"),
    plot.margin     = margin(4, 8, 4, 4)
  )

## Panel A -- within-session change ------------------------------------------
emA <- lapply(names(outcomeLabels), function(v) {
  m  <- lmer(as.formula(sprintf("%s ~ Condition * SesTime + (1|id)", v)), data = session)
  as.data.frame(emmeans::emmeans(m, ~ SesTime | Condition)) %>%
    mutate(outcome = outcomeLabels[[v]])
}) %>% bind_rows() %>%
  mutate(outcome = factor(outcome, levels = unname(outcomeLabels)))

pA <- ggplot(emA, aes(SesTime, emmean, colour = Condition, group = Condition)) +
  geom_line(aes(linetype = Condition), linewidth = 0.6) +
  geom_errorbar(aes(ymin = lower.CL, ymax = upper.CL), width = 0.08, linewidth = 0.4) +
  geom_point(aes(shape = Condition), size = 2.1) +
  # Shared y across facets: all three outcomes are 1-6 ratings, so a free
  # scale would make the smallest change (arousal) look like the largest.
  facet_wrap(~ outcome, nrow = 1) +
  scale_colour_manual(values = condCols) +
  scale_shape_manual(values = condShapes) +
  scale_linetype_manual(values = condLines) +
  labs(title = "A   Within each session", x = NULL, y = "Rating (1–6)",
       subtitle = "Stress falls, mood and arousal rise; the two arms do not differ") +
  apaTheme

## Panel B -- across-session trend -------------------------------------------
trendDat <- session %>%
  filter(SesTime == "Pre-session", !is.na(StudyDay)) %>%
  tidyr::pivot_longer(all_of(names(outcomeLabels)),
                      names_to = "outcome", values_to = "score") %>%
  filter(!is.na(score)) %>%
  mutate(outcome = factor(outcomeLabels[outcome], levels = unname(outcomeLabels)))

# Model-implied, not geom_smooth. The default OLS smooth ignores the participant
# random intercept, so the drawn line need not match the model the paper reports.
# These are fitted values from outcome ~ StudyDay * Condition + (1|id) on
# pre-session rows.
#
# Split by arm rather than pooled. Stress and valence run near-parallel, so the
# split costs nothing there and lets the figure DEMONSTRATE that the trends do
# not differ rather than asserting it. For arousal it earns its keep: CN arrives
# progressively more alert while WC stays flat (interaction p = .076), which a
# pooled line hides entirely.
trendFit <- lapply(names(outcomeLabels), function(v) {
  d <- session %>% filter(SesTime == "Pre-session", !is.na(StudyDay), !is.na(.data[[v]]))
  m <- lmer(as.formula(sprintf("%s ~ StudyDay * Condition + (1|id)", v)), data = d)
  nd <- expand.grid(
    StudyDay  = seq(min(d$StudyDay), max(d$StudyDay), length.out = 80),
    Condition = levels(d$Condition))
  X   <- model.matrix(~ StudyDay * Condition, nd)
  fit <- as.vector(X %*% lme4::fixef(m))
  se  <- sqrt(rowSums((X %*% as.matrix(vcov(m))) * X))
  data.frame(nd, fit = fit, lo = fit - 1.96 * se, hi = fit + 1.96 * se,
             outcome = outcomeLabels[[v]])
}) %>% bind_rows() %>%
  mutate(outcome = factor(outcome, levels = unname(outcomeLabels)))

pB <- ggplot(trendFit, aes(StudyDay, fit, colour = Condition, fill = Condition)) +
  geom_ribbon(aes(ymin = lo, ymax = hi), alpha = 0.13, colour = NA) +
  geom_line(aes(linetype = Condition), linewidth = 0.6) +
  facet_wrap(~ outcome, nrow = 1) +
  scale_colour_manual(values = condCols) +
  scale_fill_manual(values = condCols) +
  scale_linetype_manual(values = condLines) +
  scale_x_continuous(breaks = c(1, 7, 14, 21, 28)) +
  labs(title = "B   Across the four weeks", x = "Study day",
       y = "Pre-session rating",
       subtitle = "Mood rises in both arms; stress is flat. Arousal is the one place the arms diverge, and only marginally") +
  apaTheme

## Panel C -- study level ----------------------------------------------------
mC  <- lmer(WB ~ Time * group + (1 | id), data = prepost)
emC <- as.data.frame(emmeans::emmeans(mC, ~ Time | group)) %>%
  rename(Condition = group)

pC <- ggplot(emC, aes(Time, emmean, colour = Condition, group = Condition)) +
  geom_line(aes(linetype = Condition), linewidth = 0.6) +
  geom_errorbar(aes(ymin = lower.CL, ymax = upper.CL), width = 0.06, linewidth = 0.4) +
  geom_point(aes(shape = Condition), size = 2.1) +
  scale_colour_manual(values = condCols) +
  scale_shape_manual(values = condShapes) +
  scale_linetype_manual(values = condLines) +
  coord_cartesian(ylim = c(-1, 1)) +
  labs(title = "C   Baseline to post-intervention", x = NULL,
       y = "Well-being composite (z)",
       subtitle = "Nothing accumulates: no change over time, and no difference between arms") +
  apaTheme

## Compose -------------------------------------------------------------------
# One shared legend at the foot: strip it from the upper panels rather than
# using patchwork's `&` operator, which this ggplot2 version does not support.
noLegend <- theme(legend.position = "none")
fig <- (pA + noLegend) / (pB + noLegend) / pC +
  plot_layout(heights = c(1, 1, 0.95))

outPng <- file.path(outputDir, "Figure2_Dissociation.png")
outPdf <- file.path(outputDir, "Figure2_Dissociation.pdf")
ggsave(outPng, fig, width = 7.0, height = 8.2, units = "in", dpi = 300, bg = "white")
ggsave(outPdf, fig, width = 7.0, height = 8.2, units = "in", bg = "white",
       device = grDevices::cairo_pdf)

message("Wrote ", outPng)
message("Wrote ", outPdf, "  (vector, for production)")

## Figure 1 in vector form as well -------------------------------------------
# Journals prefer vector for line art; the CONSORT diagram is pure line art.
consortR <- file.path(.scriptDir(), "09_consort_figure.R")
message("\nNote: Figure 1 is also emitted as PDF by 09_consort_figure.R.")
