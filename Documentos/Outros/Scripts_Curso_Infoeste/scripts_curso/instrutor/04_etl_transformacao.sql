-- 04 · ETL: transformacao completa (UMA REGRA POR DEFEITO). Plano de seguranca da pratica P3:
-- se a turma atrasar aos 8 minutos, entregue este arquivo. Idempotente: rode quantas vezes quiser.
USE agromaq_dw;
START TRANSACTION;

-- Idempotencia: cada execucao refaz o resultado do zero
DELETE FROM etl_rejeito;
DELETE FROM leitura_tratada;

-- 1) Padroniza tipos sem perder a linha de origem
CREATE TEMPORARY TABLE tmp_leitura AS
SELECT s.linha_arquivo,
       s.sensor_id   AS sensor_txt,
       s.data_hora   AS data_txt,
       s.valor       AS valor_txt,
       CASE WHEN s.sensor_id REGEXP '^[0-9]+$' THEN CAST(s.sensor_id AS UNSIGNED) END AS sensor_id,
       CASE WHEN s.data_hora REGEXP '^[0-9]{2}/[0-9]{2}/[0-9]{4} [0-9]{2}:[0-9]{2}$'
                 THEN STR_TO_DATE(s.data_hora, '%d/%m/%Y %H:%i')
            WHEN s.data_hora REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$'
                 THEN STR_TO_DATE(s.data_hora, '%Y-%m-%d %H:%i:%s') END              AS data_hora,
       CASE WHEN NULLIF(TRIM(s.valor), '') IS NOT NULL
                 AND REPLACE(TRIM(s.valor), ',', '.') REGEXP '^-?[0-9]+(\\.[0-9]+)?$'
                 THEN CAST(REPLACE(TRIM(s.valor), ',', '.') AS DECIMAL(10,2)) END     AS valor,
       UPPER(TRIM(s.status_leitura))                                                  AS status_leitura,
       CONCAT(UPPER(LEFT(TRIM(s.tipo_maquina), 1)), LOWER(SUBSTRING(TRIM(s.tipo_maquina), 2))) AS tipo_maquina
FROM stg_leitura s;

-- 2) Uma regra por defeito: o primeiro motivo que se aplica vence
CREATE TEMPORARY TABLE tmp_motivo AS
SELECT t.*,
       CASE
         WHEN t.sensor_id IS NULL OR se.id_sensor IS NULL THEN 'SENSOR_INEXISTENTE'
         WHEN NULLIF(TRIM(t.valor_txt), '') IS NULL        THEN 'VALOR_NULO'
         WHEN t.valor = -999                               THEN 'VALOR_SENTINELA'
         WHEN t.valor IS NULL OR t.data_hora IS NULL       THEN 'FORMATO_INVALIDO'
       END AS motivo
FROM tmp_leitura t
LEFT JOIN agromaq_industrial.sensor se ON se.id_sensor = t.sensor_id;

-- 3) Duplicata so existe depois que as datas estao padronizadas:
--    entre as linhas validas, a primeira (menor linha_arquivo) fica
CREATE TEMPORARY TABLE tmp_final AS
SELECT m.*,
       CASE WHEN m.motivo IS NULL
                 AND ROW_NUMBER() OVER (PARTITION BY m.sensor_id, m.data_hora
                                        ORDER BY m.linha_arquivo) > 1
            THEN 'DUPLICADA' ELSE m.motivo END AS motivo_final
FROM tmp_motivo m;

INSERT INTO etl_rejeito (linha_arquivo, motivo, sensor_id, data_hora, valor)
SELECT linha_arquivo, motivo_final, sensor_txt, data_txt, valor_txt
FROM tmp_final WHERE motivo_final IS NOT NULL;

INSERT INTO leitura_tratada (linha_arquivo, sensor_id, data_hora, valor, status_leitura, tipo_maquina)
SELECT linha_arquivo, sensor_id, data_hora, valor, status_leitura, tipo_maquina
FROM tmp_final WHERE motivo_final IS NULL;

DROP TEMPORARY TABLE tmp_final;
DROP TEMPORARY TABLE tmp_motivo;
DROP TEMPORARY TABLE tmp_leitura;
COMMIT;

-- Log da execucao
SELECT (SELECT COUNT(*) FROM stg_leitura)     AS na_staging,
       (SELECT COUNT(*) FROM leitura_tratada) AS passaram,
       (SELECT COUNT(*) FROM etl_rejeito)     AS rejeitadas;
SELECT motivo, COUNT(*) AS n FROM etl_rejeito GROUP BY motivo ORDER BY motivo;
