# =============================================================================
# SCRIPT 07: Modelado de Machine Learning (XGBoost y ExtraTrees)
# Universidad Surcolombiana (USCO) — Sede Central
# =============================================================================
# INPUT:  data/processed/Serie_Sede_Desde2014.csv
#
# FLUJO:
#   1. Instalar y cargar paquetes (xgboost, ranger)
#   2. Cargar datos e ingeniería de características (lags, variables estacionales)
#   3. Partición de datos (Entrenamiento y Prueba de 6 meses)
#   4. Entrenamiento y predicción de XGBoost
#   5. Entrenamiento y predicción de ExtraTrees (ranger con splitrule = "extratrees")
#   6. Cálculo de métricas comparativas (RMSE, MAPE, MASE)
#   7. Consolidación de métricas con ARIMA (de la simulación de script 04)
#   8. Exportación de resultados y generación de gráficas
# =============================================================================

# ─────────────────────────────────────────────────────────────────────────────
# 0. PAQUETES
# ─────────────────────────────────────────────────────────────────────────────
paquetes <- c("readr", "dplyr", "tidyr", "ggplot2", "here", "lubridate", "xgboost", "ranger")
nuevos <- paquetes[!paquetes %in% installed.packages()[, "Package"]]
if (length(nuevos)) install.packages(nuevos, repos = "https://cran.r-project.org")

library(readr)
library(dplyr)
library(tidyr)
library(ggplot2)
library(here)
library(lubridate)
library(xgboost)
library(ranger)

# ─────────────────────────────────────────────────────────────────────────────
# 1. CARGA DE DATOS Y PREPARACIÓN DE CARACTERÍSTICAS
# ─────────────────────────────────────────────────────────────────────────────
cat("── Cargando datos consolidados de Sede Central...\n")
df_resumen <- read_csv(here("data", "processed", "Serie_Sede_Desde2014.csv"), show_col_types = FALSE)

# Crear características para series temporales (lags y variables estacionales)
cat("── Generando características (Lags y variables estacionales)...\n")
df_ml <- df_resumen %>%
  mutate(
    # Lags del target (Activa_Total)
    Lag_1 = lag(Activa_Total, 1),
    Lag_2 = lag(Activa_Total, 2),
    Lag_12 = lag(Activa_Total, 12),
    # Lags de Reactiva_Total (ayuda multivariada)
    Lag_Reactiva_1 = lag(Reactiva_Total, 1),
    Lag_Reactiva_12 = lag(Reactiva_Total, 12)
  ) %>%
  # Eliminar filas con NAs debido a los lags (primeros 12 meses)
  filter(!is.na(Lag_12))

# ─────────────────────────────────────────────────────────────────────────────
# 2. PARTICIÓN DE DATOS (Entrenamiento y Prueba)
# ─────────────────────────────────────────────────────────────────────────────
# Set de prueba: Últimos 6 meses (Febrero 2025 – Julio 2025)
n_test <- 6
n_total <- nrow(df_ml)

df_train <- df_ml %>% slice(1:(n_total - n_test))
df_test  <- df_ml %>% slice((n_total - n_test + 1):n_total)

# Definir variables predictoras y objetivo
target_var <- "Activa_Total"
pred_vars <- c("Lag_1", "Lag_2", "Lag_12", "Lag_Reactiva_1", "Lag_Reactiva_12",
               "Temperatura", "Vacaciones", "Mes", "Dummy_Pandemia", "Dummy_Normalidad")

# Matrices para XGBoost
X_train <- as.matrix(df_train[, pred_vars])
y_train <- df_train[[target_var]]
X_test  <- as.matrix(df_test[, pred_vars])
y_test  <- df_test[[target_var]]

# ─────────────────────────────────────────────────────────────────────────────
# 3. ENTRENAMIENTO DE MODELOS
# ─────────────────────────────────────────────────────────────────────────────
cat("── Entrenando modelo XGBoost...\n")
set.seed(42)
dtrain <- xgb.DMatrix(data = X_train, label = y_train)
# Ajustar hiperparámetros
params <- list(
  objective = "reg:squarederror",
  max_depth = 4,
  eta = 0.1,
  subsample = 0.8,
  colsample_bytree = 0.8
)
fit_xgb <- xgb.train(params = params, data = dtrain, nrounds = 80, verbose = 0)
pred_xgb <- predict(fit_xgb, X_test)

cat("── Entrenando modelo ExtraTrees...\n")
# ExtraTrees usando ranger con splitrule = "extratrees"
fit_et <- ranger(
  formula = as.formula(paste("Activa_Total ~", paste(pred_vars, collapse = " + "))),
  data = df_train,
  num.trees = 500,
  splitrule = "extratrees",
  seed = 42
)
pred_et <- predict(fit_et, data = df_test)$predictions

# ─────────────────────────────────────────────────────────────────────────────
# 4. CÁLCULO DE MÉTRICAS (MASE, RMSE, MAPE)
# ─────────────────────────────────────────────────────────────────────────────
# Función auxiliar para calcular MASE
# MASE = MAE_test / MAE_naive_insample
# donde el naive insample es un predictor estacional naive (lag 12)
calcular_mase <- function(reales_test, predicciones_test, reales_train) {
  mae_test <- mean(abs(reales_test - predicciones_test))
  # Naive estacional sobre el set de entrenamiento (lag 12)
  mae_naive <- mean(abs(reales_train[13:length(reales_train)] - reales_train[1:(length(reales_train)-12)]))
  return(mae_test / mae_naive)
}

calcular_metricas <- function(reales, predicciones, train_reales) {
  errores <- reales - predicciones
  mae  <- mean(abs(errores))
  rmse <- sqrt(mean(errores^2))
  mape <- mean(abs(errores / reales)) * 100
  mase <- calcular_mase(reales, predicciones, train_reales)
  return(list(MAE = mae, RMSE = rmse, MAPE = mape, MASE = mase))
}

metrics_xgb <- calcular_metricas(y_test, pred_xgb, df_train$Activa_Total)
metrics_et  <- calcular_metricas(y_test, pred_et, df_train$Activa_Total)

# ─────────────────────────────────────────────────────────────────────────────
# 5. CONSOLIDAR TABLA COMPARATIVA
# ─────────────────────────────────────────────────────────────────────────────
# Métricas de ARIMA ya obtenidas en el Script 04 (para que coincidan exactamente):
mae_naive_train <- mean(abs(df_train$Activa_Total[13:nrow(df_train)] - df_train$Activa_Total[1:(nrow(df_train)-12)]))

mase_auto <- 15305.47 / mae_naive_train
mase_manual <- 12540.47 / mae_naive_train
mase_vac <- 16002.67 / mae_naive_train
mase_temp <- 13946.87 / mae_naive_train
mase_mult <- 15506.81 / mae_naive_train

tabla_comparativa <- data.frame(
  Modelo = c("Auto ARIMA", "SARIMA Manual", "SARIMAX Vacaciones + Fases",
             "SARIMAX Temperatura + Fases", "SARIMAX Multivariado + Fases",
             "XGBoost", "ExtraTrees"),
  Especificacion = c("ARIMA(0,1,2)(2,1,0)[12]", "ARIMA(0,1,2)(1,1,1)[12]",
                     "ARIMAX(0,1,2)(1,0,1)[12] + Vac + Fases",
                     "ARIMAX(0,1,2)(1,0,1)[12] + Temp + Fases",
                     "ARIMAX(0,1,2)(1,0,1)[12] + Vac + Temp + Fases",
                     "XGBoost Regressor (nrounds=80, depth=4)",
                     "ranger ExtraTrees (ntree=500)"),
  AICc = c(3002.46, 2988.38, 3237.34, 3278.55, 3237.21, NA, NA),
  BIC = c(3016.14, 3002.06, 3262.28, 3303.49, 3264.75, NA, NA),
  MAE_Test = round(c(15305.47, 12540.47, 16002.67, 13946.87, 15506.81, metrics_xgb$MAE, metrics_et$MAE), 2),
  RMSE_Test = round(c(19559.03, 13634.58, 20549.07, 19355.26, 20031.05, metrics_xgb$RMSE, metrics_et$RMSE), 2),
  MAPE_Pct = round(c(9.02, 8.02, 9.59, 10.66, 9.17, metrics_xgb$MAPE, metrics_et$MAPE), 2),
  MASE_Test = round(c(mase_auto, mase_manual, mase_vac, mase_temp, mase_mult, metrics_xgb$MASE, metrics_et$MASE), 2)
)

print(tabla_comparativa)

# Exportar tabla
dir.create(here("data", "processed"), showWarnings = FALSE, recursive = TRUE)
write_csv(tabla_comparativa, here("data", "processed", "Model_Comparison_ML.csv"))
cat("   ✓ Tabla de comparación exportada a: data/processed/Model_Comparison_ML.csv\n")

# ─────────────────────────────────────────────────────────────────────────────
# 6. GRAFICAR PRONÓSTICOS COMPARATIVOS
# ─────────────────────────────────────────────────────────────────────────────
# Cargar predicciones de prueba de SARIMA
preds_sarima_df <- read_csv(here("data", "processed", "SARIMA_Test_Preds.csv"), show_col_types = FALSE)

# Crear data frame de test con las predicciones para graficar
df_grafico <- data.frame(
  Fecha = seq(from = make_date(2025, 2, 1), length.out = 6, by = "month"),
  Real = y_test,
  SARIMA_Manual = preds_sarima_df$SARIMA_Manual,
  XGBoost = pred_xgb,
  ExtraTrees = pred_et
)

df_long_grafico <- df_grafico %>%
  pivot_longer(
    cols = -Fecha,
    names_to = "Modelo",
    values_to = "Activa"
  )

p_comp <- ggplot(df_long_grafico, aes(x = Fecha, y = Activa / 1e3, color = Modelo, linetype = Modelo)) +
  geom_line(linewidth = 0.8) +
  geom_point(size = 1.5) +
  scale_color_manual(values = c("Real" = "black", "SARIMA_Manual" = "#2196F3",
                                "XGBoost" = "#FF9800", "ExtraTrees" = "#4CAF50")) +
  scale_linetype_manual(values = c("Real" = "solid", "SARIMA_Manual" = "dashed",
                                   "XGBoost" = "dotdash", "ExtraTrees" = "dotted")) +
  labs(title = "Comparativa de Pronósticos Fuera de Muestra (Febrero 2025 - Julio 2025)",
       subtitle = "Modelos Econométricos vs. Algoritmos de Machine Learning",
       x = "Fecha", y = "Consumo Activa (MWh)", color = "Modelo", linetype = "Modelo") +
  theme_minimal() +
  theme(legend.position = "bottom")

plot_dir <- here("data", "processed", "plots")
ggsave(filename = file.path(plot_dir, "Model_Comparison_Forecast.png"), plot = p_comp, width = 8, height = 4.5)
cat("   ✓ Gráfico comparativo de pronósticos guardado en: data/processed/plots/Model_Comparison_Forecast.png\n")

cat("\nProceso de modelado Machine Learning completado con éxito.\n")
