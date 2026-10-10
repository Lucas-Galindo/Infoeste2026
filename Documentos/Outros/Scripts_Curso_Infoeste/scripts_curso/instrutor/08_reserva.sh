#!/bin/bash
# Gera o PLANO B do Dia 2: (1) dump do DW ja carregado (se a E2 travar) e (2) CSVs das 7 tabelas (se o conector falhar).
# Rode depois da carga completa. Distribua a pasta reserva/ aos alunos (rede, pendrive ou nuvem).
set -e
cd "$(dirname "$0")"
mkdir -p reserva
DUMP="${DUMP:-mysqldump -uroot}"
$DUMP --no-tablespaces --routines=0 --skip-triggers --databases agromaq_dw \
      --ignore-table=agromaq_dw.stg_leitura --ignore-table=agromaq_dw.etl_rejeito \
      --ignore-table=agromaq_dw.leitura_tratada > reserva/agromaq_dw_reserva.sql
python3 exportar_csv.py "$@" --saida reserva/dw_csv
echo "reserva pronta em ./reserva"
