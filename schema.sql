CREATE DATABASE IF NOT EXISTS portico
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;
USE portico;

CREATE TABLE IF NOT EXISTS usuarios (
    id_usuario INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    usuario VARCHAR(50) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    correo VARCHAR(150) UNIQUE,
    rol ENUM('Administrador','Capataz') NOT NULL,
    activo BOOLEAN DEFAULT 1
);

CREATE TABLE IF NOT EXISTS obras (
    id_obra INT AUTO_INCREMENT PRIMARY KEY,
    numero_contrata VARCHAR(50) NOT NULL UNIQUE,
    nombre VARCHAR(150) NOT NULL,
    direccion VARCHAR(200),
    descripcion TEXT,
    fecha_inicio DATE,
    fecha_fin DATE,
    nombre_cliente VARCHAR(150) NOT NULL,
    telefono_cliente VARCHAR(30),
    activo BOOLEAN DEFAULT 1
);

CREATE TABLE IF NOT EXISTS obreros (
    id_obrero INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL,
    apellido VARCHAR(100),
    documento VARCHAR(30) NOT NULL UNIQUE,
    telefono VARCHAR(30),
    fecha_contratacion DATE,
    activo BOOLEAN DEFAULT 1
);

CREATE TABLE IF NOT EXISTS contrato_obrero (
    id_contrato_obrero INT AUTO_INCREMENT PRIMARY KEY,
    archivo LONGBLOB NOT NULL,
    nombre_archivo VARCHAR(255),
    id_obrero INT NOT NULL,
    fecha_vencimiento DATE,

    FOREIGN KEY (id_obrero) REFERENCES obreros(id_obrero)
        ON UPDATE CASCADE ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS registros (
    id_registro INT AUTO_INCREMENT PRIMARY KEY,
    fecha DATE NOT NULL,
    hora_entrada TIME NOT NULL,
    hora_salida TIME NOT NULL,
    horas_trabajadas DECIMAL(5,2),

    id_obrero INT NOT NULL,
    id_obra INT NOT NULL,
    id_usuario INT NOT NULL,

    FOREIGN KEY (id_obrero) REFERENCES obreros(id_obrero)
        ON UPDATE CASCADE ON DELETE RESTRICT,

    FOREIGN KEY (id_obra) REFERENCES obras(id_obra)
        ON UPDATE CASCADE ON DELETE RESTRICT,

    FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario)
        ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS contratos (
    id_contrato INT AUTO_INCREMENT PRIMARY KEY,
    id_obra INT NOT NULL,
    archivo LONGBLOB NOT NULL,
    nombre_archivo VARCHAR(255),
    fecha_subida DATE NOT NULL,

    FOREIGN KEY (id_obra) REFERENCES obras(id_obra)
        ON UPDATE CASCADE ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS recursos (
    id_recurso INT AUTO_INCREMENT PRIMARY KEY,
    id_obra INT NOT NULL,
    id_registro INT NULL,
    fecha DATE NOT NULL,
    nombre VARCHAR(150) NOT NULL,
    cantidad DECIMAL(10,2) NOT NULL,
    precio_unitario DECIMAL(10,2) NULL,
    es_material BOOLEAN NOT NULL DEFAULT 0,

    FOREIGN KEY (id_obra) REFERENCES obras(id_obra)
        ON UPDATE CASCADE ON DELETE CASCADE,

    FOREIGN KEY (id_registro) REFERENCES registros(id_registro)
        ON UPDATE CASCADE ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS maquinaria (
    id_maquinaria INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL,
    marca VARCHAR(100)
);

CREATE TABLE IF NOT EXISTS obra_maquinaria (
    id_obra_maquinaria INT AUTO_INCREMENT PRIMARY KEY,
    id_obra INT NOT NULL,
    id_maquinaria INT NOT NULL,
    fecha_asignacion DATE,
    fecha_retiro DATE,

    FOREIGN KEY (id_obra) REFERENCES obras(id_obra)
        ON UPDATE CASCADE ON DELETE CASCADE,

    FOREIGN KEY (id_maquinaria) REFERENCES maquinaria(id_maquinaria)
        ON UPDATE CASCADE ON DELETE CASCADE,

    UNIQUE KEY uq_obra_maquinaria (id_obra, id_maquinaria, fecha_asignacion)
);

CREATE TABLE IF NOT EXISTS certificado (
    id_certificado INT AUTO_INCREMENT PRIMARY KEY,
    archivo LONGBLOB NOT NULL,
    nombre_archivo VARCHAR(255),
    id_maquinaria INT NOT NULL,
    fecha_vencimiento DATE,

    FOREIGN KEY (id_maquinaria) REFERENCES maquinaria(id_maquinaria)
        ON UPDATE CASCADE ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS asistencia_maquinaria (
    id INT AUTO_INCREMENT PRIMARY KEY,
    id_obra INT NOT NULL,
    id_maquinaria INT NOT NULL,
    fecha DATE NOT NULL,

    FOREIGN KEY (id_obra) REFERENCES obras(id_obra)
        ON UPDATE CASCADE ON DELETE CASCADE,

    FOREIGN KEY (id_maquinaria) REFERENCES maquinaria(id_maquinaria)
        ON UPDATE CASCADE ON DELETE CASCADE,

    UNIQUE KEY uq_asistencia_maquinaria (id_obra, id_maquinaria, fecha)
);

CREATE TABLE IF NOT EXISTS intentos_login (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL,
    ip_address VARCHAR(45) NOT NULL,
    fecha DATETIME NOT NULL,
    exitoso BOOLEAN DEFAULT 0,
    INDEX idx_username_fecha (username, fecha),
    INDEX idx_ip_fecha (ip_address, fecha)
);