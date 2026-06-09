# =============================================================================
# SCRIPT 08: Exportar Tablas APA como Imágenes PNG
# =============================================================================
# Propósito: Generar imágenes PNG de alta resolución de todas las tablas
#            formateadas con estilo APA, para ser consumidas por el documento
#            Quarto de Word (Tesis_Proyecto_Energia_USCO.qmd).
# Salida:    data/processed/plots/Tabla_*.png
# =============================================================================

paquetes <- c("readr", "dplyr", "knitr", "kableExtra", "here", "webshot2")
nuevos <- paquetes[!paquetes %in% installed.packages()[, "Package"]]
if (length(nuevos)) install.packages(nuevos, repos = "https://cran.r-project.org")

library(readr)
library(dplyr)
library(knitr)
library(kableExtra)
library(here)

# ── Rutas ────────────────────────────────────────────────────────────────────
RUTA_DATOS <- here("data", "processed")
RUTA_PLOTS <- here("data", "processed", "plots")
dir.create(RUTA_PLOTS, showWarnings = FALSE, recursive = TRUE)

UMBRAL_FP <- 0.50

# ── Función auxiliar: tabla APA (idéntica a la del Quarto HTML) ──────────────
apa_table_save <- function(df, col.names = names(df), caption = NULL,
                           nota = NULL, align = NULL, save_as = NULL, ...) {
  t <- kable(df, col.names = col.names, caption = caption,
             format = "html", align = align, row.names = FALSE, ...) |>
    kable_styling(
      bootstrap_options = c("condensed"),
      full_width        = FALSE,
      position          = "left",
      html_font         = '"Times New Roman", Times, serif'
    ) |>
    row_spec(0, bold = TRUE,
             extra_css = "border-top: 2px solid #000; border-bottom: 1px solid #000;") |>
    row_spec(nrow(df), extra_css = "border-bottom: 2px solid #000;")
  if (!is.null(nota)) {
    t <- t |> footnote(general = nota, general_title = "Nota.",
                       footnote_as_chunk = TRUE,
                       title_format      = c("italic"))
  }
  if (!is.null(save_as)) {
    save_kable(t, file = save_as, zoom = 2.5)
    cat("   \u2713 Exportada:", basename(save_as), "\n")
  }
  invisible(t)
}

cat("=== Exportando tablas como imágenes PNG ===\n\n")

# ─────────────────────────────────────────────────────────────────────────────
# TABLA 1. Resumen de la ventana de análisis
# ─────────────────────────────────────────────────────────────────────────────
df <- read_csv(file.path(RUTA_DATOS, "Serie_Sede_Desde2014.csv"), show_col_types = FALSE)
df_central <- read_csv(file.path(RUTA_DATOS, "Detalle_Cuenta_Desde2014.csv"), show_col_types = FALSE)

resumen_carga <- data.frame(
  Concepto = c("Períodos en la ventana de análisis",
               "Fecha inicio", "Fecha fin",
               "Cuentas activas",
               "Umbral normativo R/A"),
  Valor = c(as.character(nrow(df)),
            paste(min(df$Ano), formatC(min(df$Mes[df$Ano == min(df$Ano)]),
                                       width = 2, flag = "0"), sep = "-"),
            paste(max(df$Ano), formatC(max(df$Mes[df$Ano == max(df$Ano)]),
                                       width = 2, flag = "0"), sep = "-"),
            as.character(length(unique(df_central$Cuenta))),
            as.character(UMBRAL_FP))
)

apa_table_save(resumen_carga,
               col.names = c("Concepto", "Valor"),
               caption   = "Tabla 1. Resumen de los datos de la ventana de análisis",
               align     = c("l", "r"),
               save_as   = file.path(RUTA_PLOTS, "Tabla_01_Resumen_Ventana.png"))

# ─────────────────────────────────────────────────────────────────────────────
# TABLA 2. Perfil Estadístico Crudo
# ─────────────────────────────────────────────────────────────────────────────
stats_crudas <- read_csv(here("data", "processed", "Estadisticas_Crudas.csv"), show_col_types = FALSE)

apa_table_save(stats_crudas,
               col.names = c("Cuenta", "N Registros", "Media Activa", "SD Activa",
                              "% Nulos Activa", "Media Reactiva", "% Nulos Reactiva"),
               caption   = "Tabla 2. Perfil estadístico de la base de datos cruda (sin imputación)",
               align     = c("l", "c", "r", "r", "r", "r", "r"),
               save_as   = file.path(RUTA_PLOTS, "Tabla_02_Perfil_Estadistico.png"))

# ─────────────────────────────────────────────────────────────────────────────
# TABLA 3. MAPE Reactiva vs Logit
# ─────────────────────────────────────────────────────────────────────────────
df_mape <- read_csv(here("data", "processed", "MAPE_Reactiva_vs_Logit.csv"), show_col_types = FALSE)

apa_table_save(df_mape,
               caption = "Tabla 3. Comparativa de error de pronóstico: reactiva directa vs transformación logit",
               save_as = file.path(RUTA_PLOTS, "Tabla_03_MAPE_Reactiva_Logit.png"))

# ─────────────────────────────────────────────────────────────────────────────
# TABLA 4. Cumplimiento por cuenta y año
# ─────────────────────────────────────────────────────────────────────────────
df_cumplimiento_ano <- read_csv(here("data", "processed", "Cumplimiento_Cuentas_Ano.csv"), show_col_types = FALSE)

apa_table_save(
  df_cumplimiento_ano %>% select(Nombre_Cuenta, Ano, Meses_Total, Meses_Cumplen, Meses_Incumplen, Porcentaje_Cumple),
  col.names = c("Cuenta", "Año", "Meses Totales", "Cumplen", "Incumplen", "% Cumplimiento"),
  caption   = "Tabla 4. Resumen anual de cumplimiento normativo por cuenta",
  align     = c("l", "c", "c", "c", "c", "r"),
  save_as   = file.path(RUTA_PLOTS, "Tabla_04_Cumplimiento_Cuentas.png"))

# ─────────────────────────────────────────────────────────────────────────────
# TABLA 5. Comparativa de modelos (Econométricos + ML)
# ─────────────────────────────────────────────────────────────────────────────
tabla_activa <- read_csv(here("data", "processed", "Model_Comparison_ML.csv"), show_col_types = FALSE)

apa_table_save(tabla_activa,
               col.names = c("Modelo", "Especificación", "AICc", "BIC",
                              "MAE", "RMSE", "MAPE (%)", "MASE"),
               caption   = "Tabla 5. Comparativa de modelos — Energía Activa (kWh)",
               nota      = "Métricas evaluadas fuera de muestra en el período de validación (Febrero 2025 - Julio 2025, h = 1, n_test = 6). Los modelos de Machine Learning (XGBoost, ExtraTrees) no estiman AICc/BIC al ser no-paramétricos. El modelo campeón según MAPE y MASE es el SARIMA Manual.",
               align     = c("l", "l", "r", "r", "r", "r", "r", "r"),
               save_as   = file.path(RUTA_PLOTS, "Tabla_05_Comparativa_Modelos.png"))

# ─────────────────────────────────────────────────────────────────────────────
# TABLA 6. Pronóstico energía activa
# ─────────────────────────────────────────────────────────────────────────────
pronostico_activa <- data.frame(
  Mes        = c("2025-08","2025-09","2025-10","2025-11","2025-12","2026-01"),
  Punto      = c(193528, 232373, 199744, 189388, 111099, 103425),
  IC80_inf   = c(152863, 183727, 148134, 134974,  54022,  43822),
  IC80_sup   = c(234193, 281019, 251355, 243801, 168176, 163029),
  IC95_inf   = c(131337, 157975, 120813, 106170,  23807,  12270),
  IC95_sup   = c(255719, 306771, 278675, 272606, 198390, 194581)
)

apa_table_save(pronostico_activa,
               col.names = c("Mes", "Pronóstico", "IC80 inf.", "IC80 sup.",
                              "IC95 inf.", "IC95 sup."),
               caption   = "Tabla 6. Pronóstico energía activa — 6 meses (kWh)",
               nota      = "Modelo: SARIMA(0,1,2)(1,1,1)[12] ajustado desde 2014. El pronóstico inicia en Agosto 2025 debido al truncado de la serie comercial.",
               align     = c("c","r","r","r","r","r"),
               save_as   = file.path(RUTA_PLOTS, "Tabla_06_Pronostico_Activa.png"))

# ─────────────────────────────────────────────────────────────────────────────
# TABLA 7. Pronóstico R/A
# ─────────────────────────────────────────────────────────────────────────────
fc_ra <- read_csv(here("data", "processed", "RA_Forecast_Logit.csv"), show_col_types = FALSE)

apa_table_save(fc_ra,
               col.names = c("Mes", "Pronóstico R/A", "IC80 inf.", "IC80 sup.",
                              "IC95 inf.", "IC95 sup."),
               caption   = "Tabla 7. Pronóstico de relación R/A agregada — 6 meses",
               nota      = "Modelo: ARIMA(1,0,0) con media ajustado sobre la serie transformada (logit). Los valores representan la relación reactiva/activa agregada con transformación inversa (función logística).",
               align     = c("c","r","r","r","r","r"),
               save_as   = file.path(RUTA_PLOTS, "Tabla_07_Pronostico_RA.png"))

# ─────────────────────────────────────────────────────────────────────────────
# TABLA 8. Ranking excedente Nueva Normalidad
# ─────────────────────────────────────────────────────────────────────────────
df_ranking_nn <- read_csv(here("data", "processed", "Ranking_Excedente_NuevaNormalidad.csv"), show_col_types = FALSE)

apa_table_save(
  df_ranking_nn %>% select(Nombre_Cuenta, Excedente_Acumulado_kVArh, Activa_Acumulada_kWh, Reactiva_Acumulada_kVArh, Relacion_Promedio, Meses_Incumplimiento, Participacion_Excedente_Pct),
  col.names = c("Cuenta", "Excedente (kVArh)", "Activa (kWh)", "Reactiva (kVArh)", "Relación R/A Prom.", "Meses Incumplimiento", "% Participación"),
  caption   = "Tabla 8. Ranking de cuentas por excedente reactivo acumulado en Nueva Normalidad (Jul 2023 - Jul 2025)",
  align     = c("l", "r", "r", "r", "r", "c", "r"),
  save_as   = file.path(RUTA_PLOTS, "Tabla_08_Ranking_Excedente.png"))

# ─────────────────────────────────────────────────────────────────────────────
# TABLA 9. Anomalías multicapa
# ─────────────────────────────────────────────────────────────────────────────
df_anomalias <- read_csv(here("data", "processed", "Anomalias_Multicapa.csv"), show_col_types = FALSE)

df_anomalias_filtrado <- df_anomalias %>%
  filter(Anomala_Capa2 == 1L | Anomala_Capa3_Sede > 0) %>%
  select(Ano, Mes, Relacion_Sede, Residuo_ARIMA_Std, Detalle_Capas)

apa_table_save(
  df_anomalias_filtrado,
  col.names = c("Año", "Mes", "Relación R/A Sede", "Residuo Estandarizado", "Capas de Detección"),
  caption   = "Tabla 9. Períodos con anomalías estadísticas (Capa 2) o estructurales (Capa 3) detectadas",
  align     = c("c", "c", "r", "r", "l"),
  save_as   = file.path(RUTA_PLOTS, "Tabla_09_Anomalias.png"))

# ─────────────────────────────────────────────────────────────────────────────
# TABLA 10. CTER escenarios
# ─────────────────────────────────────────────────────────────────────────────
df_ct_escenarios <- read_csv(here("data", "processed", "CTER_Comparacion_Escenarios.csv"), show_col_types = FALSE)

apa_table_save(
  df_ct_escenarios %>% select(Nombre_Cuenta, Excedente_Total_kVArh, CTER_SinCorreccion, CTER_MitigacionM1, CTER_Correccion100),
  col.names = c("Cuenta", "Excedente (kVArh)", "Sin Corrección (COP)", "Mitigación M = 1 (COP)", "Corrección Total (COP)"),
  caption   = "Tabla 10. Costos acumulados de CTER en la Nueva Normalidad por escenario (Jul 2023 - Jul 2025)",
  align     = c("l", "r", "r", "r", "r"),
  save_as   = file.path(RUTA_PLOTS, "Tabla_10_CTER_Escenarios.png"))

# ─────────────────────────────────────────────────────────────────────────────
# TABLA 11. Proyección CTER mensual
# ─────────────────────────────────────────────────────────────────────────────
df_proy <- read_csv(here("data", "processed", "CTER_Proyeccion_12Meses.csv"), show_col_types = FALSE)

df_proy_sede <- df_proy %>%
  group_by(Fecha) %>%
  summarise(
    Limite_Inferior = sum(CTER_Proyectado_Mitigacion),
    Limite_Superior = sum(CTER_Proyectado_Inaccion),
    .groups = "drop"
  ) %>%
  mutate(
    Brecha = Limite_Superior - Limite_Inferior,
    Mes = format(Fecha, "%b %Y")
  ) %>%
  select(Mes, Limite_Inferior, Limite_Superior, Brecha)

apa_table_save(
  df_proy_sede,
  col.names = c("Mes", "Límite Inferior ($)", "Límite Superior ($)", "Brecha de Incertidumbre ($)"),
  caption   = "Tabla 11. Proyección mensual del CTER y riesgo tarifario (Ago 2025 - Jul 2026)",
  align     = c("l", "r", "r", "r"),
  save_as   = file.path(RUTA_PLOTS, "Tabla_11_Proyeccion_CTER.png"))

cat("\n=== ¡Todas las tablas exportadas exitosamente! ===\n")
cat("Ubicación:", RUTA_PLOTS, "\n")
