# ==============================================================================
# 02_tratamento.R
# Limpeza, padronização e transformação em séries temporais (tsibble/xts)
# ==============================================================================

source("R/funcoes_auxiliares.R")
garantir_pacotes(c("dplyr", "tidyr", "tsibble", "xts", "zoo"))

library(dplyr)

# ------------------------------------------------------------------------
# 1) Carrega dados brutos
# ------------------------------------------------------------------------
indicadores_headline <- ler_dados("indicadores_headline", pasta = "raw")
ipca_grupos          <- ler_dados("ipca_grupos", pasta = "raw")

# ------------------------------------------------------------------------
# 2) Indicadores headline: formato "largo" (uma coluna por indicador)
#    e conversão para tsibble para facilitar a modelagem posterior
# ------------------------------------------------------------------------
headline_largo <- indicadores_headline |>
  mutate(mes = tsibble::yearmonth(data)) |>
  select(mes, indicador, valor) |>
  distinct(mes, indicador, .keep_all = TRUE) |>
  tidyr::pivot_wider(names_from = indicador, values_from = valor) |>
  arrange(mes)

headline_tsibble <- headline_largo |>
  tsibble::as_tsibble(index = mes)

salvar_dados(headline_largo, "headline_largo", pasta = "processed")
saveRDS(headline_tsibble, "data/processed/headline_tsibble.rds")

# Também disponibiliza em xts, útil para os pacotes vars/urca/tsDyn
headline_xts <- xts::xts(
  headline_largo |> select(-mes),
  order.by = as.Date(headline_largo$mes)
)
saveRDS(headline_xts, "data/processed/headline_xts.rds")

# ------------------------------------------------------------------------
# 3) IPCA por grupo: formato "largo" (uma coluna por grupo) + acumulado 12m
# ------------------------------------------------------------------------
grupos_largo <- ipca_grupos |>
  mutate(mes = tsibble::yearmonth(data)) |>
  select(mes, grupo, valor) |>
  distinct(mes, grupo, .keep_all = TRUE) |>
  tidyr::pivot_wider(names_from = grupo, values_from = valor) |>
  arrange(mes)

# Acumulado em 12 meses por grupo, a partir da variação mensal (%)
acumulado_12m <- function(x) {
  # (prod(1 + x/100) - 1) * 100, em janela móvel de 12 meses
  zoo::rollapply(
    x, width = 12, align = "right", fill = NA,
    FUN = function(v) (prod(1 + v / 100) - 1) * 100
  )
}

grupos_acumulado_12m <- grupos_largo |>
  mutate(across(-mes, acumulado_12m, .names = "{.col}_acum12m"))

salvar_dados(grupos_largo, "ipca_grupos_largo", pasta = "processed")
salvar_dados(grupos_acumulado_12m, "ipca_grupos_acum12m", pasta = "processed")

# ------------------------------------------------------------------------
# 4) INPC e IPCA-15 por grupo (se já coletados em R/01b_coleta_inpc_ipca15_grupos.R)
#    Mesmo tratamento aplicado ao IPCA por grupo, reaproveitando a função
#    acumulado_12m() definida acima.
# ------------------------------------------------------------------------
tratar_grupos <- function(nome_raw, nome_saida) {
  caminho <- file.path("data", "raw", paste0(nome_raw, ".rds"))
  if (!file.exists(caminho)) {
    message("Aviso: ", caminho, " não encontrado - rode 01b_coleta_inpc_ipca15_grupos.R antes.")
    return(invisible(NULL))
  }

  dados_largo <- readRDS(caminho) |>
    mutate(mes = tsibble::yearmonth(data)) |>
    select(mes, grupo, valor) |>
    distinct(mes, grupo, .keep_all = TRUE) |>
    tidyr::pivot_wider(names_from = grupo, values_from = valor) |>
    arrange(mes)

  dados_acum12m <- dados_largo |>
    mutate(across(-mes, acumulado_12m, .names = "{.col}_acum12m"))

  salvar_dados(dados_largo, paste0(nome_saida, "_largo"), pasta = "processed")
  salvar_dados(dados_acum12m, paste0(nome_saida, "_acum12m"), pasta = "processed")
  invisible(dados_largo)
}

tratar_grupos("inpc_grupos", "inpc_grupos")
tratar_grupos("ipca15_grupos", "ipca15_grupos")

message("Tratamento concluído. Arquivos salvos em data/processed/.")
