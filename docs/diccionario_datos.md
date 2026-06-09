# Diccionario de Datos

Descripción detallada de todas las variables utilizadas en el análisis de energía eléctrica de la Universidad Surcolombiana (USCO). Los datos históricos comprenden el período **2001–2025** (con $t=1$ correspondiente a Mayo de 2001) y se registran mensualmente.

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

## Tablas Intermedias Históricas (2001–2025)

### Tabla 1: `Consumo_Central.csv` — Consumo por cuenta-período (Sede Central Histórico)

Generada por: `scripts/01_Unificar_Consumo_Pagos_Central.R`
Granularidad: **una fila por cuenta × período** (las 5 cuentas de Sede Central)
Usada en: Carga inicial de datos y control histórico

| Variable | Tipo | Descripción |
|----------|------|-------------|
| Cuenta | Categórica | Identificador de la cuenta (167382131, 167383918, 357154485, 847747377, 167385482) |
| Nombre_Cuenta | Categórica | Nombre legible: Central_1 a Central_5 |
| Ano | Numérica | Año del registro |
| Mes | Numérica | Mes del registro (1–12) |
| Tiempo | Numérica | Índice secuencial del período (1 = Mayo 2001, ..., 292 = Agosto 2025) |
| Semestre | Numérica | Semestre del año: 1 (Ene–Jun), 2 (Jul–Dic) |
| Trimestre | Numérica | Trimestre del año: 1 a 4 |
| Activa | Numérica (kWh) | Energía activa consumida por la cuenta en el período (imputada en ceros intermedios) |
| Reactiva | Numérica (kVArh) | Energía reactiva consumida por la cuenta en el período (imputada en ceros intermedios) |
| Relacion | Numérica | Razón Reactiva / Activa (límite normativo CREG: ≤ 0.50) |
| Cumple | Categórica | `"Sí"` si Relación ≤ 0.50, `"No"` si la excede |
| Cumple_bin | Binaria (0/1) | 1 = cumple norma, 0 = incumple |
| Pago | Numérica (COP) | Valor pagado por la cuenta en ese período |

### Tabla 2: `Resumen_Sede.csv` — Resumen mensual de Sede Central Histórico

Generada por: `scripts/01_Unificar_Consumo_Pagos_Central.R`
Granularidad: **una fila por período** (agregación de las 5 cuentas)
Usada en: Control e históricos consolidados

| Variable | Tipo | Descripción |
|----------|------|-------------|
| Tiempo | Numérica | Índice secuencial del período (1 = Mayo 2001, ...) |
| Ano | Numérica | Año del registro |
| Mes | Numérica | Mes del registro (1–12) |
| Activa_Total | Numérica (kWh) | Suma de energía activa de las 5 cuentas |
| Reactiva_Total | Numérica (kVArh) | Suma de energía reactiva de las 5 cuentas |
| Pago_Total_Sede | Numérica (COP) | Suma de pagos de las 5 cuentas en el período |
| Cuentas_Pagadas | Numérica | Número de cuentas con pago registrado ese mes (0–5) |
| Cuentas_Incumplen | Numérica | Número de cuentas con Relación > 0.50 ese mes (0–5) |
| Sede_Incumple | Binaria (0/1) | 1 = al menos una cuenta incumple, 0 = todas cumplen |

---

## Tablas de Modelado y Análisis Filtradas (2014–2025)

Estas tablas son generadas a partir de `2014` para el ajuste de modelos econométricos y series de tiempo, aislando el impacto temporal de la pandemia y adaptando la serie al retorno a la normalidad presencial.

### Tabla 4: `Central_2014.csv` / `.xlsx` — Detalle por Cuenta de Sede Central Enriquecido

Generada por: `scripts/03_Filtrar_36_Meses.R`
Granularidad: **una fila por cuenta × período** (desde Enero 2014 a Julio 2025)
Usada en: Análisis de regresión logística a nivel de cuentas

| Variable | Tipo | Descripción |
|----------|------|-------------|
| Cuenta | Categórica | Identificador de la cuenta |
| Nombre_Cuenta | Categórica | Nombre legible: Central_1 a Central_5 |
| Ano | Numérica | Año del registro |
| Mes | Numérica | Mes del registro (1–12) |
| Tiempo | Numérica | Índice secuencial del período (Mayo 2001 = 1) |
| Semestre | Numérica | Semestre del año (1 o 2) |
| Trimestre | Numérica | Trimestre del año (1 a 4) |
| Activa | Numérica (kWh) | Energía activa consumida por la cuenta en el período (ceros imputados por media mensual) |
| Reactiva | Numérica (kVArh) | Energía reactiva consumida por la cuenta en el período (ceros imputados por media mensual) |
| Relacion | Numérica | Razón Reactiva / Activa |
| Cumple | Categórica | `"Sí"` si Relación ≤ 0.50, `"No"` si la excede |
| Cumple_bin | Binaria (0/1) | 1 = cumple norma, 0 = incumple |
| Pago | Numérica (COP) | Valor pagado por la cuenta en ese período |
| Temperatura | Numérica (°C) | Temperatura promedio mensual de la región (Neiva) |
| Vacaciones | Binaria (0/1) | 1 = mes de receso académico regular (Ene, Jun, Jul, Dic), 0 = mes lectivo regular |
| Fase | Factor / Categoría | Segmentación temporal: `"Pre-pandemia"`, `"Pandemia-Transicion"`, o `"Nueva-Normalidad"` |
| Dummy_Pandemia | Binaria (0/1) | Variable dummy que toma valor 1 si el período pertenece a la fase de Pandemia y Transición (Mar 2020 – Jun 2023) |
| Dummy_Normalidad | Binaria (0/1) | Variable dummy que toma valor 1 si el período pertenece a la fase de Nueva Normalidad (Jul 2023 en adelante) |
| Excedente | Numérica (kVArh) | Energía reactiva penalizable calculada como `max(Reactiva - 0.50 * Activa, 0)` |

### Tabla 5: `Resumen_Sede_2014.csv` / `.xlsx` — Serie Agregada Sede Central Enriquecida

Generada por: `scripts/03_Filtrar_36_Meses.R`
Granularidad: **una fila por período** (desde Enero 2014 a Julio 2025, 139 periodos continuos)
Usada en: Modelado SARIMA/SARIMAX de Sede Central (Proyecto_Energia_USCO.qmd)

| Variable | Tipo | Descripción |
|----------|------|-------------|
| Ano | Numérica | Año del registro |
| Mes | Numérica | Mes del registro (1–12) |
| Activa_Total | Numérica (kWh) | Suma de energía activa de las cuentas activas de Sede Central |
| Reactiva_Total | Numérica (kVArh) | Suma de energía reactiva de las cuentas activas de Sede Central |
| Pago_Total_Sede | Numérica (COP) | Suma de pagos de las cuentas activas de Sede Central en el período |
| Cuentas_Pagadas | Numérica | Número de cuentas con pago registrado ese mes (0–5) |
| Cuentas_Incumplen | Numérica | Número de cuentas que exceden el límite de 0.50 en su relación Reactiva/Activa |
| Sede_Incumple | Binaria (0/1) | 1 = al menos una cuenta incumple la relación normada, 0 = todas cumplen |
| Temperatura | Numérica (°C) | Temperatura promedio mensual de la región (Neiva) |
| Vacaciones | Binaria (0/1) | 1 = mes de receso académico regular (Ene, Jun, Jul, Dic), 0 = mes lectivo regular |
| Tiempo | Numérica | Índice secuencial absoluto continuo del período (Mayo 2001 = 1) |
| Fase | Factor / Categoría | Segmentación temporal: `"Pre-pandemia"`, `"Pandemia-Transicion"`, o `"Nueva-Normalidad"` |
| Dummy_Pandemia | Binaria (0/1) | Variable dummy que toma valor 1 si el período pertenece a la fase de Pandemia y Transición |
| Dummy_Normalidad | Binaria (0/1) | Variable dummy que toma valor 1 si el período pertenece a la fase de Nueva Normalidad |

---

## Tabla 3: `Consumo_Final.csv` — Consumo agregado total (todas las cuentas de la Universidad)

Generada por: `scripts/02_Unificar_Consumo_Pagos.R`
Granularidad: **una fila por período** (agregación de TODAS las cuentas de la USCO históricas)
Usada en: Reportes descriptivos globales de la universidad

| Variable | Tipo | Descripción |
|----------|------|-------------|
| Ano | Numérica | Año del registro |
| Mes | Numérica | Mes del registro (1–12) |
| Activa | Numérica (kWh) | Energía activa total de todas las cuentas |
| Reactiva | Numérica (kVArh) | Energía reactiva total de todas las cuentas |
| Cant_Cuentas | Numérica | Número de cuentas con consumo activo > 0 ese mes |
| Cuentas_Reactiva | Numérica | Número de cuentas con consumo reactivo > 0 ese mes |
| Relacion | Numérica | Razón Reactiva / Activa (límite normativo: ≤ 0.50) |
| Cumple | Categórica | `"Sí"` si Relación ≤ 0.50, `"No"` si la excede |
| Pago_Total | Numérica (COP) | Valor pagado por todas las cuentas en el período |
| Cuentas_Pagadas | Numérica | Número de cuentas con pago registrado ese mes |
| Tiempo | Numérica | Índice secuencial del período (Mayo 2001 = 1) |

---

## Normativa de Referencia

- **Resolución CREG 015 de 2018 y CREG 199 de 2019**: Establece que la relación entre energía reactiva y energía activa no debe superar **0.50** (equivalente al 50% de la energía activa mensual para niveles de tensión I y II). Superar este límite genera penalizaciones y recargos por energía reactiva excedente facturada (CTER con factor M). El conteo de M inicia formalmente en Enero de 2021.
- Todos los costos y pagos están expresados en **Pesos Colombianos (COP)**.
