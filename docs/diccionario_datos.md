# Diccionario de Datos

Descripción detallada de todas las variables utilizadas en el análisis de energía eléctrica.

| Nombre de la Variable | Descripción | Unidad de Medida | Formato |
|---|---|---|---|
| fecha | Fecha de registro del consumo | Día | YYYY-MM-DD |
| consumo_energia | Consumo de energía activa registrado | kWh | Numérico (decimal) |
| factor_potencia | Factor de potencia medido | Adimensional | Numérico (0-1) |
| energia_reactiva | Energía reactiva consumida | kVArh | Numérico (decimal) |
| demanda_pico | Demanda máxima durante el período | kW | Numérico (decimal) |
| temperatura_ambiente | Temperatura ambiental durante el período | °C | Numérico (decimal) |
| humedad_relativa | Humedad relativa del aire | % | Numérico (0-100) |
| periodo_tarifa | Clasificación del período tarifario | Categoría | Texto (Punta, Llano, Valle) |
| costo_energia | Costo de la energía consumida | COP | Numérico (entero) |
| penalizacion_reactiva | Penalización por energía reactiva | COP | Numérico (entero) |
| anomalia_detectada | Indica si se detectó anomalía | Booleano | 0/1 (No/Sí) |

## Notas

- Los datos históricos comprenden el período 2001-2025
- Todos los consumos se registran en la Sede Central de la Universidad Surcolombiana
- Las variables se actualizan mensualmente
- Los costos están expresados en Pesos Colombianos (COP)
