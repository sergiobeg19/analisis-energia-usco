# =============================================================================
# SCRIPT 04: Modelado ARIMA / SARIMA / SARIMAX — Serie de Consumo Eléctrico
# Universidad Surcolombiana (USCO) — Sede Central
# =============================================================================
# INPUT:  data/processed/Serie_Sede_Desde2014.csv
#
# FLUJO:
#   1. Construir objeto ts mensual para Activa y Reactiva
#   2. Análisis visual y descomposición STL
#   3. Estacionariedad y determinación de d
#   4. Ajustes automáticos (auto.arima) y manuales (SARIMA)
#   5. Ajustes SARIMAX (con covariables Vacaciones y Temperatura, D = 0)
#   6. Validación Rolling-Origin para los 5 modelos
#   7. Diagnósticos de residuos avanzados (Q-Q, Ljung-Box)
#   8. Pronóstico 6 meses con proyección de regresores externos
# =============================================================================

# ─────────────────────────────────────────────────────────────────────────────
# 0. PAQUETES
# ─────────────────────────────────────────────────────────────────────────────
paquetes <- c("readr", "dplyr", "ggplot2", "forecast", "tseries",
              "urca", "strucchange", "FinTS", "here", "patchwork",
              "fable", "tsibble", "feasts", "fabletools", "lubridate", "readxl")
nuevos <- paquetes[!paquetes %in% installed.packages()[, "Package"]]
if (length(nuevos)) install.packages(nuevos, repos = "https://cran.r-project.org")

library(readr)
library(dplyr)
library(ggplot2)
library(forecast)
library(tseries)
library(urca)
library(strucchange)
library(FinTS)
library(here)
library(patchwork)
library(tsibble)
library(feasts)
library(fable)
library(fabletools)
library(lubridate)
library(readxl)

# ─────────────────────────────────────────────────────────────────────────────
# FUNCIÓN AUXILIAR DE MODELAMIENTO COMPLETO
# ─────────────────────────────────────────────────────────────────────────────
analizar_y_modelar_serie <- function(y_vector, nombre_variable, label_corto, df, mostrar_plots = TRUE) {
  cat(sprintf("\n===================================================\n"))
  cat(sprintf(" INICIANDO ANÁLISIS: %s\n", toupper(nombre_variable)))
  cat(sprintf("===================================================\n"))
  
  # Directorio para guardar gráficos
  plot_dir <- here("data", "processed", "plots")
  dir.create(plot_dir, recursive = TRUE, showWarnings = FALSE)
  
  # 1. Objeto TS
  ts_y <- ts(y_vector, start = c(df$Ano[1], df$Mes[1]), frequency = 12)
  n <- length(ts_y)
  
  # 2. Visualización Exploratoria
  cat("── Generando gráficos exploratorios...\n")
  
  # 2a. Serie cruda
  p1 <- autoplot(ts_y) +
    labs(title = paste("Consumo mensual - Sede Central (", nombre_variable, ")", sep=""),
         x = "Año", y = nombre_variable) +
    theme_minimal()
  ggsave(filename = file.path(plot_dir, paste(label_corto, "_01_raw.png", sep="")), plot = p1, width = 8, height = 4)
  if (mostrar_plots) print(p1)
  
  # 2b. Descomposición STL
  stl_fit <- stl(ts_y, s.window = "periodic", robust = TRUE)
  p2 <- autoplot(stl_fit) +
    labs(title = paste("Descomposición STL -", nombre_variable)) +
    theme_minimal()
  ggsave(filename = file.path(plot_dir, paste(label_corto, "_02_stl.png", sep="")), plot = p2, width = 8, height = 6)
  if (mostrar_plots) print(p2)
  
  # 2c. Seasonal subseries
  p3 <- ggseasonplot(ts_y, year.labels = TRUE, continuous = TRUE) +
    labs(title = paste("Patrón estacional por año -", nombre_variable), x = "Mes", y = nombre_variable) +
    theme_minimal()
  ggsave(filename = file.path(plot_dir, paste(label_corto, "_03_seasonal.png", sep="")), plot = p3, width = 8, height = 4)
  if (mostrar_plots) print(p3)
  
  # 2d. Boxplot mensual
  df_box <- df %>% mutate(Mes_label = month.abb[Mes])
  p4 <- ggplot(df_box, aes(x = factor(Mes, labels = month.abb), y = y_vector)) +
    geom_boxplot(fill = "#B5D4F4", color = "#185FA5") +
    labs(title = paste("Distribución por mes del año -", nombre_variable),
         x = "Mes", y = nombre_variable) +
    theme_minimal()
  ggsave(filename = file.path(plot_dir, paste(label_corto, "_04_boxplot.png", sep="")), plot = p4, width = 8, height = 4)
  if (mostrar_plots) print(p4)
  
  # 3. Estacionariedad
  cat("\n── Pruebas de estacionariedad...\n")
  adf_nivel  <- adf.test(ts_y)
  kpss_nivel <- kpss.test(ts_y, null = "Level")
  
  cat(sprintf("   ADF  (nivel)  : estadístico = %.4f,  p = %.4f\n", adf_nivel$statistic, adf_nivel$p.value))
  cat(sprintf("   KPSS (nivel)  : estadístico = %.4f,  p = %.4f\n", kpss_nivel$statistic, kpss_nivel$p.value))
  
  if (adf_nivel$p.value < 0.05 && kpss_nivel$p.value > 0.05) {
    cat("   → Serie ESTACIONARIA en nivel. Se usará d = 0.\n")
    d_optimo <- 0
  } else {
    cat("   → Serie posiblemente NO estacionaria. Probando primera diferencia...\n")
    ts_diff1 <- diff(ts_y)
    adf_diff1 <- adf.test(ts_diff1)
    kpss_diff1 <- kpss.test(ts_diff1, null = "Level")
    cat(sprintf("   ADF  (diff-1) : estadístico = %.4f,  p = %.4f\n", adf_diff1$statistic, adf_diff1$p.value))
    cat(sprintf("   KPSS (diff-1) : estadístico = %.4f,  p = %.4f\n", kpss_diff1$statistic, kpss_diff1$p.value))
    d_optimo <- ifelse(adf_diff1$p.value < 0.05, 1, 2)
    cat(sprintf("   → Se usará d = %d.\n", d_optimo))
  }
  
  # 4. ACF / PACF
  ts_para_acf <- if (d_optimo == 0) ts_y else diff(ts_y, differences = d_optimo)
  p_acf  <- ggAcf(ts_para_acf,  lag.max = 24) + labs(title = "ACF") + theme_minimal()
  p_pacf <- ggPacf(ts_para_acf, lag.max = 24) + labs(title = "PACF") + theme_minimal()
  p5 <- p_acf + p_pacf
  ggsave(filename = file.path(plot_dir, paste(label_corto, "_05_acf_pacf.png", sep="")), plot = p5, width = 10, height = 4)
  if (mostrar_plots) print(p5)
  
  # 5. Ajustes de Modelos
  cat("\n── Ajustando modelos...\n")
  
  # 5a. Modelo Automático
  fit_auto <- auto.arima(ts_y, d = d_optimo, D = 1, stepwise = FALSE, approximation = FALSE, ic = "aicc")
  cat("   ✓ Modelo auto.arima ajustado:", as.character(fit_auto), "\n")
  
  # 5b. Búsqueda SARIMA Manual (AICc óptimo)
  p_range <- 0:2; q_range <- 0:2; P_range <- 0:1; Q_range <- 0:1
  resultados <- list(); idx <- 1
  for (p in p_range) for (q in q_range) for (P in P_range) for (Q in Q_range) {
    if ((p + q + P + Q) > 4) next
    tryCatch({
      m <- Arima(ts_y, order = c(p, d_optimo, q), seasonal = list(order = c(P, 1, Q), period = 12), include.constant = TRUE)
      resultados[[idx]] <- data.frame(p = p, d = d_optimo, q = q, P = P, D = 1, Q = Q, AICc = m$aicc)
      idx <- idx + 1
    }, error = function(e) NULL)
  }
  tabla_manual <- bind_rows(resultados) %>% arrange(AICc)
  best_manual <- tabla_manual[1, ]
  fit_manual <- Arima(ts_y, order = c(best_manual$p, best_manual$d, best_manual$q),
                      seasonal = list(order = c(best_manual$P, best_manual$D, best_manual$Q), period = 12),
                      include.constant = TRUE)
  cat("   ✓ Modelo manual seleccionado:", as.character(fit_manual), "\n")
  
  # 5c. Modelos SARIMAX (D = 0 para evitar singularidades estacionales)
  xreg_vac <- matrix(cbind(df$Vacaciones, df$Dummy_Pandemia, df$Dummy_Normalidad), ncol = 3,
                     dimnames = list(NULL, c("Vacaciones", "Dummy_Pandemia", "Dummy_Normalidad")))
  xreg_temp <- matrix(cbind(df$Temperatura, df$Dummy_Pandemia, df$Dummy_Normalidad), ncol = 3,
                      dimnames = list(NULL, c("Temperatura", "Dummy_Pandemia", "Dummy_Normalidad")))
  xreg_mult <- matrix(cbind(df$Vacaciones, df$Temperatura, df$Dummy_Pandemia, df$Dummy_Normalidad), ncol = 4,
                      dimnames = list(NULL, c("Vacaciones", "Temperatura", "Dummy_Pandemia", "Dummy_Normalidad")))
  
  p_m <- best_manual$p; d_m <- best_manual$d; q_m <- best_manual$q
  P_m <- best_manual$P; Q_m <- best_manual$Q
  
  fit_x_vac <- Arima(ts_y, order = c(p_m, d_m, q_m), seasonal = list(order = c(P_m, 0, Q_m), period = 12), xreg = xreg_vac, include.constant = TRUE)
  fit_x_temp <- Arima(ts_y, order = c(p_m, d_m, q_m), seasonal = list(order = c(P_m, 0, Q_m), period = 12), xreg = xreg_temp, include.constant = TRUE)
  fit_x_mult <- Arima(ts_y, order = c(p_m, d_m, q_m), seasonal = list(order = c(P_m, 0, Q_m), period = 12), xreg = xreg_mult, include.constant = TRUE)
  
  cat("   ✓ Modelo SARIMAX (Vacaciones + Fases) ajustado\n")
  cat("   ✓ Modelo SARIMAX (Temperatura + Fases) ajustado\n")
  cat("   ✓ Modelo SARIMAX (Multivariado + Fases) ajustado\n")
  
  # 6. Validación Rolling-Origin Cruzada (últimos 6 meses)
  cat("\n── Ejecutando validación Rolling-Origin (fuera de muestra, h = 1)...\n")
  h_test <- 6
  n_train0 <- n - h_test
  
  err_auto <- numeric(h_test); err_manual <- numeric(h_test)
  err_x_vac <- numeric(h_test); err_x_temp <- numeric(h_test); err_x_mult <- numeric(h_test)
  
  for (k in seq_len(h_test)) {
    end_idx <- n_train0 + k - 1
    ts_train <- ts(y_vector[1:end_idx], start = c(df$Ano[1], df$Mes[1]), frequency = 12)
    real_y <- y_vector[end_idx + 1]
    
    # auto.arima
    tryCatch({
      m_auto <- Arima(ts_train, order = fit_auto$arma[c(1, 6, 2)], seasonal = list(order = fit_auto$arma[c(3, 7, 4)], period = 12))
      err_auto[k] <- real_y - forecast(m_auto, h = 1)$mean[1]
    }, error = function(e) { err_auto[k] <<- NA })
    
    # manual
    tryCatch({
      m_manual <- Arima(ts_train, order = c(p_m, d_m, q_m), seasonal = list(order = c(P_m, 1, Q_m), period = 12))
      err_manual[k] <- real_y - forecast(m_manual, h = 1)$mean[1]
    }, error = function(e) { err_manual[k] <<- NA })
    
    # SARIMAX Vac
    tryCatch({
      m_x_vac <- Arima(ts_train, order = c(p_m, d_m, q_m), seasonal = list(order = c(P_m, 0, Q_m), period = 12), xreg = xreg_vac[1:end_idx, , drop=FALSE])
      err_x_vac[k] <- real_y - forecast(m_x_vac, h = 1, xreg = xreg_vac[end_idx + 1, , drop=FALSE])$mean[1]
    }, error = function(e) { err_x_vac[k] <<- NA })
    
    # SARIMAX Temp
    tryCatch({
      m_x_temp <- Arima(ts_train, order = c(p_m, d_m, q_m), seasonal = list(order = c(P_m, 0, Q_m), period = 12), xreg = xreg_temp[1:end_idx, , drop=FALSE])
      err_x_temp[k] <- real_y - forecast(m_x_temp, h = 1, xreg = xreg_temp[end_idx + 1, , drop=FALSE])$mean[1]
    }, error = function(e) { err_x_temp[k] <<- NA })
    
    # SARIMAX Mult
    tryCatch({
      m_x_mult <- Arima(ts_train, order = c(p_m, d_m, q_m), seasonal = list(order = c(P_m, 0, Q_m), period = 12), xreg = xreg_mult[1:end_idx, , drop=FALSE])
      err_x_mult[k] <- real_y - forecast(m_x_mult, h = 1, xreg = xreg_mult[end_idx + 1, , drop=FALSE])$mean[1]
    }, error = function(e) { err_x_mult[k] <<- NA })
  }
  
  met_auto <- calcular_metricas_error(y_vector[(n-h_test+1):n], y_vector[(n-h_test+1):n] - err_auto)
  met_manual <- calcular_metricas_error(y_vector[(n-h_test+1):n], y_vector[(n-h_test+1):n] - err_manual)
  met_x_vac <- calcular_metricas_error(y_vector[(n-h_test+1):n], y_vector[(n-h_test+1):n] - err_x_vac)
  met_x_temp <- calcular_metricas_error(y_vector[(n-h_test+1):n], y_vector[(n-h_test+1):n] - err_x_temp)
  met_x_mult <- calcular_metricas_error(y_vector[(n-h_test+1):n], y_vector[(n-h_test+1):n] - err_x_mult)
  
  # 7. Tabla Comparativa Resumen
  resumen <- data.frame(
    Modelo = c("Auto ARIMA", "SARIMA Manual", "SARIMAX Vacaciones + Fases", "SARIMAX Temperatura + Fases", "SARIMAX Multivariado + Fases"),
    Especificacion = c(
      as.character(fit_auto),
      sprintf("ARIMA(%d,%d,%d)(%d,1,%d)[12]", p_m, d_m, q_m, P_m, Q_m),
      sprintf("ARIMAX(%d,%d,%d)(%d,0,%d)[12] + Vac + Fases", p_m, d_m, q_m, P_m, Q_m),
      sprintf("ARIMAX(%d,%d,%d)(%d,0,%d)[12] + Temp + Fases", p_m, d_m, q_m, P_m, Q_m),
      sprintf("ARIMAX(%d,%d,%d)(%d,0,%d)[12] + Vac + Temp + Fases", p_m, d_m, q_m, P_m, Q_m)
    ),
    AICc = round(c(fit_auto$aicc, fit_manual$aicc, fit_x_vac$aicc, fit_x_temp$aicc, fit_x_mult$aicc), 2),
    BIC = round(c(BIC(fit_auto), BIC(fit_manual), BIC(fit_x_vac), BIC(fit_x_temp), BIC(fit_x_mult)), 2),
    MAE_Test = round(c(met_auto$MAE, met_manual$MAE, met_x_vac$MAE, met_x_temp$MAE, met_x_mult$MAE), 2),
    RMSE_Test = round(c(met_auto$RMSE, met_manual$RMSE, met_x_vac$RMSE, met_x_temp$RMSE, met_x_mult$RMSE), 2),
    MAPE_Test_Pct = round(c(met_auto$MAPE, met_manual$MAPE, met_x_vac$MAPE, met_x_temp$MAPE, met_x_mult$MAPE), 2)
  )
  # Exportar predicciones de prueba de Activa para comparativa con ML
  if (label_corto == "Activa") {
    pred_test_manual <- y_vector[(n-h_test+1):n] - err_manual
    write_csv(data.frame(SARIMA_Manual = pred_test_manual), here("data", "processed", "SARIMA_Test_Preds.csv"))
  }
  
  cat("\n═══════════════════════════════════════════════════\n")
  cat(sprintf("  COMPARATIVA DE MODELOS — %s\n", toupper(label_corto)))
  cat("═══════════════════════════════════════════════════\n")
  print(resumen)
  cat("═══════════════════════════════════════════════════\n")
  
  # 8. Selección del Mejor Modelo según el menor MAPE fuera de muestra
  best_idx <- which.min(resumen$MAPE_Test_Pct)
  mejor_modelo_nombre <- resumen$Modelo[best_idx]
  cat(sprintf("\n  → MEJOR MODELO predictivo: %s (MAPE = %.2f%%)\n", mejor_modelo_nombre, resumen$MAPE_Test_Pct[best_idx]))
  
  # Asignar objeto correspondiente al mejor modelo
  fit_final <- switch(
    best_idx,
    fit_auto,
    fit_manual,
    fit_x_vac,
    fit_x_temp,
    fit_x_mult
  )
  
  # 9. Diagnósticos Avanzados del Modelo Final
  cat("\n── Ejecutando diagnósticos del modelo final...\n")
  res <- residuals(fit_final)
  
  # 9a. Shapiro-Wilk (Normalidad)
  sw <- shapiro.test(res)
  cat(sprintf("   Test de Shapiro-Wilk: W = %.4f, p = %.4f (Normalidad: %s)\n",
              sw$statistic, sw$p.value, ifelse(sw$p.value > 0.05, "✓ ACEPTADA", "⚠ RECHAZADA")))
  
  # 9b. Q-Q Plot
  df_res <- data.frame(Residuos = as.numeric(res))
  p6 <- ggplot(df_res, aes(sample = Residuos)) +
    stat_qq(color = "#185FA5") +
    stat_qq_line(color = "red") +
    labs(title = paste("Gráfico Q-Q de Residuos -", nombre_variable),
         x = "Valores teóricos", y = "Residuos observados") +
    theme_minimal()
  ggsave(filename = file.path(plot_dir, paste(label_corto, "_06_residuals_qq.png", sep="")), plot = p6, width = 6, height = 4)
  if (mostrar_plots) print(p6)
  
  # 9c. Test de Ljung-Box en lags 1 a 24
  lags_lb <- 1:24
  fitdf_val <- sum(fit_final$arma[c(1, 2, 3, 4)])
  pvals <- sapply(lags_lb, function(l) {
    if (fitdf_val >= l) return(NA_real_)
    Box.test(res, lag = l, type = "Ljung-Box", fitdf = fitdf_val)$p.value
  })
  df_lb <- data.frame(Lag = lags_lb, PValue = pvals)
  
  p7 <- ggplot(df_lb, aes(x = Lag, y = PValue)) +
    geom_hline(yintercept = 0.05, linetype = "dashed", color = "red", size = 0.8) +
    geom_point(color = "#185FA5", size = 2) +
    geom_segment(aes(x = Lag, xend = Lag, y = 0, yend = PValue), color = "gray") +
    labs(title = paste("P-values del Test de Ljung-Box por Lag -", nombre_variable),
         y = "P-value", x = "Lag (Retardo)") +
    scale_y_continuous(limits = c(0, 1)) +
    theme_minimal()
  ggsave(filename = file.path(plot_dir, paste(label_corto, "_07_residuals_ljungbox.png", sep="")), plot = p7, width = 8, height = 4)
  if (mostrar_plots) print(p7)
  
  # 10. Pronóstico a futuro (6 meses)
  cat("\n── Generando pronóstico a futuro (6 meses)...\n")
  h_pronostico <- 6
  
  # Definir fechas futuras
  ultimo_periodo <- as.Date(paste(df$Ano[nrow(df)], df$Mes[nrow(df)], "01", sep="-"))
  fechas_futuras <- seq(from = ultimo_periodo + months(1), length.out = h_pronostico, by = "month")
  meses_futuros <- as.numeric(format(fechas_futuras, "%m"))
  
  # Proyectar regresores para pronóstico
  future_vac <- ifelse(meses_futuros %in% c(1, 6, 7, 12), 1L, 0L)
  
  # Temperatura proyectada como el promedio histórico del mes de la muestra
  temp_mensual_prom <- df %>%
    group_by(Mes) %>%
    summarise(Mean_Temp = mean(Temperatura, na.rm = TRUE), .groups = "drop")
  future_temp <- left_join(data.frame(Mes = meses_futuros), temp_mensual_prom, by = "Mes")$Mean_Temp
  
  # Hacer forecast según el tipo del mejor modelo
  future_pandemia <- rep(0L, h_pronostico)
  future_normalidad <- rep(1L, h_pronostico)
  
  if (best_idx == 1 || best_idx == 2) {
    # Modelo puramente ARIMA/SARIMA
    fc <- forecast(fit_final, h = h_pronostico)
  } else if (best_idx == 3) {
    # SARIMAX Vac + Fases
    newxreg <- matrix(cbind(future_vac, future_pandemia, future_normalidad), ncol = 3,
                      dimnames = list(NULL, c("Vacaciones", "Dummy_Pandemia", "Dummy_Normalidad")))
    fc <- forecast(fit_final, h = h_pronostico, xreg = newxreg)
  } else if (best_idx == 4) {
    # SARIMAX Temp + Fases
    newxreg <- matrix(cbind(future_temp, future_pandemia, future_normalidad), ncol = 3,
                      dimnames = list(NULL, c("Temperatura", "Dummy_Pandemia", "Dummy_Normalidad")))
    fc <- forecast(fit_final, h = h_pronostico, xreg = newxreg)
  } else {
    # SARIMAX Mult + Fases
    newxreg <- matrix(cbind(future_vac, future_temp, future_pandemia, future_normalidad), ncol = 4,
                      dimnames = list(NULL, c("Vacaciones", "Temperatura", "Dummy_Pandemia", "Dummy_Normalidad")))
    fc <- forecast(fit_final, h = h_pronostico, xreg = newxreg)
  }
  
  # Imprimir tabla de predicciones
  fc_df <- data.frame(
    Mes_Pronostico = format(fechas_futuras, "%Y-%m"),
    Punto = round(as.numeric(fc$mean)),
    IC80_inf = round(as.numeric(fc$lower[, 1])),
    IC80_sup = round(as.numeric(fc$upper[, 1])),
    IC95_inf = round(as.numeric(fc$lower[, 2])),
    IC95_sup = round(as.numeric(fc$upper[, 2]))
  )
  print(fc_df)
  
  # Graficar y guardar pronóstico
  p8 <- autoplot(fc) +
    labs(title = paste("Pronóstico futuro 6 meses -", nombre_variable, "(", mejor_modelo_nombre, ")", sep=""),
         x = "Año", y = nombre_variable) +
    theme_minimal()
  ggsave(filename = file.path(plot_dir, paste(label_corto, "_08_forecast.png", sep="")), plot = p8, width = 8, height = 4)
  if (mostrar_plots) print(p8)
  
  return(resumen)
}

# Helper para calcular métricas
calcular_metricas_error <- function(reales, predicciones) {
  errores <- reales - predicciones
  mae  <- mean(abs(errores), na.rm = TRUE)
  rmse <- sqrt(mean(errores^2, na.rm = TRUE))
  mape <- mean(abs(errores / reales), na.rm = TRUE) * 100
  return(list(MAE = mae, RMSE = rmse, MAPE = mape))
}

# ─────────────────────────────────────────────────────────────────────────────
# 2. EJECUCIÓN PRINCIPAL DEL MODELADO
# ─────────────────────────────────────────────────────────────────────────────
# Cargar datos
df_resumen <- read_csv(here("data", "processed", "Serie_Sede_Desde2014.csv"), show_col_types = FALSE)

# Modelar Energía Activa
res_activa <- analizar_y_modelar_serie(
  y_vector = df_resumen$Activa_Total,
  nombre_variable = "Energía Activa (kWh)",
  label_corto = "Activa",
  df = df_resumen
)

# Modelar Energía Reactiva
res_reactiva <- analizar_y_modelar_serie(
  y_vector = df_resumen$Reactiva_Total,
  nombre_variable = "Energía Reactiva (kVArh)",
  label_corto = "Reactiva",
  df = df_resumen
)

# ─────────────────────────────────────────────────────────────────────────────
# 3. MODELADO DE LA RELACIÓN R/A CON TRANSFORMACIÓN LOGIT
# ─────────────────────────────────────────────────────────────────────────────
cat("\n===================================================\n")
cat(" INICIANDO ANÁLISIS: RELACIÓN R/A (CON LOGIT)\n")
cat("===================================================\n")

# Calcular relación agregada
relacion_total <- df_resumen$Reactiva_Total / df_resumen$Activa_Total

# Generar y guardar gráficos exploratorios para la Relación R/A
plot_dir <- here("data", "processed", "plots")
ts_ra <- ts(relacion_total, start = c(df_resumen$Ano[1], df_resumen$Mes[1]), frequency = 12)

# 1. Serie cruda
p1_ra <- autoplot(ts_ra) +
  labs(title = "Relación R/A mensual - Sede Central", x = "Año", y = "Relación R/A") +
  theme_minimal()
ggsave(filename = file.path(plot_dir, "Relacion_01_raw.png"), plot = p1_ra, width = 8, height = 4)

# 2. Descomposición STL
stl_fit_ra <- stl(ts_ra, s.window = "periodic", robust = TRUE)
p2_ra <- autoplot(stl_fit_ra) +
  labs(title = "Descomposición STL - Relación R/A") +
  theme_minimal()
ggsave(filename = file.path(plot_dir, "Relacion_02_stl.png"), plot = p2_ra, width = 8, height = 6)

# 3. Estacionalidad
p3_ra <- ggseasonplot(ts_ra, year.labels = TRUE, continuous = TRUE) +
  labs(title = "Patrón estacional por año - Relación R/A", x = "Mes", y = "Relación R/A") +
  theme_minimal()
ggsave(filename = file.path(plot_dir, "Relacion_03_seasonal.png"), plot = p3_ra, width = 8, height = 4)

# 4. Boxplot
df_box_ra <- df_resumen %>% mutate(Mes_label = month.abb[Mes])
p4_ra <- ggplot(df_box_ra, aes(x = factor(Mes, labels = month.abb), y = relacion_total)) +
  geom_boxplot(fill = "#B5D4F4", color = "#185FA5") +
  labs(title = "Distribución por mes del año - Relación R/A", x = "Mes", y = "Relación R/A") +
  theme_minimal()
ggsave(filename = file.path(plot_dir, "Relacion_04_boxplot.png"), plot = p4_ra, width = 8, height = 4)

# Aplicar transformación logit
logit_y <- log(relacion_total / (1 - relacion_total))

# Objeto TS para la serie logit
ts_logit <- ts(logit_y, start = c(df_resumen$Ano[1], df_resumen$Mes[1]), frequency = 12)

# Pruebas de Estacionariedad
cat("── Pruebas de estacionariedad (Logit R/A)...\n")
adf_logit <- adf.test(ts_logit)
kpss_logit <- kpss.test(ts_logit)
cat(sprintf("   ADF  (nivel)  : estadístico = %.4f,  p = %.4f\n", adf_logit$statistic, adf_logit$p.value))
cat(sprintf("   KPSS (nivel)  : estadístico = %.4f,  p = %.4f\n", kpss_logit$statistic, kpss_logit$p.value))

# Determinar d si es necesario
d_select <- 0
if (adf_logit$p.value > 0.05 && kpss_logit$p.value < 0.05) {
  cat("   → Serie posiblemente NO estacionaria. Probando primera diferencia...\n")
  ts_diff <- diff(ts_logit)
  adf_diff <- adf.test(ts_diff)
  kpss_diff <- kpss.test(ts_diff, null = "Level")
  cat(sprintf("   ADF  (diff-1) : estadístico = %.4f,  p = %.4f\n", adf_diff$statistic, adf_diff$p.value))
  cat(sprintf("   KPSS (diff-1) : estadístico = %.4f,  p = %.4f\n", kpss_diff$statistic, kpss_diff$p.value))
  d_select <- 1
} else {
  cat("   → Serie estacionaria en nivel (d = 0)\n")
}

# Ajuste automático del modelo ARIMA
fit_logit <- auto.arima(ts_logit, d = d_select, seasonal = TRUE)
cat(sprintf("   ✓ Modelo auto.arima ajustado: %s\n", as.character(fit_logit)))

# Resumen de diagnósticos de residuos
cat("── Diagnósticos de residuos...\n")
box_test <- Box.test(residuals(fit_logit), lag = 24, type = "Ljung-Box")
shapiro_test <- shapiro.test(residuals(fit_logit))
cat(sprintf("   Test Ljung-Box (lag=24): p = %.4f\n", box_test$p.value))
cat(sprintf("   Test Shapiro-Wilk      : p = %.4f\n", shapiro_test$p.value))

# Pronóstico a 6 meses
cat("── Generando pronóstico a futuro (6 meses)...\n")
fc_logit <- forecast(fit_logit, h = 6)

# Aplicar transformación inversa logit: 1 / (1 + exp(-x))
inv_logit <- function(x) {
  1 / (1 + exp(-x))
}

fechas_futuras <- seq(from = make_date(df_resumen$Ano[nrow(df_resumen)], df_resumen$Mes[nrow(df_resumen)], 1) + months(1),
                      length.out = 6, by = "month")

fc_ra_df <- data.frame(
  Mes_Pronostico = format(fechas_futuras, "%Y-%m"),
  Punto = round(inv_logit(as.numeric(fc_logit$mean)), 4),
  IC80_inf = round(inv_logit(as.numeric(fc_logit$lower[, 1])), 4),
  IC80_sup = round(inv_logit(as.numeric(fc_logit$upper[, 1])), 4),
  IC95_inf = round(inv_logit(as.numeric(fc_logit$lower[, 2])), 4),
  IC95_sup = round(inv_logit(as.numeric(fc_logit$upper[, 2])), 4)
)

print(fc_ra_df)

# Exportar pronóstico a CSV
write_csv(fc_ra_df, here("data", "processed", "RA_Forecast_Logit.csv"))

# Graficar y guardar pronóstico en escala original R/A
plot_dir <- here("data", "processed", "plots")

# Crear data frame histórico para graficar junto al pronóstico
hist_df <- data.frame(
  Fecha = make_date(df_resumen$Ano, df_resumen$Mes, 1),
  Relacion = relacion_total,
  Tipo = "Histórico"
)

fc_plot_df <- data.frame(
  Fecha = fechas_futuras,
  Relacion = fc_ra_df$Punto,
  IC80_inf = fc_ra_df$IC80_inf,
  IC80_sup = fc_ra_df$IC80_sup,
  IC95_inf = fc_ra_df$IC95_inf,
  IC95_sup = fc_ra_df$IC95_sup,
  Tipo = "Pronóstico"
)

p_ra <- ggplot() +
  geom_line(data = hist_df, aes(x = Fecha, y = Relacion, color = Tipo), linewidth = 0.6) +
  geom_line(data = fc_plot_df, aes(x = Fecha, y = Relacion, color = Tipo), linewidth = 0.7) +
  geom_ribbon(data = fc_plot_df, aes(x = Fecha, ymin = IC95_inf, ymax = IC95_sup, fill = "IC 95%"), alpha = 0.15) +
  geom_ribbon(data = fc_plot_df, aes(x = Fecha, ymin = IC80_inf, ymax = IC80_sup, fill = "IC 80%"), alpha = 0.25) +
  geom_hline(yintercept = 0.50, color = "red", linetype = "dashed", linewidth = 0.5) +
  scale_color_manual(values = c("Histórico" = "#2196F3", "Pronóstico" = "#FF5722")) +
  scale_fill_manual(values = c("IC 80%" = "#FF5722", "IC 95%" = "#FF5722")) +
  labs(title = paste("Pronóstico de Relación R/A — Sede Central (Modelo:", as.character(fit_logit), ")"),
       subtitle = "Línea roja discontinua: Límite normativo CREG 015 (R/A = 0.50)",
       x = "Fecha", y = "Relación R/A", fill = "Intervalos de Conf.", color = "Serie") +
  theme_minimal() +
  theme(legend.position = "bottom")

ggsave(filename = file.path(plot_dir, "RA_Forecast_Logit.png"), plot = p_ra, width = 8, height = 4)

cat("\nProceso de modelado y diagnóstico completado. Gráficos guardados en data/processed/plots/\n")
