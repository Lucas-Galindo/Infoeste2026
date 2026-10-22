-- =====================================================================
-- AJUSTE DE COERENCIA CIDADE x ESTADO NA TABELA CLIENTE
-- Rodar UMA vez, depois de 03_populacao_base.sql (nao precisa refazer o 03).
-- Corrige estado_id (quando a cidade esta certa) ou a cidade (quando o estado
-- escolhido e o que faz sentido). Todos os UPDATEs usam a chave id_cliente,
-- entao funcionam com o "Safe Updates" ligado no Workbench.
-- =====================================================================
USE agromaq_industrial;

-- ---------- BRASIL (corrige o estado) ----------
UPDATE cliente SET estado_id = 25 WHERE id_cliente IN (1, 6);   -- Ribeirao Preto -> Sao Paulo
UPDATE cliente SET estado_id = 16 WHERE id_cliente IN (2, 3, 7); -- Londrina / Cascavel -> Parana
UPDATE cliente SET estado_id = 11 WHERE id_cliente = 4;          -- Rondonopolis -> Mato Grosso
UPDATE cliente SET estado_id = 13 WHERE id_cliente = 5;          -- Uberlandia -> Minas Gerais

-- ---------- ESTADOS UNIDOS ----------
UPDATE cliente SET estado_id = 30 WHERE id_cliente IN (8, 13);   -- Des Moines -> Iowa
UPDATE cliente SET estado_id = 31 WHERE id_cliente IN (9, 14);   -- Springfield -> Illinois
UPDATE cliente SET estado_id = 28 WHERE id_cliente = 10;         -- Fresno -> California
UPDATE cliente SET cidade = 'Peoria'  WHERE id_cliente = 11;     -- estado Illinois
UPDATE cliente SET cidade = 'Orlando' WHERE id_cliente = 12;     -- estado Florida

-- ---------- CHILE ----------
UPDATE cliente SET cidade = 'Valparaiso' WHERE id_cliente = 16;  -- estado Valparaiso
UPDATE cliente SET cidade = 'Santiago'   WHERE id_cliente IN (18, 21); -- Regiao Metropolitana
UPDATE cliente SET estado_id = 35 WHERE id_cliente = 19;         -- Chillan -> Biobio
UPDATE cliente SET estado_id = 33 WHERE id_cliente = 20;         -- Santiago -> Regiao Metropolitana

-- ---------- MEXICO ----------
UPDATE cliente SET estado_id = 37 WHERE id_cliente IN (22, 27);  -- Guadalajara -> Jalisco
UPDATE cliente SET estado_id = 38 WHERE id_cliente IN (23, 28);  -- Monterrey -> Nuevo Leon
UPDATE cliente SET cidade = 'Monterrey'         WHERE id_cliente = 24; -- estado Nuevo Leon
UPDATE cliente SET cidade = 'Ciudad de Mexico'  WHERE id_cliente = 25; -- estado Cidade do Mexico
UPDATE cliente SET cidade = 'Guadalajara'       WHERE id_cliente = 26; -- estado Jalisco

-- ---------- AFRICA DO SUL ----------
UPDATE cliente SET estado_id = 39 WHERE id_cliente IN (30, 34);  -- Pretoria / Johannesburgo -> Gauteng
UPDATE cliente SET cidade = 'Johannesburgo'  WHERE id_cliente = 32; -- estado Gauteng
UPDATE cliente SET cidade = 'Cidade do Cabo' WHERE id_cliente = 33; -- estado Western Cape

-- ---------- CHINA ----------
UPDATE cliente SET estado_id = 43 WHERE id_cliente = 36;         -- Xangai
UPDATE cliente SET estado_id = 42 WHERE id_cliente IN (37, 42);  -- Guangzhou -> Guangdong
UPDATE cliente SET cidade = 'Shenzhen' WHERE id_cliente = 40;    -- estado Guangdong

-- ---------- CONFERENCIA ----------
SELECT c.id_cliente, c.nome, c.cidade, e.nome AS estado, p.nome AS pais
FROM cliente c
JOIN pais p ON p.id_pais = c.pais_id
LEFT JOIN estado_provincia e ON e.id_estado = c.estado_id
ORDER BY c.id_cliente;
