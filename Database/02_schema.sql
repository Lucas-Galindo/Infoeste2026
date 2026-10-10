-- =====================================================================
-- BANCO DE DADOS INDUSTRIAL — FABRICAÇÃO DE MÁQUINAS AGRÍCOLAS
-- VERSÃO 2 — REVISADA EM AUDITORIA (ver 01_modelagem_conceitual.md, seção 9)
-- Etapa: somente estrutura (DDL). NÃO POPULAR COM DADOS OPERACIONAIS.
-- MySQL 8.0+ / InnoDB / utf8mb4
-- =====================================================================

-- ---------------------------------------------------------------------
-- 12. CRIAÇÃO DO BANCO
-- ---------------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS agromaq_industrial
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE agromaq_industrial;

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 1;

-- =====================================================================
-- 13. CRIAÇÃO DAS TABELAS
-- =====================================================================

-- ---------- CATÁLOGOS ----------

CREATE TABLE unidade (
    id_unidade      INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo          VARCHAR(10)  NOT NULL,
    nome            VARCHAR(100) NOT NULL,
    cidade          VARCHAR(100) NOT NULL,
    estado_sigla    CHAR(2)      NOT NULL,
    status          ENUM('ATIVA','INATIVA') NOT NULL DEFAULT 'ATIVA'
) ENGINE=InnoDB;

CREATE TABLE unidade_medida (
    id_unidade_medida INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    sigla             VARCHAR(10)  NOT NULL,
    descricao         VARCHAR(60)  NOT NULL
) ENGINE=InnoDB;

CREATE TABLE setor (
    id_setor        INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    unidade_id      INT UNSIGNED NOT NULL,
    nome            VARCHAR(100) NOT NULL,
    status          ENUM('ATIVO','INATIVO') NOT NULL DEFAULT 'ATIVO'
) ENGINE=InnoDB;

CREATE TABLE cargo (
    id_cargo        INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nome            VARCHAR(100) NOT NULL
) ENGINE=InnoDB;

CREATE TABLE turno (
    id_turno        INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nome            VARCHAR(30)  NOT NULL,
    hora_inicio     TIME NOT NULL,
    hora_fim        TIME NOT NULL
) ENGINE=InnoDB;

-- categoria_produto: cada categoria pertence a exatamente uma unidade fabril
-- (Trator/Colhedora -> Presidente Prudente; Plantadora/Pulverizador -> Três Lagoas).
CREATE TABLE categoria_produto (
    id_categoria    INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    unidade_id      INT UNSIGNED NOT NULL,
    nome            VARCHAR(50)  NOT NULL
) ENGINE=InnoDB;

CREATE TABLE tipo_material (
    id_tipo_material INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nome             VARCHAR(80) NOT NULL
) ENGINE=InnoDB;

CREATE TABLE tipo_sensor (
    id_tipo_sensor      INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    unidade_medida_id   INT UNSIGNED NOT NULL,
    nome                VARCHAR(60) NOT NULL
) ENGINE=InnoDB;

CREATE TABLE etapa_processo (
    id_etapa        INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nome            VARCHAR(80) NOT NULL
) ENGINE=InnoDB;

CREATE TABLE motivo_nao_conformidade (
    id_motivo       INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nome            VARCHAR(100) NOT NULL
) ENGINE=InnoDB;

CREATE TABLE tipo_perda (
    id_tipo_perda   INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nome            VARCHAR(100) NOT NULL
) ENGINE=InnoDB;

CREATE TABLE tipo_movimentacao_estoque (
    id_tipo_mov     INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nome            VARCHAR(60) NOT NULL,
    natureza        ENUM('ENTRADA','SAIDA','AJUSTE') NOT NULL
) ENGINE=InnoDB;

-- pais.mercado é o único ponto de armazenamento do conceito NACIONAL/INTERNACIONAL.
-- cliente NÃO repete esse dado (revisão item 3): mercado do cliente = pais.mercado.
CREATE TABLE pais (
    id_pais         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nome            VARCHAR(80) NOT NULL,
    sigla_iso       CHAR(2)     NOT NULL,
    mercado         ENUM('NACIONAL','INTERNACIONAL') NOT NULL
) ENGINE=InnoDB;

CREATE TABLE estado_provincia (
    id_estado       INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    pais_id         INT UNSIGNED NOT NULL,
    nome            VARCHAR(80) NOT NULL,
    sigla           VARCHAR(10)
) ENGINE=InnoDB;

-- ---------- ESTRUTURA ORGANIZACIONAL / IoT ----------

CREATE TABLE linha_producao (
    id_linha        INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    setor_id        INT UNSIGNED NOT NULL,
    categoria_id    INT UNSIGNED NOT NULL,
    nome            VARCHAR(100) NOT NULL,
    capacidade_produtiva DECIMAL(14,2),
    status          ENUM('ATIVA','INATIVA') NOT NULL DEFAULT 'ATIVA',
    CONSTRAINT chk_linha_capacidade_positiva CHECK (capacidade_produtiva IS NULL OR capacidade_produtiva > 0)
) ENGINE=InnoDB;

CREATE TABLE maquina (
    id_maquina      INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    linha_id        INT UNSIGNED NOT NULL,
    codigo          VARCHAR(30)  NOT NULL,
    nome            VARCHAR(100) NOT NULL,
    tipo            VARCHAR(80)  NOT NULL,
    fabricante      VARCHAR(100),
    modelo          VARCHAR(100),
    capacidade      DECIMAL(14,2),
    status          ENUM('ATIVA','PARADA','INATIVA') NOT NULL DEFAULT 'ATIVA',
    CONSTRAINT chk_maquina_capacidade_positiva CHECK (capacidade IS NULL OR capacidade > 0)
) ENGINE=InnoDB;

CREATE TABLE sensor (
    id_sensor       INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    maquina_id      INT UNSIGNED NOT NULL,
    tipo_sensor_id  INT UNSIGNED NOT NULL,
    codigo          VARCHAR(30)  NOT NULL,
    status          ENUM('ATIVO','INATIVO') NOT NULL DEFAULT 'ATIVO'
) ENGINE=InnoDB;

-- leitura_sensor: particionada por mês (RANGE COLUMNS em data_hora).
-- REVISÃO ITEM 13: cobertura estendida para 5 anos civis (2025-01 a 2029-12) + partição
-- de captura (p_futuro), dando folga confortável sobre os 3 anos de dataset planejados,
-- independentemente do ano-calendário exato em que a carga realmente começar.
-- Para expandir no futuro: ALTER TABLE leitura_sensor REORGANIZE PARTITION p_futuro INTO
-- (PARTITION p_2030_01 VALUES LESS THAN ('2030-02-01'), ..., PARTITION p_futuro VALUES LESS THAN (MAXVALUE));
CREATE TABLE leitura_sensor (
    id_leitura      BIGINT UNSIGNED AUTO_INCREMENT,
    sensor_id       INT UNSIGNED NOT NULL,
    data_hora       DATETIME NOT NULL,
    valor           DECIMAL(18,4) NOT NULL,
    status_leitura  ENUM('VALIDA','SUSPEITA','ERRO') NOT NULL DEFAULT 'VALIDA',
    PRIMARY KEY (id_leitura, data_hora)
) ENGINE=InnoDB
  PARTITION BY RANGE COLUMNS (data_hora) (
    PARTITION p_2025_01 VALUES LESS THAN ('2025-02-01'),
    PARTITION p_2025_02 VALUES LESS THAN ('2025-03-01'),
    PARTITION p_2025_03 VALUES LESS THAN ('2025-04-01'),
    PARTITION p_2025_04 VALUES LESS THAN ('2025-05-01'),
    PARTITION p_2025_05 VALUES LESS THAN ('2025-06-01'),
    PARTITION p_2025_06 VALUES LESS THAN ('2025-07-01'),
    PARTITION p_2025_07 VALUES LESS THAN ('2025-08-01'),
    PARTITION p_2025_08 VALUES LESS THAN ('2025-09-01'),
    PARTITION p_2025_09 VALUES LESS THAN ('2025-10-01'),
    PARTITION p_2025_10 VALUES LESS THAN ('2025-11-01'),
    PARTITION p_2025_11 VALUES LESS THAN ('2025-12-01'),
    PARTITION p_2025_12 VALUES LESS THAN ('2026-01-01'),
    PARTITION p_2026_01 VALUES LESS THAN ('2026-02-01'),
    PARTITION p_2026_02 VALUES LESS THAN ('2026-03-01'),
    PARTITION p_2026_03 VALUES LESS THAN ('2026-04-01'),
    PARTITION p_2026_04 VALUES LESS THAN ('2026-05-01'),
    PARTITION p_2026_05 VALUES LESS THAN ('2026-06-01'),
    PARTITION p_2026_06 VALUES LESS THAN ('2026-07-01'),
    PARTITION p_2026_07 VALUES LESS THAN ('2026-08-01'),
    PARTITION p_2026_08 VALUES LESS THAN ('2026-09-01'),
    PARTITION p_2026_09 VALUES LESS THAN ('2026-10-01'),
    PARTITION p_2026_10 VALUES LESS THAN ('2026-11-01'),
    PARTITION p_2026_11 VALUES LESS THAN ('2026-12-01'),
    PARTITION p_2026_12 VALUES LESS THAN ('2027-01-01'),
    PARTITION p_2027_01 VALUES LESS THAN ('2027-02-01'),
    PARTITION p_2027_02 VALUES LESS THAN ('2027-03-01'),
    PARTITION p_2027_03 VALUES LESS THAN ('2027-04-01'),
    PARTITION p_2027_04 VALUES LESS THAN ('2027-05-01'),
    PARTITION p_2027_05 VALUES LESS THAN ('2027-06-01'),
    PARTITION p_2027_06 VALUES LESS THAN ('2027-07-01'),
    PARTITION p_2027_07 VALUES LESS THAN ('2027-08-01'),
    PARTITION p_2027_08 VALUES LESS THAN ('2027-09-01'),
    PARTITION p_2027_09 VALUES LESS THAN ('2027-10-01'),
    PARTITION p_2027_10 VALUES LESS THAN ('2027-11-01'),
    PARTITION p_2027_11 VALUES LESS THAN ('2027-12-01'),
    PARTITION p_2027_12 VALUES LESS THAN ('2028-01-01'),
    PARTITION p_2028_01 VALUES LESS THAN ('2028-02-01'),
    PARTITION p_2028_02 VALUES LESS THAN ('2028-03-01'),
    PARTITION p_2028_03 VALUES LESS THAN ('2028-04-01'),
    PARTITION p_2028_04 VALUES LESS THAN ('2028-05-01'),
    PARTITION p_2028_05 VALUES LESS THAN ('2028-06-01'),
    PARTITION p_2028_06 VALUES LESS THAN ('2028-07-01'),
    PARTITION p_2028_07 VALUES LESS THAN ('2028-08-01'),
    PARTITION p_2028_08 VALUES LESS THAN ('2028-09-01'),
    PARTITION p_2028_09 VALUES LESS THAN ('2028-10-01'),
    PARTITION p_2028_10 VALUES LESS THAN ('2028-11-01'),
    PARTITION p_2028_11 VALUES LESS THAN ('2028-12-01'),
    PARTITION p_2028_12 VALUES LESS THAN ('2029-01-01'),
    PARTITION p_2029_01 VALUES LESS THAN ('2029-02-01'),
    PARTITION p_2029_02 VALUES LESS THAN ('2029-03-01'),
    PARTITION p_2029_03 VALUES LESS THAN ('2029-04-01'),
    PARTITION p_2029_04 VALUES LESS THAN ('2029-05-01'),
    PARTITION p_2029_05 VALUES LESS THAN ('2029-06-01'),
    PARTITION p_2029_06 VALUES LESS THAN ('2029-07-01'),
    PARTITION p_2029_07 VALUES LESS THAN ('2029-08-01'),
    PARTITION p_2029_08 VALUES LESS THAN ('2029-09-01'),
    PARTITION p_2029_09 VALUES LESS THAN ('2029-10-01'),
    PARTITION p_2029_10 VALUES LESS THAN ('2029-11-01'),
    PARTITION p_2029_11 VALUES LESS THAN ('2029-12-01'),
    PARTITION p_2029_12 VALUES LESS THAN ('2030-01-01'),
    PARTITION p_futuro  VALUES LESS THAN (MAXVALUE)
  );

-- funcionario: REVISÃO ITEM 5 — unidade_id REMOVIDO (era redundante e podia divergir
-- de setor.unidade_id). A unidade do funcionário é sempre obtida via setor_id -> setor.unidade_id.
CREATE TABLE funcionario (
    id_funcionario  INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    matricula       VARCHAR(20)  NOT NULL,
    nome            VARCHAR(150) NOT NULL,
    cargo_id        INT UNSIGNED NOT NULL,
    setor_id        INT UNSIGNED NOT NULL,
    turno_id        INT UNSIGNED NOT NULL,
    data_admissao   DATE NOT NULL,
    status          ENUM('ATIVO','INATIVO') NOT NULL DEFAULT 'ATIVO'
) ENGINE=InnoDB;

-- ---------- MATERIAIS (SUPERTIPO / SUBTIPO) ----------

CREATE TABLE item (
    id_item             INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    tipo_item           ENUM('MATERIA_PRIMA','COMPONENTE','PRODUTO_ACABADO') NOT NULL,
    codigo              VARCHAR(30)  NOT NULL,
    nome                VARCHAR(150) NOT NULL,
    unidade_medida_id   INT UNSIGNED NOT NULL,
    status              ENUM('ATIVO','INATIVO') NOT NULL DEFAULT 'ATIVO'
) ENGINE=InnoDB;

CREATE TABLE materia_prima (
    item_id             INT UNSIGNED PRIMARY KEY,
    tipo_material_id    INT UNSIGNED NOT NULL
) ENGINE=InnoDB;

-- componente: REVISÃO ITEM 1 e 2 — componente_pai_id (auto-hierarquia) foi REMOVIDO.
-- A hierarquia multi-nível de BOM (componente -> subcomponentes) e o BOM produto ->
-- componente agora vivem juntos, com quantidade, na tabela genérica `estrutura_bom`
-- (ver abaixo). categoria_id foi ADICIONADO (NULLABLE): quando um componente de
-- fabricação própria é específico de uma categoria de produto (ex.: "Chassi Trator"),
-- isso é registrado aqui e usado para validar OP x linha (revisão item 6). Componentes
-- genéricos/compartilhados entre categorias (ex.: parafusos padronizados) deixam NULL.
CREATE TABLE componente (
    item_id             INT UNSIGNED PRIMARY KEY,
    origem              ENUM('PROPRIA','FORNECEDOR') NOT NULL,
    categoria_id        INT UNSIGNED NULL
) ENGINE=InnoDB;
-- OBS: categoria_id só deve ser preenchida para componentes de origem PROPRIA
-- (um componente comprado de fornecedor não tem "categoria de fabricação própria" —
-- ver seção 2.1/2.15 do documento conceitual); garantido por trigger, pois envolve
-- duas colunas da própria linha (CHECK entre colunas da mesma tabela seria possível,
-- mas o padrão do restante do schema usa trigger para manter a mensagem de erro
-- consistente com as demais regras de negócio).

CREATE TABLE produto (
    item_id             INT UNSIGNED PRIMARY KEY,
    categoria_id        INT UNSIGNED NOT NULL,
    descricao           VARCHAR(255),
    capacidade_produtiva DECIMAL(14,2),
    preco_referencia    DECIMAL(14,2) NOT NULL,
    status              ENUM('ATIVO','DESCONTINUADO') NOT NULL DEFAULT 'ATIVO',
    CONSTRAINT chk_produto_preco_positivo CHECK (preco_referencia > 0),
    CONSTRAINT chk_produto_capacidade_positiva CHECK (capacidade_produtiva IS NULL OR capacidade_produtiva > 0)
) ENGINE=InnoDB;

-- estrutura_bom: REVISÃO ITEM 2 — generaliza a antiga `produto_componente`.
-- item_pai_id é o item "montado" (pode ser um PRODUTO_ACABADO ou um COMPONENTE,
-- pois um componente próprio também pode ser montado a partir de subcomponentes).
-- componente_filho_id é sempre um COMPONENTE (a peça consumida na montagem).
-- Isso cobre, com UMA única tabela, tanto:
--   Produto     -> Componente        (BOM de topo)
--   Componente  -> Subcomponente     (BOM multi-nível, agora COM quantidade por nível,
--                                      o que o antigo componente_pai_id não permitia)
CREATE TABLE estrutura_bom (
    item_pai_id         INT UNSIGNED NOT NULL,
    componente_filho_id INT UNSIGNED NOT NULL,
    quantidade          DECIMAL(14,4) NOT NULL,
    unidade_medida_id   INT UNSIGNED NOT NULL,
    PRIMARY KEY (item_pai_id, componente_filho_id),
    CONSTRAINT chk_bom_quantidade_positiva CHECK (quantidade > 0)
) ENGINE=InnoDB;

-- ---------- FORNECIMENTO E RASTREABILIDADE ----------

CREATE TABLE fornecedor (
    id_fornecedor   INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nome            VARCHAR(150) NOT NULL,
    cnpj_ficticio   VARCHAR(20),
    cidade          VARCHAR(100),
    estado_sigla    CHAR(2),
    status          ENUM('ATIVO','INATIVO') NOT NULL DEFAULT 'ATIVO'
) ENGINE=InnoDB;

-- fornecedor_item: REVISÃO ITEM 12 — só pode referenciar MATERIA_PRIMA ou COMPONENTE
-- de origem FORNECEDOR (nunca PRODUTO_ACABADO nem componente de fabricação própria);
-- validado por trigger, ver seção de triggers.
CREATE TABLE fornecedor_item (
    fornecedor_id       INT UNSIGNED NOT NULL,
    item_id             INT UNSIGNED NOT NULL,
    preco_referencia    DECIMAL(14,2),
    prazo_entrega_dias  SMALLINT UNSIGNED,
    PRIMARY KEY (fornecedor_id, item_id),
    CONSTRAINT chk_forneceditem_preco_positivo CHECK (preco_referencia IS NULL OR preco_referencia > 0)
) ENGINE=InnoDB;

CREATE TABLE lote (
    id_lote                 INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    numero_lote             VARCHAR(40) NOT NULL,
    materia_prima_item_id   INT UNSIGNED NOT NULL,
    fornecedor_id           INT UNSIGNED NOT NULL,
    data_entrada            DATE NOT NULL,
    quantidade              DECIMAL(14,3) NOT NULL,
    validade                DATE NULL,
    origem                  VARCHAR(150),
    CONSTRAINT chk_lote_quantidade_positiva CHECK (quantidade > 0)
) ENGINE=InnoDB;

-- ---------- PRODUÇÃO ----------

-- ordem_producao: REVISÃO ITEM 1 (PROBLEMA CRÍTICO) — produto_item_id renomeado para
-- item_id e agora referencia o SUPERTIPO `item`, não mais apenas `produto`. Isso permite
-- que uma OP fabrique tanto um PRODUTO_ACABADO quanto um COMPONENTE de fabricação
-- própria. Trigger garante: (a) item não pode ser MATERIA_PRIMA; (b) se for COMPONENTE,
-- este deve ter origem = 'PROPRIA'; (c) a categoria do item deve ser compatível com a
-- categoria da linha informada (revisão item 6).
CREATE TABLE ordem_producao (
    id_op                   INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    numero_op               VARCHAR(30) NOT NULL,
    item_id                 INT UNSIGNED NOT NULL,
    linha_id                INT UNSIGNED NOT NULL,
    quantidade_planejada    DECIMAL(14,2) NOT NULL,
    quantidade_produzida    DECIMAL(14,2) NOT NULL DEFAULT 0,
    quantidade_aprovada     DECIMAL(14,2) NOT NULL DEFAULT 0,
    quantidade_retrabalho   DECIMAL(14,2) NOT NULL DEFAULT 0,
    quantidade_rejeitada    DECIMAL(14,2) NOT NULL DEFAULT 0,
    data_inicio_planejada   DATE,
    data_fim_planejada      DATE,
    data_inicio_real        DATETIME,
    data_fim_real           DATETIME,
    status                  ENUM('PLANEJADA','EM_ANDAMENTO','CONCLUIDA','CANCELADA')
                                NOT NULL DEFAULT 'PLANEJADA',
    CONSTRAINT chk_op_qtd_produzida CHECK (quantidade_produzida <= quantidade_planejada),
    CONSTRAINT chk_op_qtd_resultado CHECK (
        quantidade_aprovada + quantidade_retrabalho + quantidade_rejeitada
        <= quantidade_produzida
    ),
    CONSTRAINT chk_op_datas_planejadas CHECK (
        data_fim_planejada IS NULL OR data_inicio_planejada IS NULL
        OR data_fim_planejada >= data_inicio_planejada
    ),
    CONSTRAINT chk_op_datas_reais CHECK (
        data_fim_real IS NULL OR data_inicio_real IS NULL
        OR data_fim_real >= data_inicio_real
    ),
    CONSTRAINT chk_op_qtd_planejada_positiva CHECK (quantidade_planejada > 0)
) ENGINE=InnoDB;

CREATE TABLE op_consumo_lote (
    op_id               INT UNSIGNED NOT NULL,
    lote_id             INT UNSIGNED NOT NULL,
    quantidade_consumida DECIMAL(14,3) NOT NULL,
    PRIMARY KEY (op_id, lote_id),
    CONSTRAINT chk_opconsumo_quantidade_positiva CHECK (quantidade_consumida > 0)
) ENGINE=InnoDB;

CREATE TABLE op_etapa (
    id_op_etapa     INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    op_id           INT UNSIGNED NOT NULL,
    etapa_id        INT UNSIGNED NOT NULL,
    sequencia       SMALLINT UNSIGNED NOT NULL,
    funcionario_id  INT UNSIGNED NULL,
    data_inicio     DATETIME,
    data_fim        DATETIME,
    status          ENUM('PENDENTE','EM_ANDAMENTO','CONCLUIDA') NOT NULL DEFAULT 'PENDENTE',
    CONSTRAINT chk_op_etapa_datas CHECK (
        data_fim IS NULL OR data_inicio IS NULL OR data_fim >= data_inicio
    ),
    CONSTRAINT chk_op_etapa_sequencia_positiva CHECK (sequencia > 0)
) ENGINE=InnoDB;

CREATE TABLE inspecao_qualidade (
    id_inspecao         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    op_etapa_id         INT UNSIGNED NOT NULL,
    resultado           ENUM('APROVADO','REPROVADO','RETRABALHO') NOT NULL,
    motivo_id           INT UNSIGNED NULL,
    funcionario_id      INT UNSIGNED NULL,
    data_hora           DATETIME NOT NULL,
    observacao          VARCHAR(255)
) ENGINE=InnoDB;

-- perda: REVISÃO ITEM 8 — etapa_id (catálogo genérico) REMOVIDO e substituído por
-- op_etapa_id (instância real de etapa dentro de uma OP específica). op_id é mantido,
-- nullable, para perdas que não estão ligadas a nenhuma etapa específica (ex.: perda de
-- matéria-prima no recebimento, antes de qualquer OP). Trigger garante consistência
-- entre op_id e op_etapa_id quando ambos informados (ver seção de triggers).
CREATE TABLE perda (
    id_perda        INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    tipo_perda_id   INT UNSIGNED NOT NULL,
    op_id           INT UNSIGNED NULL,
    op_etapa_id     INT UNSIGNED NULL,
    item_id         INT UNSIGNED NULL,
    quantidade      DECIMAL(14,3) NOT NULL,
    unidade_medida_id INT UNSIGNED NOT NULL,
    data_ocorrencia DATE NOT NULL,
    motivo_id       INT UNSIGNED NULL,
    observacao      VARCHAR(255),
    CONSTRAINT chk_perda_quantidade_positiva CHECK (quantidade > 0)
) ENGINE=InnoDB;

-- ---------- ESTOQUE ----------

-- estoque_movimentacao: sem FK polimórfica (item_id sempre aponta para o supertipo
-- `item`). REVISÃO ITEM 11 — triggers adicionais garantem que: (a) se lote_id
-- informado, item_id deve ser o item da matéria-prima daquele lote; (b) se op_id
-- informado e a movimentação não é consumo de lote, item_id deve ser o item que a
-- própria OP produz; (c) se venda_item_id informado, item_id deve ser o item vendido.
CREATE TABLE estoque_movimentacao (
    id_movimentacao INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    item_id         INT UNSIGNED NOT NULL,
    unidade_id      INT UNSIGNED NOT NULL,
    lote_id         INT UNSIGNED NULL,
    tipo_mov_id     INT UNSIGNED NOT NULL,
    quantidade      DECIMAL(14,3) NOT NULL,
    data_hora       DATETIME NOT NULL,
    op_id           INT UNSIGNED NULL,
    venda_item_id   INT UNSIGNED NULL,
    documento_ref   VARCHAR(60),
    CONSTRAINT chk_estmov_quantidade_positiva CHECK (quantidade > 0)
) ENGINE=InnoDB;

-- ---------- PRODUTO ACABADO E COMERCIAL ----------

-- produto_serial: REVISÃO ITEM 7 — linha_id e unidade_id REMOVIDOS (eram totalmente
-- derivados de op_id -> ordem_producao.linha_id -> linha_producao.setor_id ->
-- setor.unidade_id; mantê-los criava risco de divergência sem nenhum ganho de
-- integridade). produto_item_id é MANTIDO (é o dado semântico central do registro) e
-- validado por trigger contra ordem_producao.item_id (revisão item 10).
CREATE TABLE produto_serial (
    id_serial       INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    numero_serie    VARCHAR(40) NOT NULL,
    produto_item_id INT UNSIGNED NOT NULL,
    op_id           INT UNSIGNED NOT NULL,
    data_fabricacao DATE NOT NULL,
    status_qualidade ENUM('APROVADO','REPROVADO','RETRABALHO','PENDENTE')
                        NOT NULL DEFAULT 'PENDENTE'
) ENGINE=InnoDB;

-- cliente: REVISÃO ITEM 3 — tipo_mercado REMOVIDO (derivado de pais.mercado via
-- pais_id; ver views/consultas na camada analítica). REVISÃO ITEM 4 — a consistência
-- estado_id x pais_id é garantida por trigger (um estado só pode ser vinculado a um
-- cliente do mesmo país do estado).
CREATE TABLE cliente (
    id_cliente      INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nome            VARCHAR(150) NOT NULL,
    pais_id         INT UNSIGNED NOT NULL,
    estado_id       INT UNSIGNED NULL,
    cidade          VARCHAR(100),
    status          ENUM('ATIVO','INATIVO') NOT NULL DEFAULT 'ATIVO'
) ENGINE=InnoDB;

CREATE TABLE venda (
    id_venda        INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    numero_pedido   VARCHAR(30) NOT NULL,
    cliente_id      INT UNSIGNED NOT NULL,
    data_venda      DATE NOT NULL,
    destino         VARCHAR(150),
    status          ENUM('ABERTO','FATURADO','ENVIADO','CANCELADO') NOT NULL DEFAULT 'ABERTO'
) ENGINE=InnoDB;

CREATE TABLE venda_item (
    id_venda_item   INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    venda_id        INT UNSIGNED NOT NULL,
    produto_item_id INT UNSIGNED NOT NULL,
    quantidade      DECIMAL(14,2) NOT NULL,
    preco_unitario  DECIMAL(14,2) NOT NULL,
    valor_total     DECIMAL(16,2) AS (quantidade * preco_unitario) STORED,
    CONSTRAINT chk_vendaitem_quantidade_positiva CHECK (quantidade > 0),
    CONSTRAINT chk_vendaitem_preco_positivo CHECK (preco_unitario > 0)
) ENGINE=InnoDB;

CREATE TABLE venda_item_serial (
    venda_item_id   INT UNSIGNED NOT NULL,
    serial_id       INT UNSIGNED NOT NULL,
    PRIMARY KEY (venda_item_id, serial_id)
) ENGINE=InnoDB;

-- =====================================================================
-- 14. CONSTRAINTS (CHAVES ESTRANGEIRAS)
-- =====================================================================

ALTER TABLE setor
    ADD CONSTRAINT fk_setor_unidade
        FOREIGN KEY (unidade_id) REFERENCES unidade(id_unidade)
        ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE categoria_produto
    ADD CONSTRAINT fk_categoria_unidade
        FOREIGN KEY (unidade_id) REFERENCES unidade(id_unidade)
        ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE tipo_sensor
    ADD CONSTRAINT fk_tiposensor_unidademedida
        FOREIGN KEY (unidade_medida_id) REFERENCES unidade_medida(id_unidade_medida)
        ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE estado_provincia
    ADD CONSTRAINT fk_estado_pais
        FOREIGN KEY (pais_id) REFERENCES pais(id_pais)
        ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE linha_producao
    ADD CONSTRAINT fk_linha_setor
        FOREIGN KEY (setor_id) REFERENCES setor(id_setor)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    ADD CONSTRAINT fk_linha_categoria
        FOREIGN KEY (categoria_id) REFERENCES categoria_produto(id_categoria)
        ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE maquina
    ADD CONSTRAINT fk_maquina_linha
        FOREIGN KEY (linha_id) REFERENCES linha_producao(id_linha)
        ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE sensor
    ADD CONSTRAINT fk_sensor_maquina
        FOREIGN KEY (maquina_id) REFERENCES maquina(id_maquina)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    ADD CONSTRAINT fk_sensor_tiposensor
        FOREIGN KEY (tipo_sensor_id) REFERENCES tipo_sensor(id_tipo_sensor)
        ON UPDATE CASCADE ON DELETE RESTRICT;

-- OBS: leitura_sensor é particionada (RANGE) e o MySQL/MariaDB NÃO permite FOREIGN KEY
-- em tabelas particionadas. A integridade referencial de sensor_id é garantida na
-- camada de ingestão/ETL; a busca é garantida pelo índice ix_leitura_sensor_data.

ALTER TABLE funcionario
    ADD CONSTRAINT fk_funcionario_cargo
        FOREIGN KEY (cargo_id) REFERENCES cargo(id_cargo)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    ADD CONSTRAINT fk_funcionario_setor
        FOREIGN KEY (setor_id) REFERENCES setor(id_setor)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    ADD CONSTRAINT fk_funcionario_turno
        FOREIGN KEY (turno_id) REFERENCES turno(id_turno)
        ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE item
    ADD CONSTRAINT fk_item_unidademedida
        FOREIGN KEY (unidade_medida_id) REFERENCES unidade_medida(id_unidade_medida)
        ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE materia_prima
    ADD CONSTRAINT fk_materiaprima_item
        FOREIGN KEY (item_id) REFERENCES item(id_item)
        ON UPDATE CASCADE ON DELETE CASCADE,
    ADD CONSTRAINT fk_materiaprima_tipomaterial
        FOREIGN KEY (tipo_material_id) REFERENCES tipo_material(id_tipo_material)
        ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE componente
    ADD CONSTRAINT fk_componente_item
        FOREIGN KEY (item_id) REFERENCES item(id_item)
        ON UPDATE CASCADE ON DELETE CASCADE,
    ADD CONSTRAINT fk_componente_categoria
        FOREIGN KEY (categoria_id) REFERENCES categoria_produto(id_categoria)
        ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE produto
    ADD CONSTRAINT fk_produto_item
        FOREIGN KEY (item_id) REFERENCES item(id_item)
        ON UPDATE CASCADE ON DELETE CASCADE,
    ADD CONSTRAINT fk_produto_categoria
        FOREIGN KEY (categoria_id) REFERENCES categoria_produto(id_categoria)
        ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE estrutura_bom
    ADD CONSTRAINT fk_bom_itempai
        FOREIGN KEY (item_pai_id) REFERENCES item(id_item)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    ADD CONSTRAINT fk_bom_componentefilho
        FOREIGN KEY (componente_filho_id) REFERENCES componente(item_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    ADD CONSTRAINT fk_bom_unidademedida
        FOREIGN KEY (unidade_medida_id) REFERENCES unidade_medida(id_unidade_medida)
        ON UPDATE CASCADE ON DELETE RESTRICT;
-- OBS: item_pai_id só pode ser PRODUTO_ACABADO ou COMPONENTE, e não pode ser igual a
-- componente_filho_id (evita auto-referência direta) — garantido por trigger, pois o
-- MySQL/MariaDB recusa CHECK sobre coluna que já participa de FOREIGN KEY (erro 1901,
-- confirmado em teste). Ciclos indiretos multi-nível (A usa B, B usa C, C usa A) ficam
-- como responsabilidade da aplicação/ETL (exigiriam CTE recursiva fora do escopo de uma
-- constraint declarativa).

ALTER TABLE fornecedor_item
    ADD CONSTRAINT fk_forneceditem_fornecedor
        FOREIGN KEY (fornecedor_id) REFERENCES fornecedor(id_fornecedor)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    ADD CONSTRAINT fk_forneceditem_item
        FOREIGN KEY (item_id) REFERENCES item(id_item)
        ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE lote
    ADD CONSTRAINT fk_lote_materiaprima
        FOREIGN KEY (materia_prima_item_id) REFERENCES materia_prima(item_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    ADD CONSTRAINT fk_lote_fornecedor
        FOREIGN KEY (fornecedor_id) REFERENCES fornecedor(id_fornecedor)
        ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE ordem_producao
    ADD CONSTRAINT fk_op_item
        FOREIGN KEY (item_id) REFERENCES item(id_item)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    ADD CONSTRAINT fk_op_linha
        FOREIGN KEY (linha_id) REFERENCES linha_producao(id_linha)
        ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE op_consumo_lote
    ADD CONSTRAINT fk_opconsumo_op
        FOREIGN KEY (op_id) REFERENCES ordem_producao(id_op)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    ADD CONSTRAINT fk_opconsumo_lote
        FOREIGN KEY (lote_id) REFERENCES lote(id_lote)
        ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE op_etapa
    ADD CONSTRAINT fk_opetapa_op
        FOREIGN KEY (op_id) REFERENCES ordem_producao(id_op)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    ADD CONSTRAINT fk_opetapa_etapa
        FOREIGN KEY (etapa_id) REFERENCES etapa_processo(id_etapa)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    ADD CONSTRAINT fk_opetapa_funcionario
        FOREIGN KEY (funcionario_id) REFERENCES funcionario(id_funcionario)
        ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE inspecao_qualidade
    ADD CONSTRAINT fk_inspecao_opetapa
        FOREIGN KEY (op_etapa_id) REFERENCES op_etapa(id_op_etapa)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    ADD CONSTRAINT fk_inspecao_motivo
        FOREIGN KEY (motivo_id) REFERENCES motivo_nao_conformidade(id_motivo)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    ADD CONSTRAINT fk_inspecao_funcionario
        FOREIGN KEY (funcionario_id) REFERENCES funcionario(id_funcionario)
        ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE perda
    ADD CONSTRAINT fk_perda_tipoperda
        FOREIGN KEY (tipo_perda_id) REFERENCES tipo_perda(id_tipo_perda)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    ADD CONSTRAINT fk_perda_op
        FOREIGN KEY (op_id) REFERENCES ordem_producao(id_op)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    ADD CONSTRAINT fk_perda_opetapa
        FOREIGN KEY (op_etapa_id) REFERENCES op_etapa(id_op_etapa)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    ADD CONSTRAINT fk_perda_item
        FOREIGN KEY (item_id) REFERENCES item(id_item)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    ADD CONSTRAINT fk_perda_unidademedida
        FOREIGN KEY (unidade_medida_id) REFERENCES unidade_medida(id_unidade_medida)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    ADD CONSTRAINT fk_perda_motivo
        FOREIGN KEY (motivo_id) REFERENCES motivo_nao_conformidade(id_motivo)
        ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE estoque_movimentacao
    ADD CONSTRAINT fk_estmov_item
        FOREIGN KEY (item_id) REFERENCES item(id_item)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    ADD CONSTRAINT fk_estmov_unidade
        FOREIGN KEY (unidade_id) REFERENCES unidade(id_unidade)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    ADD CONSTRAINT fk_estmov_lote
        FOREIGN KEY (lote_id) REFERENCES lote(id_lote)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    ADD CONSTRAINT fk_estmov_tipomov
        FOREIGN KEY (tipo_mov_id) REFERENCES tipo_movimentacao_estoque(id_tipo_mov)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    ADD CONSTRAINT fk_estmov_op
        FOREIGN KEY (op_id) REFERENCES ordem_producao(id_op)
        ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE produto_serial
    ADD CONSTRAINT fk_serial_produto
        FOREIGN KEY (produto_item_id) REFERENCES produto(item_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    ADD CONSTRAINT fk_serial_op
        FOREIGN KEY (op_id) REFERENCES ordem_producao(id_op)
        ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE cliente
    ADD CONSTRAINT fk_cliente_pais
        FOREIGN KEY (pais_id) REFERENCES pais(id_pais)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    ADD CONSTRAINT fk_cliente_estado
        FOREIGN KEY (estado_id) REFERENCES estado_provincia(id_estado)
        ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE venda
    ADD CONSTRAINT fk_venda_cliente
        FOREIGN KEY (cliente_id) REFERENCES cliente(id_cliente)
        ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE venda_item
    ADD CONSTRAINT fk_vendaitem_venda
        FOREIGN KEY (venda_id) REFERENCES venda(id_venda)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    ADD CONSTRAINT fk_vendaitem_produto
        FOREIGN KEY (produto_item_id) REFERENCES produto(item_id)
        ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE estoque_movimentacao
    ADD CONSTRAINT fk_estmov_vendaitem
        FOREIGN KEY (venda_item_id) REFERENCES venda_item(id_venda_item)
        ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE venda_item_serial
    ADD CONSTRAINT fk_vis_vendaitem
        FOREIGN KEY (venda_item_id) REFERENCES venda_item(id_venda_item)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    ADD CONSTRAINT fk_vis_serial
        FOREIGN KEY (serial_id) REFERENCES produto_serial(id_serial)
        ON UPDATE CASCADE ON DELETE RESTRICT;

-- =====================================================================
-- 15. CRIAÇÃO DOS ÍNDICES
-- =====================================================================
-- (índices em FKs já são criados automaticamente pelo InnoDB; abaixo,
-- apenas índices adicionais relevantes para busca/unicidade/analytics)

CREATE UNIQUE INDEX ux_unidade_codigo            ON unidade(codigo);
CREATE UNIQUE INDEX ux_item_codigo               ON item(codigo);
CREATE INDEX ix_item_tipo                        ON item(tipo_item);
CREATE UNIQUE INDEX ux_lote_numero                ON lote(numero_lote);
CREATE INDEX ix_lote_data_entrada                ON lote(data_entrada);
CREATE UNIQUE INDEX ux_op_numero                  ON ordem_producao(numero_op);
CREATE INDEX ix_op_item                           ON ordem_producao(item_id);
CREATE INDEX ix_op_datas_reais                    ON ordem_producao(data_inicio_real, data_fim_real);
CREATE INDEX ix_op_status                         ON ordem_producao(status);
-- REVISÃO ITEM 9: uma OP não pode ter duas etapas com a mesma sequência.
CREATE UNIQUE INDEX ux_opetapa_op_sequencia       ON op_etapa(op_id, sequencia);
CREATE INDEX ix_inspecao_data                     ON inspecao_qualidade(data_hora);
CREATE INDEX ix_inspecao_resultado                ON inspecao_qualidade(resultado);
CREATE INDEX ix_perda_data                        ON perda(data_ocorrencia);
CREATE INDEX ix_perda_tipo                        ON perda(tipo_perda_id);
CREATE INDEX ix_perda_opetapa                     ON perda(op_etapa_id);
CREATE INDEX ix_estmov_data                       ON estoque_movimentacao(data_hora);
CREATE INDEX ix_estmov_item_unidade               ON estoque_movimentacao(item_id, unidade_id);
CREATE UNIQUE INDEX ux_serial_numero              ON produto_serial(numero_serie);
CREATE INDEX ix_serial_data_fabricacao            ON produto_serial(data_fabricacao);
CREATE INDEX ix_serial_op                         ON produto_serial(op_id);
CREATE UNIQUE INDEX ux_venda_numero_pedido        ON venda(numero_pedido);
CREATE INDEX ix_venda_data                        ON venda(data_venda);
CREATE INDEX ix_cliente_pais                      ON cliente(pais_id);
CREATE INDEX ix_leitura_sensor_data               ON leitura_sensor(sensor_id, data_hora);
CREATE INDEX ix_sensor_maquina                    ON sensor(maquina_id);
-- REVISÃO (auditoria de verificação): código de máquina, código de sensor e matrícula
-- de funcionário são identificadores naturais e devem ser únicos.
CREATE UNIQUE INDEX ux_maquina_codigo             ON maquina(codigo);
CREATE UNIQUE INDEX ux_sensor_codigo              ON sensor(codigo);
CREATE UNIQUE INDEX ux_funcionario_matricula      ON funcionario(matricula);
-- índice reverso da BOM: "em quais montagens este componente entra" (explosão reversa)
CREATE INDEX ix_bom_componentefilho               ON estrutura_bom(componente_filho_id);
CREATE INDEX ix_componente_categoria              ON componente(categoria_id);

-- =====================================================================
-- TRIGGERS DE INTEGRIDADE COMPLEMENTAR
-- =====================================================================
DELIMITER $$

-- ---------------------------------------------------------------------
-- Linha de produção: categoria da linha deve pertencer à mesma unidade do setor
-- (Unidade 1 = Trator/Colhedora; Unidade 2 = Plantadora/Pulverizador).
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_linha_valida_unidade_categoria
BEFORE INSERT ON linha_producao
FOR EACH ROW
BEGIN
    DECLARE v_unidade_setor INT UNSIGNED;
    DECLARE v_unidade_categoria INT UNSIGNED;

    SELECT unidade_id INTO v_unidade_setor FROM setor WHERE id_setor = NEW.setor_id;
    SELECT unidade_id INTO v_unidade_categoria FROM categoria_produto WHERE id_categoria = NEW.categoria_id;

    IF v_unidade_setor <> v_unidade_categoria THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'A categoria da linha de produção não pertence à mesma unidade do setor informado.';
    END IF;
END$$

CREATE TRIGGER trg_linha_valida_unidade_categoria_upd
BEFORE UPDATE ON linha_producao
FOR EACH ROW
BEGIN
    DECLARE v_unidade_setor INT UNSIGNED;
    DECLARE v_unidade_categoria INT UNSIGNED;

    SELECT unidade_id INTO v_unidade_setor FROM setor WHERE id_setor = NEW.setor_id;
    SELECT unidade_id INTO v_unidade_categoria FROM categoria_produto WHERE id_categoria = NEW.categoria_id;

    IF v_unidade_setor <> v_unidade_categoria THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'A categoria da linha de produção não pertence à mesma unidade do setor informado.';
    END IF;
END$$

-- ---------------------------------------------------------------------
-- Subtipos de item: cada subtipo só aceita item_id com tipo_item compatível.
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_materiaprima_valida_tipo
BEFORE INSERT ON materia_prima
FOR EACH ROW
BEGIN
    DECLARE v_tipo VARCHAR(20);
    SELECT tipo_item INTO v_tipo FROM item WHERE id_item = NEW.item_id;
    IF v_tipo <> 'MATERIA_PRIMA' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'item_id informado não é do tipo MATERIA_PRIMA em item.tipo_item.';
    END IF;
END$$

CREATE TRIGGER trg_componente_valida_tipo
BEFORE INSERT ON componente
FOR EACH ROW
BEGIN
    DECLARE v_tipo VARCHAR(20);
    SELECT tipo_item INTO v_tipo FROM item WHERE id_item = NEW.item_id;
    IF v_tipo <> 'COMPONENTE' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'item_id informado não é do tipo COMPONENTE em item.tipo_item.';
    END IF;
    IF NEW.origem = 'FORNECEDOR' AND NEW.categoria_id IS NOT NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Componente de origem FORNECEDOR não deve ter categoria_id preenchida.';
    END IF;
END$$

-- REVISÃO (auditoria de verificação): as checagens de tipo_item para os subtipos só
-- existiam para BEFORE INSERT; adicionadas as versões BEFORE UPDATE para cobrir também
-- o caso (raro, mas possível via ON UPDATE CASCADE de item.id_item) de atualização.
CREATE TRIGGER trg_materiaprima_valida_tipo_upd
BEFORE UPDATE ON materia_prima
FOR EACH ROW
BEGIN
    DECLARE v_tipo VARCHAR(20);
    SELECT tipo_item INTO v_tipo FROM item WHERE id_item = NEW.item_id;
    IF v_tipo <> 'MATERIA_PRIMA' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'item_id informado não é do tipo MATERIA_PRIMA em item.tipo_item.';
    END IF;
END$$

CREATE TRIGGER trg_componente_valida_tipo_upd
BEFORE UPDATE ON componente
FOR EACH ROW
BEGIN
    DECLARE v_tipo VARCHAR(20);
    SELECT tipo_item INTO v_tipo FROM item WHERE id_item = NEW.item_id;
    IF v_tipo <> 'COMPONENTE' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'item_id informado não é do tipo COMPONENTE em item.tipo_item.';
    END IF;
    IF NEW.origem = 'FORNECEDOR' AND NEW.categoria_id IS NOT NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Componente de origem FORNECEDOR não deve ter categoria_id preenchida.';
    END IF;
END$$

CREATE TRIGGER trg_produto_valida_tipo_upd
BEFORE UPDATE ON produto
FOR EACH ROW
BEGIN
    DECLARE v_tipo VARCHAR(20);
    SELECT tipo_item INTO v_tipo FROM item WHERE id_item = NEW.item_id;
    IF v_tipo <> 'PRODUTO_ACABADO' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'item_id informado não é do tipo PRODUTO_ACABADO em item.tipo_item.';
    END IF;
END$$

CREATE TRIGGER trg_produto_valida_tipo
BEFORE INSERT ON produto
FOR EACH ROW
BEGIN
    DECLARE v_tipo VARCHAR(20);
    SELECT tipo_item INTO v_tipo FROM item WHERE id_item = NEW.item_id;
    IF v_tipo <> 'PRODUTO_ACABADO' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'item_id informado não é do tipo PRODUTO_ACABADO em item.tipo_item.';
    END IF;
END$$

-- ---------------------------------------------------------------------
-- REVISÃO ITEM 2: estrutura_bom — item_pai_id deve ser PRODUTO_ACABADO ou COMPONENTE
-- (nunca MATERIA_PRIMA), e não pode ser igual ao próprio componente_filho_id.
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_bom_valida_itempai_ins
BEFORE INSERT ON estrutura_bom
FOR EACH ROW
BEGIN
    DECLARE v_tipo VARCHAR(20);
    SELECT tipo_item INTO v_tipo FROM item WHERE id_item = NEW.item_pai_id;
    IF v_tipo NOT IN ('PRODUTO_ACABADO','COMPONENTE') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'item_pai_id da BOM deve ser um PRODUTO_ACABADO ou um COMPONENTE.';
    END IF;
    IF NEW.item_pai_id = NEW.componente_filho_id THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Um item não pode compor a si mesmo na estrutura da BOM.';
    END IF;
END$$

CREATE TRIGGER trg_bom_valida_itempai_upd
BEFORE UPDATE ON estrutura_bom
FOR EACH ROW
BEGIN
    DECLARE v_tipo VARCHAR(20);
    SELECT tipo_item INTO v_tipo FROM item WHERE id_item = NEW.item_pai_id;
    IF v_tipo NOT IN ('PRODUTO_ACABADO','COMPONENTE') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'item_pai_id da BOM deve ser um PRODUTO_ACABADO ou um COMPONENTE.';
    END IF;
    IF NEW.item_pai_id = NEW.componente_filho_id THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Um item não pode compor a si mesmo na estrutura da BOM.';
    END IF;
END$$

-- ---------------------------------------------------------------------
-- REVISÃO ITEM 1 e 6 (PROBLEMA CRÍTICO): ordem_producao.
-- (a) item_id não pode ser MATERIA_PRIMA;
-- (b) se COMPONENTE, deve ter origem = 'PROPRIA' (só se fabrica internamente o que é
--     de fabricação própria — não faz sentido OP para item comprado de fornecedor);
-- (c) a categoria do item (produto.categoria_id ou componente.categoria_id, quando
--     preenchida) deve ser igual à categoria_id da linha informada.
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_op_valida_item_linha_ins
BEFORE INSERT ON ordem_producao
FOR EACH ROW
BEGIN
    DECLARE v_tipo VARCHAR(20);
    DECLARE v_origem VARCHAR(20);
    DECLARE v_categoria_item INT UNSIGNED;
    DECLARE v_categoria_linha INT UNSIGNED;

    SELECT tipo_item INTO v_tipo FROM item WHERE id_item = NEW.item_id;

    IF v_tipo = 'MATERIA_PRIMA' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Uma Ordem de Produção não pode fabricar MATERIA_PRIMA.';
    END IF;

    SELECT categoria_id INTO v_categoria_linha FROM linha_producao WHERE id_linha = NEW.linha_id;

    IF v_tipo = 'PRODUTO_ACABADO' THEN
        SELECT categoria_id INTO v_categoria_item FROM produto WHERE item_id = NEW.item_id;
        IF v_categoria_item <> v_categoria_linha THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'A categoria do produto da OP não corresponde à categoria da linha de produção.';
        END IF;
    ELSEIF v_tipo = 'COMPONENTE' THEN
        SELECT origem, categoria_id INTO v_origem, v_categoria_item FROM componente WHERE item_id = NEW.item_id;
        IF v_origem <> 'PROPRIA' THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Uma Ordem de Produção só pode fabricar componente de origem PROPRIA.';
        END IF;
        IF v_categoria_item IS NOT NULL AND v_categoria_item <> v_categoria_linha THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'A categoria do componente da OP não corresponde à categoria da linha de produção.';
        END IF;
    END IF;
END$$

CREATE TRIGGER trg_op_valida_item_linha_upd
BEFORE UPDATE ON ordem_producao
FOR EACH ROW
BEGIN
    DECLARE v_tipo VARCHAR(20);
    DECLARE v_origem VARCHAR(20);
    DECLARE v_categoria_item INT UNSIGNED;
    DECLARE v_categoria_linha INT UNSIGNED;

    SELECT tipo_item INTO v_tipo FROM item WHERE id_item = NEW.item_id;

    IF v_tipo = 'MATERIA_PRIMA' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Uma Ordem de Produção não pode fabricar MATERIA_PRIMA.';
    END IF;

    SELECT categoria_id INTO v_categoria_linha FROM linha_producao WHERE id_linha = NEW.linha_id;

    IF v_tipo = 'PRODUTO_ACABADO' THEN
        SELECT categoria_id INTO v_categoria_item FROM produto WHERE item_id = NEW.item_id;
        IF v_categoria_item <> v_categoria_linha THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'A categoria do produto da OP não corresponde à categoria da linha de produção.';
        END IF;
    ELSEIF v_tipo = 'COMPONENTE' THEN
        SELECT origem, categoria_id INTO v_origem, v_categoria_item FROM componente WHERE item_id = NEW.item_id;
        IF v_origem <> 'PROPRIA' THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Uma Ordem de Produção só pode fabricar componente de origem PROPRIA.';
        END IF;
        IF v_categoria_item IS NOT NULL AND v_categoria_item <> v_categoria_linha THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'A categoria do componente da OP não corresponde à categoria da linha de produção.';
        END IF;
    END IF;
END$$

-- ---------------------------------------------------------------------
-- REVISÃO ITEM 10: produto_serial.produto_item_id deve ser exatamente o item que a
-- própria OP (op_id) está fabricando — mesmo que ambas as FKs individuais sejam válidas.
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_serial_valida_op_ins
BEFORE INSERT ON produto_serial
FOR EACH ROW
BEGIN
    DECLARE v_item_op INT UNSIGNED;
    SELECT item_id INTO v_item_op FROM ordem_producao WHERE id_op = NEW.op_id;
    IF v_item_op <> NEW.produto_item_id THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'O produto do número de série não corresponde ao item fabricado pela Ordem de Produção informada.';
    END IF;
END$$

CREATE TRIGGER trg_serial_valida_op_upd
BEFORE UPDATE ON produto_serial
FOR EACH ROW
BEGIN
    DECLARE v_item_op INT UNSIGNED;
    SELECT item_id INTO v_item_op FROM ordem_producao WHERE id_op = NEW.op_id;
    IF v_item_op <> NEW.produto_item_id THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'O produto do número de série não corresponde ao item fabricado pela Ordem de Produção informada.';
    END IF;
END$$

-- ---------------------------------------------------------------------
-- REVISÃO ITEM 8: perda — se op_etapa_id informado, deve pertencer à mesma OP indicada
-- em op_id (ou, se op_id vier vazio, é preenchido automaticamente a partir da etapa).
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_perda_valida_op_etapa_ins
BEFORE INSERT ON perda
FOR EACH ROW
BEGIN
    DECLARE v_op_da_etapa INT UNSIGNED;
    IF NEW.op_etapa_id IS NOT NULL THEN
        SELECT op_id INTO v_op_da_etapa FROM op_etapa WHERE id_op_etapa = NEW.op_etapa_id;
        IF NEW.op_id IS NULL THEN
            SET NEW.op_id = v_op_da_etapa;
        ELSEIF NEW.op_id <> v_op_da_etapa THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'A etapa informada na perda não pertence à Ordem de Produção informada.';
        END IF;
    END IF;
END$$

CREATE TRIGGER trg_perda_valida_op_etapa_upd
BEFORE UPDATE ON perda
FOR EACH ROW
BEGIN
    DECLARE v_op_da_etapa INT UNSIGNED;
    IF NEW.op_etapa_id IS NOT NULL THEN
        SELECT op_id INTO v_op_da_etapa FROM op_etapa WHERE id_op_etapa = NEW.op_etapa_id;
        IF NEW.op_id IS NULL THEN
            SET NEW.op_id = v_op_da_etapa;
        ELSEIF NEW.op_id <> v_op_da_etapa THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'A etapa informada na perda não pertence à Ordem de Produção informada.';
        END IF;
    END IF;
END$$

-- ---------------------------------------------------------------------
-- REVISÃO ITEM 11: estoque_movimentacao — compatibilidade item x lote x OP x venda.
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_estmov_valida_referencias_ins
BEFORE INSERT ON estoque_movimentacao
FOR EACH ROW
BEGIN
    DECLARE v_item_lote INT UNSIGNED;
    DECLARE v_item_op INT UNSIGNED;
    DECLARE v_item_venda INT UNSIGNED;

    IF NEW.lote_id IS NOT NULL THEN
        SELECT materia_prima_item_id INTO v_item_lote FROM lote WHERE id_lote = NEW.lote_id;
        IF v_item_lote <> NEW.item_id THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'item_id da movimentação não corresponde à matéria-prima do lote informado.';
        END IF;
    ELSEIF NEW.op_id IS NOT NULL THEN
        -- Movimentação de OP sem lote = entrada em estoque do item que a própria OP produz.
        SELECT item_id INTO v_item_op FROM ordem_producao WHERE id_op = NEW.op_id;
        IF v_item_op <> NEW.item_id THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'item_id da movimentação não corresponde ao item produzido pela Ordem de Produção informada.';
        END IF;
    END IF;

    IF NEW.venda_item_id IS NOT NULL THEN
        SELECT produto_item_id INTO v_item_venda FROM venda_item WHERE id_venda_item = NEW.venda_item_id;
        IF v_item_venda <> NEW.item_id THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'item_id da movimentação não corresponde ao produto do item de venda informado.';
        END IF;
    END IF;
END$$

CREATE TRIGGER trg_estmov_valida_referencias_upd
BEFORE UPDATE ON estoque_movimentacao
FOR EACH ROW
BEGIN
    DECLARE v_item_lote INT UNSIGNED;
    DECLARE v_item_op INT UNSIGNED;
    DECLARE v_item_venda INT UNSIGNED;

    IF NEW.lote_id IS NOT NULL THEN
        SELECT materia_prima_item_id INTO v_item_lote FROM lote WHERE id_lote = NEW.lote_id;
        IF v_item_lote <> NEW.item_id THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'item_id da movimentação não corresponde à matéria-prima do lote informado.';
        END IF;
    ELSEIF NEW.op_id IS NOT NULL THEN
        SELECT item_id INTO v_item_op FROM ordem_producao WHERE id_op = NEW.op_id;
        IF v_item_op <> NEW.item_id THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'item_id da movimentação não corresponde ao item produzido pela Ordem de Produção informada.';
        END IF;
    END IF;

    IF NEW.venda_item_id IS NOT NULL THEN
        SELECT produto_item_id INTO v_item_venda FROM venda_item WHERE id_venda_item = NEW.venda_item_id;
        IF v_item_venda <> NEW.item_id THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'item_id da movimentação não corresponde ao produto do item de venda informado.';
        END IF;
    END IF;
END$$

-- ---------------------------------------------------------------------
-- REVISÃO ITEM 12: fornecedor_item só pode referenciar MATERIA_PRIMA ou COMPONENTE de
-- origem FORNECEDOR (nunca PRODUTO_ACABADO nem componente de fabricação própria).
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_forneceditem_valida_tipo_ins
BEFORE INSERT ON fornecedor_item
FOR EACH ROW
BEGIN
    DECLARE v_tipo VARCHAR(20);
    DECLARE v_origem VARCHAR(20);
    SELECT tipo_item INTO v_tipo FROM item WHERE id_item = NEW.item_id;
    IF v_tipo = 'PRODUTO_ACABADO' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Um fornecedor não pode fornecer PRODUTO_ACABADO.';
    ELSEIF v_tipo = 'COMPONENTE' THEN
        SELECT origem INTO v_origem FROM componente WHERE item_id = NEW.item_id;
        IF v_origem <> 'FORNECEDOR' THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Um fornecedor só pode fornecer componente cuja origem seja FORNECEDOR.';
        END IF;
    END IF;
END$$

CREATE TRIGGER trg_forneceditem_valida_tipo_upd
BEFORE UPDATE ON fornecedor_item
FOR EACH ROW
BEGIN
    DECLARE v_tipo VARCHAR(20);
    DECLARE v_origem VARCHAR(20);
    SELECT tipo_item INTO v_tipo FROM item WHERE id_item = NEW.item_id;
    IF v_tipo = 'PRODUTO_ACABADO' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Um fornecedor não pode fornecer PRODUTO_ACABADO.';
    ELSEIF v_tipo = 'COMPONENTE' THEN
        SELECT origem INTO v_origem FROM componente WHERE item_id = NEW.item_id;
        IF v_origem <> 'FORNECEDOR' THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Um fornecedor só pode fornecer componente cuja origem seja FORNECEDOR.';
        END IF;
    END IF;
END$$

-- ---------------------------------------------------------------------
-- REVISÃO ITEM 4: cliente.estado_id deve pertencer ao mesmo país de cliente.pais_id.
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_cliente_valida_estado_pais_ins
BEFORE INSERT ON cliente
FOR EACH ROW
BEGIN
    DECLARE v_pais_estado INT UNSIGNED;
    IF NEW.estado_id IS NOT NULL THEN
        SELECT pais_id INTO v_pais_estado FROM estado_provincia WHERE id_estado = NEW.estado_id;
        IF v_pais_estado <> NEW.pais_id THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'O estado/província informado não pertence ao país do cliente.';
        END IF;
    END IF;
END$$

CREATE TRIGGER trg_cliente_valida_estado_pais_upd
BEFORE UPDATE ON cliente
FOR EACH ROW
BEGIN
    DECLARE v_pais_estado INT UNSIGNED;
    IF NEW.estado_id IS NOT NULL THEN
        SELECT pais_id INTO v_pais_estado FROM estado_provincia WHERE id_estado = NEW.estado_id;
        IF v_pais_estado <> NEW.pais_id THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'O estado/província informado não pertence ao país do cliente.';
        END IF;
    END IF;
END$$

-- ---------------------------------------------------------------------
-- REVISÃO (auditoria de verificação): venda_item_serial não tinha nenhuma validação
-- de que o produto_serial vinculado corresponde ao produto do próprio venda_item —
-- o mesmo tipo de lacuna já corrigida para produto_serial×OP (revisão item 10), mas que
-- havia ficado sem cobertura no lado da venda. Mesmo com as duas FKs individuais
-- válidas, sem este trigger seria possível vincular o serial de um Trator a um
-- venda_item que na verdade vende uma Colhedora.
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_vendaitemserial_valida_produto_ins
BEFORE INSERT ON venda_item_serial
FOR EACH ROW
BEGIN
    DECLARE v_produto_serial INT UNSIGNED;
    DECLARE v_produto_vendaitem INT UNSIGNED;
    SELECT produto_item_id INTO v_produto_serial FROM produto_serial WHERE id_serial = NEW.serial_id;
    SELECT produto_item_id INTO v_produto_vendaitem FROM venda_item WHERE id_venda_item = NEW.venda_item_id;
    IF v_produto_serial <> v_produto_vendaitem THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'O produto do número de série não corresponde ao produto do item de venda informado.';
    END IF;
END$$

CREATE TRIGGER trg_vendaitemserial_valida_produto_upd
BEFORE UPDATE ON venda_item_serial
FOR EACH ROW
BEGIN
    DECLARE v_produto_serial INT UNSIGNED;
    DECLARE v_produto_vendaitem INT UNSIGNED;
    SELECT produto_item_id INTO v_produto_serial FROM produto_serial WHERE id_serial = NEW.serial_id;
    SELECT produto_item_id INTO v_produto_vendaitem FROM venda_item WHERE id_venda_item = NEW.venda_item_id;
    IF v_produto_serial <> v_produto_vendaitem THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'O produto do número de série não corresponde ao produto do item de venda informado.';
    END IF;
END$$

DELIMITER ;

-- =====================================================================
-- FIM DO SCRIPT — SOMENTE ESTRUTURA, NENHUM INSERT.
-- =====================================================================
