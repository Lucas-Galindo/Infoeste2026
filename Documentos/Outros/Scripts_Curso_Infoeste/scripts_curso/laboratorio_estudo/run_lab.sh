set -e
cd /home/claude/lab
mysql -uroot < 01_lab_criar_staging.sql
mysql -uroot --local-infile=1 < 02_lab_carregar_csv.sql
mysql -uroot < 04_lab_etl.sql
mysql -uroot < 05_lab_dw_ddl.sql
mysql -uroot < 06_lab_dw_carga.sql
mysql -uroot < 06_lab_dw_carga.sql
mysql -uroot < 07_lab_reconciliacao.sql
