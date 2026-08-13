# ==============================================================================
# 01b_coleta_inpc_ipca15_grupos.R
# Coleta do INPC e do IPCA-15 por grupo (mesmo padrão usado para o IPCA em
# R/01_coleta.R, bloco 3)
#
# Tabelas SIDRA confirmadas (verificação em 28/07/2026):
#   - INPC por grupo: tabela 7063
#   - IPCA-15 por grupo: tabela 7062
#   (7060 = IPCA, 7062 = IPCA-15, 7063 = INPC - mesma família de tabelas
#   criada pelo IBGE em jan/2020)
#
# Lição aprendida na primeira versão deste script: o código de variável
# "variação mensal" NÃO é necessariamente o mesmo entre 7060/7062/7063 -
# variable = 63 funciona no IPCA (7060) mas não existe na tabela do INPC
# (7063), o que gerava "Parâmetro V (Variável) com código 63 inexistente".
# Por isso, em vez de fixar números, o script agora resolve os códigos de
# variável e de categoria (grupo) dinamicamente a cada execução, consultando
# sidrar::info_sidra() - ver resolver_variavel_sidra() e
# resolver_categorias_sidra() em R/funcoes_auxiliares.R.
# ==============================================================================

source("R/funcoes_auxiliares.R")
garantir_pacotes(c("sidrar", "dplyr"))

library(dplyr)

# Nomes de grupo (mesmos 9 grupos oficiais do SNIPC, usados por IPCA, INPC
# e IPCA-15) usados para localizar os códigos de categoria em cada tabela
nomes_grupos <- c(
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

#' Coleta os grupos de uma tabela SIDRA da família 7060/7062/7063, resolvendo
#' os códigos de variável e categoria na hora (em vez de fixá-los)
coletar_grupos_snipc <- function(tabela) {
  variavel   <- resolver_variavel_sidra(tabela, "variacao mensal")
  categorias <- resolver_categorias_sidra(tabela, nomes_grupos, classific = "c315")

  dados_raw <- sidrar::get_sidra(
    x         = tabela,
    variable  = variavel,
    period    = "all",
    geo       = "Brazil",
    classific = "c315",
    category  = list(unname(categorias))
  )

  dados_raw |>
    transmute(
      data  = sidra_data_para_date(`Mês (Código)`),
      grupo = `Geral, grupo, subgrupo, item e subitem`,
      valor = as.numeric(Valor)
    )
}

# ------------------------------------------------------------------------
# 1) INPC por grupo - tabela SIDRA 7063
# ------------------------------------------------------------------------
inpc_grupos <- coletar_grupos_snipc(7063)
salvar_dados(inpc_grupos, "inpc_grupos", pasta = "raw")
message("INPC por grupo salvo em data/raw/inpc_grupos.*")

# ------------------------------------------------------------------------
# 2) IPCA-15 por grupo - tabela SIDRA 7062
# ------------------------------------------------------------------------
ipca15_grupos <- coletar_grupos_snipc(7062)
salvar_dados(ipca15_grupos, "ipca15_grupos", pasta = "raw")
message("IPCA-15 por grupo salvo em data/raw/ipca15_grupos.*")

# ------------------------------------------------------------------------
# 3) Dica de verificação de qualquer tabela SIDRA usada no projeto
# ------------------------------------------------------------------------
# Se o IBGE mudar novamente a numeração de variáveis/categorias, este script
# continua funcionando sem alterações - ele reconsulta sidrar::info_sidra()
# a cada execução. Se ainda assim algo falhar, rode manualmente
# sidrar::info_sidra(7062) ou sidrar::info_sidra(7063) e confira as
# mensagens de erro impressas por resolver_variavel_sidra()/
# resolver_categorias_sidra(), que listam todas as variáveis/categorias
# disponíveis na tabela.
