# ==============================================================================
# 03_exploratoria.R
# Estatística descritiva e visualizações dos indicadores e grupos
# ==============================================================================

source("R/funcoes_auxiliares.R")
garantir_pacotes(c("dplyr", "tidyr", "ggplot2", "tsibble"))

library(dplyr)
library(ggplot2)

headline_largo <- ler_dados("headline_largo", pasta = "processed")
grupos_largo   <- ler_dados("ipca_grupos_largo", pasta = "processed")

# ------------------------------------------------------------------------
# 1) Estatísticas descritivas dos indicadores headline
# ------------------------------------------------------------------------
estatisticas_headline <- headline_largo |>
  select(-mes) |>
  tidyr::pivot_longer(everything(), names_to = "indicador", values_to = "valor") |>
  group_by(indicador) |>
  summarise(
    media      = mean(valor, na.rm = TRUE),
    mediana    = median(valor, na.rm = TRUE),
    desvio_pad = sd(valor, na.rm = TRUE),
    minimo     = min(valor, na.rm = TRUE),
    maximo     = max(valor, na.rm = TRUE),
    .groups = "drop"
  )

readr::write_csv(estatisticas_headline, "output/tabelas/estatisticas_headline.csv")
print(estatisticas_headline)

# ------------------------------------------------------------------------
# 2) Gráficos: evolução mensal de cada indicador headline (um por arquivo)
# ------------------------------------------------------------------------
gerar_graficos_por_serie(
  dados           = headline_largo,
  coluna_tempo    = "mes",
  prefixo_arquivo = "evolucao_indicadores_headline",
  titulo_prefixo  = "Variação mensal - "
)

# ------------------------------------------------------------------------
# 3) Gráficos: evolução mensal de cada grupo do IPCA (um por arquivo)
# ------------------------------------------------------------------------
gerar_graficos_por_serie(
  dados           = grupos_largo,
  coluna_tempo    = "mes",
  prefixo_arquivo = "evolucao_ipca_grupos",
  titulo_prefixo  = "IPCA - Variação mensal - "
)

# ------------------------------------------------------------------------
# 4) Gráfico: correlação entre indicadores headline
# ------------------------------------------------------------------------
matriz_correlacao <- headline_largo |>
  select(-mes) |>
  cor(use = "pairwise.complete.obs")

readr::write_csv(
  as.data.frame(matriz_correlacao) |> tibble::rownames_to_column("indicador"),
  "output/tabelas/correlacao_headline.csv"
)
print(round(matriz_correlacao, 2))

message("Análise exploratória concluída. Gráficos em output/figuras/, tabelas em output/tabelas/.")
