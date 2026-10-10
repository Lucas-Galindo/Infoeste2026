-- 02 · Carrega o CSV sujo na staging. Idempotente: TRUNCATE antes (recarregar nunca soma).
-- Precisa de local_infile ligado: SET GLOBAL local_infile=1; e mysql --local-infile=1
USE agromaq_dw;
TRUNCATE stg_leitura;   -- idempotencia da staging: recarregar nunca soma
LOAD DATA LOCAL INFILE 'leituras_sujas.csv'
INTO TABLE stg_leitura
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(sensor_id, data_hora, valor, status_leitura, tipo_maquina);
SELECT COUNT(*) AS linhas_na_staging FROM stg_leitura;
