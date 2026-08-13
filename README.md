# Projeto de Análise de Indicadores Econômicos em R

Versão inicial do projeto de análise estatística e econométrica de indicadores
de inflação da economia brasileira (IPCA, IPCA-15, INPC, IGP-DI, IGP-M) e dos
grupos que compõem o IPCA.

## Como usar

1. Abra `projeto-indicadores.Rproj` no RStudio (garante que o diretório de
   trabalho já fica correto para os caminhos relativos usados nos scripts).
2. Rode os scripts na ordem, a partir da raiz do projeto:

```r
source("R/01_coleta.R")                          # IPCA (headline e por grupo), IPCA-15/INPC/IGP-DI/IGP-M headline
source("R/01b_coleta_inpc_ipca15_grupos.R")      # INPC e IPCA-15 por grupo
source("R/02_tratamento.R")                      # organiza em séries temporais (tsibble/xts)
source("R/03_exploratoria.R")                    # estatísticas descritivas e gráficos
source("R/04_modelos.R")                         # ARIMA, testes de raiz unitária, VAR, cointegração
```

Os pacotes necessários são instalados automaticamente na primeira execução
(via `garantir_pacotes()`, em `R/funcoes_auxiliares.R`).

## Estrutura

```
projeto-indicadores/
├── R/
│   ├── 01_coleta.R
│   ├── 02_tratamento.R
│   ├── 03_exploratoria.R
│   ├── 04_modelos.R
│   └── funcoes_auxiliares.R
├── data/
│   ├── raw/          # dados brutos coletados (.rds + .csv)
│   └── processed/    # dados tratados, prontos para análise
├── output/
│   ├── figuras/       # gráficos exportados (.png) - um arquivo por série,
│   │                   # ex.: evolucao_indicadores_headline_ipca.png,
│   │                   # evolucao_ipca_grupos_habitacao.png
│   └── tabelas/       # tabelas exportadas (.csv)
└── projeto-indicadores.Rproj
```

## Pontos de atenção nesta versão inicial

- **IGP**: a FGV não publica um índice chamado apenas "IGP" — os índices
  existentes são o **IGP-DI**, o **IGP-M** e o **IGP-10**. O script de coleta
  traz IGP-DI e IGP-M; o IGP-10 pode ser incluído depois seguindo o mesmo
  padrão (basta adicionar o código de série SGS correspondente).
- **Grupos do IPCA, INPC e IPCA-15** (`R/01_coleta.R` e
  `R/01b_coleta_inpc_ipca15_grupos.R`): as tabelas SIDRA usadas são 7060
  (IPCA), 7063 (INPC) e 7062 (IPCA-15) — a mesma família de tabelas criada
  pelo IBGE em jan/2020. Uma primeira versão deste projeto fixava o código
  de variável "variação mensal" (63) supondo que seria igual nas três
  tabelas, o que quebrou ao rodar para o INPC (`Parâmetro V com código 63
  inexistente`) — cada tabela tem sua própria numeração de variáveis e
  categorias. Por isso os scripts agora **resolvem esses códigos
  dinamicamente** a cada execução, via `resolver_variavel_sidra()` e
  `resolver_categorias_sidra()` (em `R/funcoes_auxiliares.R`), que consultam
  `sidrar::info_sidra()` e buscam pelo nome (ex.: "variação mensal",
  "habitação") em vez de depender de números fixos. Se algo mudar de novo no
  SIDRA, o erro aponta exatamente quais variáveis/categorias estão
  disponíveis na tabela.
- **Códigos SGS/Bacen usados**: IPCA (433), IPCA-15 (7478), INPC (188),
  IGP-DI (190), IGP-M (189). Confirme em https://www3.bcb.gov.br/sgspub caso
  alguma série pareça desatualizada.
- O modelo VAR/cointegração do script `04_modelos.R` usa IPCA x IGP-M como
  exemplo de par a analisar (repasse atacado-varejo); é fácil estender para
  outros pares (ex.: IPCA x INPC).
