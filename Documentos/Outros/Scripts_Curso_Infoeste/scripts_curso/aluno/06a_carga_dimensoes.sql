-- =====================================================================
-- 06a · Carga das DIMENSOES (pratica E1). Padrao: atualiza se existe, insere se e nova.
-- Idempotente: rodar de novo nao duplica nem muda as chaves substitutas (sk_*).
-- Ordem: dim_linha -> dim_maquina (precisa de sk_linha) -> dim_sensor -> dim_produto -> dim_tempo.
-- Pre-requisitos: 05_dw_agromaq.sql, 04_etl_transformacao.sql e 03b_populacao_producao.sql ja rodados.
-- =====================================================================
USE agromaq_dw;
START TRANSACTION;

INSERT INTO dim_linha (id_linha_origem, nome_linha, setor, categoria, unidade)
SELECT l.id_linha, l.nome, st.nome, c.nome, u.nome
FROM agromaq_industrial.linha_producao l
JOIN agromaq_industrial.setor st            ON st.id_setor     = l.setor_id
JOIN agromaq_industrial.categoria_produto c ON c.id_categoria  = l.categoria_id
JOIN agromaq_industrial.unidade u           ON u.id_unidade    = c.unidade_id
ON DUPLICATE KEY UPDATE nome_linha = VALUES(nome_linha), setor = VALUES(setor),
                        categoria  = VALUES(categoria),  unidade = VALUES(unidade);

INSERT INTO dim_maquina (id_maquina_origem, codigo, nome_maquina, tipo_maquina, status_maquina, sk_linha)
SELECT m.id_maquina, m.codigo, m.nome, m.tipo, m.status, dl.sk_linha
FROM agromaq_industrial.maquina m
JOIN dim_linha dl ON dl.id_linha_origem = m.linha_id
ON DUPLICATE KEY UPDATE codigo = VALUES(codigo), nome_maquina = VALUES(nome_maquina),
                        tipo_maquina = VALUES(tipo_maquina), status_maquina = VALUES(status_maquina),
                        sk_linha = VALUES(sk_linha);

INSERT INTO dim_sensor (id_sensor_origem, codigo_sensor, tipo_sensor, unidade_medida, codigo_maquina,
                        nome_maquina, nome_linha, setor, categoria, unidade, faixa_min, faixa_max)
SELECT s.id_sensor, s.codigo, ts.nome, um.sigla, m.codigo, m.nome, l.nome, st.nome, c.nome, u.nome,
       f.faixa_min, f.faixa_max
FROM agromaq_industrial.sensor s
JOIN agromaq_industrial.tipo_sensor ts       ON ts.id_tipo_sensor    = s.tipo_sensor_id
JOIN agromaq_industrial.unidade_medida um    ON um.id_unidade_medida = ts.unidade_medida_id
JOIN agromaq_industrial.maquina m            ON m.id_maquina         = s.maquina_id
JOIN agromaq_industrial.linha_producao l     ON l.id_linha           = m.linha_id
JOIN agromaq_industrial.setor st             ON st.id_setor          = l.setor_id
JOIN agromaq_industrial.categoria_produto c  ON c.id_categoria       = l.categoria_id
JOIN agromaq_industrial.unidade u            ON u.id_unidade         = c.unidade_id
LEFT JOIN cfg_faixa_sensor f                 ON f.tipo_sensor        = ts.nome COLLATE utf8mb4_unicode_ci
ON DUPLICATE KEY UPDATE codigo_sensor = VALUES(codigo_sensor), tipo_sensor = VALUES(tipo_sensor),
                        unidade_medida = VALUES(unidade_medida), codigo_maquina = VALUES(codigo_maquina),
                        nome_maquina = VALUES(nome_maquina), nome_linha = VALUES(nome_linha),
                        setor = VALUES(setor), categoria = VALUES(categoria), unidade = VALUES(unidade),
                        faixa_min = VALUES(faixa_min), faixa_max = VALUES(faixa_max);

INSERT INTO dim_produto (id_produto_origem, codigo, nome_produto, categoria, unidade, preco_referencia)
SELECT p.item_id, i.codigo, i.nome, c.nome, u.nome, p.preco_referencia
FROM agromaq_industrial.produto p
JOIN agromaq_industrial.item i              ON i.id_item      = p.item_id
JOIN agromaq_industrial.categoria_produto c ON c.id_categoria = p.categoria_id
JOIN agromaq_industrial.unidade u           ON u.id_unidade   = c.unidade_id
ON DUPLICATE KEY UPDATE codigo = VALUES(codigo), nome_produto = VALUES(nome_produto),
                        categoria = VALUES(categoria), unidade = VALUES(unidade),
                        preco_referencia = VALUES(preco_referencia);

-- dim_tempo: um dia por linha, do primeiro ao ultimo dia presente em QUALQUER fato (ate 1.000 dias).
-- Gerada com produto cartesiano de digitos (funciona em MySQL 8 e MariaDB sem configuracao).
INSERT INTO dim_tempo (sk_tempo, data, ano, mes, nome_mes, dia, dia_semana)
WITH digitos (d) AS (SELECT 0 UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
                     UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9),
     limites AS (
         SELECT LEAST(
                    (SELECT DATE(MIN(data_hora)) FROM leitura_tratada),
                    (SELECT DATE(MIN(data_fim_real)) FROM agromaq_industrial.ordem_producao WHERE status = 'CONCLUIDA')) AS ini,
                GREATEST(
                    (SELECT DATE(MAX(data_hora)) FROM leitura_tratada),
                    (SELECT DATE(MAX(data_fim_real)) FROM agromaq_industrial.ordem_producao WHERE status = 'CONCLUIDA')) AS fim),
     dias (dt) AS (
         SELECT l.ini + INTERVAL (a.d + 10*b.d + 100*c.d) DAY
         FROM limites l, digitos a, digitos b, digitos c
         WHERE l.ini + INTERVAL (a.d + 10*b.d + 100*c.d) DAY <= l.fim)
SELECT CAST(DATE_FORMAT(dt, '%Y%m%d') AS UNSIGNED), dt, YEAR(dt), MONTH(dt),
       ELT(MONTH(dt), 'Janeiro','Fevereiro','Marco','Abril','Maio','Junho','Julho','Agosto',
                      'Setembro','Outubro','Novembro','Dezembro'),
       DAY(dt),
       ELT(WEEKDAY(dt) + 1, 'Segunda','Terca','Quarta','Quinta','Sexta','Sabado','Domingo')
FROM dias
ON DUPLICATE KEY UPDATE data = VALUES(data);

COMMIT;

SELECT (SELECT COUNT(*) FROM dim_linha)   AS dim_linha,
       (SELECT COUNT(*) FROM dim_maquina) AS dim_maquina,
       (SELECT COUNT(*) FROM dim_sensor)  AS dim_sensor,
       (SELECT COUNT(*) FROM dim_produto) AS dim_produto,
       (SELECT COUNT(*) FROM dim_tempo)   AS dim_tempo;
