# ⚡ Análisis de Energía Eléctrica — Universidad Surcolombiana

Repositorio oficial del **Trabajo de Grado / Tesis** para la Especialización en Estadística de la Universidad Surcolombiana (USCO).

Este proyecto desarrolla un análisis estadístico avanzado del consumo eléctrico y del factor de potencia en la Sede Central de la USCO (2014–2025). Su objetivo es caracterizar el incumplimiento normativo, pronosticar la demanda de energía mediante series de tiempo y Machine Learning, detectar anomalías multicapa y cuantificar el impacto económico del riesgo tarifario asociado a la energía reactiva.

## 📋 Características y Metodología

El proyecto abarca el pipeline completo de ciencia de datos:
- **Análisis Exploratorio y Limpieza:** Imputación de datos faltantes, transformación de estructuras y agregación temporal.
- **Series de Tiempo (SARIMA):** Modelado predictivo clásico de la demanda de energía activa y reactiva.
- **Machine Learning (XGBoost y ExtraTrees):** Comparativa de modelos no lineales para el pronóstico de la relación R/A (Reactiva/Activa).
- **Detección de Anomalías Multicapa:** Identificación de rupturas estructurales, atípicos estadísticos y violaciones de la normativa.
- **Estimación Económica (CTER):** Cuantificación de los sobrecostos por penalizaciones regulatorias proyectadas en escenarios de inacción vs. mitigación.

## 📂 Estructura del Proyecto

```text
analisis-energia-usco/
├── data/
│   ├── raw/                          # Datos crudos (fuentes originales)
│   └── processed/                    # Datos procesados y gráficos autogenerados (ignorado por Git)
├── scripts/                          # Pipeline de procesamiento numérico y analítico
│   ├── 01_Preparacion_Datos.R        # Limpieza, imputación y estructura de series temporales
│   ├── 01b_Estadisticas_Metodologia.R# Estadísticas descriptivas preliminares
│   ├── 01c_Validacion_Decisiones.R   # Justificación de las imputaciones
│   ├── 02_Subsets_Exploracion.R      # Exploración visual de tendencias históricas
│   ├── 03_Analisis_Cuentas.R         # Desagregación por cuenta y focalización en anomalías
│   ├── 04_Modelado_ARIMA.R           # Modelado predictivo con SARIMA
│   ├── 05_Deteccion_Anomalias.R      # Detección multicapa de atípicos e incumplimientos
│   ├── 06_Estimacion_CTER.R          # Proyección económica de penalizaciones tarifarias
│   ├── 07_Modelos_Machine_Learning.R # Modelado avanzado (XGBoost, ExtraTrees)
│   └── 08_Exportar_Tablas_PNG.R      # Formateo y exportación de tablas para Quarto
├── notebooks/                        # Documentos y reportes
│   └── Tesis_Proyecto_Energia_USCO.qmd  # Código fuente de la tesis (Quarto APA 7)
├── docs/                             # Documentos complementarios y versiones renderizadas
└── README.md                         # Descripción del proyecto
```

## 🚀 Reproducción del Proyecto

### Requisitos Técnicos
- **R** ≥ 4.3
- **Quarto** ≥ 1.4
- **Paquetes Principales de R:** `tidyverse`, `lubridate`, `fpp3`, `forecast`, `tseries`, `isotree`, `xgboost`, `caret`, `flextable`, `here`.

### Pasos de Ejecución
Para reproducir la investigación desde cero:

1. **Clonar el repositorio:**
   ```bash
   git clone https://github.com/sergiobeg19/analisis-energia-usco.git
   ```

2. **Abrir el proyecto** en RStudio (`analisis-energia-usco.Rproj`).

3. **Ejecutar el Pipeline de Datos:**
   Debes ejecutar secuencialmente los scripts dentro de la carpeta `scripts/` (del `01` al `08`). Estos scripts leerán los datos crudos, entrenarán los modelos, realizarán los pronósticos y exportarán todos los `.csv` y gráficas `.png` necesarios a la carpeta `data/processed/`.

4. **Renderizar la Tesis Final:**
   Una vez ejecutados los scripts, compila el documento principal de Quarto para generar el archivo de Word final con el formato riguroso de normas APA 7:
   ```bash
   quarto render notebooks/Tesis_Proyecto_Energia_USCO.qmd --to docx
   ```

## 📜 Marcos de Referencia Normativos

El análisis estadístico y económico fundamenta sus parámetros en las siguientes normativas:
- **CREG 015 de 2018 y CREG 199 de 2019 (Colombia):** Regulan el límite del factor de potencia (R/A ≤ 0.50). Su incumplimiento reiterado activa el multiplicador penalizador $M$ del Cargo por Transporte de Energía Reactiva (CTER).
- **ISO 50001:2018/2019:** Sistema de Gestión de Energía. Estándar internacional que guía las recomendaciones estratégicas emitidas en este proyecto para la eficiencia energética institucional.

## 👥 Autores

- **Sergio Andrés Beltrán**
- **Juan Pablo Donato**

**Programa:** Especialización en Estadística — Universidad Surcolombiana (USCO).
