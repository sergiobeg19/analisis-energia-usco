# =============================================================================
# SCRIPT 03: Análisis Individual por Cuenta y Reconstrucción del Factor M
# Universidad Surcolombiana (USCO) — Sede Central
# =============================================================================
# INPUT:  data/processed/Detalle_Cuenta_Periodo.csv
#
# OUTPUT: data/processed/Cumplimiento_Cuentas_Ano.csv
#         data/processed/Central2_FactorM.csv
#         data/processed/Ranking_Excedente_NuevaNormalidad.csv
#         data/processed/plots/Cuentas_RA_TimeSeries.png
#         data/processed/plots/Central2_FactorM_Trajectory.png
# =============================================================================

library(dplyr)
library(readr)
library(ggplot2)
library(here)
library(lubridate)
library(tidyr)

# ─────────────────────────────────────────────────────────────────────────────
# PARÁMETROS Y CONFIGURACIÓN
# ─────────────────────────────────────────────────────────────────────────────
UMBRAL_FP        <- 0.50   # Umbral normativo CREG para Niveles I y II (R/A <= 0.50)
FECHA_INICIO_NN  <- make_date(2023, 7, 1)
FECHA_FIN_NN     <- make_date(2025, 7, 31)

# Rutas de archivos
RUTA_DETALLE_RAW <- here("data", "processed", "Detalle_Cuenta_Periodo.csv")
RUTA_PLOTS       <- here("data", "processed", "plots")
dir.create(RUTA_PLOTS, showWarnings = FALSE, recursive = TRUE)

# Cargar datos
cat("── Cargando datos de consumo detallado por cuenta...\n")
df_detalle <- read_csv(RUTA_DETALLE_RAW, show_col_types = FALSE)

# =============================================================================
# BLOQUE 1: Tabla de Cumplimiento por Cuenta y Año (Cumple == "Sí")
# =============================================================================
cat("── Generando Tabla 1: Cumplimiento por cuenta y año...\n")

df_cumplimiento <- df_detalle %>%
  group_by(Cuenta, Nombre_Cuenta, Ano) %>%
  summarise(
    Meses_Total      = n(),
    Meses_Cumplen    = sum(Cumple == "Sí", na.rm = TRUE),
    Meses_Incumplen  = sum(Cumple == "No", na.rm = TRUE),
    Porcentaje_Cumple = round(Meses_Cumplen / Meses_Total * 100, 1),
    .groups = "drop"
  )

write_csv(df_cumplimiento, here("data", "processed", "Cumplimiento_Cuentas_Ano.csv"))
cat("   ✓ Tabla de cumplimiento guardada en: data/processed/Cumplimiento_Cuentas_Ano.csv\n")

# =============================================================================
# BLOQUE 2: Serie Temporal de Relación R/A por Cuenta
# =============================================================================
cat("── Generando Gráfica 1: Serie temporal de R/A por cuenta...\n")

df_plot <- df_detalle %>%
  mutate(Fecha = make_date(Ano, Mes, 1))

p_ra <- ggplot(df_plot, aes(x = Fecha, y = Relacion, color = Nombre_Cuenta)) +
  geom_line(linewidth = 0.6, show.legend = FALSE) +
  geom_hline(yintercept = UMBRAL_FP, linetype = "dashed", color = "red", linewidth = 0.8) +
  facet_wrap(~ Nombre_Cuenta, scales = "free_y", ncol = 1) +
  labs(
    title = "Relación Reactiva / Activa (R/A) por Cuenta — Sede Central",
    subtitle = paste("Línea roja discontinua: Límite normativo CREG (R/A =", UMBRAL_FP, ")"),
    x = "Fecha",
    y = "Relación R/A"
  ) +
  theme_minimal() +
  theme(
    strip.text = element_text(face = "bold", size = 10),
    panel.grid.minor = element_blank(),
    plot.title = element_text(face = "bold", size = 14)
  )

ggsave(file.path(RUTA_PLOTS, "Cuentas_RA_TimeSeries.png"), plot = p_ra, width = 10, height = 12)
cat("   ✓ Gráfico R/A por cuenta guardado en: data/processed/plots/Cuentas_RA_TimeSeries.png\n")

# =============================================================================
# BLOQUE 3: Reconstrucción de la Trayectoria del Factor M para Central_2
# =============================================================================
cat("── Reconstruyendo trayectoria del Factor M para Central_2 (CREG 199/2019)...\n")

# Filtrar Central_2 cronológicamente
df_c2 <- df_detalle %>%
  filter(Nombre_Cuenta == "Central_2") %>%
  arrange(Ano, Mes) %>%
  mutate(Fecha = make_date(Ano, Mes, 1))

# Inicializar vectores de estado
n_periodos <- nrow(df_c2)
M_vector <- numeric(n_periodos)
nocumple_acumulado <- 0
consec_cumple <- 0

for (i in 1:n_periodos) {
  # Regla transitoria: Cualquier mes anterior a enero de 2021 tiene M = 1
  if (df_c2$Fecha[i] < as.Date("2021-01-01")) {
    M_val <- 1
    nocumple_acumulado <- 0
    consec_cumple <- 0
  } else {
    # El conteo formal y acumulación inicia en enero de 2021
    # Verificar si el mes actual es de incumplimiento (Relación R/A > Umbral)
    if (df_c2$Relacion[i] > UMBRAL_FP) {
      consec_cumple <- 0
      nocumple_acumulado <- nocumple_acumulado + 1
      
      # Aplicar la regla de gradualidad del factor M
      if (nocumple_acumulado <= 12) {
        M_val <- 1
      } else {
        meses_despues_12 <- nocumple_acumulado - 12
        if (meses_despues_12 <= 5) {
          # Incrementa de 1 en 1 hasta alcanzar M = 6 (meses 13 a 17 después de iniciar)
          M_val <- 1 + meses_despues_12
        } else {
          # Se alcanzó M = 6 en el mes de exceso 17. Permanece en 6 por 12 meses (meses 17 a 28)
          meses_en_6 <- nocumple_acumulado - 17 + 1
          if (meses_en_6 <= 12) {
            M_val <- 6
          } else {
            # Transcurrido un año en M = 6, sube mensualmente hasta M = 12
            M_val <- min(6 + (meses_en_6 - 12), 12)
          }
        }
      }
    } else {
      # Mes de cumplimiento
      consec_cumple <- consec_cumple + 1
      if (consec_cumple >= 3) {
        # Reiniciar estado
        nocumple_acumulado <- 0
        M_val <- 1
      } else {
        # Cumplimiento temporal (1 o 2 meses). No cuenta como mes de exceso, 
        # pero no reinicia la penalización. Se mantiene el último factor activo.
        M_val <- if (i > 1) M_vector[i - 1] else 1
      }
    }
  }
  M_vector[i] <- M_val
}

df_c2$Factor_M <- M_vector

# Guardar resultados de Central_2
df_c2_export <- df_c2 %>%
  select(Cuenta, Nombre_Cuenta, Ano, Mes, Activa, Reactiva, Relacion, Cumple, Excedente, Factor_M)

write_csv(df_c2_export, here("data", "processed", "Central2_FactorM.csv"))
cat("   ✓ Trayectoria de Central_2 exportada a: data/processed/Central2_FactorM.csv\n")

# Gráfico de trayectoria de M
p_m <- ggplot(df_c2, aes(x = Fecha, y = Factor_M)) +
  geom_step(color = "#1F77B4", linewidth = 1) +
  geom_point(color = "#1F77B4", size = 1.5) +
  scale_y_continuous(breaks = 1:12, limits = c(1, 12)) +
  labs(
    title = "Trayectoria Histórica del Factor Multiplicador M — Central_2",
    subtitle = "Reconstrucción bajo las reglas CREG 199/2019 (escala 1 a 12)",
    x = "Fecha",
    y = "Factor M"
  ) +
  theme_minimal() +
  theme(
    panel.grid.minor = element_blank(),
    plot.title = element_text(face = "bold", size = 12)
  )

ggsave(file.path(RUTA_PLOTS, "Central2_FactorM_Trajectory.png"), plot = p_m, width = 10, height = 5)
cat("   ✓ Gráfico de Factor M guardado en: data/processed/plots/Central2_FactorM_Trajectory.png\n")


# =============================================================================
# BLOQUE 4: Ranking de Cuentas por Excedente Acumulado (Nueva Normalidad)
# =============================================================================
cat("── Generando Ranking de Cuentas para el período de Nueva Normalidad (Jul 2023 - Jul 2025)...\n")

df_nn <- df_detalle %>%
  mutate(Fecha = make_date(Ano, Mes, 1)) %>%
  filter(Fecha >= FECHA_INICIO_NN & Fecha <= FECHA_FIN_NN)

df_ranking <- df_nn %>%
  group_by(Cuenta, Nombre_Cuenta) %>%
  summarise(
    Excedente_Acumulado_kVArh = sum(Excedente, na.rm = TRUE),
    Activa_Acumulada_kWh      = sum(Activa, na.rm = TRUE),
    Reactiva_Acumulada_kVArh  = sum(Reactiva, na.rm = TRUE),
    Relacion_Promedio         = mean(Relacion, na.rm = TRUE),
    Meses_Incumplimiento      = sum(Cumple == "No", na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(desc(Excedente_Acumulado_kVArh)) %>%
  mutate(
    Participacion_Excedente_Pct = round(Excedente_Acumulado_kVArh / sum(Excedente_Acumulado_kVArh) * 100, 2)
  )

write_csv(df_ranking, here("data", "processed", "Ranking_Excedente_NuevaNormalidad.csv"))
cat("   ✓ Ranking de excedentes guardado en: data/processed/Ranking_Excedente_NuevaNormalidad.csv\n\n")

# Imprimir ranking en consola
cat("══════════════════════════════════════════════════════════════════════════════\n")
cat("   RANKING DE CUENTAS POR EXCEDENTE REACTIVO ACUMULADO (NUEVA NORMALIDAD)\n")
cat("══════════════════════════════════════════════════════════════════════════════\n")
print(df_ranking)
cat("══════════════════════════════════════════════════════════════════════════════\n\n")

cat("Script completado exitosamente.\n")
