# =============================================================================
# SCRIPT 03: Filtrar período post-pandemia (2022+), enriquecer y preparar series
# Universidad Surcolombiana (USCO) — Sede Central (Enfoque Exclusivo)
# =============================================================================
# INPUT:  data/processed/Consumo_Central.csv (Detalle por cuenta de Sede Central)
#         data/raw/Datos_Temperatura_Media.xlsx (Temperatura mensual)
#
# OUTPUT: data/processed/Central_2022.xlsx / .csv     (Detalle por cuenta post-2022)
#         data/processed/Resumen_Sede_2022.xlsx / .csv (Serie agregada Sede Central post-2022)
# =============================================================================

library(dplyr)
library(readr)
library(readxl)
library(writexl)
library(here)
library(tsibble)

# ─────────────────────────────────────────────────────────────────────────────
# PARÁMETROS
# ─────────────────────────────────────────────────────────────────────────────
UMBRAL_FP    <- 0.485          # Umbral normativo unificado (R/A <= 0.485)
ANO_INICIO   <- 2022           # Filtro post-pandemia

# ─────────────────────────────────────────────────────────────────────────────
# CARGA Y PROCESAMIENTO DE TEMPERATURA
# ─────────────────────────────────────────────────────────────────────────────
cat("── Cargando datos de temperatura promedio...\n")
RUTA_TEMPERATURA <- here("data", "raw", "Datos_Temperatura_Media.xlsx")

df_temp <- read_excel(RUTA_TEMPERATURA, sheet = "Datos") %>%
  mutate(
    Temperatura = as.numeric(`Valor:`),
    Ano         = as.numeric(substr(Fecha, 1, 4)),
    Mes         = as.numeric(substr(Fecha, 6, 7))
  ) %>%
  select(Ano, Mes, Temperatura)

# ─────────────────────────────────────────────────────────────────────────────
# CARGA DE CONSUMO HISTÓRICO DE SEDE CENTRAL
# ─────────────────────────────────────────────────────────────────────────────
cat("── Cargando datos históricos de Sede Central...\n")
df_central <- read_csv(here("data", "processed", "Consumo_Central.csv"), show_col_types = FALSE)

# ─────────────────────────────────────────────────────────────────────────────
# BLOQUE 1: Detalle por Cuenta Post-Pandemia (Central_2022)
# ─────────────────────────────────────────────────────────────────────────────
cat("── Procesando Detalle de Sede Central (Central_2022) desde 2022...\n")

df_central_2022 <- df_central %>%
  filter(Ano >= ANO_INICIO) %>%
  arrange(Cuenta, Ano, Mes) %>%
  left_join(df_temp, by = c("Ano", "Mes")) %>%
  mutate(
    Vacaciones = ifelse(Mes %in% c(1, 6, 7, 12), 1L, 0L),
    Relacion   = ifelse(Activa > 0, Reactiva / Activa, NA_real_),
    Cumple     = ifelse(Relacion <= UMBRAL_FP, "Sí", "No"),
    Cumple_bin = ifelse(Cumple == "Sí", 1L, 0L),
    Excedente  = pmax(Reactiva - UMBRAL_FP * Activa, 0)
  ) %>%
  group_by(Cuenta) %>%
  mutate(Tiempo = row_number()) %>%
  ungroup()

# ─────────────────────────────────────────────────────────────────────────────
# BLOQUE 2: Serie Agregada Sede Central Post-Pandemia (Resumen_Sede_2022)
# ─────────────────────────────────────────────────────────────────────────────
cat("── Agrupando y corrigiendo Resumen de Sede Central (Resumen_Sede_2022) desde 2022...\n")

df_sede_2022 <- df_central_2022 %>%
  group_by(Ano, Mes) %>%
  summarise(
    Activa_Total      = sum(Activa,          na.rm = TRUE),
    Reactiva_Total    = sum(Reactiva,        na.rm = TRUE),
    Pago_Total_Sede   = sum(Pago,            na.rm = TRUE),
    Cuentas_Pagadas   = sum(!is.na(Pago) & Pago > 0),
    Cuentas_Incumplen = sum(Cumple == "No",  na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(
    Sede_Incumple = ifelse(Cuentas_Incumplen > 0, 1L, 0L)
  ) %>%
  arrange(Ano, Mes) %>%
  left_join(df_temp, by = c("Ano", "Mes")) %>%
  mutate(
    Vacaciones = ifelse(Mes %in% c(1, 6, 7, 12), 1L, 0L),
    Tiempo     = row_number()
  )

# ─────────────────────────────────────────────────────────────────────────────
# BLOQUE 3: Verificar continuidad de la serie agregada
# ─────────────────────────────────────────────────────────────────────────────
cat("\n── Verificando continuidad de la serie agregada...\n")

ts_check <- tsibble(
  fecha = yearmonth(paste(df_sede_2022$Ano, df_sede_2022$Mes, sep = "-")),
  index = fecha
)
n_gaps <- sum(has_gaps(ts_check)$.gaps)
if (n_gaps == 0) {
  cat("   ✓ Resumen_Sede_2022: Serie continua sin huecos\n")
} else {
  cat(sprintf("   ⚠ ATENCIÓN: %d hueco(s) detectados en Resumen_Sede_2022\n", n_gaps))
}

# ─────────────────────────────────────────────────────────────────────────────
# BLOQUE 4: Diagnóstico rápido
# ─────────────────────────────────────────────────────────────────────────────
cat("═══════════════════════════════════════════════════\n")
cat("  DIAGNÓSTICO — SEDE CENTRAL DESDE 2022\n")
cat("═══════════════════════════════════════════════════\n")
cat(sprintf("  Período Resumen Sede    : %d-%02d a %d-%02d (%d meses)\n",
            min(df_sede_2022$Ano), min(df_sede_2022$Mes), max(df_sede_2022$Ano), max(df_sede_2022$Mes), nrow(df_sede_2022)))
cat(sprintf("  Cuentas únicas en Sede  : %d\n", n_distinct(df_central_2022$Cuenta)))
cat(sprintf("  Temperatura media Sede  : %.2f °C (rango: %.2f - %.2f)\n",
            mean(df_sede_2022$Temperatura, na.rm = TRUE), min(df_sede_2022$Temperatura, na.rm = TRUE), max(df_sede_2022$Temperatura, na.rm = TRUE)))
cat("═══════════════════════════════════════════════════\n\n")

# ─────────────────────────────────────────────────────────────────────────────
# BLOQUE 5: Exportar
# ─────────────────────────────────────────────────────────────────────────────
cat("── Exportando archivos procesados...\n")

# Escribir CSVs primero para asegurar que el pipeline de modelado pueda correr
# incluso si los archivos Excel están abiertos en Excel por el usuario.
write_csv(df_central_2022,  here("data", "processed", "Central_2022.csv"))
write_csv(df_sede_2022,     here("data", "processed", "Resumen_Sede_2022.csv"))

cat("   ✓ Central_2022.csv\n")
cat("   ✓ Resumen_Sede_2022.csv\n")

# Escribir Excel en bloques tryCatch para que un bloqueo en Excel no aborte el script completo
tryCatch({
  write_xlsx(df_central_2022, here("data", "processed", "Central_2022.xlsx"))
  cat("   ✓ Central_2022.xlsx\n")
}, error = function(e) {
  cat("   ⚠ ADVERTENCIA: No se pudo escribir Central_2022.xlsx (posiblemente abierto en Excel)\n")
})

tryCatch({
  write_xlsx(df_sede_2022,    here("data", "processed", "Resumen_Sede_2022.xlsx"))
  cat("   ✓ Resumen_Sede_2022.xlsx\n")
}, error = function(e) {
  cat("   ⚠ ADVERTENCIA: No se pudo escribir Resumen_Sede_2022.xlsx (posiblemente abierto en Excel)\n")
})

cat("\nProceso completado exitosamente.\n")
