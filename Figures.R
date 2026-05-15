# Drawing figures
# ---------------------------------------------------------------------------------
rm(list = ls())
library(stargazer)
library(ggplot2)
library(quantreg)
library(dplyr)
library(lubridate)
library(tidyr)
library(patchwork)
# F1 ------------------------------
# Load data set

setwd("/Users/yourname/file/")
path <- "/Users/yourname/file/"


clean <- file.path(path, "Clean Data")
out   <- file.path(path, "output")
raw   <- file.path(path, "Raw_data")


df <- read.csv(file.path(raw, "carbon_pri.csv"))


# Transfer to date
df_q <- df %>%
  mutate(Date = as.Date(Date)) %>%
  mutate(quarter = floor_date(Date, "quarter")) %>%
  group_by(quarter) %>%
  summarise(price_mean = mean(Price, na.rm = TRUE)) %>%
  ungroup()

p <- ggplot(df_q, aes(x = quarter, y = price_mean)) +
  geom_line(linewidth = 0.8, color = "black") +
  geom_point(size = 1.5, color = "black") +
  
  labs(
    x = NULL,
    y = "Average Carbon Price (EURO)",
  ) +
  
  scale_x_date(date_breaks = "1 year", date_labels = "%Y") +
  
  theme_classic(base_size = 12) +
  theme(
    plot.title = element_text(hjust = 0.5),
    axis.text = element_text(color = "black"),
    axis.title = element_text(size = 12),
    panel.grid = element_blank()
  )
print(p)

# Carbon Price Graph
ggsave(file.path(out,"quarterly_price.pdf"), p, width = 6, height = 4)


# F2 ------------------------------
# Load data set
df_elec <- read.csv(file.path(raw, "EU_electricity price.csv"),check.names = FALSE)

colnames(df_elec)[1] <- "Type"
df_t <- as.data.frame(t(df_elec))
colnames(df_t) <- df_t[1, ]
df_t <- df_t[-1, ]

df_t$Time <- rownames(df_t)
rownames(df_t) <- NULL

df_t$Time <- gsub("^X", "", df_t$Time)
df_t$Time <- gsub("\\.1$", "", df_t$Time)

library(tidyr)
df_long <- df_t %>%
  pivot_longer(
    cols = c(Household, `Non-household`),
    names_to = "Type",
    values_to = "Price"
  )

df_long$Price <- as.numeric(trimws(df_long$Price))

df_year <- df_long %>%
  group_by(Time, Type) %>%
  summarise(price_mean = mean(Price, na.rm = TRUE), .groups = "drop")

df_year <- df_year %>%
  rename(year = Time)
df_year$year <- as.numeric(df_year$year)

p2 <- ggplot(df_year,
            aes(x = year,
                y = price_mean,
                linetype = Type,
                group = Type)) +
  
  geom_line(linewidth = 1, color = "black") +
  geom_point(size = 2) +
  
  labs(
    x = NULL,
    y = "Average Electricity Price (EURO)",
  ) +
  
  scale_x_continuous(breaks = sort(unique(df_year$year))) +
  
  theme_classic(base_size = 13) +
  
  theme(
    legend.title = element_blank(),
    legend.position = "bottom",
    plot.title = element_text(hjust = 0.5),
    axis.text = element_text(color = "black"),
    axis.line = element_line(color = "black")
  )

print(p2)

# EU Electricity Price Graph
ggsave(file.path(out,"EU_elec_price.pdf"), p2, width = 6, height = 4)

# F3 ------------------------------
# Load data set

df3 <- read.csv(file.path(raw, "US_elec_p.csv"))
df3$Residential <- df3$Residential / 100

df3$Industrial  <- df3$Industrial / 100

p3 <- ggplot(df3, aes(x = Year)) +
  
  geom_line(aes(y = Residential, linetype = "Residential"),
            linewidth = 1, color = "black") +
  
  geom_line(aes(y = Industrial, linetype = "Industrial"),
            linewidth = 1, color = "black") +
  
  geom_point(aes(y = Residential), size = 2) +
  geom_point(aes(y = Industrial), size = 2) +
  
  scale_linetype_manual(values = c("solid", "dashed")) +
  
  scale_x_continuous(breaks = df3$Year) +
  
  labs(
    x = NULL,
    y = "Average Electricity Price (USD)",
  ) +
  
  theme_classic(base_size = 13) +
  
  theme(
    legend.title = element_blank(),
    legend.position = "bottom",
    plot.title = element_text(hjust = 0.5),
    axis.text = element_text(color = "black"),
    axis.line = element_line(color = "black")
  )

# US Electricity Price Graph
print(p3)
ggsave(file.path(out,"US_elec_price.pdf"), p3, width = 6, height = 4)

# F4 ------------------------------
# Mean graph
df_mean <- read.csv(file.path(clean, "mean_graphs.csv"))

plot_mean <- function(data, yvar, ylab, title_text){
  
  ggplot(data,
         aes(x = fiscalyear,
             y = .data[[yvar]],
             linetype = factor(treat),
             group = treat)) +
    
    geom_line(linewidth = 1, color = "black") +
    
    scale_linetype_manual(
      values = c("solid", "dashed"),
      labels = c("Control", "Treat")
    ) +
    
    labs(
      x = NULL,
      y = ylab,
      title = title_text
    ) +
    
    theme_classic(base_size = 13) +
    
    theme(
      legend.title = element_blank(),
      legend.position = "bottom",
      plot.title = element_text(hjust = 0.5),
      axis.text = element_text(color = "black")
    )
}

# Mean graphs
pm1 <- plot_mean(df_mean, "Log_GHG_Scope1_Intensity", "Log Scope 1 Intensity", "")
ggsave(file.path(out,"mean_intensity.pdf"), pm1, width = 6, height = 4)
pm2 <- plot_mean(df_mean, "Log_GHG_Scope1", "Log Scope 1 Emissions", "")
ggsave(file.path(out,"mean_emission.pdf"), pm2, width = 6, height = 4)
pm3 <- plot_mean(df_mean, "log_sale_usd", "Log Sales", "")
ggsave(file.path(out,"mean_sales.pdf"), pm3, width = 6, height = 4)


# F5 ------------------------------
# Event study graph
df_es <- read.csv(file.path(clean, "main_event.csv"))

# Functions
plot_event_study <- function(data,
                             title_text = "",
                             ylab = "Effect on Emission Intensity",
                             ylim_range = NULL,
                             show_labels = FALSE) {
  
  p <- ggplot(data, aes(x = time, y = estimate)) +
    
    # CI
    geom_errorbar(aes(ymin = min95, ymax = max95),
                  width = 0.2,
                  color = "black") +
    
    # Point
    geom_point(size = 2) +
    
    # Line
    geom_line(linewidth = 0.6) +
    
    # y=0
    geom_hline(yintercept = 0,
               linetype = "dashed",
               color = "grey50") +
    
    # event time = 0
    geom_vline(xintercept = 0,
               linetype = "dotted") +
    
    labs(
      x = "Years Relative to 2018",
      y = ylab,
      title = title_text
    ) +
    
    theme_classic(base_size = 13) +
    
    theme(
      plot.title = element_text(hjust = 0.5),
      axis.text = element_text(color = "black")
    )
  
  if (!is.null(ylim_range)) {
    p <- p + coord_cartesian(ylim = ylim_range)
  }
  
  if (show_labels) {
    p <- p + geom_text(aes(label = estimate_3dp),
                       vjust = -1,
                       size = 3)
  }
  
  return(p)
}

# Main event study graph
pes1 <- plot_event_study(df_es, title_text = "")
ggsave(file.path(out,"main_es.pdf"), pes1, width = 6, height = 4)

# F6 ------------------------------
# Other Event study graphs by using alternative control
df_es2 <- read.csv(file.path(clean, "sic2_event.csv"))
df_es3 <- read.csv(file.path(clean, "sic2_balancing.csv"))
df_es4 <- read.csv(file.path(clean, "sic1_event.csv"))
df_es5 <- read.csv(file.path(clean, "sic1_balancing.csv"))
df_es6 <- read.csv(file.path(clean, "all_event.csv"))
df_es7 <- read.csv(file.path(clean, "all_balancing.csv"))


pes2 <- plot_event_study(df_es2, title_text = "")
ggsave(file.path(out,"es2.pdf"), pes2, width = 6, height = 4)
pes2

pes3 <- plot_event_study(df_es3, title_text = "")
ggsave(file.path(out,"es3.pdf"), pes3, width = 6, height = 4)
pes3
p_all <- (pes2 | pes3)

pes4 <- plot_event_study(df_es4, title_text = "")
ggsave(file.path(out,"es4.pdf"), pes4, width = 6, height = 4)
pes4

pes5 <- plot_event_study(df_es5, title_text = "")
ggsave(file.path(out,"es5.pdf"), pes5, width = 6, height = 4)
pes5

pes6 <- plot_event_study(df_es6, title_text = "")
ggsave(file.path(out,"es6.pdf"), pes6, width = 6, height = 4)
pes6

pes7 <- plot_event_study(df_es7, title_text = "")
ggsave(file.path(out,"es7.pdf"), pes7, width = 6, height = 4)
pes7

