# Exportação CSV do banco AgroMaq

Gerado em 25/10/2026 a partir dos scripts do projeto (`02_schema`, `03_populacao_base`, `05_ajustes_clientes`, `03b_populacao_producao` e o pipeline do DW).

- `agromaq_industrial/`: todas as 38 tabelas do banco operacional. Dez delas estão vazias no banco (só o cabeçalho): `estoque_movimentacao`, `inspecao_qualidade`, `leitura_sensor`, `lote`, `op_consumo_lote`, `op_etapa`, `produto_serial`, `venda`, `venda_item`, `venda_item_serial`.
- `agromaq_dw/`: as 9 tabelas do data warehouse (`dim_*`, `fato_*`, `cfg_faixa_sensor` e `etl_rejeito`). Ficaram de fora a staging `stg_leitura` e a `leitura_tratada`, que repetem as 209.804 leituras e já existem como `leituras_sujas.csv`.
- `_resumo_tabelas.csv`: banco, tabela e número de linhas.

Formato: UTF-8 com BOM, separador `;`, decimal com vírgula, datas em `AAAA-MM-DD`, valores vazios para NULL. O Power BI e o Excel em português leem direto.
