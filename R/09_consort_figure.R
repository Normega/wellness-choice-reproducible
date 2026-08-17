# 09_consort_figure.R -------------------------------------------------------
# Draws the CONSORT flow diagram (Figure 1) from the counts produced by
# 03_clean.R and 08_descriptives.R, so the figure cannot drift from the data.
#
# Output: output/Figure1_CONSORT.png  (300 dpi, publication size)

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
flowTab  <- read.csv(file.path(outputDir, "consort_by_condition.csv"))
demoTab  <- read.csv(file.path(outputDir, "demographics.csv"))
consort  <- read.csv(file.path(outputDir, "consort.csv"))
dualN    <- length(readLines(file.path(dataDir, "dual_enrolled_ids.txt")))

## Pull every number from the pipeline ---------------------------------------
getFlow <- function(reason, cond) {
  v <- flowTab[flowTab$exit == reason, cond]
  if (length(v) == 0) 0L else as.integer(v)
}

randWC <- sum(baseData$Condition == "Choice")
randCN <- sum(baseData$Condition == "Nature")
randTot <- randWC + randCN

battStep <- consort[consort$step == "remove incomplete outcome battery" &
                      consort$stage == "baseline", ]
attnStep <- consort[consort$step == "remove failed attention checks (<3 of 4)", ]
enrolStep <- consort[consort$step == "enrolled (completed battery, incl. dual)", ]

# Total who completed the baseline outcome battery, dual enrolments included --
# the dual-enrolment exclusion is then shown as a subtraction from this figure.
enrolled <- as.integer(enrolStep$idsAfter)
attnLost <- as.integer(battStep$idsAfter) - as.integer(attnStep$idsAfter)

analWC <- getFlow("analysed", "Choice");  analCN <- getFlow("analysed", "Nature")
overall <- demoTab[demoTab$Condition == "Overall", ]
wc <- demoTab[demoTab$Condition == "Choice", ]
cn <- demoTab[demoTab$Condition == "Nature", ]

## Two analysis samples ------------------------------------------------------
# The study analyses at two levels on two different samples, and the diagram has
# to show both or the session-level tables (N = 125) look inconsistent with the
# study-level ones (N = 120). Adherence is the gate for the session-level models;
# the post-intervention survey is an additional gate for the study-level models.
samples <- read.csv(file.path(outputDir, "analysis_samples.csv"))
adh <- samples[samples$sample == "adherent (>= 8 of 12 sessions)", ]
adhWC <- as.integer(adh$wc); adhCN <- as.integer(adh$cn)

## Age, matched to the sample each box describes ------------------------------
# The condition boxes report the RANDOMISED arms, so they must use randomised-arm
# ages. Using demographics.csv here (the analysed subset) would pair n = 80 with
# the ages of 63 people.
#
# Median and IQR are shown alongside the mean because the WC mean and SD are
# driven by a few mature students: one 60-year-old accounts for about two thirds
# of that arm's age variance. The median makes the arms' actual similarity
# visible rather than hiding it behind an inflated SD.
ageTab <- read.csv(file.path(outputDir, "age_by_condition.csv"))
ageOf <- function(sampleLabel, condition) {
  r <- ageTab[ageTab$sample == sampleLabel & ageTab$Condition == condition, ]
  if (nrow(r) != 1) stop("age row not found: ", sampleLabel, " / ", condition)
  r
}
ageRand <- list(Choice = ageOf("randomised and eligible", "Choice"),
                Nature = ageOf("randomised and eligible", "Nature"))
ageAnal <- list(Choice = ageOf("analysed", "Choice"),
                Nature = ageOf("analysed", "Nature"))

ageLine <- function(r) sprintf("Median(age) = %g (IQR %g–%g)\nM = %.2f, SD = %.2f",
                               r$median, r$q1, r$q3, r$M, r$SD)

## Layout --------------------------------------------------------------------
boxes <- tibble::tribble(
  ~key,     ~x,    ~y,   ~w,  ~h,  ~fill,
  "enrol",  5.0, 12.55, 4.0, 0.95, "white",
  "exclA",  9.05, 12.55, 4.5, 1.15, "#DCEBF5",
  "rand",   5.0, 10.95, 4.4, 0.80, "white",
  "wc",     2.3,  9.30, 4.1, 1.50, "white",
  "cn",     7.7,  9.30, 4.1, 1.50, "white",
  "exclB",  5.0,  7.15, 4.6, 1.50, "#DCEBF5",
  "adWC",   2.3,  5.15, 3.9, 1.15, "white",
  "adCN",   7.7,  5.15, 3.9, 1.15, "white",
  "exclC",  5.0,  3.45, 4.6, 1.00, "#DCEBF5",
  "anWC",   2.3,  1.95, 3.9, 1.15, "white",
  "anCN",   7.7,  1.95, 3.9, 1.15, "white",
  "final",  5.0,  0.40, 7.2, 1.30, "#EAF2F8"
)

labels <- c(
  enrol = sprintf("**Completed baseline survey**\nn = %d", enrolled),
  exclA = sprintf("**Excluded (n = %d)**\nFailed attention checks\n(< 3 of 4 correct): %d\nEnrolled in both conditions: %d",
                  attnLost + dualN, attnLost, dualN),
  rand  = sprintf("**Randomized**\nn = %d (WC: n = %d, CN: n = %d)", randTot, randWC, randCN),
  wc    = sprintf("**WC condition**\nn = %d\n%s", randWC, ageLine(ageRand$Choice)),
  cn    = sprintf("**CN condition**\nn = %d\n%s", randCN, ageLine(ageRand$Nature)),
  exclB = sprintf(paste0("**Excluded**\nDid not begin intervention:\nWC: n = %d, CN: n = %d\n",
                         "Non-adherence (< 8/12 boosters):\nWC: n = %d, CN: n = %d"),
                  getFlow("did not begin intervention", "Choice"),
                  getFlow("did not begin intervention", "Nature"),
                  getFlow("non-adherent (< 8 sessions)", "Choice"),
                  getFlow("non-adherent (< 8 sessions)", "Nature")),
  adWC  = sprintf("**Adherent**\nn = %d\n*session-level analyses*", adhWC),
  adCN  = sprintf("**Adherent**\nn = %d\n*session-level analyses*", adhCN),
  exclC = sprintf(paste0("**Excluded from study-level analyses**\n",
                         "No post-intervention survey:\nWC: n = %d, CN: n = %d\n",
                         "*(retained in session-level analyses)*"),
                  getFlow("no post-intervention survey", "Choice"),
                  getFlow("no post-intervention survey", "Nature")),
  anWC  = sprintf("**Analyzed**\nn = %d\n*study-level analyses*", analWC),
  anCN  = sprintf("**Analyzed**\nn = %d\n*study-level analyses*", analCN),
  final = sprintf(paste0("**Analysis samples**\n",
                         "Session level: n = %d (WC: n = %d, CN: n = %d)\n",
                         "Study level: n = %d (WC: n = %d, CN: n = %d)\n",
                         "*Study-level sample: %.1f%% women, median(age) = %g ",
                         "(IQR %g–%g),*\n*M = %.2f, SD = %.2f*"),
                  adhWC + adhCN, adhWC, adhCN,
                  analWC + analCN, analWC, analCN,
                  overall$woman_pc,
                  overall$age_median, overall$age_q1, overall$age_q3,
                  overall$age_M, overall$age_SD)
)

boxes$label <- labels[boxes$key]
boxes <- boxes %>%
  mutate(xmin = x - w / 2, xmax = x + w / 2,
         ymin = y - h / 2, ymax = y + h / 2)

bx <- function(k) boxes[boxes$key == k, ]

## Connectors ----------------------------------------------------------------
splitY <- 10.25   # horizontal bar under "Randomized"

arrows <- tibble::tribble(
  ~x,  ~y,                    ~xend, ~yend,
  5.0, bx("enrol")$ymin,      5.0,   bx("rand")$ymax,        # enrol -> randomized
  5.0, bx("rand")$ymin,       5.0,   splitY,                 # randomized -> split
  2.3, splitY,                2.3,   bx("wc")$ymax,          # split -> WC
  7.7, splitY,                7.7,   bx("cn")$ymax,          # split -> CN
  2.3, bx("wc")$ymin,         2.3,   bx("adWC")$ymax,        # WC -> adherent
  7.7, bx("cn")$ymin,         7.7,   bx("adCN")$ymax,        # CN -> adherent
  2.3, bx("adWC")$ymin,       2.3,   bx("anWC")$ymax,        # adherent -> analyzed
  7.7, bx("adCN")$ymin,       7.7,   bx("anCN")$ymax,        # adherent -> analyzed
  5.0, 1.10,                  5.0,   bx("final")$ymax        # merge -> final
)

# Plain connectors: the split bar under "Randomized", the merge bar above the
# final-sample box, and the two vertical drops feeding that merge bar. These
# carry no arrowheads -- only the single drop into the final box does, so the
# converging lines do not collide head-on.
segments <- tibble::tribble(
  ~x,  ~y,               ~xend, ~yend,
  2.3, splitY,           7.7,   splitY,
  2.3, 1.10,             7.7,   1.10,
  2.3, bx("anWC")$ymin,  2.3,   1.10,
  7.7, bx("anCN")$ymin,  7.7,   1.10
)

# Dashed spurs tie each exclusion box to the two condition columns it applies to.
dashed <- tibble::tribble(
  ~x,  ~y,          ~xend,            ~yend,
  2.3, bx("exclB")$y, bx("exclB")$xmin, bx("exclB")$y,
  7.7, bx("exclB")$y, bx("exclB")$xmax, bx("exclB")$y,
  2.3, bx("exclC")$y, bx("exclC")$xmin, bx("exclC")$y,
  7.7, bx("exclC")$y, bx("exclC")$xmax, bx("exclC")$y
)

## Draw ----------------------------------------------------------------------
p <- ggplot() +
  geom_segment(data = segments, aes(x, y, xend = xend, yend = yend),
               linewidth = 0.5, colour = "grey25") +
  geom_segment(data = dashed, aes(x, y, xend = xend, yend = yend),
               linewidth = 0.4, colour = "grey45", linetype = "22") +
  geom_segment(data = arrows, aes(x, y, xend = xend, yend = yend),
               linewidth = 0.5, colour = "grey25",
               arrow = arrow(length = unit(2.0, "mm"), type = "closed")) +
  geom_rect(data = boxes,
            aes(xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax, fill = fill),
            colour = "grey25", linewidth = 0.45) +
  ggtext::geom_richtext(data = boxes, aes(x = x, y = y, label = gsub("\n", "<br>", label)),
                        size = 3.8, lineheight = 1.25, fill = NA, label.colour = NA,
                        colour = "grey10") +
  scale_fill_identity() +
  coord_cartesian(xlim = c(0.3, 11.6), ylim = c(-0.3, 13.2)) +
  theme_void() +
  theme(plot.margin = margin(6, 6, 6, 6))

outFile <- file.path(outputDir, "Figure1_CONSORT.png")
ggsave(outFile, p, width = 9.5, height = 10.2, units = "in", dpi = 300, bg = "white")

# Vector copy as well: a CONSORT diagram is pure line art, and journals set it
# far better from PDF than from a raster. Note that cairo stamps a /CreationDate
# into the file, so PDFs are not byte-reproducible across runs even though their
# drawing content is -- compare the PNGs when checking reproducibility.
outPdf <- file.path(outputDir, "Figure1_CONSORT.pdf")
ggsave(outPdf, p, width = 9.5, height = 10.2,
       units = "in", bg = "white", device = grDevices::cairo_pdf)

message("Wrote ", outFile)
message(sprintf("  enrolled %d -> randomized %d (WC %d, CN %d)", enrolled, randTot, randWC, randCN))
message(sprintf("  -> adherent %d (WC %d, CN %d)      [session-level analyses]",
                adhWC + adhCN, adhWC, adhCN))
message(sprintf("  -> analysed %d (WC %d, CN %d)      [study-level analyses]",
                analWC + analCN, analWC, analCN))
