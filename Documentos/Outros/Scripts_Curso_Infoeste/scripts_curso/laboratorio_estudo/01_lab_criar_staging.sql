-- LABORATORIO DE ESTUDO · Alem do Codigo (nao e o CSV nem o DDL oficial da aula)
CREATE DATABASE IF NOT EXISTS agromaq_lab CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE agromaq_lab;

-- Staging: tudo em VARCHAR, para nada ser recusado na entrada
DROP TABLE IF EXISTS stg_leitura;
CREATE TABLE stg_leitura (
    linha_arquivo  INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    sensor_id      VARCHAR(20),
    data_hora      VARCHAR(30),
    valor          VARCHAR(30),
    status_leitura VARCHAR(20),
    tipo_maquina   VARCHAR(40)
) ENGINE=InnoDB;

-- Quarentena: cada linha rejeitada guarda o motivo
DROP TABLE IF EXISTS etl_rejeito;
CREATE TABLE etl_rejeito (
    id_rejeito     INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    linha_arquivo  INT UNSIGNED NOT NULL,
    motivo         VARCHAR(30)  NOT NULL,
    sensor_id      VARCHAR(20),
    data_hora      VARCHAR(30),
    valor          VARCHAR(30),
    KEY ix_rej_linha (linha_arquivo)
) ENGINE=InnoDB;

-- Destino tratado
DROP TABLE IF EXISTS leitura_tratada;
CREATE TABLE leitura_tratada (
    id_tratada     INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    linha_arquivo  INT UNSIGNED NOT NULL,
    sensor_id      INT UNSIGNED NOT NULL,
    data_hora      DATETIME     NOT NULL,
    valor          DECIMAL(10,2) NOT NULL,
    status_leitura ENUM('VALIDA','SUSPEITA','ERRO') NOT NULL,
    tipo_maquina   VARCHAR(20)  NOT NULL,
    UNIQUE KEY uq_leitura (sensor_id, data_hora)
) ENGINE=InnoDB;
