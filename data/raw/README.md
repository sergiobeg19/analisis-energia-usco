# 📥 Datos Crudos (data/raw)

Este directorio contiene los **datasets originales y no modificados** provistos por las fuentes primarias institucionales o meteorológicas.

## 📄 Descripción de las Fuentes Principales
- **Consumo_Cuentas_.xlsx:** Consumo histórico mensual (energía activa y reactiva) de la Sede Central.
- **Pago_Cuentas.xls:** Registros históricos de facturación.
- **Datos_Temperatura_Med.xlsx / Datos_Precipitacion_media.xlsx:** Variables climáticas provistas por el IDEAM utilizadas como regresores externos (xreg) en los modelos predictivos.

**Regla de Oro:** Los archivos contenidos en esta carpeta **nunca** deben ser alterados, sobrescritos o limpiados manualmente. Toda limpieza o imputación de datos debe realizarse a través de código programático en la carpeta `../scripts/` (comenzando por `01_Preparacion_Datos.R`).