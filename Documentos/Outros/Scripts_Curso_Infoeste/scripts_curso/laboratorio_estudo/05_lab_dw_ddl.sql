USE agromaq_lab;
SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS fato_leitura_sensor;
DROP TABLE IF EXISTS dim_sensor;
DROP TABLE IF EXISTS dim_maquina;
DROP TABLE IF EXISTS dim_linha;
DROP TABLE IF EXISTS dim_tempo;
SET FOREIGN_KEY_CHECKS = 1;

-- Dimensao de linha: chave natural (id_linha_origem) + chave substituta (sk_linha)
CREATE TABLE dim_linha (
    sk_linha         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_linha_origem  INT UNSIGNED NOT NULL,
    nome_linha       VARCHAR(100) NOT NULL,
    categoria        VARCHAR(50)  NOT NULL,
    unidade          VARCHAR(100) NOT NULL,
    UNIQUE KEY uq_dim_linha_origem (id_linha_origem)
) ENGINE=InnoDB;

CREATE TABLE dim_maquina (
    sk_maquina        INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_maquina_origem INT UNSIGNED NOT NULL,
    codigo            VARCHAR(30)  NOT NULL,
    nome_maquina      VARCHAR(100) NOT NULL,
    tipo_maquina      VARCHAR(80)  NOT NULL,
    status_maquina    VARCHAR(20)  NOT NULL,
    sk_linha          INT UNSIGNED NOT NULL,
    UNIQUE KEY uq_dim_maquina_origem (id_maquina_origem),
    CONSTRAINT fk_dm_linha FOREIGN KEY (sk_linha) REFERENCES dim_linha (sk_linha)
) ENGINE=InnoDB;

-- Dimensao larga: o sensor ja traz maquina, linha e unidade achatadas
CREATE TABLE dim_sensor (
    sk_sensor         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_sensor_origem  INT UNSIGNED NOT NULL,
    codigo_sensor     VARCHAR(30)  NOT NULL,
    tipo_sensor       VARCHAR(100) NOT NULL,
    codigo_maquina    VARCHAR(30)  NOT NULL,
    nome_maquina      VARCHAR(100) NOT NULL,
    nome_linha        VARCHAR(100) NOT NULL,
    categoria         VARCHAR(50)  NOT NULL,
    unidade           VARCHAR(100) NOT NULL,
    faixa_min         DECIMAL(10,2) NULL,   -- definicao do laboratorio, nao do banco operacional
    faixa_max         DECIMAL(10,2) NULL,
    UNIQUE KEY uq_dim_sensor_origem (id_sensor_origem)
) ENGINE=InnoDB;

-- Granularidade: 1 linha por DIA (a tabela de datas do Power BI exige uma data por linha;
-- hora e turno ficam na fato)
CREATE TABLE dim_tempo (
    sk_tempo     INT UNSIGNED PRIMARY KEY,      -- AAAAMMDD
    data         DATE     NOT NULL,
    ano          SMALLINT NOT NULL,
    mes          TINYINT  NOT NULL,
    nome_mes     VARCHAR(12) NOT NULL,
    dia          TINYINT  NOT NULL,
    dia_semana   VARCHAR(15) NOT NULL,
    UNIQUE KEY uq_dim_tempo_data (data)
) ENGINE=InnoDB;

-- Fato: 1 linha por sensor por hora
CREATE TABLE fato_leitura_sensor (
    sk_tempo        INT UNSIGNED NOT NULL,       -- dia
    hora            TINYINT      NOT NULL,       -- 0 a 23
    turno           VARCHAR(10)  NOT NULL,       -- Manha, Tarde, Noite
    sk_sensor       INT UNSIGNED NOT NULL,
    valor           DECIMAL(10,2) NOT NULL,
    status_leitura  VARCHAR(10)  NOT NULL,
    fora_faixa      TINYINT      NOT NULL,       -- 1 = fora da faixa do sensor, 0 = dentro
    PRIMARY KEY (sk_tempo, hora, sk_sensor),
    CONSTRAINT fk_fl_tempo  FOREIGN KEY (sk_tempo)  REFERENCES dim_tempo  (sk_tempo),
    CONSTRAINT fk_fl_sensor FOREIGN KEY (sk_sensor) REFERENCES dim_sensor (sk_sensor)
) ENGINE=InnoDB;
