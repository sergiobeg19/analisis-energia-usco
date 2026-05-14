# Diccionario de Datos

Descripción detallada de todas las variables utilizadas en el análisis de energía eléctrica de la Universidad Surcolombiana (USCO). Los datos históricos comprenden el período **2000–2025** y se registran mensualmente.

---

## Datos Crudos (Archivos de entrada)

### `Consumo_Cuentas_.xlsx` — Consumo eléctrico por cuenta

| Variable | Tipo | Descripción |
|----------|------|-------------|
| Cuenta | Numérica | Identificador numérico de la cuenta eléctrica |
| Consumo Valorizado | Numérica | Consumo valorizado en pesos (COP) |
| Consumo Real MAX | Numérica | Consumo real máximo registrado en el período |
| Ano | Numérica | Año del registro |
| Mes | Numérica | Mes del registro (1–12) |
| Consumo Real | Numérica | Consumo real de energía en el período (kWh o kVArh según tipo) |
| Tipo Energia | Categórica | Tipo de energía: `A` (Activa) o `R` (Reactiva) |

### `Pago_Cuentas.xls` — Pagos por cuenta

| Variable | Tipo | Descripción |
|----------|------|-------------|
| Cuenta | Numérica | Identificador numérico de la cuenta eléctrica |
| Valor Pago | Numérica | Valor del pago registrado (COP) |
| Ano | Numérica | Año del pago |
| Mes | Numérica | Mes del pago (1–12) |
| Valor | Numérica | Valor efectivo del pago (COP) |

---

## Tabla 1: `Consumo_Central.csv` — Consumo por cuenta-período (Sede Central)

Generada por: `scripts/01_Unificar_Consumo_Pagos_Central.R`
Granularidad: **una fila por cuenta × período** (solo 5 cuentas de Sede Central)
Usada en: Notebook de Regresión Logística

| Variable | Tipo | Descripción |
|----------|------|-------------|
| Cuenta | Categórica | Identificador de la cuenta (167382131, 167383918, 357154485, 847747377, 167385482) |
| Nombre_Cuenta | Categórica | Nombre legible: Central_1 a Central_5 |
| Ano | Numérica | Año del registro |
| Mes | Numérica | Mes del registro (1–12) |
| Tiempo | Numérica | Índice secuencial del período (1, 2, 3, ...) |
| Semestre | Numérica | Semestre del año: 1 (Ene–Jun), 2 (Jul–Dic) |
| Trimestre | Numérica | Trimestre del año: 1 a 4 |
| Activa | Numérica (kWh) | Energía activa consumida por la cuenta en el período |
| Reactiva | Numérica (kVArh) | Energía reactiva consumida por la cuenta en el período |
| Relacion | Numérica | Razón Reactiva / Activa (límite normativo: ≤ 0.48) |
| Cumple | Categórica | `"Sí"` si Relación ≤ 0.48, `"No"` si la excede |
| Cumple_bin | Binaria (0/1) | 1 = cumple norma, 0 = incumple |
| Pago | Numérica (COP) | Valor pagado por la cuenta en ese período |

---

## Tabla 2: `Resumen_Sede.csv` — Resumen mensual de Sede Central

Generada por: `scripts/01_Unificar_Consumo_Pagos_Central.R`
Granularidad: **una fila por período** (agregación de las 5 cuentas)
Usada en: Notebook de Regresión Logística

| Variable | Tipo | Descripción |
|----------|------|-------------|
| Tiempo | Numérica | Índice secuencial del período |
| Ano | Numérica | Año del registro |
| Mes | Numérica | Mes del registro (1–12) |
| Activa_Total | Numérica (kWh) | Suma de energía activa de las 5 cuentas |
| Reactiva_Total | Numérica (kVArh) | Suma de energía reactiva de las 5 cuentas |
| Pago_Total_Sede | Numérica (COP) | Suma de pagos de las 5 cuentas en el período |
| Cuentas_Pagadas | Numérica | Número de cuentas con pago registrado ese mes (0–5) |
| Cuentas_Incumplen | Numérica | Número de cuentas con Relación > 0.48 ese mes (0–5) |
| Sede_Incumple | Binaria (0/1) | 1 = al menos una cuenta incumple, 0 = todas cumplen |

---

## Tabla 3: `Consumo_Final.csv` — Consumo agregado total (todas las cuentas)

Generada por: `scripts/02_Unificar_Consumo_Pagos.R`
Granularidad: **una fila por período** (agregación de TODAS las cuentas de la USCO)
Usada en: Notebook de Regresión Lineal

| Variable | Tipo | Descripción |
|----------|------|-------------|
| Ano | Numérica | Año del registro |
| Mes | Numérica | Mes del registro (1–12) |
| Activa | Numérica (kWh) | Energía activa total de todas las cuentas |
| Reactiva | Numérica (kVArh) | Energía reactiva total de todas las cuentas |
| Cant_Cuentas | Numérica | Número de cuentas con consumo activo > 0 ese mes |
| Cuentas_Reactiva | Numérica | Número de cuentas con consumo reactivo > 0 ese mes |
| Relacion | Numérica | Razón Reactiva / Activa (límite normativo: ≤ 0.48) |
| Cumple | Categórica | `"Sí"` si Relación ≤ 0.48, `"No"` si la excede |
| Pago_Total | Numérica (COP) | Suma de pagos de todas las cuentas en el período |
| Cuentas_Pagadas | Numérica | Número de cuentas con pago registrado ese mes |
| Tiempo | Numérica | Índice secuencial del período |

---

## Variables Derivadas (creadas en runtime por los notebooks)

| Variable | Creada en | Fórmula | Descripción |
|----------|-----------|---------|-------------|
| Vacaciones | Notebook Logístico | `ifelse(Mes %in% c(1, 6, 7, 12), 1, 0)` | 1 = mes de receso académico, 0 = mes de clases |

---

## Normativa de Referencia

- **CREG 015 de 2018**: La relación entre energía reactiva y energía activa no debe superar **0.48**. El incumplimiento genera recargos económicos en la factura.
- Todos los costos están expresados en **Pesos Colombianos (COP)**.
