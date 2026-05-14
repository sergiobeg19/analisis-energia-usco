# =============================================================================
# SCRIPT: Unificación de Consumo de Cuentas y Pagos por Período
# Universidad Surcolombiana (USCO) — TODAS LAS CUENTAS
# =============================================================================
# RESULTADO: Consumo_Final.csv / .xlsx — una fila por período (Año-Mes)
#   Ano | Mes | Activa | Reactiva | Cant_Cuentas | Cuentas_Reactiva |
#   Relacion | Cumple | Pago_Total | Cuentas_Pagadas | Tiempo
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
RUTA_SALIDA_XLSX <- here("data", "processed", "Consumo_Final.xlsx")
RUTA_SALIDA_CSV  <- here("data", "processed", "Consumo_Final.csv")

# =============================================================================
# BLOQUE 1: Construir tabla de consumo mensual (Consumo_Final)
# =============================================================================
cat("── Cargando consumo de cuentas...\n")

df_raw <- read_excel(RUTA_CONSUMO_RAW)

# Reemplazar NA por 0 en Consumo Real
df_raw <- df_raw %>%
  mutate(`Consumo Real` = replace_na(`Consumo Real`, 0))

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

# Sumar todas las cuentas por período
df_consumo <- df_wide %>%
  group_by(Ano, Mes) %>%
  summarise(
    Activa           = sum(A,    na.rm = TRUE),
    Reactiva         = sum(R,    na.rm = TRUE),
    Cant_Cuentas     = sum(A > 0, na.rm = TRUE),
    Cuentas_Reactiva = sum(R > 0, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(Ano, Mes) %>%
  filter(Activa > 0) %>%                               # excluir períodos sin datos
  mutate(
    Relacion = ifelse(Activa > 0, Reactiva / Activa, NA_real_),
    Cumple   = ifelse(Relacion <= 0.48, "Sí", "No"),
    Tiempo   = row_number()
  )

cat("   Períodos de consumo construidos:", nrow(df_consumo), "\n")
cat("   Rango de años:", min(df_consumo$Ano), "–", max(df_consumo$Ano), "\n\n")

# =============================================================================
# BLOQUE 2: Calcular Pago_Total por período (suma de todas las cuentas)
# =============================================================================
cat("── Cargando archivo de pagos...\n")

df_pagos_raw <- read_excel(RUTA_PAGOS)

# Estandarizar nombres (el XLS puede traer espacios o mayúsculas distintas)
colnames(df_pagos_raw) <- c("Cuenta", "Valor_Pago", "Ano", "Mes", "Valor")

cat("   Registros de pago cargados:", nrow(df_pagos_raw), "\n")
cat("   Cuentas únicas en pagos:   ", n_distinct(df_pagos_raw$Cuenta), "\n\n")

# Sumar el valor de pago de TODAS las cuentas por Año-Mes
# Se usa Valor_Pago (columna que incluye activa + recargo reactiva si aplica)
# Se ignoran NA (cuentas sin pago registrado ese período)
pago_mensual <- df_pagos_raw %>%
  filter(!is.na(Valor), Valor > 0) %>%
  group_by(Ano, Mes) %>%
  summarise(
    Pago_Total      = sum(Valor, na.rm = TRUE),     # suma total del período
    Cuentas_Pagadas = n_distinct(Cuenta),               # cuántas cuentas pagaron
    .groups = "drop"
  ) %>%
  arrange(Ano, Mes)

cat("── Períodos con pago registrado:", nrow(pago_mensual), "\n\n")

# =============================================================================
# BLOQUE 3: Unir consumo + pago por Año-Mes (left join)
# =============================================================================
# Left join: se conservan TODOS los períodos de consumo.
# Si un período no tiene pago registrado, queda NA en Pago_Total.

df_final <- df_consumo %>%
  left_join(pago_mensual, by = c("Ano", "Mes")) %>%
  relocate(Tiempo, .after = last_col())               # Tiempo al final (igual que antes)

# Orden de columnas final:
# Ano | Mes | Activa | Reactiva | Cant_Cuentas | Cuentas_Reactiva |
# Relacion | Cumple | Pago_Total | Cuentas_Pagadas | Tiempo

# =============================================================================
# BLOQUE 4: Verificación
# =============================================================================
cat("═══════════════════════════════════════════════════\n")
cat("  RESUMEN DEL ARCHIVO UNIFICADO\n")
cat("═══════════════════════════════════════════════════\n")
cat(sprintf("  Períodos totales        : %d\n",  nrow(df_final)))
cat(sprintf("  Con pago registrado     : %d\n",  sum(!is.na(df_final$Pago_Total))))
cat(sprintf("  Sin pago (NA)           : %d\n",  sum( is.na(df_final$Pago_Total))))
cat(sprintf("  Cumple norma (≤ 0.48)   : %d\n",  sum(df_final$Cumple == "Sí", na.rm = TRUE)))
cat(sprintf("  Incumple norma (> 0.48) : %d\n",  sum(df_final$Cumple == "No", na.rm = TRUE)))
cat(sprintf("  Pago promedio mensual   : $ %s COP\n",
            formatC(mean(df_final$Pago_Total, na.rm = TRUE),
                    format = "f", digits = 0, big.mark = ".", decimal.mark = ",")))
cat(sprintf("  Pago máximo registrado  : $ %s COP\n",
            formatC(max(df_final$Pago_Total, na.rm = TRUE),
                    format = "f", digits = 0, big.mark = ".", decimal.mark = ",")))
cat("═══════════════════════════════════════════════════\n\n")

cat("Primeros registros del archivo unificado:\n")
print(head(df_final, 10))

# =============================================================================
# BLOQUE 5: Exportar
# =============================================================================
cat("\n── Exportando archivos...\n")

write_xlsx(df_final, RUTA_SALIDA_XLSX)
write.csv(df_final,  RUTA_SALIDA_CSV, row.names = FALSE)

cat(sprintf("   ✓ Excel guardado en: %s\n", RUTA_SALIDA_XLSX))
cat(sprintf("   ✓ CSV   guardado en: %s\n", RUTA_SALIDA_CSV))
cat("\nProceso completado exitosamente.\n")
