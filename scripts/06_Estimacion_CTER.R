# =============================================================================
# SCRIPT 06: Estimación Económica del Cargo por Transporte de Energía Reactiva (CTER)
# Universidad Surcolombiana (USCO) — Sede Central
# =============================================================================
# INPUT:  data/processed/Detalle_Cuenta_Periodo.csv
#         data/processed/Central2_FactorM.csv
#
# OUTPUT: data/processed/CTER_Comparacion_Escenarios.csv
#         data/processed/CTER_Proyeccion_12Meses.csv
#         data/processed/plots/CTER_Comparacion_Escenarios.png
#         data/processed/plots/CTER_Proyeccion_12Meses.png
# =============================================================================

library(dplyr)
library(readr)
library(ggplot2)
library(here)
library(lubridate)
library(tidyr)

# ─────────────────────────────────────────────────────────────────────────────
# CONFIGURACIÓN Y PARÁMETROS
# ─────────────────────────────────────────────────────────────────────────────
FECHA_INICIO_NN <- make_date(2023, 7, 1)
FECHA_FIN_NN    <- make_date(2025, 7, 31)

# Rutas de salida
RUTA_PLOTS <- here("data", "processed", "plots")
dir.create(RUTA_PLOTS, showWarnings = FALSE, recursive = TRUE)

cat("── Cargando datos de consumo y factor M...\n")
df_detalle <- read_csv(here("data", "processed", "Detalle_Cuenta_Periodo.csv"), show_col_types = FALSE)
df_c2_m    <- read_csv(here("data", "processed", "Central2_FactorM.csv"), show_col_types = FALSE)

# =============================================================================
# BLOQUE 1: Preparación de Datos Históricos con Cargos D y Factor M
# =============================================================================
cat("── Preparando tarifas D y factores M por cuenta...\n")

# Extraer el factor M de Central_2
df_m_c2_join <- df_c2_m %>%
  select(Ano, Mes, Factor_M)

df_economico <- df_detalle %>%
  mutate(
    Fecha = make_date(Ano, Mes, 1),
    # Asignar D: 82 antes de pandemia (marzo 2020), 130 de ahí en adelante
    D = ifelse(Fecha < make_date(2020, 3, 1), 82, 130)
  ) %>%
  left_join(df_m_c2_join, by = c("Ano", "Mes")) %>%
  mutate(
    # Para Central_2 usamos el M reconstruido; para las demás asumimos M = 1
    Factor_M = ifelse(Nombre_Cuenta == "Central_2", replace_na(Factor_M, 1), 1)
  )

# =============================================================================
# BLOQUE 2: Evaluación de Escenarios en la Nueva Normalidad (Jul 2023 - Jul 2025)
# =============================================================================
cat("── Evaluando escenarios económicos para el período de Nueva Normalidad...\n")

df_nn <- df_economico %>%
  filter(Fecha >= FECHA_INICIO_NN & Fecha <= FECHA_FIN_NN) %>%
  mutate(
    CTER_S1_SinCorreccion = Excedente * D * Factor_M,
    CTER_S2_MitigacionM1  = Excedente * D * 1,
    CTER_S3_Correccion100 = 0
  )

# Resumir acumulado por cuenta
df_escenarios_resumen <- df_nn %>%
  group_by(Cuenta, Nombre_Cuenta) %>%
  summarise(
    Excedente_Total_kVArh = sum(Excedente, na.rm = TRUE),
    CTER_SinCorreccion    = sum(CTER_S1_SinCorreccion, na.rm = TRUE),
    CTER_MitigacionM1     = sum(CTER_S2_MitigacionM1, na.rm = TRUE),
    CTER_Correccion100    = sum(CTER_S3_Correccion100, na.rm = TRUE),
    Ahorro_Potencial_COP  = CTER_SinCorreccion - CTER_Correccion100,
    Ahorro_Por_Mitigar_COP = CTER_SinCorreccion - CTER_MitigacionM1,
    .groups = "drop"
  )

write_csv(df_escenarios_resumen, here("data", "processed", "CTER_Comparacion_Escenarios.csv"))
cat("   ✓ Comparativa de escenarios guardada en: data/processed/CTER_Comparacion_Escenarios.csv\n")

# Gráfico de barras comparativo
df_plot_escenarios <- df_escenarios_resumen %>%
  select(Nombre_Cuenta, CTER_SinCorreccion, CTER_MitigacionM1, CTER_Correccion100) %>%
  pivot_longer(
    cols = starts_with("CTER_"),
    names_to = "Escenario",
    values_to = "Costo_COP"
  ) %>%
  mutate(
    Escenario = case_when(
      Escenario == "CTER_SinCorreccion" ~ "Límite Superior (Escenario Pesimista, M Acumulado)",
      Escenario == "CTER_MitigacionM1"  ~ "Límite Inferior (Escenario Optimista, M=1)",
      Escenario == "CTER_Correccion100" ~ "Corrección Física (CTER = 0)"
    )
  )

p_escenarios <- ggplot(df_plot_escenarios, aes(x = Nombre_Cuenta, y = Costo_COP / 1e6, fill = Escenario)) +
  geom_col(position = "dodge", alpha = 0.8) +
  scale_y_continuous(labels = scales::comma_format(suffix = " M")) +
  scale_fill_manual(values = c("Límite Superior (Escenario Pesimista, M Acumulado)" = "#D62728", 
                               "Límite Inferior (Escenario Optimista, M=1)" = "#FF7F0E", 
                               "Corrección Física (CTER = 0)" = "#2CA02C")) +
  labs(
    title = "Comparación de Costos de Energía Reactiva (CTER) por Escenario",
    subtitle = "Acumulado en los 25 meses de la Nueva Normalidad (Julio 2023 - Julio 2025)",
    x = "Cuenta",
    y = "Costo Acumulado (Millones de COP)",
    fill = "Escenario"
  ) +
  theme_minimal() +
  theme(
    legend.position = "bottom",
    plot.title = element_text(face = "bold", size = 12)
  )

ggsave(file.path(RUTA_PLOTS, "CTER_Comparacion_Escenarios.png"), plot = p_escenarios, width = 10, height = 5)
cat("   ✓ Gráfico de escenarios guardado en: data/processed/plots/CTER_Comparacion_Escenarios.png\n")

# =============================================================================
# BLOQUE 3: Proyección Futura a 12 Meses (Agosto 2025 - Julio 2026)
# =============================================================================
cat("── Calculando proyección CTER a 12 meses futuros...\n")

# 1. Obtener el promedio de excedente estacional mensual de la Nueva Normalidad por cuenta
estacionalidad_excedente <- df_nn %>%
  group_by(Nombre_Cuenta, Cuenta, Mes) %>%
  summarise(
    Excedente_Promedio = mean(Excedente, na.rm = TRUE),
    .groups = "drop"
  )

# 2. Generar grid de proyección para los próximos 12 meses
meses_futuros <- seq(from = make_date(2025, 8, 1), length.out = 12, by = "month")

df_proyeccion_grid <- expand_grid(
  Fecha = meses_futuros,
  Nombre_Cuenta = unique(df_detalle$Nombre_Cuenta)
) %>%
  mutate(
    Ano = year(Fecha),
    Mes = month(Fecha)
  ) %>%
  left_join(estacionalidad_excedente, by = c("Nombre_Cuenta", "Mes")) %>%
  mutate(
    # Si es Central_2, asumimos inacción con M = 12; si no, M = 1
    Factor_M = ifelse(Nombre_Cuenta == "Central_2", 12, 1),
    D = 130, # Tarifa vigente
    Excedente_Proyectado = replace_na(Excedente_Promedio, 0),
    CTER_Proyectado_Inaccion = Excedente_Proyectado * D * Factor_M,
    CTER_Proyectado_Mitigacion = Excedente_Proyectado * D * 1,
    CTER_Proyectado_Correccion = 0
  )

write_csv(df_proyeccion_grid, here("data", "processed", "CTER_Proyeccion_12Meses.csv"))
cat("   ✓ Proyección de CTER guardada en: data/processed/CTER_Proyeccion_12Meses.csv\n")

# Gráfico de la proyección mensual agregada de la sede
df_proyeccion_sede <- df_proyeccion_grid %>%
  group_by(Fecha) %>%
  summarise(
    CTER_Sede_Inaccion = sum(CTER_Proyectado_Inaccion),
    CTER_Sede_Mitigacion = sum(CTER_Proyectado_Mitigacion),
    CTER_Sede_Correccion = sum(CTER_Proyectado_Correccion),
    .groups = "drop"
  ) %>%
  pivot_longer(
    cols = starts_with("CTER_Sede_"),
    names_to = "Escenario",
    values_to = "Costo_COP"
  ) %>%
  mutate(
    Escenario = case_when(
      Escenario == "CTER_Sede_Inaccion" ~ "Límite Superior (Escenario Pesimista, M=12)",
      Escenario == "CTER_Sede_Mitigacion" ~ "Límite Inferior (Escenario Optimista, M=1)",
      Escenario == "CTER_Sede_Correccion" ~ "Compensación Física (CTER=0)"
    )
  )

p_proyeccion <- ggplot(df_proyeccion_sede, aes(x = Fecha, y = Costo_COP / 1e6, color = Escenario, group = Escenario)) +
  geom_line(linewidth = 1) +
  geom_point(size = 2) +
  scale_y_continuous(labels = scales::comma_format(suffix = " M")) +
  scale_color_manual(values = c("Límite Superior (Escenario Pesimista, M=12)" = "#D62728", 
                                "Límite Inferior (Escenario Optimista, M=1)" = "#FF7F0E",
                                "Compensación Física (CTER=0)" = "#2CA02C")) +
  labs(
    title = "Proyección Mensual del CTER de la Sede Central USCO (Próximos 12 meses)",
    subtitle = "Rango de Incertidumbre: Límite Superior (M=12) vs. Límite Inferior (M=1) vs. Compensado",
    x = "Mes",
    y = "Costo Proyectado (Millones de COP)",
    color = "Escenario"
  ) +
  theme_minimal() +
  theme(
    legend.position = "bottom",
    plot.title = element_text(face = "bold", size = 12)
  )

ggsave(file.path(RUTA_PLOTS, "CTER_Proyeccion_12Meses.png"), plot = p_proyeccion, width = 10, height = 5)
cat("   ✓ Gráfico de proyección guardado en: data/processed/plots/CTER_Proyeccion_12Meses.png\n\n")

# Imprimir resumen consolidado
cat("══════════════════════════════════════════════════════════════════════════════\n")
cat("   RANGO DE INCERTIDUMBRE ECONÓMICA CTER — NUEVA NORMALIDAD (25 MESES)\n")
cat("══════════════════════════════════════════════════════════════════════════════\n")
df_nn_total <- df_escenarios_resumen %>%
  summarise(
    Total_SinCorreccion = sum(CTER_SinCorreccion),
    Total_Mitigacion    = sum(CTER_MitigacionM1),
    Total_Ahorro        = sum(Ahorro_Potencial_COP),
    Total_Ahorro_M1     = sum(Ahorro_Por_Mitigar_COP)
  )

cat(sprintf("   Límite Superior (Escenario Pesimista)  : $%s COP\n", format(round(df_nn_total$Total_SinCorreccion), big.mark = ",", scientific = FALSE)))
cat(sprintf("   Límite Inferior (Escenario Optimista)  : $%s COP\n", format(round(df_nn_total$Total_Mitigacion), big.mark = ",", scientific = FALSE)))
cat(sprintf("   Brecha de Incertidumbre (Diferencia)   : $%s COP\n", format(round(df_nn_total$Total_Ahorro_M1), big.mark = ",", scientific = FALSE)))
cat(sprintf("   Ahorro Máximo por corrección (S1 - S3) : $%s COP\n", format(round(df_nn_total$Total_Ahorro), big.mark = ",", scientific = FALSE)))
cat("══════════════════════════════════════════════════════════════════════════════\n\n")

# Imprimir proyección a 12 meses
cat("══════════════════════════════════════════════════════════════════════════════\n")
cat("   PROYECCIÓN DE AHORRO CTER A 12 MESES FUTUROS\n")
cat("══════════════════════════════════════════════════════════════════════════════\n")
futuro_inaccion <- sum(df_proyeccion_grid$CTER_Proyectado_Inaccion)
futuro_mitigacion <- sum(df_proyeccion_grid$CTER_Proyectado_Mitigacion)
cat(sprintf("   Proyección Límite Superior (M=12)          : $%s COP\n", format(round(futuro_inaccion), big.mark = ",", scientific = FALSE)))
cat(sprintf("   Proyección Límite Inferior (M=1)           : $%s COP\n", format(round(futuro_mitigacion), big.mark = ",", scientific = FALSE)))
cat(sprintf("   Costo proyectado a 12 meses con corrección : $0 COP\n"))
cat("══════════════════════════════════════════════════════════════════════════════\n\n")

cat("Script 06 completado exitosamente.\n")
