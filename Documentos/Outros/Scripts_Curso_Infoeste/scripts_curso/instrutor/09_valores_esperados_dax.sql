-- =====================================================================
-- 09 · Valores esperados das medidas DAX do Dia 2 (X1 e D1 a D3), calculados em SQL no DW.
-- Se a medida do Power BI mostrar outro numero, o defeito esta na medida ou no modelo.
-- =====================================================================
USE agromaq_dw;

-- Leituras: total, fora da faixa e percentual, por contexto
SELECT 'Total' AS contexto, COUNT(*) AS leituras, SUM(fora_faixa) AS fora_da_faixa,
       ROUND(100 * SUM(fora_faixa) / COUNT(*), 3) AS pct_fora
FROM fato_leitura_sensor
UNION ALL
SELECT t.nome_mes, COUNT(*), SUM(f.fora_faixa), ROUND(100 * SUM(f.fora_faixa) / COUNT(*), 3)
FROM fato_leitura_sensor f JOIN dim_tempo t ON t.sk_tempo = f.sk_tempo
GROUP BY t.mes, t.nome_mes
UNION ALL
SELECT CONCAT('Turno ', f.turno), COUNT(*), SUM(f.fora_faixa), ROUND(100 * SUM(f.fora_faixa) / COUNT(*), 3)
FROM fato_leitura_sensor f GROUP BY f.turno;

-- Producao: total produzido, refugo e %, por mes (e variacao contra o mes anterior)
SELECT t.nome_mes,
       SUM(p.quantidade_produzida)  AS total_produzido,
       SUM(p.quantidade_rejeitada)  AS refugo,
       ROUND(100 * SUM(p.quantidade_rejeitada) / SUM(p.quantidade_produzida), 2) AS pct_refugo,
       SUM(p.quantidade_produzida) - LAG(SUM(p.quantidade_produzida)) OVER (ORDER BY t.mes) AS variacao_produzido_vs_mes_anterior
FROM fato_producao p JOIN dim_tempo t ON t.sk_tempo = p.sk_tempo
GROUP BY t.mes, t.nome_mes ORDER BY t.mes;

-- Producao por unidade fabril (segmentacao da pagina 1)
SELECT l.unidade, SUM(p.quantidade_produzida) AS total_produzido,
       ROUND(100 * SUM(p.quantidade_rejeitada) / SUM(p.quantidade_produzida), 2) AS pct_refugo
FROM fato_producao p JOIN dim_linha l ON l.sk_linha = p.sk_linha
GROUP BY l.unidade ORDER BY l.unidade;

-- Mes anterior (fora da faixa): o que a medida 'Fora da faixa mes anterior' deve mostrar
SELECT t.nome_mes, SUM(f.fora_faixa) AS fora_da_faixa,
       LAG(SUM(f.fora_faixa)) OVER (ORDER BY t.mes) AS fora_no_mes_anterior
FROM fato_leitura_sensor f JOIN dim_tempo t ON t.sk_tempo = f.sk_tempo
GROUP BY t.mes, t.nome_mes ORDER BY t.mes;
