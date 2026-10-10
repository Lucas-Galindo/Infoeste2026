-- =====================================================================
-- CONSULTAS DE VALIDACAO - POPULACAO INICIAL (TABELAS BASE/CADASTRAIS)
-- Todas executadas e conferidas contra a carga real (03_populacao_base.sql)
-- =====================================================================
USE agromaq_industrial;

-- 1. Quantidade de registros por tabela (contagem exata)
SELECT 'pais' t, COUNT(*) qtd FROM pais UNION ALL
SELECT 'estado_provincia', COUNT(*) FROM estado_provincia UNION ALL
SELECT 'unidade_medida', COUNT(*) FROM unidade_medida UNION ALL
SELECT 'unidade', COUNT(*) FROM unidade UNION ALL
SELECT 'setor', COUNT(*) FROM setor UNION ALL
SELECT 'cargo', COUNT(*) FROM cargo UNION ALL
SELECT 'turno', COUNT(*) FROM turno UNION ALL
SELECT 'categoria_produto', COUNT(*) FROM categoria_produto UNION ALL
SELECT 'tipo_material', COUNT(*) FROM tipo_material UNION ALL
SELECT 'tipo_sensor', COUNT(*) FROM tipo_sensor UNION ALL
SELECT 'etapa_processo', COUNT(*) FROM etapa_processo UNION ALL
SELECT 'motivo_nao_conformidade', COUNT(*) FROM motivo_nao_conformidade UNION ALL
SELECT 'tipo_perda', COUNT(*) FROM tipo_perda UNION ALL
SELECT 'tipo_movimentacao_estoque', COUNT(*) FROM tipo_movimentacao_estoque UNION ALL
SELECT 'item', COUNT(*) FROM item UNION ALL
SELECT 'materia_prima', COUNT(*) FROM materia_prima UNION ALL
SELECT 'componente', COUNT(*) FROM componente UNION ALL
SELECT 'produto', COUNT(*) FROM produto UNION ALL
SELECT 'estrutura_bom', COUNT(*) FROM estrutura_bom UNION ALL
SELECT 'fornecedor', COUNT(*) FROM fornecedor UNION ALL
SELECT 'fornecedor_item', COUNT(*) FROM fornecedor_item UNION ALL
SELECT 'linha_producao', COUNT(*) FROM linha_producao UNION ALL
SELECT 'maquina', COUNT(*) FROM maquina UNION ALL
SELECT 'sensor', COUNT(*) FROM sensor UNION ALL
SELECT 'funcionario', COUNT(*) FROM funcionario UNION ALL
SELECT 'cliente', COUNT(*) FROM cliente;

-- 2. REGRA CRITICA: Unidade 1 (Presidente Prudente) so pode ter Trator/Colhedora;
--    Unidade 2 (Tres Lagoas) so pode ter Plantadora/Pulverizador
SELECT u.nome AS unidade, c.nome AS categoria
FROM categoria_produto c
JOIN unidade u ON u.id_unidade = c.unidade_id
ORDER BY u.nome, c.nome;

-- 3. Produtos por categoria (esperado: 5 em cada uma das 4 categorias = 20 total)
SELECT c.nome AS categoria, COUNT(*) AS qtd_produtos,
       MIN(p.preco_referencia) AS preco_min, MAX(p.preco_referencia) AS preco_max
FROM produto p JOIN categoria_produto c ON c.id_categoria = p.categoria_id
GROUP BY c.nome;

-- 4. Linhas de producao por unidade/categoria (nenhuma linha pode cruzar unidade errada)
SELECT u.nome AS unidade, c.nome AS categoria, COUNT(*) AS qtd_linhas
FROM linha_producao l
JOIN categoria_produto c ON c.id_categoria = l.categoria_id
JOIN unidade u ON u.id_unidade = c.unidade_id
GROUP BY u.nome, c.nome
ORDER BY u.nome, c.nome;

-- 5. Maquinas por linha (minimo/maximo/media)
SELECT MIN(qtd) AS min_maquinas_por_linha, MAX(qtd) AS max_maquinas_por_linha,
       ROUND(AVG(qtd), 2) AS media_maquinas_por_linha
FROM (SELECT linha_id, COUNT(*) AS qtd FROM maquina GROUP BY linha_id) x;

-- 6. Sensores totais e amostra por tipo de maquina
SELECT COUNT(*) AS total_sensores FROM sensor;
SELECT m.tipo, COUNT(*) AS qtd_sensores
FROM sensor se JOIN maquina m ON m.id_maquina = se.maquina_id
GROUP BY m.tipo ORDER BY qtd_sensores DESC;

-- 7. Funcionarios por unidade (via setor, ja que funcionario nao tem unidade_id direto)
SELECT u.nome AS unidade, COUNT(*) AS qtd_funcionarios
FROM funcionario f
JOIN setor s ON s.id_setor = f.setor_id
JOIN unidade u ON u.id_unidade = s.unidade_id
GROUP BY u.nome;

-- 8. Funcionarios por status
SELECT status, COUNT(*) FROM funcionario GROUP BY status;

-- 9. Fornecedores por quantidade de itens fornecidos
SELECT f.nome, COUNT(*) AS qtd_itens
FROM fornecedor_item fi JOIN fornecedor f ON f.id_fornecedor = fi.fornecedor_id
GROUP BY f.nome ORDER BY qtd_itens DESC;

-- 10. Garantia: todo item forneciivel (materia-prima ou componente de origem
--     FORNECEDOR) tem pelo menos um fornecedor cadastrado (esperado: 0 em ambas)
SELECT COUNT(*) AS materias_primas_sem_fornecedor
FROM materia_prima mp
WHERE NOT EXISTS (SELECT 1 FROM fornecedor_item fi WHERE fi.item_id = mp.item_id);

SELECT COUNT(*) AS componentes_fornecedor_sem_fornecedor
FROM componente c
WHERE c.origem = 'FORNECEDOR'
  AND NOT EXISTS (SELECT 1 FROM fornecedor_item fi WHERE fi.item_id = c.item_id);

-- 11. Componentes por produto (BOM) - confirma que a estrutura NAO e identica
--     entre categorias diferentes (tratores/colhedoras tem mais itens que
--     plantadoras/pulverizadores, que nao tem motor proprio)
SELECT i.nome AS produto, COUNT(*) AS qtd_componentes_na_bom
FROM estrutura_bom b JOIN item i ON i.id_item = b.item_pai_id
GROUP BY i.nome ORDER BY i.nome;

-- 12. Origem dos componentes e coerencia com categoria_id (regra: FORNECEDOR
--     nunca deve ter categoria_id preenchida; PROPRIA sempre deve, no recorte atual)
SELECT origem, COUNT(*) AS qtd, SUM(categoria_id IS NOT NULL) AS com_categoria_preenchida
FROM componente GROUP BY origem;

-- 13. Clientes por pais e mercado (nacional x internacional, derivado de pais.mercado)
SELECT p.nome AS pais, p.mercado, COUNT(*) AS qtd_clientes
FROM cliente c JOIN pais p ON p.id_pais = c.pais_id
GROUP BY p.nome, p.mercado
ORDER BY p.mercado, p.nome;

-- 14. Integridade cliente.estado_id x cliente.pais_id (esperado: 0 violacoes,
--     ja garantido pelo trigger trg_cliente_valida_estado_pais, checado aqui tambem)
SELECT COUNT(*) AS violacoes_estado_pais
FROM cliente c
JOIN estado_provincia e ON e.id_estado = c.estado_id
WHERE e.pais_id <> c.pais_id;

-- 15. Unicidade de identificadores naturais (esperado: total = distintos em todos)
SELECT (SELECT COUNT(*) FROM funcionario) AS total_funcionarios,
       (SELECT COUNT(DISTINCT matricula) FROM funcionario) AS matriculas_distintas;
SELECT (SELECT COUNT(*) FROM maquina) AS total_maquinas,
       (SELECT COUNT(DISTINCT codigo) FROM maquina) AS codigos_distintos;
SELECT (SELECT COUNT(*) FROM item) AS total_itens,
       (SELECT COUNT(DISTINCT codigo) FROM item) AS codigos_distintos;

-- 16. Materiais/componentes por tipo (visao geral do catalogo de materia-prima)
SELECT tm.nome AS tipo_material, COUNT(*) AS qtd_materia_prima
FROM materia_prima mp JOIN tipo_material tm ON tm.id_tipo_material = mp.tipo_material_id
GROUP BY tm.nome ORDER BY qtd_materia_prima DESC, tm.nome;
