# ==============================================================================
# funcoes_auxiliares.R
# Funções utilitárias reutilizadas pelos demais scripts do projeto
# ==============================================================================

#' Converte uma coluna de data no formato SIDRA (AAAAMM) para Date (dia 1)
#'
#' @param x vetor character no formato "AAAAMM" (ex.: "202401")
#' @return vetor de classe Date
sidra_data_para_date <- function(x) {
  as.Date(paste0(x, "01"), format = "%Y%m%d")
}

#' Salva um data.frame/tibble em data/raw ou data/processed em formato .rds e .csv
#'
#' @param df objeto a salvar
#' @param nome nome do arquivo, sem extensão
#' @param pasta "raw" ou "processed"
salvar_dados <- function(df, nome, pasta = c("raw", "processed")) {
  pasta <- match.arg(pasta)
  caminho <- file.path("data", pasta)
  if (!dir.exists(caminho)) dir.create(caminho, recursive = TRUE)

  saveRDS(df, file.path(caminho, paste0(nome, ".rds")))
  readr::write_csv(df, file.path(caminho, paste0(nome, ".csv")))

  invisible(df)
}

#' Lê um data.frame previamente salvo por salvar_dados()
#'
#' @param nome nome do arquivo, sem extensão
#' @param pasta "raw" ou "processed"
ler_dados <- function(nome, pasta = c("raw", "processed")) {
  pasta <- match.arg(pasta)
  caminho <- file.path("data", pasta, paste0(nome, ".rds"))
  if (!file.exists(caminho)) {
    stop("Arquivo não encontrado: ", caminho, ". Rode o script de coleta/tratamento antes.")
  }
  readRDS(caminho)
}

#' Tema ggplot2 padrão do projeto, para manter consistência visual entre gráficos
tema_projeto <- function() {
  ggplot2::theme_minimal(base_size = 12) +
    ggplot2::theme(
      plot.title = ggplot2::element_text(face = "bold"),
      panel.grid.minor = ggplot2::element_blank(),
      legend.position = "bottom"
    )
}

#' Salva um gráfico ggplot2 em output/figuras com dimensões padronizadas
#'
#' @param grafico objeto ggplot
#' @param nome nome do arquivo, sem extensão
salvar_grafico <- function(grafico, nome) {
  pasta <- file.path("output", "figuras")
  if (!dir.exists(pasta)) dir.create(pasta, recursive = TRUE)
  ggplot2::ggsave(
    filename = file.path(pasta, paste0(nome, ".png")),
    plot = grafico,
    width = 9, height = 5.5, dpi = 150
  )
}

#' Resolve o código de uma variável do SIDRA a partir de um trecho do nome
#' (ex.: "variação mensal"), em vez de fixar um código que pode variar de
#' tabela para tabela (ex.: 7060, 7062 e 7063 não usam necessariamente os
#' mesmos códigos de variável, mesmo tendo estrutura parecida).
#'
#' @param tabela número da tabela SIDRA
#' @param padrao trecho do nome da variável a procurar (sem acento, minúsculo)
resolver_variavel_sidra <- function(tabela, padrao) {
  info <- sidrar::info_sidra(tabela)
  vars <- info$variable

  normalizar <- function(x) tolower(iconv(x, to = "ASCII//TRANSLIT"))
  nomes  <- normalizar(vars$desc)
  alvo   <- normalizar(padrao)

  idx <- grepl(alvo, nomes, fixed = TRUE)
  if (!any(idx)) {
    stop(
      "Não encontrei nenhuma variável com o padrao '", padrao, "' na tabela ", tabela, ".\n",
      "Variaveis disponiveis:\n",
      paste(vars$cod, "-", vars$desc, collapse = "\n")
    )
  }

  codigo <- as.integer(vars$cod[idx][1])
  message("Tabela ", tabela, ": variavel '", padrao, "' resolvida para o codigo ", codigo,
          " (", vars$desc[idx][1], ")")
  codigo
}

#' Resolve os códigos de categoria (ex.: grupos do IPCA/INPC/IPCA-15) a
#' partir dos nomes dos grupos, dentro da classificação de produtos de uma
#' tabela SIDRA. Evita fixar códigos de categoria que podem ser diferentes
#' entre as tabelas de cada pesquisa.
#'
#' @param tabela número da tabela SIDRA
#' @param nomes_grupos vetor nomeado ou não com os nomes dos grupos a buscar
#' @param classific nome da classificação (ex.: "c315"); se NULL, usa a
#'   primeira classificação disponível na tabela
resolver_categorias_sidra <- function(tabela, nomes_grupos, classific = NULL) {
  info <- sidrar::info_sidra(tabela)
  cc   <- info$classific_category

  categorias <- if (!is.null(classific) && !is.null(cc[[classific]])) {
    cc[[classific]]
  } else {
    cc[[1]]
  }

  normalizar <- function(x) tolower(iconv(x, to = "ASCII//TRANSLIT"))
  nomes_categorias <- normalizar(categorias$desc)

  codigos <- vapply(nomes_grupos, function(nome) {
    alvo <- normalizar(nome)
    idx  <- grepl(alvo, nomes_categorias, fixed = TRUE)
    if (!any(idx)) {
      stop(
        "Nao encontrei o grupo '", nome, "' na classificacao da tabela ", tabela, ".\n",
        "Categorias disponiveis:\n",
        paste(categorias$cod, "-", categorias$desc, collapse = "\n")
      )
    }
    as.integer(categorias$cod[idx][1])
  }, FUN.VALUE = integer(1))

  names(codigos) <- names(nomes_grupos)
  codigos
}

#' Converte um texto em um "slug" seguro para nome de arquivo (minúsculo,
#' sem acento, espaços e caracteres especiais viram "_")
#'
#' @param x texto a converter
slug <- function(x) {
  x <- tolower(iconv(x, to = "ASCII//TRANSLIT"))
  x <- gsub("[^a-z0-9]+", "_", x)
  gsub("^_|_$", "", x)
}

#' Gera e salva um gráfico de linha (evolução mensal) separado para cada
#' coluna de um data.frame em formato largo (uma coluna por série + uma
#' coluna de data/mês), em vez de um único gráfico com todas as séries
#' sobrepostas.
#'
#' @param dados data.frame em formato largo, com a coluna de tempo e uma
#'   coluna por série
#' @param coluna_tempo nome da coluna de tempo (ex.: "mes")
#' @param prefixo_arquivo prefixo usado no nome de cada arquivo salvo (ex.:
#'   "evolucao_indicadores_headline" gera
#'   "evolucao_indicadores_headline_<serie>.png")
#' @param titulo_prefixo texto usado no início do título de cada gráfico
#' @param y_label rótulo do eixo Y
gerar_graficos_por_serie <- function(dados, coluna_tempo = "mes",
                                      prefixo_arquivo, titulo_prefixo = "",
                                      y_label = "Variação mensal (%)") {
  colunas_series <- setdiff(names(dados), coluna_tempo)

  for (serie in colunas_series) {
    grafico <- ggplot2::ggplot(
      dados,
      ggplot2::aes(x = as.Date(.data[[coluna_tempo]]), y = .data[[serie]])
    ) +
      ggplot2::geom_line(colour = "#1F4E5F", linewidth = 0.8) +
      ggplot2::labs(
        title = paste0(titulo_prefixo, serie),
        x = NULL, y = y_label
      ) +
      tema_projeto()

    nome_arquivo <- paste0(prefixo_arquivo, "_", slug(serie))
    salvar_grafico(grafico, nome_arquivo)
  }

  message(
    length(colunas_series), " gráficos salvos em output/figuras/ com prefixo '",
    prefixo_arquivo, "_'"
  )
  invisible(colunas_series)
}

#' Verifica se os pacotes necessários estão instalados e os instala se preciso
#'
#' @param pacotes vetor character com nomes dos pacotes
garantir_pacotes <- function(pacotes) {
  faltantes <- pacotes[!pacotes %in% rownames(installed.packages())]
  if (length(faltantes) > 0) {
    message("Instalando pacotes: ", paste(faltantes, collapse = ", "))
    install.packages(faltantes)
  }
  invisible(lapply(pacotes, require, character.only = TRUE))
}
