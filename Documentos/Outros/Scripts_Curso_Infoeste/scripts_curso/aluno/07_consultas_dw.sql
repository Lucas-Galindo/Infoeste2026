-- =====================================================================
-- 07 · Consultas do DW: reconciliacao, integridade e perguntas de negocio
-- (o dado virou informacao). Rode depois da carga e compare com gabarito_leituras.json
-- e gabarito_producao.json.
-- =====================================================================
USE agromaq_dw;

-- R1. A conta que fecha: staging - rejeitos = fato
SELECT (SELECT COUNT(*) FROM stg_leitura)                                      AS staging,
       (SELECT COUNT(*) FROM etl_rejeito)                                      AS rejeitos,
       (SELECT COUNT(*) FROM stg_leitura) - (SELECT COUNT(*) FROM etl_rejeito) AS esperado_na_fato,
       (SELECT COUNT(*) FROM fato_leitura_sensor)                              AS na_fato;

-- R2. Rejeitos por motivo
SELECT motivo, COUNT(*) AS n FROM etl_rejeito GROUP BY motivo ORDER BY motivo;

-- R3. Integridade: fatos sem dimensao (todos devem dar 0)
SELECT 'leitura sem sensor' AS teste, COUNT(*) AS n FROM fato_leitura_sensor f
  LEFT JOIN dim_sensor s ON s.sk_sensor = f.sk_sensor WHERE s.sk_sensor IS NULL
UNION ALL SELECT 'leitura sem tempo', COUNT(*) FROM fato_leitura_sensor f
  LEFT JOIN dim_tempo t ON t.sk_tempo = f.sk_tempo WHERE t.sk_tempo IS NULL
UNION ALL SELECT 'producao sem linha', COUNT(*) FROM fato_producao f
  LEFT JOIN dim_linha l ON l.sk_linha = f.sk_linha WHERE l.sk_linha IS NULL
UNION ALL SELECT 'producao sem produto', COUNT(*) FROM fato_producao f
  LEFT JOIN dim_produto p ON p.sk_produto = f.sk_produto WHERE p.sk_produto IS NULL
UNION ALL SELECT 'producao sem tempo', COUNT(*) FROM fato_producao f
  LEFT JOIN dim_tempo t ON t.sk_tempo = f.sk_tempo WHERE t.sk_tempo IS NULL;

-- R4. Producao no DW = producao no OLTP (a outra reconciliacao)
SELECT (SELECT SUM(quantidade_produzida) FROM agromaq_industrial.ordem_producao WHERE status = 'CONCLUIDA') AS produzido_oltp,
       (SELECT SUM(quantidade_produzida) FROM fato_producao)                                               AS produzido_dw,
       (SELECT SUM(quantidade) FROM agromaq_industrial.perda WHERE op_id IN
            (SELECT id_op FROM agromaq_industrial.ordem_producao WHERE numero_op LIKE 'OP2026-%'))        AS perdas_oltp,
       (SELECT SUM(quantidade_rejeitada) FROM fato_producao)                                               AS rejeitado_dw;

-- Q1. Quantas leituras sairam da faixa, por categoria e por turno?
SELECT ds.categoria, f.turno, SUM(f.fora_faixa) AS fora_da_faixa
FROM fato_leitura_sensor f JOIN dim_sensor ds ON ds.sk_sensor = f.sk_sensor
GROUP BY ds.categoria, f.turno
HAVING SUM(f.fora_faixa) > 0
ORDER BY ds.categoria, f.turno;

-- Q2. Quanto produzimos e quanto refugamos, por mes?
SELECT t.mes, t.nome_mes, SUM(p.quantidade_produzida) AS produzido, SUM(p.quantidade_rejeitada) AS rejeitado,
       ROUND(100 * SUM(p.quantidade_rejeitada) / SUM(p.quantidade_produzida), 2) AS pct_refugo
FROM fato_producao p JOIN dim_tempo t ON t.sk_tempo = p.sk_tempo
GROUP BY t.mes, t.nome_mes ORDER BY t.mes;

-- Q3. Onde perdemos? Refugo por setor e mes (o setor de soldagem se destaca em marco)
SELECT l.setor, t.nome_mes, SUM(p.quantidade_produzida) AS produzido,
       ROUND(100 * SUM(p.quantidade_rejeitada) / SUM(p.quantidade_produzida), 2) AS pct_refugo
FROM fato_producao p
JOIN dim_linha l ON l.sk_linha = p.sk_linha
JOIN dim_tempo t ON t.sk_tempo = p.sk_tempo
GROUP BY l.setor, t.mes, t.nome_mes ORDER BY l.setor, t.mes;

-- Q4. Por que? Motivo principal das ordens com refugo nas linhas de soldagem, em marco
SELECT p.motivo_principal, COUNT(*) AS ordens, SUM(p.quantidade_rejeitada) AS pecas_rejeitadas
FROM fato_producao p
JOIN dim_linha l ON l.sk_linha = p.sk_linha
JOIN dim_tempo t ON t.sk_tempo = p.sk_tempo
WHERE l.setor = 'Soldagem' AND t.mes = 3 AND p.motivo_principal IS NOT NULL
GROUP BY p.motivo_principal ORDER BY pecas_rejeitadas DESC;
