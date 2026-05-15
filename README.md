# ⚡ Análisis de Energía Eléctrica — Universidad Surcolombiana

Análisis estadístico del consumo eléctrico y del factor de potencia en la Sede Central de la Universidad Surcolombiana (USCO): cuantificación del incumplimiento normativo e impacto económico de la energía reactiva (2000–2025).

## 📋 Descripción

Este proyecto analiza los registros mensuales de consumo de energía activa y reactiva de la USCO para:

- **Regresión Lineal:** Modelar y predecir el consumo de energía reactiva a partir del consumo activo y el número de cuentas.
- **Regresión Logística:** Estimar la probabilidad de incumplimiento de la norma CREG 015/2018 (relación Reactiva/Activa ≤ 0.48) a nivel de sede y por cuenta individual.

## 📂 Estructura del Proyecto

```
analisis-energia-usco/
├── data/
│   ├── raw/                          # Datos crudos (fuentes originales)
│   │   ├── Consumo_Cuentas_.xlsx     # Consumo por cuenta y tipo de energía
│   │   └── Pago_Cuentas.xls          # Pagos por cuenta y período
│   └── processed/                    # Datos procesados (generados por scripts)
│       ├── Consumo_Central.csv/.xlsx  # Tabla 1: cuenta × período (Sede Central)
│       ├── Resumen_Sede.csv/.xlsx     # Tabla 2: resumen mensual sede
│       └── Consumo_Final.csv/.xlsx    # Tabla 3: agregado total todas las cuentas
├── scripts/
│   ├── 01_Unificar_Consumo_Pagos_Central.R  # Genera Tablas 1 y 2
│   └── 02_Unificar_Consumo_Pagos.R          # Genera Tabla 3
├── notebooks/
│   ├── Taller_Regresion_Lineal_USCO.qmd     # Código fuente — Regresión Lineal
│   └── Taller_Regresion_Logistica.qmd       # Código fuente — Regresión Logística
├── docs/
│   ├── Anteproyecto.docx                    # Anteproyecto del trabajo de grado
│   ├── diccionario_datos.md                  # Diccionario de variables
│   ├── Taller_Regresion_Lineal_USCO.html    # Reporte renderizado
│   └── Taller_Regresion_Logistica.html      # Reporte renderizado
└── .gitignore
```

## 🚀 Reproducción

### Requisitos

- **R** ≥ 4.3
- Paquetes: `readxl`, `dplyr`, `tidyr`, `writexl`, `here`, `ggplot2`, `knitr`, `kableExtra`, `scales`

### Pasos

1. Clonar el repositorio:
   ```bash
   git clone https://github.com/sergiobeg19/analisis-energia-usco.git
   ```

2. Abrir el proyecto en RStudio (`analisis-energia-usco.Rproj`).

3. Ejecutar los scripts de procesamiento:
   ```r
   source("scripts/01_Unificar_Consumo_Pagos_Central.R")  # Tablas 1 y 2
   source("scripts/02_Unificar_Consumo_Pagos.R")           # Tabla 3
   ```

4. Los reportes HTML ya renderizados están disponibles en `docs/`.

## 📊 Datos

| Tabla | Archivo | Granularidad | Filas | Generada por |
|-------|---------|-------------|-------|-------------|
| Tabla 1 | `Consumo_Central.csv` | Cuenta × período (5 cuentas) | 1.112 | Script 01 |
| Tabla 2 | `Resumen_Sede.csv` | Período mensual (sede) | 291 | Script 01 |
| Tabla 3 | `Consumo_Final.csv` | Período mensual (todas las cuentas) | 308 | Script 02 |

Consulta el [Diccionario de Datos](docs/diccionario_datos.md) para la descripción completa de cada variable.

## 📄 Documentos y Reportes

- [Anteproyecto](docs/Anteproyecto.docx) — Anteproyecto del trabajo de grado
- [Regresión Lineal](docs/Taller_Regresion_Lineal_USCO.html) — Activa → Reactiva (modelo simple y múltiple)
- [Regresión Logística](docs/Taller_Regresion_Logistica.html) — Predicción de incumplimiento normativo

## 👥 Autores

- Sergio Andrés Beltrán
- Juan Pablo Donato

**Programa:** Especialización en Estadística — Universidad Surcolombiana (USCO)

## 📜 Referencia Normativa

- **CREG 015 de 2018** — Relación Reactiva/Activa ≤ 0.48. El incumplimiento genera recargos económicos en la factura eléctrica.
