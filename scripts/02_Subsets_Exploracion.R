# =============================================================================
# SCRIPT 02: Creación de Subsets Temporales y Exploración Visual
# Universidad Surcolombiana (USCO) — Sede Central
# =============================================================================
# INPUT:  data/processed/Detalle_Cuenta_Periodo.csv  (Script 01)
#         data/raw/Datos_Temperatura_Media.xlsx       (IDEAM, desde 2020)
#
# FLUJO:
#   Bloque A — Subset desde 2014 (con temperatura, fases y dummies)
#   Exploración Visual — Gráficas de series individuales y agregadas
#   Bloque B — Subset Nueva Normalidad (Jul 2023 – Jul 2025)
#
# OUTPUT: data/processed/Detalle_Cuenta_Desde2014.csv
#         data/processed/Serie_Sede_Desde2014.csv
#         data/processed/Detalle_Cuenta_NuevaNormalidad.csv
#         data/processed/Serie_Sede_NuevaNormalidad.csv
#         data/processed/plots/ (gráficos exploratorios)
# =============================================================================

library(dplyr)
library(readr)
library(readxl)
library(here)
library(lubridate)
library(tsibble)
library(ggplot2)
library(patchwork)

# ─────────────────────────────────────────────────────────────────────────────
# PARÁMETROS
# ─────────────────────────────────────────────────────────────────────────────
UMBRAL_FP       <- 0.4843
ANO_INICIO      <- 2014
FECHA_INICIO_NN <- make_date(2023, 7, 1)
FECHA_FIN_NN    <- make_date(2025, 7, 31)
mostrar_plots   <- TRUE

# Directorio de gráficos
plot_dir <- here("data", "processed", "plots")
dir.create(plot_dir, recursive = TRUE, showWarnings = FALSE)

# ─────────────────────────────────────────────────────────────────────────────
# CARGA DE DATOS
# ─────────────────────────────────────────────────────────────────────────────
cat("── Cargando datos procesados de Sede Central...\n")
df_central <- read_csv(here("data", "processed", "Detalle_Cuenta_Periodo.csv"), show_col_types = FALSE)

cat("── Cargando datos de temperatura promedio (IDEAM)...\n")
RUTA_TEMPERATURA <- here("data", "raw", "Datos_Temperatura_Media.xlsx")

df_temp <- read_excel(RUTA_TEMPERATURA, sheet = "Datos") %>%
  mutate(
    Temperatura = as.numeric(`Valor:`),
    Ano         = as.numeric(substr(Fecha, 1, 4)),
    Mes         = as.numeric(substr(Fecha, 6, 7))
  ) %>%
  select(Ano, Mes, Temperatura)

cat(sprintf("   Temperatura disponible: %d-%02d a %d-%02d (%d registros)\n",
            min(df_temp$Ano), min(df_temp$Mes[df_temp$Ano == min(df_temp$Ano)]),
            max(df_temp$Ano), max(df_temp$Mes[df_temp$Ano == max(df_temp$Ano)]),
            nrow(df_temp)))

# =============================================================================
# BLOQUE A — Subset desde 2014
# =============================================================================
cat("\n═══════════════════════════════════════════════════\n")
cat("  BLOQUE A — SUBSET DESDE 2014\n")
cat("═══════════════════════════════════════════════════\n")

# --- Detalle por cuenta ---
df_detalle_2014 <- df_central %>%
  filter(Ano >= ANO_INICIO) %>%
  arrange(Cuenta, Ano, Mes) %>%
  left_join(df_temp, by = c("Ano", "Mes")) %>%
  mutate(
    Vacaciones = ifelse(Mes %in% c(1, 6, 7, 12), 1L, 0L),
    Fecha = make_date(Ano, Mes, 1),
    Fase = case_when(
      Fecha < make_date(2020, 3, 1) ~ "Pre-pandemia",
      Fecha < make_date(2023, 7, 7) ~ "Pandemia-Transicion",
      TRUE ~ "Nueva-Normalidad"
    ),
    Fase = factor(Fase, levels = c("Pre-pandemia", "Pandemia-Transicion", "Nueva-Normalidad")),
    Dummy_Pandemia   = ifelse(Fase == "Pandemia-Transicion", 1L, 0L),
    Dummy_Normalidad = ifelse(Fase == "Nueva-Normalidad", 1L, 0L)
  ) %>%
  select(-Fecha)

# --- Serie agregada ---
df_serie_2014 <- df_detalle_2014 %>%
  group_by(Ano, Mes) %>%
  summarise(
    Activa_Total      = sum(Activa,    na.rm = TRUE),
    Reactiva_Total    = sum(Reactiva,  na.rm = TRUE),
    Excedente_Total   = sum(Excedente, na.rm = TRUE),
    Pago_Total_Sede   = sum(Pago,      na.rm = TRUE),
    Cuentas_Pagadas   = sum(!is.na(Pago) & Pago > 0),
    Cuentas_Incumplen = sum(Cumple == "No", na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(
    Sede_Incumple = ifelse(Cuentas_Incumplen > 0, 1L, 0L)
  ) %>%
  arrange(Ano, Mes) %>%
  left_join(df_temp, by = c("Ano", "Mes")) %>%
  mutate(
    Vacaciones = ifelse(Mes %in% c(1, 6, 7, 12), 1L, 0L),
    # Tiempo cronológico absoluto continuo (May 2001 = 1)
    Tiempo     = (Ano - 2001) * 12 + (Mes - 5) + 1,
    Fecha = make_date(Ano, Mes, 1),
    Fase = case_when(
      Fecha < make_date(2020, 3, 1) ~ "Pre-pandemia",
      Fecha < make_date(2023, 7, 7) ~ "Pandemia-Transicion",
      TRUE ~ "Nueva-Normalidad"
    ),
    Fase = factor(Fase, levels = c("Pre-pandemia", "Pandemia-Transicion", "Nueva-Normalidad")),
    Dummy_Pandemia   = ifelse(Fase == "Pandemia-Transicion", 1L, 0L),
    Dummy_Normalidad = ifelse(Fase == "Nueva-Normalidad", 1L, 0L)
  ) %>%
  select(-Fecha)

# --- Verificar continuidad ---
cat("\n── Verificando continuidad de la serie agregada...\n")
ts_check <- tsibble(
  fecha = yearmonth(paste(df_serie_2014$Ano, df_serie_2014$Mes, sep = "-")),
  index = fecha
)
n_gaps <- sum(has_gaps(ts_check)$.gaps)
if (n_gaps == 0) {
  cat("   ✓ Serie continua sin huecos\n")
} else {
  cat(sprintf("   ⚠ ATENCIÓN: %d hueco(s) detectados\n", n_gaps))
}

# --- Diagnóstico ---
cat(sprintf("  Período: %d-%02d a %d-%02d (%d meses)\n",
            min(df_serie_2014$Ano), min(df_serie_2014$Mes[df_serie_2014$Ano == min(df_serie_2014$Ano)]),
            max(df_serie_2014$Ano), max(df_serie_2014$Mes[df_serie_2014$Ano == max(df_serie_2014$Ano)]),
            nrow(df_serie_2014)))
cat(sprintf("  Cuentas únicas: %d\n", n_distinct(df_detalle_2014$Cuenta)))
cat(sprintf("  Temperatura media: %.2f °C (rango: %.2f – %.2f)\n",
            mean(df_serie_2014$Temperatura, na.rm = TRUE),
            min(df_serie_2014$Temperatura, na.rm = TRUE),
            max(df_serie_2014$Temperatura, na.rm = TRUE)))

# --- Exportar Bloque A ---
cat("\n── Exportando Bloque A...\n")
write_csv(df_detalle_2014, here("data", "processed", "Detalle_Cuenta_Desde2014.csv"))
write_csv(df_serie_2014,   here("data", "processed", "Serie_Sede_Desde2014.csv"))
cat("   ✓ Detalle_Cuenta_Desde2014.csv\n")
cat("   ✓ Serie_Sede_Desde2014.csv\n")

# =============================================================================
# EXPLORACIÓN VISUAL
# =============================================================================
cat("\n═══════════════════════════════════════════════════\n")
cat("  EXPLORACIÓN VISUAL — SERIES DESDE 2014\n")
cat("═══════════════════════════════════════════════════\n")

# Paleta de colores para las fases
colores_fase <- c("Pre-pandemia" = "#2196F3",
                  "Pandemia-Transicion" = "#FF5722",
                  "Nueva-Normalidad" = "#4CAF50")

# Preparar datos con fecha para graficar
df_plot_detalle <- df_detalle_2014 %>%
  mutate(Fecha = make_date(Ano, Mes, 1))

df_plot_serie <- df_serie_2014 %>%
  mutate(Fecha = make_date(Ano, Mes, 1))

# Fechas de corte para las bandas verticales
fecha_pandemia    <- as.Date("2020-03-01")
fecha_normalidad  <- as.Date("2023-07-01")

# ─────────────────────────────────────────────────────────────────────────────
# Gráfica 1: Series individuales de Energía Activa por cuenta
# ─────────────────────────────────────────────────────────────────────────────
cat("── Generando gráfica 1: Series individuales Activa por cuenta...\n")

p_exp1 <- ggplot(df_plot_detalle, aes(x = Fecha, y = Activa, color = Fase)) +
  geom_line(linewidth = 0.5) +
  geom_vline(xintercept = fecha_pandemia, linetype = "dashed", color = "gray40", linewidth = 0.4) +
  geom_vline(xintercept = fecha_normalidad, linetype = "dashed", color = "gray40", linewidth = 0.4) +
  facet_wrap(~ Nombre_Cuenta, scales = "free_y", ncol = 1) +
  scale_color_manual(values = colores_fase) +
  labs(title = "Energía Activa (kWh) por Cuenta — Sede Central",
       subtitle = "Líneas verticales: inicio de Pandemia (Mar 2020) y Nueva Normalidad (Jul 2023)",
       x = "Fecha", y = "Activa (kWh)", color = "Fase") +
  theme_minimal() +
  theme(legend.position = "bottom", strip.text = element_text(face = "bold"))

ggsave(file.path(plot_dir, "Exp_01_Activa_por_cuenta.png"), plot = p_exp1, width = 10, height = 12)
if (mostrar_plots) print(p_exp1)

# ─────────────────────────────────────────────────────────────────────────────
# Gráfica 2: Series individuales de Energía Reactiva por cuenta
# ─────────────────────────────────────────────────────────────────────────────
cat("── Generando gráfica 2: Series individuales Reactiva por cuenta...\n")

p_exp2 <- ggplot(df_plot_detalle, aes(x = Fecha, y = Reactiva, color = Fase)) +
  geom_line(linewidth = 0.5) +
  geom_vline(xintercept = fecha_pandemia, linetype = "dashed", color = "gray40", linewidth = 0.4) +
  geom_vline(xintercept = fecha_normalidad, linetype = "dashed", color = "gray40", linewidth = 0.4) +
  facet_wrap(~ Nombre_Cuenta, scales = "free_y", ncol = 1) +
  scale_color_manual(values = colores_fase) +
  labs(title = "Energía Reactiva (kVArh) por Cuenta — Sede Central",
       subtitle = "Líneas verticales: inicio de Pandemia (Mar 2020) y Nueva Normalidad (Jul 2023)",
       x = "Fecha", y = "Reactiva (kVArh)", color = "Fase") +
  theme_minimal() +
  theme(legend.position = "bottom", strip.text = element_text(face = "bold"))

ggsave(file.path(plot_dir, "Exp_02_Reactiva_por_cuenta.png"), plot = p_exp2, width = 10, height = 12)
if (mostrar_plots) print(p_exp2)

# ─────────────────────────────────────────────────────────────────────────────
# Gráfica 3: Serie agregada Sede Central — Activa y Reactiva
# ─────────────────────────────────────────────────────────────────────────────
cat("── Generando gráfica 3: Serie agregada Sede Central...\n")

p_exp3a <- ggplot(df_plot_serie, aes(x = Fecha, y = Activa_Total, color = Fase)) +
  geom_line(linewidth = 0.6) +
  geom_vline(xintercept = fecha_pandemia, linetype = "dashed", color = "gray40", linewidth = 0.4) +
  geom_vline(xintercept = fecha_normalidad, linetype = "dashed", color = "gray40", linewidth = 0.4) +
  scale_color_manual(values = colores_fase) +
  labs(title = "Energía Activa Total — Sede Central",
       x = NULL, y = "Activa (kWh)", color = "Fase") +
  theme_minimal() +
  theme(legend.position = "none")

p_exp3b <- ggplot(df_plot_serie, aes(x = Fecha, y = Reactiva_Total, color = Fase)) +
  geom_line(linewidth = 0.6) +
  geom_vline(xintercept = fecha_pandemia, linetype = "dashed", color = "gray40", linewidth = 0.4) +
  geom_vline(xintercept = fecha_normalidad, linetype = "dashed", color = "gray40", linewidth = 0.4) +
  scale_color_manual(values = colores_fase) +
  labs(title = "Energía Reactiva Total — Sede Central",
       x = "Fecha", y = "Reactiva (kVArh)", color = "Fase") +
  theme_minimal() +
  theme(legend.position = "bottom")

p_exp3 <- p_exp3a / p_exp3b +
  plot_annotation(title = "Series Agregadas de Consumo — Sede Central USCO",
                  subtitle = "Líneas verticales: Pandemia (Mar 2020) | Nueva Normalidad (Jul 2023)")

ggsave(file.path(plot_dir, "Exp_03_Serie_Agregada.png"), plot = p_exp3, width = 10, height = 7)
if (mostrar_plots) print(p_exp3)

# ─────────────────────────────────────────────────────────────────────────────
# Gráfica 4: Excedente de Reactiva agregado
# ─────────────────────────────────────────────────────────────────────────────
cat("── Generando gráfica 4: Excedente de Reactiva agregado...\n")

p_exp4 <- ggplot(df_plot_serie, aes(x = Fecha, y = Excedente_Total, fill = Fase)) +
  geom_col(width = 25) +
  geom_hline(yintercept = 0, color = "gray30", linewidth = 0.3) +
  geom_vline(xintercept = fecha_pandemia, linetype = "dashed", color = "gray40", linewidth = 0.4) +
  geom_vline(xintercept = fecha_normalidad, linetype = "dashed", color = "gray40", linewidth = 0.4) +
  scale_fill_manual(values = colores_fase) +
  labs(title = "Excedente de Energía Reactiva Total — Sede Central",
       subtitle = "Exceso sobre el umbral CREG (R/A > 0.4843)",
       x = "Fecha", y = "Excedente (kVArh)", fill = "Fase") +
  theme_minimal() +
  theme(legend.position = "bottom")

ggsave(file.path(plot_dir, "Exp_04_Excedente_Reactiva.png"), plot = p_exp4, width = 10, height = 5)
if (mostrar_plots) print(p_exp4)

# ─────────────────────────────────────────────────────────────────────────────
# Gráfica 5: Pago Total Sede en el tiempo
# ─────────────────────────────────────────────────────────────────────────────
cat("── Generando gráfica 5: Pago Total Sede...\n")

p_exp5 <- ggplot(df_plot_serie, aes(x = Fecha, y = Pago_Total_Sede / 1e6, color = Fase)) +
  geom_line(linewidth = 0.6) +
  geom_point(size = 0.8, alpha = 0.6) +
  geom_vline(xintercept = fecha_pandemia, linetype = "dashed", color = "gray40", linewidth = 0.4) +
  geom_vline(xintercept = fecha_normalidad, linetype = "dashed", color = "gray40", linewidth = 0.4) +
  scale_color_manual(values = colores_fase) +
  scale_y_continuous(labels = scales::comma_format(suffix = " M")) +
  labs(title = "Pago Total Mensual — Sede Central USCO",
       subtitle = "Valores en millones de COP",
       x = "Fecha", y = "Pago (millones COP)", color = "Fase") +
  theme_minimal() +
  theme(legend.position = "bottom")

ggsave(file.path(plot_dir, "Exp_05_Pago_Total_Sede.png"), plot = p_exp5, width = 10, height = 5)
if (mostrar_plots) print(p_exp5)

# ─────────────────────────────────────────────────────────────────────────────
# Gráfica 6: Boxplots comparativos por Fase
# ─────────────────────────────────────────────────────────────────────────────
cat("── Generando gráfica 6: Boxplots por Fase...\n")

p_exp6a <- ggplot(df_plot_serie, aes(x = Fase, y = Activa_Total, fill = Fase)) +
  geom_boxplot(alpha = 0.7, show.legend = FALSE) +
  scale_fill_manual(values = colores_fase) +
  labs(title = "Activa Total", y = "kWh", x = NULL) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 20, hjust = 1, size = 8))

p_exp6b <- ggplot(df_plot_serie, aes(x = Fase, y = Reactiva_Total, fill = Fase)) +
  geom_boxplot(alpha = 0.7, show.legend = FALSE) +
  scale_fill_manual(values = colores_fase) +
  labs(title = "Reactiva Total", y = "kVArh", x = NULL) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 20, hjust = 1, size = 8))

p_exp6c <- ggplot(df_plot_serie, aes(x = Fase, y = Pago_Total_Sede / 1e6, fill = Fase)) +
  geom_boxplot(alpha = 0.7, show.legend = FALSE) +
  scale_fill_manual(values = colores_fase) +
  scale_y_continuous(labels = scales::comma_format(suffix = " M")) +
  labs(title = "Pago Total Sede", y = "Millones COP", x = NULL) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 20, hjust = 1, size = 8))

p_exp6 <- p_exp6a + p_exp6b + p_exp6c +
  plot_annotation(title = "Distribución por Fase — Sede Central USCO",
                  subtitle = "Comparación de niveles de consumo y pago entre las 3 fases del análisis")

ggsave(file.path(plot_dir, "Exp_06_Boxplots_por_Fase.png"), plot = p_exp6, width = 12, height = 5)
if (mostrar_plots) print(p_exp6)

cat("\n   ✓ 6 gráficos exploratorios generados en:", plot_dir, "\n")

# =============================================================================
# BLOQUE B — Subset Nueva Normalidad (Jul 2023 – Jul 2025)
# =============================================================================
cat("\n═══════════════════════════════════════════════════\n")
cat("  BLOQUE B — SUBSET NUEVA NORMALIDAD\n")
cat("═══════════════════════════════════════════════════\n")

# --- Detalle por cuenta ---
df_detalle_nn <- df_detalle_2014 %>%
  mutate(Fecha = make_date(Ano, Mes, 1)) %>%
  filter(Fecha >= FECHA_INICIO_NN & Fecha <= FECHA_FIN_NN) %>%
  group_by(Cuenta) %>%
  mutate(Tiempo_Serie = Tiempo - min(Tiempo)) %>%
  ungroup() %>%
  select(-Fecha)

# --- Serie agregada ---
df_serie_nn <- df_detalle_nn %>%
  group_by(Ano, Mes, Tiempo) %>%
  summarise(
    Activa_Total       = sum(Activa,    na.rm = TRUE),
    Reactiva_Total     = sum(Reactiva,  na.rm = TRUE),
    Excedente_Total    = sum(Excedente, na.rm = TRUE),
    Pago_Total_Sede    = sum(Pago,      na.rm = TRUE),
    Cuentas_Pagadas    = sum(!is.na(Pago) & Pago > 0),
    Cuentas_Incumplen  = sum(Cumple == "No", na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(
    Sede_Incumple  = ifelse(Cuentas_Incumplen > 0, 1L, 0L),
    Tiempo_Serie   = Tiempo - min(Tiempo),
    Vacaciones     = ifelse(Mes %in% c(1, 6, 7, 12), 1L, 0L)
  ) %>%
  arrange(Ano, Mes)

# --- Diagnóstico ---
cat(sprintf("  Período: %s a %s (%d meses)\n",
            format(FECHA_INICIO_NN, "%Y-%m"), format(FECHA_FIN_NN, "%Y-%m"),
            nrow(df_serie_nn)))
cat(sprintf("  Cuentas: %d\n", n_distinct(df_detalle_nn$Cuenta)))

# --- Exportar Bloque B ---
cat("\n── Exportando Bloque B...\n")
write_csv(df_detalle_nn, here("data", "processed", "Detalle_Cuenta_NuevaNormalidad.csv"))
write_csv(df_serie_nn,   here("data", "processed", "Serie_Sede_NuevaNormalidad.csv"))
cat("   ✓ Detalle_Cuenta_NuevaNormalidad.csv\n")
cat("   ✓ Serie_Sede_NuevaNormalidad.csv\n")

cat("\nProceso completado exitosamente.\n")
