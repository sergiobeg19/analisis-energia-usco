# =============================================================================
# SCRIPT 01: Preparación de Datos — Consumo y Pagos de Sede Central
# Universidad Surcolombiana (USCO) — Sede Central (5 cuentas)
# =============================================================================
# INPUT:  data/raw/Consumo_Cuentas_.xlsx   (Histórico de consumo por cuenta)
#         data/raw/Pago_Cuentas.xls        (Histórico de pagos por cuenta)
#
# OUTPUT: data/processed/Detalle_Cuenta_Periodo.csv  (Tabla 1: una fila por cuenta-período)
#         data/processed/Serie_Sede_Central.csv       (Tabla 2: serie agregada por período)
#
# TABLA 1 — Detalle_Cuenta_Periodo:
#   Cuenta | Nombre_Cuenta | Ano | Mes | Tiempo | Semestre | Trimestre |
#   Activa | Reactiva | Relacion | Cumple | Cumple_bin | Excedente | Pago
#
# TABLA 2 — Serie_Sede_Central:
#   Tiempo | Ano | Mes | Activa_Total | Reactiva_Total | Excedente_Total |
#   Pago_Total_Sede | Cuentas_Pagadas | Cuentas_Incumplen | Sede_Incumple
# =============================================================================

library(readxl)
library(dplyr)
library(tidyr)
library(readr)
library(here)
library(lubridate)

# ─────────────────────────────────────────────────────────────────────────────
# PARÁMETROS
# ─────────────────────────────────────────────────────────────────────────────
UMBRAL_FP <- 0.4843   # Umbral normativo CREG 015 de 2018 (R/A <= 0.4843)

# Rutas de entrada
RUTA_CONSUMO_RAW <- here("data", "raw", "Consumo_Cuentas_.xlsx")
RUTA_PAGOS       <- here("data", "raw", "Pago_Cuentas.xls")

# Rutas de salida
RUTA_DETALLE_CSV  <- here("data", "processed", "Detalle_Cuenta_Periodo.csv")
RUTA_SERIE_CSV    <- here("data", "processed", "Serie_Sede_Central.csv")

# Cuentas de Sede Central
cuentas_central <- c(167382131,   # Central 1
                     167383918,   # Central 4
                     357154485,   # Central 5
                     847747377,   # Central 3
                     167385482)   # Central 2

nombres_central <- c("167382131" = "Central_1",
                     "167383918" = "Central_4",
                     "357154485" = "Central_5",
                     "847747377" = "Central_3",
                     "167385482" = "Central_2")

# =============================================================================
# BLOQUE 1: Cargar y filtrar solo Sede Central
# =============================================================================
cat("── Cargando consumo de cuentas...\n")

df_raw <- read_excel(RUTA_CONSUMO_RAW)

# Reemplazar NA por 0 en Consumo Real
df_raw <- df_raw %>%
  mutate(`Consumo Real` = replace_na(`Consumo Real`, 0))

# Filtrar solo las 5 cuentas de Sede Central
df_raw <- df_raw %>%
  filter(Cuenta %in% cuentas_central)

cat("   Registros Sede Central cargados:", nrow(df_raw), "\n")
cat("   Cuentas encontradas:", n_distinct(df_raw$Cuenta), "de 5 esperadas\n\n")

# Tomar el máximo por cuenta-período-tipo (evita duplicados)
df_max <- df_raw %>%
  group_by(Cuenta, Ano, Mes, `Tipo Energia`) %>%
  summarise(Consumo = max(`Consumo Real`), .groups = "drop")

# Pivotar: una fila por cuenta-período, columnas A y R
df_wide <- df_max %>%
  pivot_wider(
    names_from  = `Tipo Energia`,
    values_from = Consumo,
    values_fill = 0
  )

# =============================================================================
# BLOQUE 2: Construir métricas por cuenta-período (con imputación)
# =============================================================================

# 1. Determinar fecha de inicio individual por cuenta (primer mes con A > 0)
start_dates <- df_wide %>%
  filter(A > 0) %>%
  group_by(Cuenta) %>%
  summarise(Start_Date = min(make_date(Ano, Mes, 1)), .groups = "drop")

# 2. Crear grid secuencial completo para cada cuenta desde su Start_Date hasta Julio 2025
df_grid <- start_dates %>%
  group_by(Cuenta) %>%
  reframe(
    Fecha = seq(Start_Date, make_date(2025, 7, 1), by = "1 month")
  ) %>%
  mutate(
    Ano = year(Fecha),
    Mes = month(Fecha)
  ) %>%
  select(-Fecha)

# 3. Unir con df_wide para obtener datos observados
df_consumo_raw <- df_grid %>%
  left_join(df_wide, by = c("Cuenta", "Ano", "Mes")) %>%
  mutate(
    Activa   = replace_na(A, 0),
    Reactiva = replace_na(R, 0)
  )

# 4. Calcular medias históricas mensuales por cuenta (excluyendo ceros) para imputación
medias_mensuales <- df_consumo_raw %>%
  filter(Activa > 0) %>%
  group_by(Cuenta, Mes) %>%
  summarise(
    Mean_Activa = mean(Activa, na.rm = TRUE),
    Mean_Reactiva = mean(Reactiva, na.rm = TRUE),
    .groups = "drop"
  )

# 5. Imputar ceros intermedios y calcular métricas
df_consumo <- df_consumo_raw %>%
  left_join(medias_mensuales, by = c("Cuenta", "Mes")) %>%
  mutate(
    Es_Imputado = Activa == 0,
    Activa      = ifelse(Activa == 0, Mean_Activa, Activa),
    Reactiva    = ifelse(Es_Imputado, Mean_Reactiva, Reactiva),
    Relacion    = ifelse(Activa > 0, Reactiva / Activa, NA_real_),
    Cumple      = ifelse(Relacion <= UMBRAL_FP, "Sí", "No"),
    # Excedente de reactiva sobre el umbral normativo
    Excedente   = pmax(Reactiva - UMBRAL_FP * Activa, 0)
  ) %>%
  select(Cuenta, Ano, Mes, Activa, Reactiva, Relacion, Cumple, Excedente) %>%
  arrange(Cuenta, Ano, Mes)

cat("── Registros por cuenta-período construidos (con imputación de ceros):", nrow(df_consumo), "\n")

# =============================================================================
# BLOQUE 3: Calcular Pago individual por cuenta y Pago_Total_Sede por período
# =============================================================================
cat("── Cargando archivo de pagos...\n")

df_pagos_raw <- read_excel(RUTA_PAGOS)
colnames(df_pagos_raw) <- c("Cuenta", "Valor_Pago", "Ano", "Mes", "Valor")

# Filtrar solo cuentas de Sede Central en pagos
df_pagos_central <- df_pagos_raw %>%
  filter(Cuenta %in% cuentas_central,
         !is.na(Valor), Valor > 0)

cat("   Registros de pago Sede Central:", nrow(df_pagos_central), "\n\n")

# Pago individual: máximo por cuenta-período (evita duplicados de factura)
pago_individual <- df_pagos_central %>%
  group_by(Cuenta, Ano, Mes) %>%
  summarise(Pago = sum(Valor, na.rm = TRUE), .groups = "drop")

# Pago_Total_Sede: suma de las 5 cuentas por período
pago_sede <- pago_individual %>%
  group_by(Ano, Mes) %>%
  summarise(Pago_Total_Sede = sum(Pago, na.rm = TRUE),
            Cuentas_Pagadas = n_distinct(Cuenta),
            .groups = "drop")

# =============================================================================
# BLOQUE 4: Unir consumo + pago individual + pago sede
# =============================================================================
min_date <- make_date(min(df_consumo$Ano), min(df_consumo$Mes[df_consumo$Ano == min(df_consumo$Ano)]), 1)

df_final <- df_consumo %>%
  left_join(pago_individual, by = c("Cuenta", "Ano", "Mes")) %>%
  mutate(
    Nombre_Cuenta = nombres_central[as.character(Cuenta)],
    Cuenta        = factor(Cuenta, levels = cuentas_central),
    # Tiempo cronológico absoluto continuo desde el inicio global (May 2001)
    Tiempo        = (Ano - year(min_date)) * 12 + (Mes - month(min_date)) + 1,
    # Variables para modelo logístico
    Cumple_bin    = ifelse(Cumple == "Sí", 1L, 0L),
    Semestre      = ifelse(Mes <= 6, 1L, 2L),
    Trimestre     = ceiling(Mes / 3L)
  ) %>%
  select(Cuenta, Nombre_Cuenta, Ano, Mes, Tiempo, Semestre, Trimestre,
         Activa, Reactiva, Relacion, Cumple, Cumple_bin, Excedente, Pago)

# =============================================================================
# BLOQUE 5: Construir Tabla 2 — Serie_Sede_Central (una fila por período)
# =============================================================================

serie_sede <- df_final %>%
  group_by(Tiempo, Ano, Mes) %>%
  summarise(
    Activa_Total      = sum(Activa,          na.rm = TRUE),
    Reactiva_Total    = sum(Reactiva,        na.rm = TRUE),
    Excedente_Total   = sum(Excedente,       na.rm = TRUE),
    Cuentas_Incumplen = sum(Cumple == "No",  na.rm = TRUE),
    .groups = "drop"
  ) %>%
  left_join(pago_sede, by = c("Ano", "Mes")) %>%
  mutate(
    Sede_Incumple = ifelse(Cuentas_Incumplen > 0, 1L, 0L)
  ) %>%
  arrange(Tiempo) %>%
  select(Tiempo, Ano, Mes, Activa_Total, Reactiva_Total, Excedente_Total,
         Pago_Total_Sede, Cuentas_Pagadas, Cuentas_Incumplen, Sede_Incumple)

# =============================================================================
# BLOQUE 6: Verificación
# =============================================================================
cat("═══════════════════════════════════════════════════\n")
cat("  RESUMEN — CONSUMO SEDE CENTRAL\n")
cat("═══════════════════════════════════════════════════\n")
cat(sprintf("  TABLA 1 — filas (cuenta-período) : %d\n", nrow(df_final)))
cat(sprintf("  TABLA 2 — filas (período)        : %d\n", nrow(serie_sede)))
cat(sprintf("  Cuentas                          : %d\n", n_distinct(df_final$Cuenta)))
cat(sprintf("  Rango de años                    : %d – %d\n",
            min(df_final$Ano), max(df_final$Ano)))
cat("\n  Cumplimiento por cuenta:\n")
print(df_final %>%
        group_by(Cuenta, Nombre_Cuenta) %>%
        summarise(Periodos   = n(),
                  Cumple     = sum(Cumple == "Sí"),
                  No_Cumple  = sum(Cumple == "No"),
                  Pct_Cumple = round(Cumple / Periodos * 100, 1),
                  .groups = "drop"))
cat("\n  Primeros registros Tabla 1:\n")
print(head(df_final, 6))
cat("\n  Primeros registros Tabla 2:\n")
print(head(serie_sede, 6))
cat("═══════════════════════════════════════════════════\n\n")

# =============================================================================
# BLOQUE 7: Exportar solo CSV
# =============================================================================
cat("── Exportando archivos...\n")

dir.create(here("data", "processed"), showWarnings = FALSE, recursive = TRUE)

write_csv(df_final,   RUTA_DETALLE_CSV)
write_csv(serie_sede,  RUTA_SERIE_CSV)

cat(sprintf("   ✓ Detalle cuenta-período : %s\n", RUTA_DETALLE_CSV))
cat(sprintf("   ✓ Serie Sede Central     : %s\n", RUTA_SERIE_CSV))
cat("\nProceso completado exitosamente.\n")
