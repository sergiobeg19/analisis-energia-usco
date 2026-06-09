# =============================================================================
# SCRIPT 01b: Estadísticas Descriptivas y Validación de Imputación
# =============================================================================

library(readxl)
library(dplyr)
library(tidyr)
library(ggplot2)
library(here)
library(readr)
library(lubridate)

# Rutas
RUTA_CONSUMO_RAW <- here("data", "raw", "Consumo_Cuentas_.xlsx")
RUTA_DETALLE_CSV <- here("data", "processed", "Detalle_Cuenta_Periodo.csv")

# Cuentas de Sede Central
cuentas_central <- c(167382131, 167383918, 357154485, 847747377, 167385482)
nombres_central <- c("167382131" = "Central_1",
                     "167383918" = "Central_4",
                     "357154485" = "Central_5",
                     "847747377" = "Central_3",
                     "167385482" = "Central_2")

df_raw <- read_excel(RUTA_CONSUMO_RAW)

df_max <- df_raw %>%
  filter(Cuenta %in% cuentas_central) %>%
  mutate(
    Cuenta_Nombre = nombres_central[as.character(Cuenta)],
    `Consumo Real` = replace_na(`Consumo Real`, 0)
  ) %>%
  group_by(Cuenta_Nombre, Ano, Mes, `Tipo Energia`) %>%
  summarise(Consumo = max(`Consumo Real`), .groups = "drop")

df_wide_raw <- df_max %>%
  filter(`Tipo Energia` %in% c("A", "R")) %>%
  pivot_wider(names_from = `Tipo Energia`, values_from = Consumo, values_fill = 0)

# =============================================================================
# 1. ESTADÍSTICAS DESCRIPTIVAS CRUDAS
# =============================================================================
stats_crudas <- df_wide_raw %>%
  group_by(Cuenta_Nombre) %>%
  summarise(
    N_Registros = n(),
    Activa_Media = mean(A, na.rm = TRUE),
    Activa_SD = sd(A, na.rm = TRUE),
    Activa_Ceros_Pct = round(mean(A == 0) * 100, 2),
    Reactiva_Media = mean(R, na.rm = TRUE),
    Reactiva_Ceros_Pct = round(mean(R == 0) * 100, 2)
  )

write_csv(stats_crudas, here("data", "processed", "Estadisticas_Crudas.csv"))

# =============================================================================
# 2. GRÁFICO ANTES/DESPUÉS DE IMPUTACIÓN (Central_2)
# =============================================================================
# Datos imputados
df_imputado <- read_csv(RUTA_DETALLE_CSV, show_col_types = FALSE) %>%
  filter(Nombre_Cuenta == "Central_2") %>%
  mutate(Fecha = make_date(Ano, Mes, 1))

# Unir con datos crudos
df_comparacion <- df_imputado %>%
  left_join(
    df_wide_raw %>% 
      filter(Cuenta_Nombre == "Central_2") %>%
      mutate(Fecha = make_date(Ano, Mes, 1)) %>%
      select(Fecha, A_cruda = A),
    by = "Fecha"
  ) %>%
  mutate(A_cruda = replace_na(A_cruda, 0)) %>%
  # Limitar a un periodo de 2017 a 2019 para ver claramente los ceros
  filter(Fecha >= as.Date("2017-01-01"), Fecha <= as.Date("2019-12-01"))

# Plot
p_imputacion <- ggplot(df_comparacion, aes(x = Fecha)) +
  geom_line(aes(y = Activa, color = "Imputada (Suavizada)"), size = 1, linetype = "dashed") +
  geom_point(aes(y = Activa, color = "Imputada (Suavizada)"), size = 2) +
  geom_line(aes(y = A_cruda, color = "Original Cruda (con fallos)"), size = 1, alpha = 0.7) +
  geom_point(aes(y = A_cruda, color = "Original Cruda (con fallos)"), size = 2, alpha = 0.7) +
  scale_y_continuous(labels = scales::comma_format()) +
  scale_color_manual(values = c("Original Cruda (con fallos)" = "#D62728", "Imputada (Suavizada)" = "#1F77B4")) +
  theme_minimal(base_size = 14) +
  labs(
    title = "Validación Metodológica: Imputación de Ceros Anómalos (Central_2)",
    subtitle = "Reconstrucción de continuidad temporal basada en promedios históricos mensuales",
    x = "Fecha", y = "Energía Activa (kWh)", color = "Serie Temporal"
  ) +
  theme(
    legend.position = "bottom",
    plot.title = element_text(face = "bold"),
    plot.background = element_rect(fill = "white", color = NA)
  )

ggsave(here("data", "processed", "plots", "Imputacion_Antes_Despues.png"), p_imputacion, width = 10, height = 6, dpi = 300)

cat("Script completado: Estadísticas y gráfico generados.\n")
