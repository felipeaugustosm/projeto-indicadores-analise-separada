# ==============================================================================
# 01_coleta.R
# Coleta dos indicadores IPCA, IPCA-15, INPC, IGP-DI e IGP-M (+ grupos do IPCA)
#
# Fontes:
#   - SIDRA/IBGE (pacote sidrar)  -> IPCA série histórica e por grupo
#   - SGS/Banco Central (pacote rbcb) -> séries "oficiais" já consolidadas,
#     incluindo IGP-DI e IGP-M (calculados pela FGV e replicados no SGS)
#
# Observação importante:
#   A FGV não publica um índice chamado apenas "IGP" isoladamente - os índices
#   publicados são o IGP-DI, o IGP-M e o IGP-10. Este script coleta IGP-DI e
#   IGP-M (os dois citados no escopo do projeto); o IGP-10 pode ser adicionado
#   depois com o mesmo padrão, caso seja necessário.
# ==============================================================================

source("R/funcoes_auxiliares.R")
garantir_pacotes(c("sidrar", "rbcb", "dplyr", "readr", "purrr"))

library(dplyr)

# ------------------------------------------------------------------------
# 1) Séries "headline" (índice geral) via SGS/Banco Central
# ------------------------------------------------------------------------
# Códigos de série do SGS (consolidados e estáveis, usados também pelo BCB
# nos boletins de conjuntura). Confira/atualize em https://www3.bcb.gov.br/sgspub
codigos_sgs <- c(
  ipca      = 433,   # IPCA - variação % mensal
  ipca_15   = 7478,  # IPCA-15 - variação % mensal
  inpc      = 188,   # INPC - variação % mensal
  igp_di    = 190,   # IGP-DI - variação % mensal
  igp_m     = 189    # IGP-M - variação % mensal
)

coletar_series_sgs <- function(codigos, data_inicio = as.Date("2000-01-01")) {
  purrr::imap_dfr(codigos, function(codigo, nome) {
    rbcb::get_series(codigo, start_date = data_inicio) |>
      setNames(c("data", "valor")) |>
      mutate(indicador = nome)
  })
}

indicadores_headline <- coletar_series_sgs(codigos_sgs)
salvar_dados(indicadores_headline, "indicadores_headline", pasta = "raw")

# ------------------------------------------------------------------------
# 2) IPCA - série histórica oficial (número-índice e variações acumuladas)
#    Tabela SIDRA 1737
# ------------------------------------------------------------------------
# variable 2266 = "IPCA - Variação mensal"; ajuste/consulte outras variáveis
# disponíveis com sidrar::info_sidra(1737)
ipca_historico_raw <- sidrar::get_sidra(
  x        = 1737,
  variable = 2266,
  period   = "all",
  geo      = "Brazil"
)

ipca_historico <- ipca_historico_raw |>
  transmute(
    data      = sidra_data_para_date(`Mês (Código)`),
    valor     = as.numeric(Valor),
    indicador = "ipca"
  )

salvar_dados(ipca_historico, "ipca_historico", pasta = "raw")

# ------------------------------------------------------------------------
# 3) IPCA por grupo (ex.: alimentação e bebidas, habitação, transportes...)
#    Tabela SIDRA 7060 - variação mensal por grupo (classific c315)
# ------------------------------------------------------------------------
# Os códigos de variável e de categoria (grupo) são resolvidos dinamicamente
# logo abaixo via resolver_variavel_sidra()/resolver_categorias_sidra(), em
# vez de fixados manualmente - evita quebrar caso o IBGE reordene os códigos
# (foi exatamente isso que causou erro ao reaproveitar o código de variável
# do IPCA na tabela do INPC, ver R/01b_coleta_inpc_ipca15_grupos.R).

# Nomes de grupo usados para localizar os códigos de categoria (c315) da
# tabela na hora - evita fixar códigos que podem não ser os mesmos em outras
# tabelas da mesma família (7062, 7063)
nomes_grupos_ipca <- c(
  "Alimentação e bebidas"      = "alimentacao e bebidas",
  "Habitação"                  = "habitacao",
  "Artigos de residência"      = "artigos de residencia",
  "Vestuário"                  = "vestuario",
  "Transportes"                = "transportes",
  "Saúde e cuidados pessoais"  = "saude e cuidados pessoais",
  "Despesas pessoais"          = "despesas pessoais",
  "Educação"                   = "educacao",
  "Comunicação"                = "comunicacao"
)

variavel_ipca_mensal <- resolver_variavel_sidra(7060, "variacao mensal")
categorias_ipca       <- resolver_categorias_sidra(7060, nomes_grupos_ipca, classific = "c315")

ipca_grupos_raw <- sidrar::get_sidra(
  x         = 7060,
  variable  = variavel_ipca_mensal,
  period    = "all",
  geo       = "Brazil",
  classific = "c315",
  category  = list(unname(categorias_ipca))
)

ipca_grupos <- ipca_grupos_raw |>
  transmute(
    data      = sidra_data_para_date(`Mês (Código)`),
    grupo     = `Geral, grupo, subgrupo, item e subitem`,
    valor     = as.numeric(Valor)
  )

salvar_dados(ipca_grupos, "ipca_grupos", pasta = "raw")

# ------------------------------------------------------------------------
# 4) INPC e IPCA-15 por grupo
# ------------------------------------------------------------------------
# Ver R/01b_coleta_inpc_ipca15_grupos.R - usa o mesmo padrão de resolução
# dinâmica de códigos (tabelas 7063 e 7062, respectivamente).

message("Coleta concluída. Arquivos salvos em data/raw/.")
