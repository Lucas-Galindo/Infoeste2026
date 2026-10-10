USE agromaq_lab;
START TRANSACTION;

-- ---------- DIMENSOES: atualiza se existe, insere se e nova ----------
INSERT INTO dim_linha (id_linha_origem, nome_linha, categoria, unidade)
SELECT l.id_linha, l.nome, c.nome, u.nome
FROM agromaq_industrial.linha_producao l
JOIN agromaq_industrial.categoria_produto c ON c.id_categoria = l.categoria_id
JOIN agromaq_industrial.unidade u           ON u.id_unidade   = c.unidade_id
ON DUPLICATE KEY UPDATE nome_linha = VALUES(nome_linha),
                        categoria  = VALUES(categoria),
                        unidade    = VALUES(unidade);

INSERT INTO dim_maquina (id_maquina_origem, codigo, nome_maquina, tipo_maquina, status_maquina, sk_linha)
SELECT m.id_maquina, m.codigo, m.nome, m.tipo, m.status, dl.sk_linha
FROM agromaq_industrial.maquina m
JOIN dim_linha dl ON dl.id_linha_origem = m.linha_id
ON DUPLICATE KEY UPDATE codigo = VALUES(codigo), nome_maquina = VALUES(nome_maquina),
                        tipo_maquina = VALUES(tipo_maquina), status_maquina = VALUES(status_maquina),
                        sk_linha = VALUES(sk_linha);

INSERT INTO dim_sensor (id_sensor_origem, codigo_sensor, tipo_sensor, codigo_maquina, nome_maquina,
                        nome_linha, categoria, unidade, faixa_min, faixa_max)
SELECT s.id_sensor, s.codigo, ts.nome, m.codigo, m.nome, l.nome, c.nome, u.nome,
       CASE WHEN ts.nome = 'Temperatura Motor' THEN 50.00 END,
       CASE WHEN ts.nome = 'Temperatura Motor' THEN 95.00 END
FROM agromaq_industrial.sensor s
JOIN agromaq_industrial.tipo_sensor ts      ON ts.id_tipo_sensor = s.tipo_sensor_id
JOIN agromaq_industrial.maquina m           ON m.id_maquina      = s.maquina_id
JOIN agromaq_industrial.linha_producao l    ON l.id_linha        = m.linha_id
JOIN agromaq_industrial.categoria_produto c ON c.id_categoria    = l.categoria_id
JOIN agromaq_industrial.unidade u           ON u.id_unidade      = c.unidade_id
ON DUPLICATE KEY UPDATE codigo_sensor = VALUES(codigo_sensor), tipo_sensor = VALUES(tipo_sensor),
                        codigo_maquina = VALUES(codigo_maquina), nome_maquina = VALUES(nome_maquina),
                        nome_linha = VALUES(nome_linha), categoria = VALUES(categoria),
                        unidade = VALUES(unidade), faixa_min = VALUES(faixa_min), faixa_max = VALUES(faixa_max);

-- dim_tempo: uma linha por dia, do primeiro ao ultimo registro tratado
INSERT INTO dim_tempo (sk_tempo, data, ano, mes, nome_mes, dia, dia_semana)
WITH digitos (d) AS (SELECT 0 UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
                     UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9),
     limites AS (SELECT DATE(MIN(data_hora)) AS ini, DATE(MAX(data_hora)) AS fim FROM leitura_tratada),
     dias (dt) AS (
         SELECT l.ini + INTERVAL (a.d + 10*b.d + 100*c.d) DAY          -- ate 1.000 dias
         FROM limites l, digitos a, digitos b, digitos c
         WHERE l.ini + INTERVAL (a.d + 10*b.d + 100*c.d) DAY <= l.fim)
SELECT CAST(DATE_FORMAT(dt, '%Y%m%d') AS UNSIGNED), dt, YEAR(dt), MONTH(dt),
       ELT(MONTH(dt), 'Janeiro','Fevereiro','Marco','Abril','Maio','Junho','Julho','Agosto',
                      'Setembro','Outubro','Novembro','Dezembro'),
       DAY(dt),
       ELT(WEEKDAY(dt) + 1, 'Segunda','Terca','Quarta','Quinta','Sexta','Sabado','Domingo')
FROM dias
ON DUPLICATE KEY UPDATE data = VALUES(data);

-- ---------- FATO: carga por particao (apaga o intervalo e reinsere) ----------
SET @lo = (SELECT CAST(DATE_FORMAT(MIN(data_hora), '%Y%m%d') AS UNSIGNED) FROM leitura_tratada);
SET @hi = (SELECT CAST(DATE_FORMAT(MAX(data_hora), '%Y%m%d') AS UNSIGNED) FROM leitura_tratada);

DELETE FROM fato_leitura_sensor WHERE sk_tempo BETWEEN @lo AND @hi;

INSERT INTO fato_leitura_sensor (sk_tempo, hora, turno, sk_sensor, valor, status_leitura, fora_faixa)
SELECT dt.sk_tempo, HOUR(lt.data_hora),
       CASE WHEN HOUR(lt.data_hora) BETWEEN 6 AND 13 THEN 'Manha'
            WHEN HOUR(lt.data_hora) BETWEEN 14 AND 21 THEN 'Tarde' ELSE 'Noite' END,
       ds.sk_sensor, lt.valor, lt.status_leitura,
       CASE WHEN ds.faixa_min IS NOT NULL
                 AND (lt.valor < ds.faixa_min OR lt.valor > ds.faixa_max) THEN 1 ELSE 0 END
FROM leitura_tratada lt
JOIN dim_sensor ds ON ds.id_sensor_origem = lt.sensor_id
JOIN dim_tempo  dt ON dt.data = DATE(lt.data_hora);

COMMIT;

SELECT (SELECT COUNT(*) FROM dim_linha)           AS dim_linha,
       (SELECT COUNT(*) FROM dim_maquina)         AS dim_maquina,
       (SELECT COUNT(*) FROM dim_sensor)          AS dim_sensor,
       (SELECT COUNT(*) FROM dim_tempo)           AS dim_tempo,
       (SELECT COUNT(*) FROM fato_leitura_sensor) AS fato_leitura_sensor;
