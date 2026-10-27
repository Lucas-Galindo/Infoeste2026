#!/bin/bash
# Roda o pipeline inteiro (para ensaio). Ajuste MYSQL se precisar de usuario/senha.
set -e
cd "$(dirname "$0")"
MYSQL="${MYSQL:-mysql -uroot}"
# Ajuste opcional de cidade x estado dos clientes (Database/05_ajustes_clientes.sql).
# Rode apos o 03_populacao_base.sql. Uso: AJUSTES_CLIENTES="caminho/05_ajustes_clientes.sql" bash run_pipeline.sh
if [ -n "${AJUSTES_CLIENTES:-}" ]; then $MYSQL < "$AJUSTES_CLIENTES"; fi
$MYSQL < 03b_populacao_producao.sql
$MYSQL < 01_criar_staging.sql
$MYSQL --local-infile=1 < 02_carregar_csv.sql
$MYSQL < 03_perfilamento.sql
$MYSQL < 04_etl_transformacao.sql
$MYSQL < 05_dw_agromaq.sql
$MYSQL < 06a_carga_dimensoes.sql
$MYSQL < 06b_carga_fatos.sql
echo "--- segunda rodada (idempotencia) ---"
$MYSQL < 04_etl_transformacao.sql
$MYSQL < 06a_carga_dimensoes.sql
$MYSQL < 06b_carga_fatos.sql
$MYSQL -t < 07_consultas_dw.sql
