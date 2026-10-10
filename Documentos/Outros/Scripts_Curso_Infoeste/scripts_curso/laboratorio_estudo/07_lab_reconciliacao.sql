USE agromaq_lab;
-- linhas da staging  -  rejeitos  =  linhas na fato ?
SELECT (SELECT COUNT(*) FROM stg_leitura)                                   AS staging,
       (SELECT COUNT(*) FROM etl_rejeito)                                   AS rejeitos,
       (SELECT COUNT(*) FROM stg_leitura) - (SELECT COUNT(*) FROM etl_rejeito) AS esperado_na_fato,
       (SELECT COUNT(*) FROM fato_leitura_sensor)                           AS na_fato;

-- fato sem chave nula / sem orfao de dimensao
SELECT COUNT(*) AS fatos_sem_sensor FROM fato_leitura_sensor f
LEFT JOIN dim_sensor s ON s.sk_sensor = f.sk_sensor WHERE s.sk_sensor IS NULL;
SELECT COUNT(*) AS fatos_sem_tempo FROM fato_leitura_sensor f
LEFT JOIN dim_tempo t ON t.sk_tempo = f.sk_tempo WHERE t.sk_tempo IS NULL;
