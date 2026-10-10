-- =====================================================================
-- 06b · Carga das FATOS (pratica E2). Padrao: apaga o intervalo e reinsere (carga por particao).
-- Idempotente: rodar de novo para o mesmo intervalo da o mesmo resultado (pratica E3).
-- Pre-requisito: 06a_carga_dimensoes.sql (a fato precisa das chaves substitutas).
-- =====================================================================
USE agromaq_dw;
START TRANSACTION;

-- ---------- fato_leitura_sensor: 1 linha por sensor por hora ----------
SET @lo = (SELECT CAST(DATE_FORMAT(MIN(data_hora), '%Y%m%d') AS UNSIGNED) FROM leitura_tratada);
SET @hi = (SELECT CAST(DATE_FORMAT(MAX(data_hora), '%Y%m%d') AS UNSIGNED) FROM leitura_tratada);

DELETE FROM fato_leitura_sensor WHERE sk_tempo BETWEEN @lo AND @hi;

INSERT INTO fato_leitura_sensor (sk_tempo, hora, turno, sk_sensor, valor, status_leitura, fora_faixa)
SELECT dt.sk_tempo,
       HOUR(lt.data_hora),
       CASE WHEN HOUR(lt.data_hora) BETWEEN 6  AND 13 THEN 'Manha'
            WHEN HOUR(lt.data_hora) BETWEEN 14 AND 21 THEN 'Tarde'
            ELSE 'Noite' END,
       ds.sk_sensor, lt.valor, lt.status_leitura,
       CASE WHEN ds.faixa_min IS NOT NULL
                 AND (lt.valor < ds.faixa_min OR lt.valor > ds.faixa_max) THEN 1 ELSE 0 END
FROM leitura_tratada lt
JOIN dim_sensor ds ON ds.id_sensor_origem = lt.sensor_id
JOIN dim_tempo  dt ON dt.data = DATE(lt.data_hora);

-- ---------- fato_producao: 1 linha por ordem de producao concluida ----------
SET @plo = (SELECT CAST(DATE_FORMAT(MIN(data_fim_real), '%Y%m%d') AS UNSIGNED)
            FROM agromaq_industrial.ordem_producao WHERE status = 'CONCLUIDA');
SET @phi = (SELECT CAST(DATE_FORMAT(MAX(data_fim_real), '%Y%m%d') AS UNSIGNED)
            FROM agromaq_industrial.ordem_producao WHERE status = 'CONCLUIDA');

DELETE FROM fato_producao WHERE sk_tempo BETWEEN @plo AND @phi;

INSERT INTO fato_producao (id_op_origem, numero_op, sk_tempo, sk_linha, sk_produto,
                           quantidade_planejada, quantidade_produzida, quantidade_aprovada,
                           quantidade_retrabalho, quantidade_rejeitada, motivo_principal)
SELECT o.id_op, o.numero_op, dt.sk_tempo, dl.sk_linha, dp.sk_produto,
       o.quantidade_planejada, o.quantidade_produzida, o.quantidade_aprovada,
       o.quantidade_retrabalho, o.quantidade_rejeitada,
       (SELECT mn.nome
        FROM agromaq_industrial.perda p
        JOIN agromaq_industrial.motivo_nao_conformidade mn ON mn.id_motivo = p.motivo_id
        WHERE p.op_id = o.id_op
        GROUP BY mn.id_motivo, mn.nome
        ORDER BY SUM(p.quantidade) DESC, mn.id_motivo
        LIMIT 1)
FROM agromaq_industrial.ordem_producao o
JOIN dim_tempo   dt ON dt.data = DATE(o.data_fim_real)
JOIN dim_linha   dl ON dl.id_linha_origem = o.linha_id
JOIN dim_produto dp ON dp.id_produto_origem = o.item_id
WHERE o.status = 'CONCLUIDA';

COMMIT;

SELECT (SELECT COUNT(*) FROM fato_leitura_sensor) AS fato_leitura_sensor,
       (SELECT SUM(fora_faixa) FROM fato_leitura_sensor) AS fora_da_faixa,
       (SELECT COUNT(*) FROM fato_producao)       AS fato_producao;
