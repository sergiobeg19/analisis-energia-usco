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
│   │   ├── Datos_Temperatura_Media.xlsx # Registros de temperatura media mensual
│   │   └── Pago_Cuentas.xls          # Pagos por cuenta y período
│   └── processed/                    # Datos procesados (generados por scripts)
│       ├── Consumo_Central.csv/.xlsx  # Tabla 1: cuenta × período (Sede Central)
│       ├── Resumen_Sede.csv/.xlsx     # Tabla 2: resumen mensual sede
│       ├── Consumo_Final.csv/.xlsx    # Tabla 3: agregado total todas las cuentas
│       ├── Central_2022.csv/.xlsx     # Detalle por cuenta filtrado post-pandemia (2022+)
│       └── Resumen_Sede_2022.csv/.xlsx # Serie agregada filtrada post-pandemia (2022+)
├── scripts/
│   ├── 01_Preparacion_Datos.R            # Carga, limpieza, imputación y preparación de datos
│   ├── 02_Subsets_Exploracion.R          # Creación de subsets temporales y gráficos exploratorios
│   ├── 03_Analisis_Cuentas.R             # Análisis descriptivo por cuenta, ranking y factor M (CREG 199)
│   └── 04_Modelado_ARIMA.R               # EDA y modelado predictivo (ARIMA/SARIMAX)
│   └── README.md                         # Descripción de los scripts
├── notebooks/
│   ├── Taller_Regresion_Lineal_USCO.qmd     # Código fuente — Regresión Lineal
│   ├── Taller_Regresion_Logistica.qmd       # Código fuente — Regresión Logística
│   ├── Proyecto_Energia_USCO.qmd            # Análisis principal, pronóstico y anomalías
│   └── usco_apa.css                         # Estilos CSS para los reportes (.gitignore)
├── docs/
│   ├── Anteproyecto.docx                    # Anteproyecto del trabajo de grado
│   ├── diccionario_datos.md                 # Diccionario de variables
│   ├── Taller_Regresion_Lineal_USCO.html    # Reporte renderizado
│   └── Taller_Regresion_Logistica.html      # Reporte renderizado
└── .gitignore
```

## 🚀 Reproducción

### Requisitos

- **R** ≥ 4.3
- **Quarto** ≥ 1.4
- Paquetes de R: `readxl`, `dplyr`, `tidyr`, `writexl`, `here`, `ggplot2`, `knitr`, `kableExtra`, `scales`, `tsibble`, `feasts`, `fable`, `fabletools`, `forecast`, `tseries`, `urca`, `strucchange`, `FinTS`, `patchwork`, `lubridate`

### Pasos

1. Clonar el repositorio:
   ```bash
   git clone https://github.com/sergiobeg19/analisis-energia-usco.git
   ```

2. Abrir el proyecto en RStudio (`analisis-energia-usco.Rproj`).

3. Ejecutar la tubería de scripts de procesamiento:
   ```r
   source("scripts/01_Preparacion_Datos.R")     # Carga, limpieza, imputación y preparación de datos
   source("scripts/02_Subsets_Exploracion.R")   # Creación de subsets temporales y gráficos
   source("scripts/03_Analisis_Cuentas.R")      # Análisis por cuenta, ranking y factor M
   source("scripts/04_Modelado_ARIMA.R")        # Modelamiento y pronóstico ARIMA/SARIMA
   ```

4. Renderizar el reporte principal en formato HTML:
   ```bash
   quarto render notebooks/Proyecto_Energia_USCO.qmd
   ```

## 📊 Datos

| Tabla | Archivo | Granularidad | Generada por | Descripción |
|-------|---------|-------------|-------------|-------------|
| Tabla 1 | `Consumo_Central.csv` | Cuenta × período (5 cuentas) | Script 01 | Histórico completo de Sede Central |
| Tabla 2 | `Resumen_Sede.csv` | Período mensual (sede) | Script 01 | Histórico mensual agregado de Sede Central |
| Tabla 3 | `Consumo_Final.csv` | Período mensual (sede) | Script 02 | Histórico mensual de todas las cuentas |
| Tabla 4 | `Central_2022.csv` | Cuenta × período post-2022 | Script 03 | Detalle por cuenta filtrado post-pandemia (2022+) |
| Tabla 5 | `Resumen_Sede_2022.csv` | Período mensual post-2022 | Script 03 | Serie agregada post-pandemia con temperatura |

Consulta el [Diccionario de Datos](docs/diccionario_datos.md) para la descripción completa de cada variable.

## 📄 Documentos y Reportes

- [Anteproyecto](docs/Anteproyecto.docx) — Anteproyecto del trabajo de grado
- [Regresión Lineal](docs/Taller_Regresion_Lineal_USCO.html) — Activa → Reactiva (modelo simple y múltiple)
- [Regresión Logística](docs/Taller_Regresion_Logistica.html) — Predicción de incumplimiento normativo
- [Proyecto Principal (Quarto)](notebooks/Proyecto_Energia_USCO.qmd) — Documento fuente del análisis predictivo de energía, detección de anomalías y estimación CTER

## 👥 Autores

- Sergio Andrés Beltrán
- Juan Pablo Donato

**Programa:** Especialización en Estadística — Universidad Surcolombiana (USCO)

## 📜 Referencia Normativa

- **CREG 015 de 2018** y **CREG 199 de 2019** — Regulan el factor de potencia (límite R/A ≤ 0.50 para Niveles I y II, equivalente a un factor de potencia de 0.90 o reactiva equivalente al 50% de la activa). El incumplimiento reiterado genera el cobro del Cargo por Transporte de Energía Reactiva (CTER) con factor multiplicador M.
