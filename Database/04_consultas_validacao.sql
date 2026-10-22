-- =====================================================================
-- CONSULTAS DE VALIDACAO - POPULACAO INICIAL (TABELAS BASE/CADASTRAIS)
-- Versao revisada. Cada consulta indica o resultado ESPERADO.
-- Rodar DEPOIS de 02_schema.sql, 03_populacao_base.sql e 05_ajustes_clientes.sql
-- Execute o arquivo todo com Ctrl+Shift+Enter (cada consulta gera uma aba).
-- =====================================================================
USE agromaq_industrial;

-- 1. Contagem por tabela, com comparacao automatica contra o esperado
--    (esperado NULL = apenas informativo)
SELECT t AS tabela, qtd, esperado,
       IF(esperado IS NULL, '-', IF(qtd = esperado, 'OK', 'DIVERGENTE')) AS resultado
FROM (
    SELECT 'pais' t, COUNT(*) qtd, 10 esperado FROM pais UNION ALL
    SELECT 'estado_provincia', COUNT(*), 50 FROM estado_provincia UNION ALL
    SELECT 'unidade_medida', COUNT(*), 51 FROM unidade_medida UNION ALL
    SELECT 'unidade', COUNT(*), 2 FROM unidade UNION ALL
    SELECT 'setor', COUNT(*), 40 FROM setor UNION ALL
    SELECT 'cargo', COUNT(*), 49 FROM cargo UNION ALL
    SELECT 'turno', COUNT(*), 4 FROM turno UNION ALL
    SELECT 'categoria_produto', COUNT(*), 4 FROM categoria_produto UNION ALL
    SELECT 'tipo_material', COUNT(*), 42 FROM tipo_material UNION ALL
    SELECT 'tipo_sensor', COUNT(*), 40 FROM tipo_sensor UNION ALL
    SELECT 'etapa_processo', COUNT(*), 41 FROM etapa_processo UNION ALL
    SELECT 'motivo_nao_conformidade', COUNT(*), 41 FROM motivo_nao_conformidade UNION ALL
    SELECT 'tipo_perda', COUNT(*), 7 FROM tipo_perda UNION ALL
    SELECT 'tipo_movimentacao_estoque', COUNT(*), 10 FROM tipo_movimentacao_estoque UNION ALL
    SELECT 'item', COUNT(*), 152 FROM item UNION ALL
    SELECT 'materia_prima', COUNT(*), 50 FROM materia_prima UNION ALL
    SELECT 'componente', COUNT(*), 82 FROM componente UNION ALL
    SELECT 'produto', COUNT(*), 20 FROM produto UNION ALL
    SELECT 'estrutura_bom', COUNT(*), 350 FROM estrutura_bom UNION ALL
    SELECT 'fornecedor', COUNT(*), 20 FROM fornecedor UNION ALL
    SELECT 'fornecedor_item', COUNT(*), NULL FROM fornecedor_item UNION ALL
    SELECT 'linha_producao', COUNT(*), 40 FROM linha_producao UNION ALL
    SELECT 'maquina', COUNT(*), 120 FROM maquina UNION ALL
    SELECT 'sensor', COUNT(*), 316 FROM sensor UNION ALL
    SELECT 'funcionario', COUNT(*), 500 FROM funcionario UNION ALL
    SELECT 'cliente', COUNT(*), 42 FROM cliente
) x;

-- 2. REGRA CRITICA: Unidade 1 (Presidente Prudente) so tem Trator/Colhedora;
--    Unidade 2 (Tres Lagoas) so tem Plantadora/Pulverizador.
--    Esperado: 4 linhas (2 por unidade), como descrito acima.
SELECT u.nome AS unidade, c.nome AS categoria
FROM categoria_produto c
JOIN unidade u ON u.id_unidade = c.unidade_id
ORDER BY u.nome, c.nome;

-- 3. Produtos por categoria. Esperado: 5 em cada uma das 4 categorias (20 no total).
SELECT c.nome AS categoria, COUNT(*) AS qtd_produtos,
       MIN(p.preco_referencia) AS preco_min, MAX(p.preco_referencia) AS preco_max
FROM produto p JOIN categoria_produto c ON c.id_categoria = p.categoria_id
GROUP BY c.nome;

-- 4. Linhas de producao por unidade/categoria. Esperado: 10 linhas em cada uma
--    das 4 combinacoes (a checagem de violacao esta na consulta 19).
SELECT u.nome AS unidade, c.nome AS categoria, COUNT(*) AS qtd_linhas
FROM linha_producao l
JOIN categoria_produto c ON c.id_categoria = l.categoria_id
JOIN unidade u ON u.id_unidade = c.unidade_id
GROUP BY u.nome, c.nome
ORDER BY u.nome, c.nome;

-- 5. Maquinas por linha. Esperado: minimo 3, maximo 3, media 3.00
SELECT MIN(qtd) AS min_maquinas_por_linha, MAX(qtd) AS max_maquinas_por_linha,
       ROUND(AVG(qtd), 2) AS media_maquinas_por_linha
FROM (SELECT linha_id, COUNT(*) AS qtd FROM maquina GROUP BY linha_id) x;

-- 6. Sensores totais (esperado: 316) e por tipo de maquina
SELECT COUNT(*) AS total_sensores FROM sensor;
SELECT m.tipo, COUNT(*) AS qtd_sensores
FROM sensor se JOIN maquina m ON m.id_maquina = se.maquina_id
GROUP BY m.tipo ORDER BY qtd_sensores DESC;

-- 7. Funcionarios por unidade (via setor). Esperado: Presidente Prudente 300, Tres Lagoas 200
SELECT u.nome AS unidade, COUNT(*) AS qtd_funcionarios
FROM funcionario f
JOIN setor s ON s.id_setor = f.setor_id
JOIN unidade u ON u.id_unidade = s.unidade_id
GROUP BY u.nome;

-- 8. Funcionarios por status (informativo: a maior parte deve ser ATIVO)
SELECT status, COUNT(*) AS qtd FROM funcionario GROUP BY status;

-- 9. Fornecedores por quantidade de itens fornecidos (informativo)
SELECT f.nome, COUNT(*) AS qtd_itens
FROM fornecedor_item fi JOIN fornecedor f ON f.id_fornecedor = fi.fornecedor_id
GROUP BY f.nome ORDER BY qtd_itens DESC;

-- 10. Todo item fornecivel (materia-prima, ou componente de origem FORNECEDOR)
--     tem pelo menos um fornecedor. Esperado: 0 nas duas consultas.
SELECT COUNT(*) AS materias_primas_sem_fornecedor
FROM materia_prima mp
WHERE NOT EXISTS (SELECT 1 FROM fornecedor_item fi WHERE fi.item_id = mp.item_id);

SELECT COUNT(*) AS componentes_fornecedor_sem_fornecedor
FROM componente c
WHERE c.origem = 'FORNECEDOR'
  AND NOT EXISTS (SELECT 1 FROM fornecedor_item fi WHERE fi.item_id = c.item_id);

-- 11. Componentes por produto na BOM de topo (produto -> componente).
--     Esperado: Tratores e Colhedoras com 23 componentes; Plantadoras e
--     Pulverizadores com 12 (nao tem motor proprio). Ainda nao ha BOM
--     componente -> subcomponente nesta carga.
SELECT i.nome AS produto, COUNT(*) AS qtd_componentes_na_bom
FROM estrutura_bom b JOIN item i ON i.id_item = b.item_pai_id
GROUP BY i.nome ORDER BY i.nome;

-- 12. Origem dos componentes e coerencia com categoria_id.
--     Esperado: FORNECEDOR = 58 componentes, 0 com categoria;
--               PROPRIA    = 24 componentes, 24 com categoria.
SELECT origem, COUNT(*) AS qtd, SUM(categoria_id IS NOT NULL) AS com_categoria_preenchida
FROM componente GROUP BY origem;

-- 13. Clientes por pais e mercado. Esperado: Brasil NACIONAL com 7 clientes;
--     EUA, Chile, Mexico, Africa do Sul e China INTERNACIONAL com 7 cada.
--     (Argentina, Paraguai, Uruguai e Canada existem como pais, sem clientes.)
SELECT p.nome AS pais, p.mercado, COUNT(*) AS qtd_clientes
FROM cliente c JOIN pais p ON p.id_pais = c.pais_id
GROUP BY p.nome, p.mercado
ORDER BY p.mercado, p.nome;

-- 14. Integridade cliente.estado_id x cliente.pais_id. Esperado: 0
--     (ja garantido pelos triggers trg_cliente_valida_estado_pais_ins/_upd)
SELECT COUNT(*) AS violacoes_estado_pais
FROM cliente c
JOIN estado_provincia e ON e.id_estado = c.estado_id
WHERE e.pais_id <> c.pais_id;

-- 15. Unicidade de identificadores naturais. Esperado: total = distintos em todos
SELECT (SELECT COUNT(*) FROM funcionario) AS total_funcionarios,
       (SELECT COUNT(DISTINCT matricula) FROM funcionario) AS matriculas_distintas;
SELECT (SELECT COUNT(*) FROM maquina) AS total_maquinas,
       (SELECT COUNT(DISTINCT codigo) FROM maquina) AS codigos_distintos;
SELECT (SELECT COUNT(*) FROM sensor) AS total_sensores,
       (SELECT COUNT(DISTINCT codigo) FROM sensor) AS codigos_distintos;
SELECT (SELECT COUNT(*) FROM item) AS total_itens,
       (SELECT COUNT(DISTINCT codigo) FROM item) AS codigos_distintos;

-- 16. Materias-primas por tipo de material (informativo)
SELECT tm.nome AS tipo_material, COUNT(*) AS qtd_materia_prima
FROM materia_prima mp JOIN tipo_material tm ON tm.id_tipo_material = mp.tipo_material_id
GROUP BY tm.nome ORDER BY qtd_materia_prima DESC, tm.nome;

-- ---------------------------------------------------------------------
-- CONSULTAS NOVAS (17 em diante)
-- ---------------------------------------------------------------------

-- 17. Itens por tipo. Esperado: MATERIA_PRIMA 50, COMPONENTE 82, PRODUTO_ACABADO 20
SELECT tipo_item, COUNT(*) AS qtd FROM item GROUP BY tipo_item;

-- 17b. Item sem registro no subtipo correspondente. Esperado: 0
SELECT COUNT(*) AS itens_sem_subtipo
FROM item i
WHERE (i.tipo_item = 'MATERIA_PRIMA'   AND NOT EXISTS (SELECT 1 FROM materia_prima m WHERE m.item_id = i.id_item))
   OR (i.tipo_item = 'COMPONENTE'      AND NOT EXISTS (SELECT 1 FROM componente c    WHERE c.item_id = i.id_item))
   OR (i.tipo_item = 'PRODUTO_ACABADO' AND NOT EXISTS (SELECT 1 FROM produto p       WHERE p.item_id = i.id_item));

-- 18. BOM com componente proprio de categoria diferente da do produto
--     (ex.: Trator usando "Chassi Colhedora"). Esperado: 0
SELECT COUNT(*) AS bom_categoria_incompativel
FROM estrutura_bom b
JOIN produto p    ON p.item_id = b.item_pai_id
JOIN componente c ON c.item_id = b.componente_filho_id
WHERE c.categoria_id IS NOT NULL
  AND c.categoria_id <> p.categoria_id;

-- 19. Linha de producao cujo setor e categoria estao em unidades diferentes. Esperado: 0
SELECT COUNT(*) AS linhas_unidade_incoerente
FROM linha_producao l
JOIN setor s            ON s.id_setor = l.setor_id
JOIN categoria_produto c ON c.id_categoria = l.categoria_id
WHERE s.unidade_id <> c.unidade_id;

-- 20. Maquinas sem sensor, e fornecedores sem itens. Esperado: 0 em ambas
SELECT COUNT(*) AS maquinas_sem_sensor
FROM maquina m
WHERE NOT EXISTS (SELECT 1 FROM sensor s WHERE s.maquina_id = m.id_maquina);

SELECT COUNT(*) AS fornecedores_sem_itens
FROM fornecedor f
WHERE NOT EXISTS (SELECT 1 FROM fornecedor_item fi WHERE fi.fornecedor_id = f.id_fornecedor);

-- 21. Funcionario com data de admissao no futuro. Esperado: 0
SELECT COUNT(*) AS admissoes_futuras FROM funcionario WHERE data_admissao > CURDATE();

-- 22. Coerencia cidade x estado x pais dos clientes (REVISAO VISUAL).
--     Depois do 05_ajustes_clientes.sql, cada cidade deve pertencer ao estado exibido.
SELECT c.id_cliente, c.nome, c.cidade, e.nome AS estado, p.nome AS pais
FROM cliente c
JOIN pais p ON p.id_pais = c.pais_id
LEFT JOIN estado_provincia e ON e.id_estado = c.estado_id
ORDER BY p.nome, e.nome, c.cidade;

-- 23. Tabelas de fatos/operacionais devem estar VAZIAS nesta etapa. Esperado: 0 em todas
SELECT 'lote' t, COUNT(*) qtd FROM lote UNION ALL
SELECT 'ordem_producao', COUNT(*) FROM ordem_producao UNION ALL
SELECT 'op_etapa', COUNT(*) FROM op_etapa UNION ALL
SELECT 'op_consumo_lote', COUNT(*) FROM op_consumo_lote UNION ALL
SELECT 'inspecao_qualidade', COUNT(*) FROM inspecao_qualidade UNION ALL
SELECT 'perda', COUNT(*) FROM perda UNION ALL
SELECT 'estoque_movimentacao', COUNT(*) FROM estoque_movimentacao UNION ALL
SELECT 'produto_serial', COUNT(*) FROM produto_serial UNION ALL
SELECT 'venda', COUNT(*) FROM venda UNION ALL
SELECT 'venda_item', COUNT(*) FROM venda_item UNION ALL
SELECT 'venda_item_serial', COUNT(*) FROM venda_item_serial UNION ALL
SELECT 'leitura_sensor', COUNT(*) FROM leitura_sensor;
