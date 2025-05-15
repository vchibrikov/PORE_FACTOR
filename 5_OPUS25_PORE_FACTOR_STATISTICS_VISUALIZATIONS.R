#### LIBRARIES ####

library("agricolae")
library("tidyverse")
library("RColorBrewer")
library("Cairo")
library("pals")
library("ggrepel")
library("gridExtra")
library("varhandle")
library("gtools")
library("bbplot")
library("readxl")
library("stringr")
library("xlsx")
library("gtools")
library("gridExtra")

pacman::p_load('dplyr', 'tidyr', 'gapminder',
               'ggplot2',  'ggalt',
               'forcats', 'R.utils', 'png',
               'grid', 'ggpubr', 'scales',
               'bbplot')

#### GGPLOT PARAMETERS ####
axis.text.font.size = 18
axis.title.font.size = 24
group.labels.font.size = 6
legend.font.size = 18
dodge.value <- 0.5
x.axis.title.angle = 45
width_index = 0.2
colors <- brewer.pal(9, "Set1")

#### LOGICAL ORDER ####

logical_order <- c("", "", "")

#### GGPLOT ####

get_data_plot <- function(my.data, point.size, padding, ymin, ymax, anova_text_margin,
                          hline_linewidth, xlabel, ylabel, aspect.ratio.plot, axis.title.font.size,
                          axis.text.font.size, legend.font.size, legend.title.font.size,
                          plot.tag.size, plot.tag, y.scale.gaps, shape.values)
{

  ymin_rounded <- round(ymin, 2)
  ymax_rounded <- round(ymax, 2)
  y.scale.gaps_rounded <- round(y.scale.gaps, 2)

  result <- ggplot(data = my.data, mapping = aes(x = sample, y = mean, color = sample, group = sample, shape = sample)) +

    geom_bar(stat = "identity", position = position_dodge2(width = width_index,
                                                           preserve = "single",
                                                           padding = padding),
             alpha = 0, linewidth = 1) +

    geom_hline(yintercept = ymin_rounded, linewidth = hline_linewidth, colour = "#333333") +

    geom_errorbar(mapping = aes(ymax = mean + sd, ymin = ifelse(mean - sd < 0, 0, mean - sd)),
                  width = width_index,
                  linewidth = 1,
                  position = position_dodge2(width = width_index),
                  show.legend = FALSE, alpha = 1) +

    geom_text(aes(label = group, y = mean + sd + anova_text_margin),
              vjust = 0.4, position = position_dodge2(width = width_index,
                                                      preserve = "single", padding = padding), angle = 0,
              size = group.labels.font.size, show.legend = FALSE) +

    labs(x = xlabel, y = ylabel) +

    scale_color_manual(values = colors, name = "Sample") +

    scale_shape_manual(values = shape.values, name = "Sample") +

    scale_y_continuous(limits = c(ymin_rounded, ymax_rounded),
                       breaks = seq(ymin_rounded, ymax_rounded, by = y.scale.gaps_rounded),
                       labels = function(x) format(x, nsmall = 2)) +

    bbc_style() +

    theme(aspect.ratio = aspect.ratio.plot,
          panel.border = element_rect(color = "black", linewidth = 1, fill = NA),
          panel.background = element_blank(),
          plot.background = element_blank(),
          plot.margin = margin(0.2, 0.2, 0.2, 0.2, "cm")) +
    guides(shape = guide_legend(ncol = 1, byrow = TRUE)) +
    theme(axis.title = ggplot2::element_text(family = "TT Arial", size = axis.title.font.size,
                                             face = "bold", color = "#222222"),
          axis.text.y = ggplot2::element_text(size = axis.text.font.size),
          axis.text.x = ggplot2::element_text(size = axis.text.font.size - 6, angle = 0),
          legend.position = "none",
          legend.text = element_text(size = legend.font.size),
          legend.key.size = unit(0.2, "cm"),
          legend.title = element_text(size = legend.title.font.size, face = "bold"),
          legend.spacing.y = unit(0.2, "cm")) +
    labs(tag = plot.tag) +
    theme(plot.tag.position = c(0.02, 0.1)) +
    theme(plot.tag = element_text(size = plot.tag.size))
}

#### DATA PROCESSING ####

raw.data <- read_excel("./read/raw/data.xlsx", sheet = 1)

data <- raw.data
data$filename <- substr(data$filename, 1, nchar(data$filename) - 4)

pattern <- "(.*?)_(.*?)_(.*?)_(.*?)_(.*?)_(.*?)_(.*)"
filename_split <- tibble(date = sub(pattern, "\\1_\\2_\\3", data$filename),
                         sample = sub(pattern, "\\4_\\5_\\6", data$filename),
                         composition = sub(pattern, "\\4", data$filename))

data <- cbind(data, filename_split)

data <- filter(data, composition == "")

#### PORE FACTOR ####

anova.model <- aov(pore_factor ~ sample, data = data)
anova.out <- HSD.test(anova.model,"sample", group = TRUE, console = TRUE)

data <- data %>%
  group_by(sample) %>%
  mutate(mean = mean(pore_factor),
         sd = sd(pore_factor)) %>%
  distinct(sample, .keep_all = TRUE) %>%
  ungroup() %>%
  select(sample, mean, sd)

data <- left_join(data,
                        tibble(sample = str_replace(rownames(anova.out$groups),",","."),
                               group = anova.out$groups$groups),
                        by = "sample") -> data

group <- data$group

data$sample <- factor(data$sample, levels = mixedsort(unique(data$sample)))

data$sample <- factor(data$sample, levels = logical_order)

get_data_plot <- function(my.data, point.size, padding, ymin, ymax, anova_text_margin,
                          hline_linewidth, xlabel, ylabel, aspect.ratio.plot, axis.title.font.size,
                          axis.text.font.size, legend.font.size, legend.title.font.size,
                          plot.tag.size, plot.tag, y.scale.gaps, shape.values, yintercept)
{
  
  ymin_rounded <- round(ymin, 2)
  ymax_rounded <- round(ymax, 2)
  y.scale.gaps_rounded <- round(y.scale.gaps, 2)
  
  result <- ggplot(data = my.data, mapping = aes(x = sample, y = mean, color = sample, group = sample, shape = sample)) +
    
    geom_bar(stat = "identity", position = position_dodge2(width = width_index,
                                                           preserve = "single",
                                                           padding = padding),
             alpha = 0, linewidth = 1) +
    
    geom_hline(yintercept = ymin_rounded, linewidth = hline_linewidth, colour = "#333333") +
    geom_hline(yintercept = yintercept, linewidth = hline_linewidth, linetype = "dashed", colour = "#333333") +
    
    
    geom_errorbar(mapping = aes(ymax = mean + sd, ymin = ifelse(mean - sd < 0, 0, mean - sd)),
                  width = width_index,
                  linewidth = 1,
                  position = position_dodge2(width = width_index),
                  show.legend = FALSE, alpha = 1) +
    
    geom_text(aes(label = group, y = mean + sd + anova_text_margin),
              vjust = 0.4, position = position_dodge2(width = width_index,
                                                      preserve = "single", padding = padding), angle = 0,
              size = group.labels.font.size, show.legend = FALSE) +
    
    labs(x = xlabel, y = ylabel) +
    
    scale_color_manual(values = colors, name = "Sample") +
    
    scale_shape_manual(values = shape.values, name = "Sample") +
    
    scale_y_continuous(limits = c(ymin_rounded, ymax_rounded),
                       breaks = seq(ymin_rounded, ymax_rounded, by = y.scale.gaps_rounded),
                       labels = function(x) format(x, nsmall = 2)) +
    
    bbc_style() +
    
    theme(aspect.ratio = aspect.ratio.plot,
          panel.border = element_rect(color = "black", linewidth = 1, fill = NA),
          panel.background = element_blank(),
          plot.background = element_blank(),
          plot.margin = margin(0.2, 0.2, 0.2, 0.2, "cm")) +
    guides(shape = guide_legend(ncol = 1, byrow = TRUE)) +
    theme(axis.title = ggplot2::element_text(family = "TT Arial", size = axis.title.font.size,
                                             face = "bold", color = "#222222"),
          axis.text.y = ggplot2::element_text(size = axis.text.font.size),
          axis.text.x = ggplot2::element_text(size = axis.text.font.size - 6, angle = 0),
          legend.position = "none",
          legend.text = element_text(size = legend.font.size),
          legend.key.size = unit(0.2, "cm"),
          legend.title = element_text(size = legend.title.font.size, face = "bold"),
          legend.spacing.y = unit(0.2, "cm")) +
    labs(tag = plot.tag) +
    theme(plot.tag.position = c(0.02, 0.1)) +
    theme(plot.tag = element_text(size = plot.tag.size))
}

pore.factor.plot <- get_data_plot(my.data = data,
                             point.size = 4,
                             padding = 3,
                             ymin = 0,
                             ymax = 2,
                             yintercept = 1,
                             y.scale.gaps = 0.5,
                             anova_text_margin = 0.1,
                             hline_linewidth = 0.5,
                             xlabel = "Sample",
                             ylabel = "Pore factor (a.u.)",
                             aspect.ratio.plot = 1,
                             axis.title.font.size = 18,
                             axis.text.font.size = 16,
                             legend.font.size = 8,
                             legend.title.font.size = 12,
                             plot.tag.size = 18,
                             shape.values = c(16, 15, 17, 18, 19, 20, 21),
                             plot.tag = "")

plot_width <- 12
plot_height <- 12
plot_filename <- "./plot/output/filename.jpeg"
ggsave(pore.factor.plot, filename = plot_filename, dpi = 300, type = "cairo",
       width = plot_width, height = plot_height, units = "cm")

#### AREA ####

raw.data <- read_excel(".read/raw/data.xlsx", sheet = 1)

data <- raw.data
data$filename <- substr(data$filename, 1, nchar(data$filename) - 4)

pattern <- "(.*?)_(.*?)_(.*?)_(.*?)_(.*?)_(.*?)_(.*)"
filename_split <- tibble(date = sub(pattern, "\\1_\\2_\\3", data$filename),
                         sample = sub(pattern, "\\4_\\5_\\6", data$filename),
                         composition = sub(pattern, "\\4", data$filename))

data <- cbind(data, filename_split)

data <- filter(data, composition == "")

data$area_mm2 <- data$area_px / (data$distance_30_mm_px / 30)^2

anova.model <- aov(area_mm2 ~ sample, data = data)
anova.out <- HSD.test(anova.model,"sample", group = TRUE, console = TRUE)

data <- data %>%
  group_by(sample) %>%
  mutate(mean = mean(area_mm2),
         sd = sd(area_mm2)) %>%
  distinct(sample, .keep_all = TRUE) %>%
  ungroup() %>%
  select(sample, mean, sd)

data <- left_join(data,
                  tibble(sample = str_replace(rownames(anova.out$groups),",","."),
                         group = anova.out$groups$groups),
                  by = "sample") -> data

group <- data$group

data$sample <- factor(data$sample, levels = mixedsort(unique(data$sample)))

data$sample <- factor(data$sample, levels = logical_order)

pore.area.plot <- get_data_plot(my.data = data,
                                  point.size = 4,
                                  padding = 3,
                                  ymin = 0,
                                  ymax = 5,
                                  yintercept = 0,
                                  y.scale.gaps = 1,
                                  anova_text_margin = 0.25,
                                  hline_linewidth = 0.5,
                                  xlabel = "Sample",
                                  ylabel = "Pore area (sq. mm)",
                                  aspect.ratio.plot = 1,
                                  axis.title.font.size = 18,
                                  axis.text.font.size = 16,
                                  legend.font.size = 8,
                                  legend.title.font.size = 12,
                                  plot.tag.size = 18,
                                  shape.values = c(16, 15, 17, 18, 19, 20, 21),
                                  plot.tag = "")

plot_filename <- "./output/plot/filename.jpeg"
ggsave(pore.area.plot, filename = plot_filename, dpi = 300, type = "cairo",
       width = plot_width, height = plot_height, units = "cm")

#### PERIMETER ####

data <- raw.data
data$filename <- substr(data$filename, 1, nchar(data$filename) - 4)

pattern <- "(.*?)_(.*?)_(.*?)_(.*?)_(.*?)_(.*?)_(.*)"
filename_split <- tibble(date = sub(pattern, "\\1_\\2_\\3", data$filename),
                         sample = sub(pattern, "\\4_\\5_\\6", data$filename),
                         composition = sub(pattern, "\\4", data$filename))

data <- cbind(data, filename_split)

data <- filter(data, composition == "")

data$perimeter_mm <- data$perimeter_px / (data$distance_30_mm_px/30)

anova.model <- aov(perimeter_mm ~ sample, data = data)
anova.out <- HSD.test(anova.model,"sample", group = TRUE, console = TRUE)

data <- data %>%
  group_by(sample) %>%
  mutate(mean = mean(perimeter_mm),
         sd = sd(perimeter_mm)) %>%
  distinct(sample, .keep_all = TRUE) %>%
  ungroup() %>%
  select(sample, mean, sd)

data <- left_join(data,
                  tibble(sample = str_replace(rownames(anova.out$groups),",","."),
                         group = anova.out$groups$groups),
                  by = "sample") -> data

group <- data$group

data$sample <- factor(data$sample, levels = mixedsort(unique(data$sample)))

data$sample <- factor(data$sample, levels = logical_order)

pore.perimeter.plot <- get_data_plot(my.data = data,
                                point.size = 4,
                                padding = 3,
                                ymin = 0,
                                ymax = 10,
                                yintercept = 0,
                                y.scale.gaps = 2,
                                anova_text_margin = 0.5,
                                hline_linewidth = 0.5,
                                xlabel = "Sample",
                                ylabel = "Pore perimeter (mm)",
                                aspect.ratio.plot = 1,
                                axis.title.font.size = 18,
                                axis.text.font.size = 16,
                                legend.font.size = 8,
                                legend.title.font.size = 12,
                                plot.tag.size = 18,
                                shape.values = c(16, 15, 17, 18, 19, 20, 21),
                                plot.tag = "")

plot_filename <- ".plot/output/filename.jpeg"
ggsave(pore.perimeter.plot, filename = plot_filename, dpi = 300, type = "cairo",
       width = plot_width, height = plot_height, units = "cm")

#### CIRCULARITY ####

data <- raw.data
data$filename <- substr(data$filename, 1, nchar(data$filename) - 4)

pattern <- "(.*?)_(.*?)_(.*?)_(.*?)_(.*?)_(.*?)_(.*)"
filename_split <- tibble(date = sub(pattern, "\\1_\\2_\\3", data$filename),
                         sample = sub(pattern, "\\4_\\5_\\6", data$filename),
                         composition = sub(pattern, "\\4", data$filename))

data <- cbind(data, filename_split)

data <- filter(data, composition == "")

data$circularity <- (4 * pi * data$area_px) / (data$perimeter_px^2)

anova.model <- aov(circularity ~ sample, data = data)
anova.out <- HSD.test(anova.model,"sample", group = TRUE, console = TRUE)

data <- data %>%
  group_by(sample) %>%
  mutate(mean = mean(circularity),
         sd = sd(circularity)) %>%
  distinct(sample, .keep_all = TRUE) %>%
  ungroup() %>%
  select(sample, mean, sd)

data <- left_join(data,
                  tibble(sample = str_replace(rownames(anova.out$groups),",","."),
                         group = anova.out$groups$groups),
                  by = "sample") -> data

group <- data$group

data$sample <- factor(data$sample, levels = mixedsort(unique(data$sample)))

data$sample <- factor(data$sample, levels = logical_order)

pore.circularity.plot <- get_data_plot(my.data = data,
                                     point.size = 4,
                                     padding = 3,
                                     ymin = 0,
                                     ymax = 1.25,
                                     yintercept = 0,
                                     y.scale.gaps = 0.25,
                                     anova_text_margin = 0.05,
                                     hline_linewidth = 0.5,
                                     xlabel = "Sample",
                                     ylabel = "Pore circularity (a.u.)",
                                     aspect.ratio.plot = 1,
                                     axis.title.font.size = 18,
                                     axis.text.font.size = 16,
                                     legend.font.size = 8,
                                     legend.title.font.size = 12,
                                     plot.tag.size = 18,
                                     shape.values = c(16, 15, 17, 18, 19, 20, 21),
                                     plot.tag = "")


plot_filename <- "./plot/output/filename.jpeg"
ggsave(pore.circularity.plot, filename = plot_filename, dpi = 300, type = "cairo",
       width = plot_width, height = plot_height, units = "cm")

#### FORM FACTOR ####

data <- raw.data
data$filename <- substr(data$filename, 1, nchar(data$filename) - 4)

pattern <- "(.*?)_(.*?)_(.*?)_(.*?)_(.*?)_(.*?)_(.*)"
filename_split <- tibble(date = sub(pattern, "\\1_\\2_\\3", data$filename),
                         sample = sub(pattern, "\\4_\\5_\\6", data$filename),
                         composition = sub(pattern, "\\4", data$filename))

data <- cbind(data, filename_split)

data <- filter(data, composition == "")

data$form_factor <- data$perimeter_px / (data$area_px^0.5)

anova.model <- aov(form_factor ~ sample, data = data)
anova.out <- HSD.test(anova.model,"sample", group = TRUE, console = TRUE)

data <- data %>%
  group_by(sample) %>%
  mutate(mean = mean(form_factor),
         sd = sd(form_factor)) %>%
  distinct(sample, .keep_all = TRUE) %>%
  ungroup() %>%
  select(sample, mean, sd)

data <- left_join(data,
                  tibble(sample = str_replace(rownames(anova.out$groups),",","."),
                         group = anova.out$groups$groups),
                  by = "sample") -> data

group <- data$group

data$sample <- factor(data$sample, levels = mixedsort(unique(data$sample)))

data$sample <- factor(data$sample, levels = logical_order)

pore.form.factor.plot <- get_data_plot(my.data = data,
                                       point.size = 4,
                                       padding = 3,
                                       ymin = 0,
                                       ymax = 6,
                                       yintercept = 0,
                                       y.scale.gaps = 2,
                                       anova_text_margin = 0.25,
                                       hline_linewidth = 0.5,
                                       xlabel = "Sample",
                                       ylabel = "Pore form factor (a.u.)",
                                       aspect.ratio.plot = 1,
                                       axis.title.font.size = 18,
                                       axis.text.font.size = 16,
                                       legend.font.size = 8,
                                       legend.title.font.size = 12,
                                       plot.tag.size = 18,
                                       shape.values = c(16, 15, 17, 18, 19, 20, 21),
                                       plot.tag = "")


plot_filename <- "./plot/output/filename.jpeg"
ggsave(pore.form.factor.plot, filename = plot_filename, dpi = 300, type = "cairo",
       width = plot_width, height = plot_height, units = "cm")

#### SURFACE-TO-AREA RATIO ####

data <- raw.data
data$filename <- substr(data$filename, 1, nchar(data$filename) - 4)

pattern <- "(.*?)_(.*?)_(.*?)_(.*?)_(.*?)_(.*?)_(.*)"
filename_split <- tibble(date = sub(pattern, "\\1_\\2_\\3", data$filename),
                         sample = sub(pattern, "\\4_\\5_\\6", data$filename),
                         composition = sub(pattern, "\\4", data$filename))

data <- cbind(data, filename_split)

data <- filter(data, composition == "")

data$surface_to_area_ratio <- data$perimeter_px / data$area_px

anova.model <- aov(surface_to_area_ratio ~ sample, data = data)
anova.out <- HSD.test(anova.model,"sample", group = TRUE, console = TRUE)

data <- data %>%
  group_by(sample) %>%
  mutate(mean = mean(surface_to_area_ratio),
         sd = sd(surface_to_area_ratio)) %>%
  distinct(sample, .keep_all = TRUE) %>%
  ungroup() %>%
  select(sample, mean, sd)

data <- left_join(data,
                  tibble(sample = str_replace(rownames(anova.out$groups),",","."),
                         group = anova.out$groups$groups),
                  by = "sample") -> data

group <- data$group

data$sample <- factor(data$sample, levels = mixedsort(unique(data$sample)))

data$sample <- factor(data$sample, levels = logical_order)

pore.form.factor.plot <- get_data_plot(my.data = data,
                                       point.size = 4,
                                       padding = 3,
                                       ymin = 0,
                                       ymax = 0.3,
                                       yintercept = 0,
                                       y.scale.gaps = 0.1,
                                       anova_text_margin = 0.01,
                                       hline_linewidth = 0.5,
                                       xlabel = "Sample",
                                       ylabel = "Surface-to-area ratio (a.u.)",
                                       aspect.ratio.plot = 1,
                                       axis.title.font.size = 18,
                                       axis.text.font.size = 16,
                                       legend.font.size = 8,
                                       legend.title.font.size = 12,
                                       plot.tag.size = 18,
                                       shape.values = c(16, 15, 17, 18, 19, 20, 21),
                                       plot.tag = "")

plot_filename <- "./plot/output/filename.jpeg"
ggsave(pore.form.factor.plot, filename = plot_filename, dpi = 300, type = "cairo",
       width = plot_width, height = plot_height, units = "cm")

#### PORE NUMBER ####

data <- raw.data
data$filename <- substr(data$filename, 1, nchar(data$filename) - 4)

pattern <- "(.*?)_(.*?)_(.*?)_(.*?)_(.*?)_(.*?)_(.*)"
filename_split <- tibble(date = sub(pattern, "\\1_\\2_\\3", data$filename),
                         sample = sub(pattern, "\\4_\\5_\\6", data$filename),
                         composition = sub(pattern, "\\4", data$filename))

data <- cbind(data, filename_split)

data <- filter(data, composition == "")

data <- data %>%
  group_by(filename) %>%
  mutate(n = n()) %>%
  select(filename, n, sample, composition) %>%
  unique()

anova.model <- aov(n ~ sample, data = data)
anova.out <- HSD.test(anova.model,"sample", group = TRUE, console = TRUE)

data <- data %>%
  group_by(sample) %>%
  mutate(mean = mean(n),
         sd = sd(n)) %>%
  distinct(sample, .keep_all = TRUE) %>%
  ungroup() %>%
  select(sample, mean, sd)

data <- left_join(data,
                  tibble(sample = str_replace(rownames(anova.out$groups),",","."),
                         group = anova.out$groups$groups),
                  by = "sample") -> data
group <- data$group

data$sample <- factor(data$sample, levels = mixedsort(unique(data$sample)))

data$sample <- factor(data$sample, levels = logical_order)

pore.number <- get_data_plot(my.data = data,
                                       point.size = 4,
                                       padding = 3,
                                       ymin = 0,
                                       ymax = 20,
                                       yintercept = 16,
                                       y.scale.gaps = 5,
                                       anova_text_margin = 1,
                                       hline_linewidth = 0.5,
                                       xlabel = "Sample",
                                       ylabel = "Avg. pore number (per image)",
                                       aspect.ratio.plot = 1,
                                       axis.title.font.size = 18,
                                       axis.text.font.size = 16,
                                       legend.font.size = 8,
                                       legend.title.font.size = 12,
                                       plot.tag.size = 18,
                                       shape.values = c(16, 15, 17, 18, 19, 20, 21),
                                       plot.tag = "")

plot_filename <- "./plot/output/filename.jpeg"
ggsave(pore.number, filename = plot_filename, dpi = 300, type = "cairo",
       width = plot_width, height = plot_height, units = "cm")

#### PORE FACTOR DISTRIBUTION ####

data <- raw.data
data$filename <- substr(data$filename, 1, nchar(data$filename) - 4)

pattern <- "(.*?)_(.*?)_(.*?)_(.*?)_(.*?)_(.*?)_(.*)"
filename_split <- tibble(date = sub(pattern, "\\1_\\2_\\3", data$filename),
                         sample = sub(pattern, "\\4_\\5_\\6", data$filename),
                         composition = sub(pattern, "\\4", data$filename))

data <- cbind(data, filename_split)

data <- filter(data, composition == "")

pore.factor.distribution <- ggplot(data, aes(x = pore_factor, fill = sample)) +
  geom_histogram(position = "identity", 
                 binwidth = 0.1, 
                 alpha = 0.5, 
                 color = NA) +
  facet_wrap(~ sample, ncol = 4) +   # or nrow = 1 for horizontal layout
  geom_hline(yintercept = 0, linewidth = 0.5, colour = "#333333") +
  geom_vline(xintercept = 1, linewidth = 0.5, linetype = "dashed", colour = "#333333") +
  
  # geom_density(aes(color = sample),
  #              fill = NA,
  #              alpha = 1,
  #              adjust = 6, linewidth = 1) +
  bbc_style() +
  theme(
    aspect.ratio = 1,
    panel.border = element_rect(color = "black", linewidth = 0.5, fill = NA),
    panel.background = element_blank(),
    plot.background = element_blank(),
    plot.margin = margin(0.2, 0.2, 0.2, 0.2, "cm"),
    axis.title = element_text(family = "TT Arial", size = 18,
                              face = "bold", color = "#333333"),
    axis.text.y = element_text(size = 16),
    axis.text.x = element_text(size = 16),
    legend.position = "none",
    legend.text = element_text(size = 16),
    legend.key.size = unit(0.2, "cm"),
    legend.title = element_blank(),
    legend.spacing.y = unit(0.2, "cm"),
    strip.text = element_text(size = 16, family = "TT Arial", color = "#333333")
  ) +
  labs(
    x = "Pore factor (a.u.)",
    y = "Nr of observations") +
  scale_x_continuous(
    limits = c(0, 3),
    breaks = seq(0, 3, by = 0.5),
    labels = function(x) format(x, nsmall = 0))

plot_width <- 36
plot_height <- 12
plot_filename <- "./plot/output/filename.jpeg"
ggsave(pore.factor.distribution, filename = plot_filename, dpi = 300, type = "cairo",
       width = plot_width, height = plot_height, units = "cm")

#### MERGE FIGURE ####
 
filename <- "./plot/output/summary_filename.jpeg"
CairoPNG(filename, width = 48, height = 24, units = "cm", dpi = 600, bg = "white")

grid.arrange(
  pore.factor.plot,
  pore.perimeter.plot,
  pore.area.plot,
  pore.number,
  pore.circularity.plot,
  pore.factor.distribution,
  layout_matrix = rbind(
    c(1, 2, 3, 4),
    c(5, 6, 6, 6)
  )
)

dev.off()
