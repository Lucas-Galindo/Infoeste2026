-- 03 · Perfilamento da staging: mede cada defeito sem corrigir nada (pratica P2).
USE agromaq_dw;
-- 1) Quantas linhas chegaram
SELECT COUNT(*) AS linhas FROM stg_leitura;

-- 2) Nulos / vazios por coluna
SELECT SUM(sensor_id IS NULL OR TRIM(sensor_id) = '')           AS sensor_vazio,
       SUM(data_hora IS NULL OR TRIM(data_hora) = '')           AS data_vazia,
       SUM(valor IS NULL OR TRIM(valor) = '')                   AS valor_vazio,
       SUM(status_leitura IS NULL OR TRIM(status_leitura) = '') AS status_vazio
FROM stg_leitura;

-- 3) Duplicatas EXATAS, olhando o texto como veio (mesmo sensor, mesma data, mesmo valor)
SELECT COALESCE(SUM(n - 1), 0) AS linhas_em_excesso
FROM (SELECT COUNT(*) AS n FROM stg_leitura
      GROUP BY sensor_id, data_hora, valor HAVING COUNT(*) > 1) d;

-- 4) Sentinela: valores que nao sao medidas
SELECT valor, COUNT(*) AS n FROM stg_leitura WHERE valor IN ('-999', '9999', '-1') GROUP BY valor;

-- 5) Orfaos: sensor que nao existe no banco operacional
SELECT COUNT(*) AS leituras_orfas
FROM stg_leitura s
LEFT JOIN agromaq_industrial.sensor se ON se.id_sensor = CAST(s.sensor_id AS UNSIGNED)
WHERE se.id_sensor IS NULL;

-- 6) Formato: datas que nao seguem AAAA-MM-DD HH:MM:SS
SELECT COUNT(*) AS datas_fora_do_padrao FROM stg_leitura
WHERE data_hora NOT REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$';

-- 7) Formato: valores com virgula decimal
SELECT COUNT(*) AS valores_com_virgula FROM stg_leitura WHERE valor LIKE '%,%';

-- 8) Texto solto: variantes de tipo_maquina (BINARY diferencia maiuscula e espaco final)
SELECT BINARY tipo_maquina AS variante, COUNT(*) AS n
FROM stg_leitura GROUP BY BINARY tipo_maquina ORDER BY variante;
