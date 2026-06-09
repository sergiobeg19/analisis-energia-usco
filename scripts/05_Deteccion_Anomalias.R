# =============================================================================
# SCRIPT 05: Esquema Multicapa de Detección de Anomalías
# Universidad Surcolombiana (USCO) — Sede Central
# =============================================================================
# INPUT:  data/processed/Detalle_Cuenta_Desde2014.csv
#         data/processed/Serie_Sede_Desde2014.csv
#
# OUTPUT: data/processed/Anomalias_Multicapa.csv
#         data/processed/plots/Anomalias_Deteccion_Multicapa.png
# =============================================================================

library(dplyr)
library(readr)
library(ggplot2)
library(here)
library(forecast)
library(strucchange)
library(lubridate)
library(patchwork)

# ─────────────────────────────────────────────────────────────────────────────
# PARÁMETROS
# ─────────────────────────────────────────────────────────────────────────────
UMBRAL_FP <- 0.50   # Umbral normativo CREG para Niveles I y II

# Directorios de salida
RUTA_PLOTS <- here("data", "processed", "plots")
dir.create(RUTA_PLOTS, showWarnings = FALSE, recursive = TRUE)

cat("── Cargando datos procesados desde 2014...\n")
df_detalle <- read_csv(here("data", "processed", "Detalle_Cuenta_Desde2014.csv"), show_col_types = FALSE)
df_serie   <- read_csv(here("data", "processed", "Serie_Sede_Desde2014.csv"), show_col_types = FALSE)

# =============================================================================
# CAPA 1: Criterio Normativo Determinístico (R/A > 0.50)
# =============================================================================
cat("── Procesando Capa 1 (Determinística)...\n")

df_capa1 <- df_detalle %>%
  mutate(
    Anomala_Capa1 = ifelse(Relacion > UMBRAL_FP, 1L, 0L)
  ) %>%
  select(Cuenta, Nombre_Cuenta, Ano, Mes, Relacion, Anomala_Capa1)

# =============================================================================
# CAPA 2: Criterio Estadístico (Residuos ARIMA de R/A Sede Central)
# =============================================================================
cat("── Procesando Capa 2 (Estadística - ARIMA de R/A Sede Central)...\n")

# Calcular relación R/A agregada mensual para Sede Central
df_ra_sede <- df_serie %>%
  mutate(
    Relacion_Sede = Reactiva_Total / Activa_Total
  ) %>%
  arrange(Ano, Mes)

# Objeto de serie de tiempo
ts_ra_sede <- ts(df_ra_sede$Relacion_Sede, start = c(df_ra_sede$Ano[1], df_ra_sede$Mes[1]), frequency = 12)

# Ajustar modelo ARIMA automático
fit_arima_ra <- auto.arima(ts_ra_sede, ic = "aicc")
cat("   ✓ Modelo auto.arima ajustado para R/A Sede:", as.character(fit_arima_ra), "\n")

# Obtener residuos y estandarizarlos (Z-score)
residuos <- residuals(fit_arima_ra)
sd_residuos <- sd(residuos)
residuos_std <- as.numeric(residuos / sd_residuos)

df_ra_sede <- df_ra_sede %>%
  mutate(
    Residuo_ARIMA = as.numeric(residuos),
    Residuo_ARIMA_Std = residuos_std,
    Anomala_Capa2 = ifelse(abs(Residuo_ARIMA_Std) > 2.5, 1L, 0L)
  )

# =============================================================================
# CAPA 3: Cambio de Régimen (Prueba de Bai-Perron para Central_2)
# =============================================================================
cat("── Procesando Capa 3 (Cambio de Régimen - Bai-Perron para Central_2)...\n")

df_c2 <- df_detalle %>%
  filter(Nombre_Cuenta == "Central_2") %>%
  arrange(Ano, Mes)

# Serie de Central_2
ts_c2 <- ts(df_c2$Relacion, start = c(df_c2$Ano[1], df_c2$Mes[1]), frequency = 12)

# Ejecutar prueba de Bai-Perron usando breakpoints
# Relacion ~ 1 busca cambios estructurales en la media de la relación R/A
bp_c2 <- breakpoints(ts_c2 ~ 1)
cat("   ✓ Puntos de quiebre estructural detectados en Central_2 (índices):", bp_c2$breakpoints, "\n")

# Identificar los meses correspondientes a los quiebres
meses_quiebre <- integer(nrow(df_c2))
if (!all(is.na(bp_c2$breakpoints))) {
  meses_quiebre[bp_c2$breakpoints] <- 1L
}

df_c2 <- df_c2 %>%
  mutate(
    Anomala_Capa3 = meses_quiebre
  )

# =============================================================================
# CONSOLIDACIÓN Y EXPORTACIÓN
# =============================================================================
cat("── Consolidando tabla unificada de anomalías...\n")

# 1. Unificar Capa 1 y Capa 3 a nivel de cuenta/período
df_cuentas_consolidado <- df_capa1 %>%
  left_join(
    df_c2 %>% select(Cuenta, Ano, Mes, Anomala_Capa3),
    by = c("Cuenta", "Ano", "Mes")
  ) %>%
  mutate(
    Anomala_Capa3 = ifelse(is.na(Anomala_Capa3), 0L, Anomala_Capa3)
  )

# 2. Unificar Capa 2 (que está a nivel de sede agregada) y resumir Capa 1/3
df_sede_resumen <- df_cuentas_consolidado %>%
  group_by(Ano, Mes) %>%
  summarise(
    Cuentas_Incumplen_Capa1 = sum(Anomala_Capa1 == 1L, na.rm = TRUE),
    Anomala_Capa1_Sede      = ifelse(Cuentas_Incumplen_Capa1 > 0, 1L, 0L),
    Anomala_Capa3_Sede      = sum(Anomala_Capa3 == 1L, na.rm = TRUE),
    .groups = "drop"
  )

df_consolidado <- df_ra_sede %>%
  select(Ano, Mes, Activa_Total, Reactiva_Total, Relacion_Sede, Residuo_ARIMA_Std, Anomala_Capa2) %>%
  left_join(df_sede_resumen, by = c("Ano", "Mes")) %>%
  mutate(
    Anomala_Total = ifelse(Anomala_Capa1_Sede == 1L | Anomala_Capa2 == 1L | Anomala_Capa3_Sede > 0, 1L, 0L),
    Detalle_Capas = case_when(
      Anomala_Capa1_Sede == 1 & Anomala_Capa2 == 1 & Anomala_Capa3_Sede > 0 ~ "Capa 1 + Capa 2 + Capa 3",
      Anomala_Capa1_Sede == 1 & Anomala_Capa2 == 1 ~ "Capa 1 + Capa 2",
      Anomala_Capa1_Sede == 1 & Anomala_Capa3_Sede > 0 ~ "Capa 1 + Capa 3",
      Anomala_Capa2 == 1 & Anomala_Capa3_Sede > 0 ~ "Capa 2 + Capa 3",
      Anomala_Capa1_Sede == 1 ~ "Capa 1 (Normativa)",
      Anomala_Capa2 == 1 ~ "Capa 2 (Estadística ARIMA)",
      Anomala_Capa3_Sede > 0 ~ "Capa 3 (Quiebre Bai-Perron)",
      TRUE ~ "Normal"
    )
  )

write_csv(df_consolidado, here("data", "processed", "Anomalias_Multicapa.csv"))
cat("   ✓ Tabla consolidada de anomalías guardada en: data/processed/Anomalias_Multicapa.csv\n")

# =============================================================================
# GRÁFICO EXPLICATIVO
# =============================================================================
cat("── Generando gráficos de anomalías...\n")

df_plot <- df_consolidado %>%
  mutate(Fecha = make_date(Ano, Mes, 1))

# Gráfico 1: Relación R/A con Capa 2 y Capa 3 marcadas
p_anomalias_sede <- ggplot(df_plot, aes(x = Fecha, y = Relacion_Sede)) +
  geom_line(color = "gray40", linewidth = 0.5) +
  geom_hline(yintercept = UMBRAL_FP, linetype = "dashed", color = "red", linewidth = 0.7) +
  geom_point(data = filter(df_plot, Anomala_Capa2 == 1L), aes(color = "Capa 2 (Residuos ARIMA)"), size = 2) +
  geom_vline(data = filter(df_plot, Anomala_Capa3_Sede > 0), aes(xintercept = Fecha, color = "Capa 3 (Quiebre Bai-Perron)"), linetype = "dotted", linewidth = 1) +
  scale_color_manual(values = c("Capa 2 (Residuos ARIMA)" = "darkorange", "Capa 3 (Quiebre Bai-Perron)" = "purple")) +
  labs(
    title = "Monitoreo de Anomalías del Factor de Potencia — Sede Central USCO",
    subtitle = paste("Línea roja discontinua: Límite normativo CREG (R/A =", UMBRAL_FP, ")"),
    x = "Fecha",
    y = "Relación R/A Agregada Sede",
    color = "Capa de Detección"
  ) +
  theme_minimal() +
  theme(legend.position = "bottom", plot.title = element_text(face = "bold", size = 12))

# Gráfico 2: Residuos Estandarizados ARIMA (Capa 2)
p_residuos <- ggplot(df_plot, aes(x = Fecha, y = Residuo_ARIMA_Std)) +
  geom_hline(yintercept = c(-2.5, 2.5), linetype = "dashed", color = "darkorange", linewidth = 0.6) +
  geom_line(color = "#1F77B4", linewidth = 0.5) +
  geom_point(data = filter(df_plot, Anomala_Capa2 == 1L), color = "darkorange", size = 2) +
  labs(
    title = "Capa 2 — Residuos Estandarizados del Modelo ARIMA R/A",
    subtitle = "Líneas discontinuas muestran límites de control ±2.5σ",
    x = "Fecha",
    y = "Residuos Estandarizados"
  ) +
  theme_minimal() +
  theme(plot.title = element_text(face = "bold", size = 11))

# Unir gráficos usando patchwork
p_final <- p_anomalias_sede / p_residuos + plot_layout(heights = c(2, 1))
ggsave(file.path(RUTA_PLOTS, "Anomalias_Deteccion_Multicapa.png"), plot = p_final, width = 10, height = 8)
cat("   ✓ Gráfico de anomalías guardado en: data/processed/plots/Anomalias_Deteccion_Multicapa.png\n\n")

# Imprimir resumen de meses anómalos detectados
cat("══════════════════════════════════════════════════════════════════════════════\n")
cat("   RESUMEN DE DETECCIONES DE ANOMALÍAS POR CAPA\n")
cat("══════════════════════════════════════════════════════════════════════════════\n")
cat(sprintf("   Meses totales analizados        : %d\n", nrow(df_consolidado)))
cat(sprintf("   Meses con anomalía Capa 1       : %d\n", sum(df_consolidado$Anomala_Capa1_Sede)))
cat(sprintf("   Meses con anomalía Capa 2       : %d\n", sum(df_consolidado$Anomala_Capa2)))
cat(sprintf("   Meses con anomalía Capa 3       : %d\n", sum(df_consolidado$Anomala_Capa3_Sede)))
cat(sprintf("   Total meses anómalos únicos     : %d\n", sum(df_consolidado$Anomala_Total)))
cat("══════════════════════════════════════════════════════════════════════════════\n\n")

# Mostrar meses con Capa 2 o Capa 3
cat("   Meses detectados por Capa 2 (Estadística ARIMA) o Capa 3 (Quiebre estructural):\n")
print(df_consolidado %>%
        filter(Anomala_Capa2 == 1L | Anomala_Capa3_Sede > 0) %>%
        select(Ano, Mes, Relacion_Sede, Residuo_ARIMA_Std, Detalle_Capas))
cat("══════════════════════════════════════════════════════════════════════════════\n\n")

cat("Script 05 completado exitosamente.\n")
