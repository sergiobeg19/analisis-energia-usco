# ⚙️ Datos Procesados y Gráficos (data/processed)

Este directorio está destinado a almacenar **exclusivamente los resultados autogenerados** por el pipeline de análisis de datos (scripts R).

## 📄 Contenido Temporal

Todos los archivos en esta carpeta (salvo este README) son generados por código y son ignorados por el sistema de control de versiones (`.gitignore`) para evitar saturar el repositorio. Incluyen:
- `*.csv` y `*.xlsx`: Bases de datos limpias, imputadas y agregadas temporalmente.
- `/plots/*.png`: Visualizaciones, diagnósticos de modelos ARIMA/Machine Learning, y proyecciones tarifarias (CTER).

**Nota de Reproducibilidad:** Si este directorio aparece vacío al clonar el repositorio, simplemente ejecuta los scripts de R localizados en `../scripts/` (del 01 al 08) en orden y la carpeta se poblará automáticamente.