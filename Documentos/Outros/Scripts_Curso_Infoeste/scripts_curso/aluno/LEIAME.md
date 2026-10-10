# Arquivos da aula · Além do Código (Infoeste 2026)

| Arquivo | Quando usar |
|:--|:--|
| `leituras_sujas.csv` | Dia 1, P2: o CSV com defeitos que você vai carregar e tratar |
| `01_criar_staging.sql` | Dia 1, P2: cria o banco `agromaq_dw` e as tabelas de staging, rejeitos e tratada |
| `02_carregar_csv.sql` | Dia 1, P2: carrega o CSV na staging (precisa de `local_infile` ligado) |
| `05_dw_agromaq.sql` | Dia 2: cria as tabelas do data warehouse |
| `06a_carga_dimensoes.sql` | Dia 2, E1: carga das dimensões |
| `06b_carga_fatos.sql` | Dia 2, E2 e E3: carga das fatos (rode de novo para provar que não duplica) |
| `07_consultas_dw.sql` | Dia 2: reconciliação e perguntas de negócio |

Pré-requisito: o banco `agromaq_industrial` (`02_schema.sql`, `03_populacao_base.sql` e `03b_populacao_producao.sql`).

Rode os arquivos de dentro da pasta (o CSV é lido do diretório atual):

```
mysql -u root -p --local-infile=1
```

Ordem: `01`, `02`, (seu ETL do Dia 1), `05`, `06a`, `06b`, `07`.
