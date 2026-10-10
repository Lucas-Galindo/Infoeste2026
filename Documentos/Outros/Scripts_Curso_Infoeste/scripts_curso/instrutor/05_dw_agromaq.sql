-- =====================================================================
-- 05 · Data warehouse da AgroMaq (modelo estrela) no banco agromaq_dw
--
--   5 dimensoes : dim_tempo, dim_sensor, dim_maquina, dim_linha, dim_produto
--   2 fatos     : fato_leitura_sensor  (1 linha por sensor por hora)
--                 fato_producao        (1 linha por ordem de producao concluida)
--   1 apoio     : cfg_faixa_sensor     (faixa normal por tipo de sensor)
--
-- Rode DEPOIS do 01_criar_staging.sql. Recria as tabelas do DW (nao toca na staging).
-- A faixa normal NAO existe no banco operacional: e uma regra de negocio do curso,
-- guardada em cfg_faixa_sensor para ficar visivel e editavel em um so lugar.
-- =====================================================================
USE agromaq_dw;

SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS fato_producao;
DROP TABLE IF EXISTS fato_leitura_sensor;
DROP TABLE IF EXISTS dim_produto;
DROP TABLE IF EXISTS dim_sensor;
DROP TABLE IF EXISTS dim_maquina;
DROP TABLE IF EXISTS dim_linha;
DROP TABLE IF EXISTS dim_tempo;
DROP TABLE IF EXISTS cfg_faixa_sensor;
SET FOREIGN_KEY_CHECKS = 1;

-- ---------------------------------------------------------------- apoio
CREATE TABLE cfg_faixa_sensor (
    tipo_sensor  VARCHAR(60)   NOT NULL PRIMARY KEY,   -- igual a tipo_sensor.nome no banco operacional
    faixa_min    DECIMAL(10,2) NOT NULL,
    faixa_max    DECIMAL(10,2) NOT NULL
) ENGINE=InnoDB;

INSERT INTO cfg_faixa_sensor (tipo_sensor, faixa_min, faixa_max) VALUES
 ('Temperatura Motor',          50,   95),
 ('Temperatura Forno Pintura', 160,  200),
 ('Vibracao Geral',              0,    7.1),
 ('Pressao Hidraulica',        150,  220),
 ('Velocidade Angular',       1200, 1800),
 ('Velocidade de Corte',        90,  150),
 ('Consumo Energetico',         10,   60),
 ('Corrente Eletrica',          20,   70),
 ('Umidade Tinta',              40,   70),
 ('Posicao Linear',              0,  500),
 ('Torque',                    250,  400),
 ('Tempo de Ciclo',             30,   60),
 ('Quantidade Produzida',        0,   12),
 ('Status Operacional',          0,    1),
 ('Espessura de Tinta',         60,  110);

-- ------------------------------------------------------------- dimensoes
-- Toda dimensao tem chave SUBSTITUTA (sk_*, criada aqui) e chave NATURAL (id_*_origem, do OLTP).
-- A natural e a chave do upsert; a substituta liga fato e dimensao.
CREATE TABLE dim_linha (
    sk_linha         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_linha_origem  INT UNSIGNED NOT NULL,
    nome_linha       VARCHAR(100) NOT NULL,
    setor            VARCHAR(100) NOT NULL,       -- Corte, Usinagem, Soldagem, Pintura, Montagem, ...
    categoria        VARCHAR(50)  NOT NULL,
    unidade          VARCHAR(100) NOT NULL,
    UNIQUE KEY uq_dim_linha_origem (id_linha_origem)
) ENGINE=InnoDB;

CREATE TABLE dim_maquina (
    sk_maquina         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_maquina_origem  INT UNSIGNED NOT NULL,
    codigo             VARCHAR(30)  NOT NULL,
    nome_maquina       VARCHAR(100) NOT NULL,
    tipo_maquina       VARCHAR(80)  NOT NULL,
    status_maquina     VARCHAR(20)  NOT NULL,
    sk_linha           INT UNSIGNED NOT NULL,
    UNIQUE KEY uq_dim_maquina_origem (id_maquina_origem),
    CONSTRAINT fk_dm_linha FOREIGN KEY (sk_linha) REFERENCES dim_linha (sk_linha)
) ENGINE=InnoDB;

-- Dimensao LARGA: o sensor ja traz maquina, linha e unidade achatadas (sem JOIN em cadeia na leitura).
CREATE TABLE dim_sensor (
    sk_sensor         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_sensor_origem  INT UNSIGNED NOT NULL,
    codigo_sensor     VARCHAR(30)  NOT NULL,
    tipo_sensor       VARCHAR(100) NOT NULL,
    unidade_medida    VARCHAR(20)  NOT NULL,      -- sigla: gC, bar, rpm...
    codigo_maquina    VARCHAR(30)  NOT NULL,
    nome_maquina      VARCHAR(100) NOT NULL,
    nome_linha        VARCHAR(100) NOT NULL,
    setor             VARCHAR(100) NOT NULL,
    categoria         VARCHAR(50)  NOT NULL,
    unidade           VARCHAR(100) NOT NULL,      -- unidade fabril (Presidente Prudente / Tres Lagoas)
    faixa_min         DECIMAL(10,2) NULL,
    faixa_max         DECIMAL(10,2) NULL,
    UNIQUE KEY uq_dim_sensor_origem (id_sensor_origem)
) ENGINE=InnoDB;

CREATE TABLE dim_produto (
    sk_produto         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_produto_origem  INT UNSIGNED NOT NULL,     -- item.id_item
    codigo             VARCHAR(30)  NOT NULL,
    nome_produto       VARCHAR(150) NOT NULL,
    categoria          VARCHAR(50)  NOT NULL,
    unidade            VARCHAR(100) NOT NULL,
    preco_referencia   DECIMAL(14,2) NOT NULL,
    UNIQUE KEY uq_dim_produto_origem (id_produto_origem)
) ENGINE=InnoDB;

-- GRANULARIDADE: 1 linha por DIA. A tabela de datas do Power BI exige uma data por linha;
-- por isso hora e turno ficam na fato, nao aqui.
CREATE TABLE dim_tempo (
    sk_tempo    INT UNSIGNED PRIMARY KEY,         -- AAAAMMDD
    data        DATE        NOT NULL,
    ano         SMALLINT    NOT NULL,
    mes         TINYINT     NOT NULL,
    nome_mes    VARCHAR(12) NOT NULL,
    dia         TINYINT     NOT NULL,
    dia_semana  VARCHAR(15) NOT NULL,
    UNIQUE KEY uq_dim_tempo_data (data)
) ENGINE=InnoDB;

-- ----------------------------------------------------------------- fatos
-- GRANULARIDADE: cada linha e a leitura de UM sensor em UMA hora.
CREATE TABLE fato_leitura_sensor (
    sk_tempo        INT UNSIGNED  NOT NULL,       -- dia
    hora            TINYINT       NOT NULL,       -- 0 a 23
    turno           VARCHAR(10)   NOT NULL,       -- Manha (6-13h), Tarde (14-21h), Noite (22-5h)
    sk_sensor       INT UNSIGNED  NOT NULL,
    valor           DECIMAL(10,2) NOT NULL,
    status_leitura  VARCHAR(10)   NOT NULL,
    fora_faixa      TINYINT       NOT NULL,       -- 1 = fora da faixa do tipo de sensor, 0 = dentro
    PRIMARY KEY (sk_tempo, hora, sk_sensor),
    KEY ix_fl_sensor (sk_sensor),
    CONSTRAINT fk_fl_tempo  FOREIGN KEY (sk_tempo)  REFERENCES dim_tempo  (sk_tempo),
    CONSTRAINT fk_fl_sensor FOREIGN KEY (sk_sensor) REFERENCES dim_sensor (sk_sensor)
) ENGINE=InnoDB;

-- GRANULARIDADE: cada linha e UMA ORDEM DE PRODUCAO CONCLUIDA (data = dia do fim real).
-- id_op_origem e numero_op sao dimensoes degeneradas (identificam a ordem, sem tabela propria).
-- motivo_principal: motivo com mais pecas rejeitadas na ordem (vazio se nao houve rejeito).
CREATE TABLE fato_producao (
    id_op_origem          INT UNSIGNED  NOT NULL PRIMARY KEY,
    numero_op             VARCHAR(30)   NOT NULL,
    sk_tempo              INT UNSIGNED  NOT NULL,
    sk_linha              INT UNSIGNED  NOT NULL,
    sk_produto            INT UNSIGNED  NOT NULL,
    quantidade_planejada  DECIMAL(14,2) NOT NULL,
    quantidade_produzida  DECIMAL(14,2) NOT NULL,
    quantidade_aprovada   DECIMAL(14,2) NOT NULL,
    quantidade_retrabalho DECIMAL(14,2) NOT NULL,
    quantidade_rejeitada  DECIMAL(14,2) NOT NULL,
    motivo_principal      VARCHAR(100)  NULL,
    KEY ix_fp_tempo (sk_tempo), KEY ix_fp_linha (sk_linha), KEY ix_fp_produto (sk_produto),
    CONSTRAINT fk_fp_tempo   FOREIGN KEY (sk_tempo)   REFERENCES dim_tempo   (sk_tempo),
    CONSTRAINT fk_fp_linha   FOREIGN KEY (sk_linha)   REFERENCES dim_linha   (sk_linha),
    CONSTRAINT fk_fp_produto FOREIGN KEY (sk_produto) REFERENCES dim_produto (sk_produto)
) ENGINE=InnoDB;

SHOW TABLES;
