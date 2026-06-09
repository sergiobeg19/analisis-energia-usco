# 💻 Scripts de Procesamiento y Análisis (scripts)

Este directorio alberga todo el motor computacional y matemático de la investigación. Todos los scripts están desarrollados en R.

## 🔄 Tubería de Ejecución (Pipeline)

Para reproducir los resultados, ejecuta los scripts en el siguiente orden secuencial:

1. **`01_Preparacion_Datos.R`**: Carga, limpieza, cruce con variables meteorológicas y estructuración base de series de tiempo.
2. **`01b_Estadisticas_Metodologia.R`**: Descriptivas preliminares.
3. **`01c_Validacion_Decisiones.R`**: Justificación y validación de técnicas de imputación de valores faltantes.
4. **`02_Subsets_Exploracion.R`**: Exploración visual por períodos históricos (Pandemia vs. Nueva Normalidad).
5. **`03_Analisis_Cuentas.R`**: Focalización por subestación, ranking de sobrecostos e identificación del factor penalizador M.
6. **`04_Modelado_ARIMA.R`**: Optimización y pronóstico de demanda energética mediante modelos clásicos (SARIMA/ARIMA).
7. **`05_Deteccion_Anomalias.R`**: Detección multicapa de atípicos estructurales en el tiempo.
8. **`06_Estimacion_CTER.R`**: Estimación matemática del riesgo económico y simulación de proyecciones tarifarias.
9. **`07_Modelos_Machine_Learning.R`**: Contraste predictivo con modelos no lineales (ExtraTrees, XGBoost).
10. **`08_Exportar_Tablas_PNG.R`**: Consolidación final y exportación visual estandarizada para Quarto.