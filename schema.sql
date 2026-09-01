SET FOREIGN_KEY_CHECKS = 0;

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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS obreros (
    id_obrero INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL,
    apellido VARCHAR(100),
    documento VARCHAR(30) NOT NULL UNIQUE,
    telefono VARCHAR(30),
    fecha_contratacion DATE,
    fecha_fin DATE,
    cargo ENUM('Albañil','Capataz','Electricista','Plomero','Pintor','Carpintero','Soldador','Operador de maquinaria','Peón','Otro') NOT NULL DEFAULT 'Peón',
    activo BOOLEAN DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS maquinaria (
    id_maquinaria INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL,
    marca VARCHAR(100)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS contrato_obrero (
    id_contrato_obrero INT AUTO_INCREMENT PRIMARY KEY,
    archivo LONGBLOB NOT NULL,
    nombre_archivo VARCHAR(255),
    id_obrero INT NOT NULL,
    fecha_vencimiento DATE,

    INDEX idx_contrato_obrero_obrero (id_obrero),
    CONSTRAINT fk_contrato_obrero_obrero FOREIGN KEY (id_obrero) REFERENCES obreros(id_obrero)
        ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS certificado (
    id_certificado INT AUTO_INCREMENT PRIMARY KEY,
    archivo LONGBLOB NOT NULL,
    nombre_archivo VARCHAR(255),
    id_maquinaria INT NOT NULL,
    fecha_vencimiento DATE,

    INDEX idx_certificado_maquinaria (id_maquinaria),
    CONSTRAINT fk_certificado_maquinaria FOREIGN KEY (id_maquinaria) REFERENCES maquinaria(id_maquinaria)
        ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS obra_maquinaria (
    id_obra_maquinaria INT AUTO_INCREMENT PRIMARY KEY,
    id_obra INT NOT NULL,
    id_maquinaria INT NOT NULL,
    fecha_asignacion DATE,
    fecha_retiro DATE,

    INDEX idx_obra_maquinaria_obra (id_obra),
    INDEX idx_obra_maquinaria_maq (id_maquinaria),
    CONSTRAINT fk_obra_maquinaria_obra FOREIGN KEY (id_obra) REFERENCES obras(id_obra)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_obra_maquinaria_maq FOREIGN KEY (id_maquinaria) REFERENCES maquinaria(id_maquinaria)
        ON UPDATE CASCADE ON DELETE CASCADE,

    UNIQUE KEY uq_obra_maquinaria (id_obra, id_maquinaria, fecha_asignacion)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS asistencia_maquinaria (
    id INT AUTO_INCREMENT PRIMARY KEY,
    id_obra INT NOT NULL,
    id_maquinaria INT NOT NULL,
    fecha DATE NOT NULL,
    hora_salida TIME NOT NULL,
    hora_devolucion TIME NOT NULL,

    INDEX idx_asistencia_maq_obra (id_obra),
    INDEX idx_asistencia_maq_maq (id_maquinaria),
    CONSTRAINT fk_asistencia_maq_obra FOREIGN KEY (id_obra) REFERENCES obras(id_obra)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_asistencia_maq_maq FOREIGN KEY (id_maquinaria) REFERENCES maquinaria(id_maquinaria)
        ON UPDATE CASCADE ON DELETE CASCADE,

    UNIQUE KEY uq_asistencia_maquinaria (id_obra, id_maquinaria, fecha)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS contratos (
    id_contrato INT AUTO_INCREMENT PRIMARY KEY,
    id_obra INT NOT NULL,
    archivo LONGBLOB NOT NULL,
    nombre_archivo VARCHAR(255),
    fecha_subida DATE NOT NULL,

    INDEX idx_contratos_obra (id_obra),
    CONSTRAINT fk_contratos_obra FOREIGN KEY (id_obra) REFERENCES obras(id_obra)
        ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS contrato_tareas (
    id_tarea INT AUTO_INCREMENT PRIMARY KEY,
    id_contrato INT NOT NULL,
    id_tarea_origen INT NULL,
    descripcion VARCHAR(255) NOT NULL,
    importe DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    estado ENUM('Pendiente','Completada') NOT NULL DEFAULT 'Pendiente',
    fecha_completada DATE NULL,

    INDEX idx_contrato_tareas_contrato (id_contrato),
    INDEX idx_contrato_tareas_origen (id_tarea_origen),
    CONSTRAINT fk_contrato_tareas_contrato FOREIGN KEY (id_contrato) REFERENCES contratos(id_contrato)
        ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS registros (
    id_registro INT AUTO_INCREMENT PRIMARY KEY,
    fecha DATE NOT NULL,
    hora_entrada TIME NOT NULL,
    hora_salida TIME NOT NULL,
    horas_trabajadas DECIMAL(5,2),

    id_obrero INT NOT NULL,
    id_obra INT NOT NULL,
    id_usuario INT NULL,

    INDEX idx_registros_obrero (id_obrero),
    INDEX idx_registros_obra (id_obra),
    INDEX idx_registros_usuario (id_usuario),
    CONSTRAINT fk_registros_obrero FOREIGN KEY (id_obrero) REFERENCES obreros(id_obrero)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_registros_obra FOREIGN KEY (id_obra) REFERENCES obras(id_obra)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_registros_usuario FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario)
        ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS recursos (
    id_recurso INT AUTO_INCREMENT PRIMARY KEY,
    id_obra INT NOT NULL,
    id_registro INT NULL,
    fecha DATE NOT NULL,
    nombre VARCHAR(150) NOT NULL,
    cantidad DECIMAL(10,2) NOT NULL,
    precio_unitario DECIMAL(10,2) NULL,
    es_material BOOLEAN NOT NULL DEFAULT 0,

    INDEX idx_recursos_obra (id_obra),
    INDEX idx_recursos_registro (id_registro),
    CONSTRAINT fk_recursos_obra FOREIGN KEY (id_obra) REFERENCES obras(id_obra)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_recursos_registro FOREIGN KEY (id_registro) REFERENCES registros(id_registro)
        ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS combustible (
    id_combustible INT AUTO_INCREMENT PRIMARY KEY,
    nombre_combustible VARCHAR(100) NOT NULL,
    litros DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    precio_unitario DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    precio_total DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    fecha DATE NOT NULL,
    id_obra INT NOT NULL,
    id_maquinaria INT NULL,

    INDEX idx_combustible_fecha (fecha),
    INDEX idx_combustible_obra (id_obra),
    INDEX idx_combustible_maquinaria (id_maquinaria),
    CONSTRAINT fk_combustible_obra FOREIGN KEY (id_obra) REFERENCES obras(id_obra)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_combustible_maquinaria FOREIGN KEY (id_maquinaria) REFERENCES maquinaria(id_maquinaria)
        ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS intentos_login (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL,
    ip_address VARCHAR(45) NOT NULL,
    fecha DATETIME NOT NULL,
    exitoso BOOLEAN DEFAULT 0,
    INDEX idx_username_fecha (username, fecha),
    INDEX idx_ip_fecha (ip_address, fecha)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS auditoria_logs (
    id_log INT AUTO_INCREMENT PRIMARY KEY,
    id_usuario INT NULL,
    usuario VARCHAR(50) NULL,
    rol VARCHAR(20) NULL,
    accion VARCHAR(20) NOT NULL,
    entidad VARCHAR(50) NOT NULL,
    entidad_id INT NULL,
    detalle_json TEXT NULL,
    ip_address VARCHAR(45) NULL,
    created_at DATETIME NOT NULL,
    INDEX idx_accion (accion),
    INDEX idx_entidad (entidad),
    INDEX idx_created_at (created_at),
    CONSTRAINT fk_auditoria_usuario FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario)
        ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SET FOREIGN_KEY_CHECKS = 1;