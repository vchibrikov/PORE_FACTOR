# -----------------------------------------------------------------------------
#
# Script: Pore Geometry Analysis and Visualization
# Author: [Your Name]
# Date: 2025-10-07
#
# Description: This script processes data from segmented image pores to
#              calculate various geometric and morphological metrics, including
#              Pore Factor, Area, Perimeter, Circularity, and Form Factor.
#              It performs statistical analysis (ANOVA + Tukey's HSD) and
#              generates a multi-panel summary figure.
#
# -----------------------------------------------------------------------------


# -----------------------------------------------------------------------------
# SECTION 1: SETUP AND CONFIGURATION
# -----------------------------------------------------------------------------

# --- 1.1: Load Required Libraries ---
# Using pacman to manage and load packages
if (!require("pacman")) install.packages("pacman")
pacman::p_load(
  'tidyverse', 'readxl', 'agricolae', 'gtools', 'Cairo', 'bbplot', 'gridExtra'
)

# --- 1.2: Configuration ---
# Define file paths, output directories, and key analysis parameters.
#
# Input file (assumes a 'distance_30_mm_px' column for scaling)
data_path <- "./path/to/data.xlsx"

# Output directory for plots and the final summary figure
output_dir <- "./path/to/output/directory/"
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

# Analysis parameters
FILTER_COMPOSITION <- "YOUR_FILTER" # Which composition to analyze
LOGICAL_ORDER <- c("YOUR", "LOGICAL", "ORDER") # X-axis order for plots

# --- 1.3: Plotting Parameters ---
colors <- RColorBrewer::brewer.pal(9, "Set1")


# -----------------------------------------------------------------------------
# SECTION 2: DATA LOADING AND PREPARATION
# -----------------------------------------------------------------------------
# This section loads the raw data ONCE, parses filenames, calculates all
# derived metrics, and filters the data.

data <- read_excel(data_path) %>%
  # Use tidyr::extract for robust filename parsing
  tidyr::extract(
    filename,
    into = c("date", "sample", "composition"),
    regex = "(\\d{4}_\\d{2}_\\d{2})_(\\d{2}_\\d{2}_\\d{2})_(\\d{2})_.*",
    remove = FALSE
  ) %>%
  # Filter for the desired composition
  filter(composition == FILTER_COMPOSITION) %>%
  # Calculate all derived metrics in one step
  mutate(
    # Ensure pixel-to-mm scale is present in the input file
    px_per_mm = distance_30_mm_px / 30,

    # Calculate metrics in real-world units (mm)
    area_mm2 = area_px / (px_per_mm^2),
    perimeter_mm = perimeter_px / px_per_mm,

    # Calculate dimensionless shape factors
    circularity = (4 * pi * area_px) / (perimeter_px^2),
    form_factor = perimeter_px / (area_px^0.5),
    surface_to_area_ratio = perimeter_px / area_px
  ) %>%
  # Set the desired factor level order for plotting
  mutate(sample = factor(sample, levels = LOGICAL_ORDER))


# -----------------------------------------------------------------------------
# SECTION 3: HELPER FUNCTIONS FOR ANALYSIS AND PLOTTING
# -----------------------------------------------------------------------------

#' Perform Statistical Analysis and Summarize Data
#'
#' This function takes the prepared data, performs an ANOVA and HSD test
#' on a specified metric, and returns a summarized tibble ready for plotting.
#'
#' @param data The input dataframe.
#' @param metric_var The name of the column to analyze (e.g., "pore_factor").
#' @return A summarized tibble with mean, sd, and HSD group letters.
perform_analysis <- function(data, metric_var) {
  # Formula for ANOVA, e.g., pore_factor ~ sample
  formula <- as.formula(paste(metric_var, "~ sample"))
  anova_model <- aov(formula, data = data)
  hsd_test <- HSD.test(anova_model, "sample", group = TRUE, console = FALSE)
  hsd_groups <- as_tibble(hsd_test$groups, rownames = "sample")

  data %>%
    group_by(sample) %>%
    summarise(
      mean = mean(.data[[metric_var]], na.rm = TRUE),
      sd = sd(.data[[metric_var]], na.rm = TRUE),
      .groups = 'drop'
    ) %>%
    left_join(hsd_groups %>% select(sample, groups), by = "sample")
}

#' Create a Standard Summary Bar Plot
#'
#' @param summary_data A summarized tibble from perform_analysis().
#' @param y_label The label for the y-axis.
#' @param y_limits A vector for the y-axis limits, e.g., c(0, 4).
#' @param y_intercept The position for a dashed horizontal reference line.
#' @return A ggplot object.
create_summary_plot <- function(summary_data, y_label, y_limits, y_intercept) {
  ggplot(summary_data, aes(x = sample, y = mean, color = sample)) +
    geom_bar(stat = "identity", fill = NA, linewidth = 1) +
    geom_errorbar(
      aes(ymin = mean - sd, ymax = mean + sd),
      width = 0.2, linewidth = 1
    ) +
    geom_text(
      aes(label = groups, y = mean + sd),
      vjust = -0.5, color = "black", size = 5
    ) +
    geom_hline(yintercept = y_intercept, linetype = "dashed", color = "#333333") +
    scale_y_continuous(limits = y_limits) +
    scale_color_manual(values = colors) +
    labs(x = "Sample", y = y_label) +
    bbc_style() +
    theme(
      aspect.ratio = 1,
      legend.position = "none",
      axis.title = element_text(size = 18, face = "bold"),
      axis.text = element_text(size = 16)
    )
}


# -----------------------------------------------------------------------------
# SECTION 4: PERFORM ANALYSIS AND GENERATE PLOTS
# -----------------------------------------------------------------------------

# --- 4.1: Pore Factor ---
summary_pf <- perform_analysis(data, "pore_factor")
plot_pf <- create_summary_plot(summary_pf, "Pore factor (a.u.)", c(0, 4), 1)

# --- 4.2: Pore Area (mm^2) ---
summary_area <- perform_analysis(data, "area_mm2")
plot_area <- create_summary_plot(summary_area, bquote("Pore area"~(mm^2)), c(0, 50), 46.52)

# --- 4.3: Pore Perimeter (mm) ---
summary_perimeter <- perform_analysis(data, "perimeter_mm")
plot_perimeter <- create_summary_plot(summary_perimeter, "Pore perimeter (mm)", c(0, 30), 27.28)

# --- 4.4: Circularity ---
summary_circ <- perform_analysis(data, "circularity")
plot_circ <- create_summary_plot(summary_circ, "Pore circularity (a.u.)", c(0, 1.25), 1)

# --- 4.5: Pore Number (per image) ---
# This requires a slightly different summarization method
summary_number <- data %>%
  group_by(filename, sample) %>%
  summarise(n = n(), .groups = "drop_last") %>%
  summarise(
      mean = mean(n, na.rm = TRUE),
      sd = sd(n, na.rm = TRUE),
      .groups = 'drop'
    ) # No HSD test for this one in this simplified workflow

plot_number <- ggplot(summary_number, aes(x = sample, y = mean, color = sample)) +
  geom_bar(stat = "identity", fill = NA, linewidth = 1) +
  geom_errorbar(aes(ymin = mean - sd, ymax = mean + sd), width = 0.2, linewidth = 1) +
  scale_y_continuous(limits = c(0, 30)) +
  labs(x = "Sample", y = "Avg. pore number") +
  bbc_style() +
  theme(aspect.ratio = 1, legend.position = "none",
        axis.title = element_text(size = 18, face = "bold"),
        axis.text = element_text(size = 16))


# --- 4.6: Pore Factor Distribution ---
plot_dist <- ggplot(data, aes(x = pore_factor, fill = sample)) +
  geom_histogram(binwidth = 0.1, alpha = 0.7, color = "white") +
  geom_vline(xintercept = 1, linetype = "dashed", color = "#333333") +
  facet_wrap(~ sample, ncol = 4) +
  scale_x_continuous(limits = c(0, 5), breaks = seq(0, 5, 1)) +
  scale_fill_manual(values = colors) +
  labs(x = "Pore factor (a.u.)", y = "Count") +
  bbc_style() +
  theme(
    aspect.ratio = 1,
    legend.position = "none",
    strip.text = element_text(size = 14, face = "bold")
  )


# -----------------------------------------------------------------------------
# SECTION 5: ASSEMBLE AND SAVE FINAL FIGURE
# -----------------------------------------------------------------------------
summary_filename <- file.path(output_dir, paste0("PORE_FACTOR_SUMMARY_", FILTER_COMPOSITION, ".jpeg"))

CairoJPEG(summary_filename, width = 48, height = 24, units = "cm", dpi = 600, bg = "white")

grid.arrange(
  plot_pf, plot_perimeter, plot_area, plot_number,
  plot_circ, plot_dist,
  layout_matrix = rbind(
    c(1, 2, 3, 4),
    c(5, 6, 6, 6)
  )
)

dev.off()

print(paste("Analysis complete. Summary figure saved to:", summary_filename))
