# ==============================================================================
# 04_modelos.R
# Modelos univariados (ARIMA) e relações entre indicadores (VAR, cointegração)
# ==============================================================================

source("R/funcoes_auxiliares.R")
garantir_pacotes(c("dplyr", "forecast", "urca", "vars", "tsDyn"))

library(dplyr)

# Atenção: o pacote "vars" depende do "MASS", que também define uma função
# select() (para seleção de modelos, sem relação com colunas de data.frame).
# Como vars é carregado depois do dplyr neste script, MASS::select acaba
# mascarando dplyr::select - por isso as chamadas abaixo usam dplyr::select()
# e dplyr::bind_rows() explicitamente, em vez da forma sem prefixo.

headline_largo <- ler_dados("headline_largo", pasta = "processed")

# ------------------------------------------------------------------------
# 1) Modelo ARIMA univariado para cada indicador (ex.: IPCA)
# ------------------------------------------------------------------------
ajustar_arima <- function(serie_valores, frequencia = 12) {
  serie_ts <- ts(serie_valores, frequency = frequencia)
  modelo   <- forecast::auto.arima(serie_ts)
  modelo
}

modelo_ipca <- ajustar_arima(headline_largo$ipca)
print(summary(modelo_ipca))

previsao_ipca <- forecast::forecast(modelo_ipca, h = 6)
print(previsao_ipca)

png("output/figuras/previsao_ipca_arima.png", width = 900, height = 550, res = 130)
plot(previsao_ipca, main = "Previsão ARIMA - IPCA (variação mensal, %)")
dev.off()

# Repita ajustar_arima() para os demais indicadores (ipca_15, inpc, igp_di, igp_m)
# trocando a coluna de headline_largo passada como argumento.

# ------------------------------------------------------------------------
# 2) Testes de raiz unitária (estacionariedade) - pré-requisito para VAR/cointegração
# ------------------------------------------------------------------------
testar_raiz_unitaria <- function(x, nome) {
  adf  <- urca::ur.df(na.omit(x), type = "drift", selectlags = "AIC")
  kpss <- urca::ur.kpss(na.omit(x), type = "mu")
  list(
    indicador = nome,
    adf_estatistica  = adf@teststat[1],
    adf_valor_critico_5pct = adf@cval[1, "5pct"],
    kpss_estatistica = kpss@teststat,
    kpss_valor_critico_5pct = kpss@cval[1, "5pct"]
  )
}

testes_raiz_unitaria <- dplyr::bind_rows(lapply(
  c("ipca", "ipca_15", "inpc", "igp_di", "igp_m"),
  function(nome) as.data.frame(testar_raiz_unitaria(headline_largo[[nome]], nome))
))

readr::write_csv(testes_raiz_unitaria, "output/tabelas/testes_raiz_unitaria.csv")
print(testes_raiz_unitaria)

# ------------------------------------------------------------------------
# 3) VAR entre IPCA e IGP-M (repasse de preços do atacado para o varejo)
# ------------------------------------------------------------------------
dados_var <- headline_largo |>
  dplyr::select(ipca, igp_m) |>
  na.omit()

n_defasagens <- vars::VARselect(dados_var, lag.max = 12, type = "const")
print(n_defasagens$selection)

modelo_var <- vars::VAR(
  dados_var,
  p    = n_defasagens$selection["AIC(n)"],
  type = "const"
)
print(summary(modelo_var))

# Causalidade de Granger: IGP-M "causa" IPCA?
causalidade <- vars::causality(modelo_var, cause = "igp_m")
print(causalidade$Granger)

# Função de impulso-resposta: efeito de um choque no IGP-M sobre o IPCA
irf_resultado <- vars::irf(
  modelo_var, impulse = "igp_m", response = "ipca",
  n.ahead = 12, boot = TRUE
)

png("output/figuras/irf_igpm_ipca.png", width = 900, height = 550, res = 130)
plot(irf_resultado, main = "Resposta do IPCA a um choque no IGP-M")
dev.off()

# ------------------------------------------------------------------------
# 4) Teste de cointegração de Johansen (IPCA x IGP-M)
# ------------------------------------------------------------------------
teste_johansen <- urca::ca.jo(
  dados_var, type = "trace", ecdet = "const",
  K = n_defasagens$selection["AIC(n)"]
)
print(summary(teste_johansen))

# Caso haja cointegração (estatística de traço > valor crítico), o próximo
# passo natural é estimar um VECM com tsDyn::VECM(dados_var, lag = ..., r = 1)

message("Modelagem concluída. Resultados e gráficos salvos em output/.")
