# =============================================================================
# SCRIPT: Unificación de Consumo de Cuentas y Pagos por Período
# Universidad Surcolombiana (USCO) — SEDE CENTRAL
# =============================================================================
# TABLA 1 — Consumo_Central (una fila por cuenta-período):
#   Cuenta | Nombre_Cuenta | Ano | Mes | Tiempo | Semestre | Trimestre |
#   Activa | Reactiva | Relacion | Cumple | Cumple_bin | Pago
#
# TABLA 2 — Resumen_Sede (una fila por período):
#   Tiempo | Ano | Mes | Activa_Total | Reactiva_Total |
#   Pago_Total_Sede | Cuentas_Pagadas | Cuentas_Incumplen | Sede_Incumple
# =============================================================================

library(readxl)
library(dplyr)
library(tidyr)
library(writexl)
library(here)

# -----------------------------------------------------------------------------
# RUTAS DE ARCHIVOS — portables con here() (funciona en cualquier equipo con Git)
# -----------------------------------------------------------------------------

# RUTAS DE ENTRADA (Apuntan a la carpeta raw que acabas de llenar)
RUTA_CONSUMO_RAW <- here("data", "raw", "Consumo_Cuentas_.xlsx")
RUTA_PAGOS       <- here("data", "raw", "Pago_Cuentas.xls")

# RUTAS DE SALIDA (Se guardarán en processed para que el .qmd las lea de ahí)
RUTA_SALIDA_XLSX  <- here("data", "processed", "Consumo_Central.xlsx")
RUTA_SALIDA_CSV   <- here("data", "processed", "Consumo_Central.csv")
RUTA_RESUMEN_XLSX <- here("data", "processed", "Resumen_Sede.xlsx")
RUTA_RESUMEN_CSV  <- here("data", "processed", "Resumen_Sede.csv")

# -----------------------------------------------------------------------------
# CUENTAS DE SEDE CENTRAL
# -----------------------------------------------------------------------------
cuentas_central <- c(167382131,   # Central 1
                     167383918,   # Central 4  ← CAMBIA EL NÚMERO AQUÍ SI ES NECESARIO
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

# ── LÍNEA NUEVA: filtrar solo las 5 cuentas de Sede Central ──────────────────
df_raw <- df_raw %>%
  filter(Cuenta %in% cuentas_central)
# ─────────────────────────────────────────────────────────────────────────────

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
# BLOQUE 2: Construir métricas por cuenta-período (formato largo)
# =============================================================================

# ── CAMBIO CLAVE: ya NO se agrupa eliminando Cuenta ──────────────────────────
#    Se conserva Cuenta como columna → una fila por cuenta-período
df_consumo <- df_wide %>%
  filter(A > 0) %>%                                    # excluir períodos sin consumo real
  mutate(
    Activa   = A,
    Reactiva = R,
    Relacion = ifelse(A > 0, R / A, NA_real_),
    Cumple   = ifelse(Relacion <= 0.48, "Sí", "No")
  ) %>%
  select(Cuenta, Ano, Mes, Activa, Reactiva, Relacion, Cumple) %>%
  arrange(Cuenta, Ano, Mes)
# ─────────────────────────────────────────────────────────────────────────────

cat("── Registros por cuenta-período construidos:", nrow(df_consumo), "\n")

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
df_final <- df_consumo %>%
  left_join(pago_individual, by = c("Cuenta", "Ano", "Mes")) %>%
  mutate(
    Nombre_Cuenta = nombres_central[as.character(Cuenta)],
    Cuenta        = factor(Cuenta, levels = cuentas_central),
    Tiempo        = dense_rank(Ano * 100 + Mes),
    # ── Variables para modelo logístico ────────────────────────────────────
    Cumple_bin    = ifelse(Cumple == "Sí", 1L, 0L),   # Y binaria: 1=cumple, 0=incumple
    Semestre      = ifelse(Mes <= 6, 1L, 2L),          # 1=ene-jun, 2=jul-dic
    Trimestre     = ceiling(Mes / 3L)                  # 1 a 4
  ) %>%
  select(Cuenta, Nombre_Cuenta, Ano, Mes, Tiempo, Semestre, Trimestre,
         Activa, Reactiva, Relacion, Cumple, Cumple_bin, Pago)

# =============================================================================
# BLOQUE 5: Construir Tabla 2 — Resumen_Sede (una fila por período)
# =============================================================================

resumen_sede <- df_final %>%
  group_by(Tiempo, Ano, Mes) %>%
  summarise(
    Activa_Total      = sum(Activa,          na.rm = TRUE),  # total activa sede
    Reactiva_Total    = sum(Reactiva,        na.rm = TRUE),  # total reactiva sede
    Cuentas_Incumplen = sum(Cumple == "No",  na.rm = TRUE),  # cuántas incumplen
    .groups = "drop"
  ) %>%
  left_join(pago_sede, by = c("Ano", "Mes")) %>%
  mutate(
    # Y binaria para modelo logístico nivel sede
    Sede_Incumple = ifelse(Cuentas_Incumplen > 0, 1L, 0L)   # 0=todas cumplen, 1=al menos 1 incumple
  ) %>%
  arrange(Tiempo) %>%
  select(Tiempo, Ano, Mes, Activa_Total, Reactiva_Total,
         Pago_Total_Sede, Cuentas_Pagadas, Cuentas_Incumplen, Sede_Incumple)

# =============================================================================
# BLOQUE 6: Verificación
# =============================================================================
cat("═══════════════════════════════════════════════════\n")
cat("  RESUMEN — CONSUMO SEDE CENTRAL\n")
cat("═══════════════════════════════════════════════════\n")
cat(sprintf("  TABLA 1 — filas (cuenta-período) : %d\n", nrow(df_final)))
cat(sprintf("  TABLA 2 — filas (período)        : %d\n", nrow(resumen_sede)))
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
print(head(resumen_sede, 6))
cat("═══════════════════════════════════════════════════\n\n")

# =============================================================================
# BLOQUE 7: Exportar
# =============================================================================
cat("── Exportando archivos...\n")

write_xlsx(df_final,    RUTA_SALIDA_XLSX)
write.csv(df_final,     RUTA_SALIDA_CSV,   row.names = FALSE)
write_xlsx(resumen_sede, RUTA_RESUMEN_XLSX)
write.csv(resumen_sede,  RUTA_RESUMEN_CSV,  row.names = FALSE)

cat(sprintf("   ✓ Tabla 1 Excel : %s\n", RUTA_SALIDA_XLSX))
cat(sprintf("   ✓ Tabla 1 CSV   : %s\n", RUTA_SALIDA_CSV))
cat(sprintf("   ✓ Tabla 2 Excel : %s\n", RUTA_RESUMEN_XLSX))
cat(sprintf("   ✓ Tabla 2 CSV   : %s\n", RUTA_RESUMEN_CSV))
cat("\nProceso completado exitosamente.\n")
