# 📔 Notebooks y Código Fuente de Tesis (notebooks)

Este directorio contiene el código principal de redacción y ensamble computacional del documento final de la Tesis.

## 📄 Tesis Principal
- **`Tesis_Proyecto_Energia_USCO.qmd`:** Archivo central desarrollado en formato Quarto. Este documento ensambla el texto literario en estilo APA 7 con las tablas e imágenes (generadas por los scripts de R) para producir la versión exportable del trabajo de grado.

## 🚀 Compilación
Para renderizar el documento final de la tesis con el formato de normas APA, ejecuta en la consola:
```bash
quarto render Tesis_Proyecto_Energia_USCO.qmd --to docx
```

*(Nota: Adicionalmente se encuentran archivos de talleres previos como `Taller_Regresion_Lineal_USCO.qmd` correspondientes a la evolución inicial del proyecto).*