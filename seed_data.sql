-- =============================================================================
-- BASE DE DATOS: Portico
-- Schema y Datos de Muestra (Seeds Actualizados)
-- =============================================================================

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
    fecha_fin DATE,
    cargo ENUM('Albañil','Capataz','Electricista','Plomero','Pintor','Carpintero','Soldador','Operador de maquinaria','Peón','Otro') NOT NULL DEFAULT 'Peón',
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
    id_usuario INT NULL,

    FOREIGN KEY (id_obrero) REFERENCES obreros(id_obrero)
        ON UPDATE CASCADE ON DELETE CASCADE,

    FOREIGN KEY (id_obra) REFERENCES obras(id_obra)
        ON UPDATE CASCADE ON DELETE CASCADE,

    FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario)
        ON UPDATE CASCADE ON DELETE SET NULL
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
    hora_salida TIME NOT NULL,
    hora_devolucion TIME NOT NULL,

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
    FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario)
        ON UPDATE CASCADE ON DELETE SET NULL
);

USE portico;

START TRANSACTION;

-- =============================================================================
-- 1. USUARIOS (5 usuarios con contraseñas seguras y correos)
-- =============================================================================
INSERT INTO usuarios (nombre, usuario, password_hash, correo, rol, activo) VALUES
('Administrador Principal', 'admin', '$2y$12$KKDvf8gV1uJvDOal4pwqpeSNPIaNkbeVxaVzF7qOps3UwIHoUe0.q', 'admin@portico.local', 'Administrador', 1),
('Capataz General', 'capataz', '$2y$12$eFL7X6dijAsHUsEapoACFOn.9AoS.DBK1wPH4Izh9IxTXCdc4Bmpq', 'capataz@portico.local', 'Capataz', 1),
('Supervisor de Obras', 'supervisor', '$2y$12$KKDvf8gV1uJvDOal4pwqpeSNPIaNkbeVxaVzF7qOps3UwIHoUe0.q', 'supervisor@portico.local', 'Administrador', 1),
('Juan Pérez', 'juan.perez', '$2y$12$eFL7X6dijAsHUsEapoACFOn.9AoS.DBK1wPH4Izh9IxTXCdc4Bmpq', 'juan.perez@portico.local', 'Capataz', 1),
('María González', 'maria.gonzalez', '$2y$12$KKDvf8gV1uJvDOal4pwqpeSNPIaNkbeVxaVzF7qOps3UwIHoUe0.q', 'maria.gonzalez@portico.local', 'Administrador', 1)
ON DUPLICATE KEY UPDATE
    nombre = VALUES(nombre),
    password_hash = VALUES(password_hash),
    correo = VALUES(correo),
    rol = VALUES(rol),
    activo = VALUES(activo);

SET @admin_id = (SELECT id_usuario FROM usuarios WHERE usuario = 'admin' LIMIT 1);
SET @capataz_id = (SELECT id_usuario FROM usuarios WHERE usuario = 'capataz' LIMIT 1);
SET @supervisor_id = (SELECT id_usuario FROM usuarios WHERE usuario = 'supervisor' LIMIT 1);

-- ===== 2. OBRAS (30 obras) =====
INSERT INTO obras (numero_contrata, nombre, direccion, descripcion, fecha_inicio, fecha_fin, nombre_cliente, telefono_cliente, activo) VALUES
('CTR-2026-001', 'Pavimentación Av. Costanera Sur', 'Av. Costanera Sur y Av. Mitre, Posadas', 'Pavimentación y cordón cuneta en tramo costanero.', '2026-01-10', '2026-11-20', 'Municipalidad de Posadas', '3764-440101', 1),
('CTR-2026-002', 'Construcción Hospital Nivel II', 'Av. Las Américas 1450, Garupá', 'Edificación de nuevo centro de salud de mediana complejidad.', '2026-01-15', '2027-04-30', 'Ministerio de Salud Pública', '3764-440102', 1),
('CTR-2026-003', 'Ampliación Red de Agua Potable', 'Barrio Belgrano, Oberá', 'Tendido de 4500m de cañería de polipropileno y conexiones domiciliarias.', '2026-02-01', '2026-09-15', 'SAMSA / IPRODHA', '3755-420203', 1),
('CTR-2026-004', 'Remodelación Pasarela Cataratas', 'Parque Nacional Iguazú, Puerto Iguazú', 'Reparación estructural de pasarelas y miradores turísticos.', '2026-02-10', '2026-08-30', 'Dirección Nacional de Parques', '3757-490304', 1),
('CTR-2026-005', 'Cordón Cuneta y Empedrado', 'Barrio San Martín, Apóstoles', 'Construcción de cordón cuneta y badenes de hormigón.', '2026-03-01', '2026-10-15', 'Municipalidad de Apóstoles', '3758-422405', 1),
('CTR-2026-006', 'Red Cloacal Troncal Este', 'Av. Libertador 890, San Vicente', 'Instalación de colectores cloacales e impulsión.', '2026-03-15', '2027-01-20', 'EPRAC Misiones', '3755-460506', 1),
('CTR-2026-007', 'Puesta en Valor Plaza Central', 'Av. El Libertador y San Martín, Montecarlo', 'Recambio de veredas, luminarias LED y mobiliario urbano.', '2026-01-20', '2026-06-15', 'Municipalidad de Montecarlo', '3751-480607', 1),
('CTR-2026-008', 'Desagües Pluviales Cuenca Arroyo', 'Ruta Prov. 12 km 1520, Eldorado', 'Canalización y entubado de arroyo para mitigación de inundaciones.', '2026-02-15', '2026-12-10', 'Dirección Provincial de Vialidad', '3751-430708', 1),
('CTR-2026-009', 'Construcción 40 Viviendas Sociales', 'Barrio Itaembé Guazú Sector 5, Posadas', 'Viviendas unifamiliares con infraestructura de servicios.', '2026-01-05', '2027-03-01', 'IPRODHA', '3764-447809', 1),
('CTR-2026-010', 'Centro Comunitario y Polideportivo', 'Av. Quiroga 320, San Ignacio', 'Tinglado parabólico metálico y dependencias sanitarias.', '2026-02-20', '2026-10-30', 'Ministerio de Desarrollo Social', '3764-470910', 1),
('CTR-2026-011', 'Repavimentación Ruta Costera 2', 'Tramo Panambí - Santa Rita', 'Bacheo profundo y carpeta asfáltica en caliente de 5cm.', '2026-03-05', '2026-11-25', 'Vialidad Provincial', '3755-499111', 1),
('CTR-2026-012', 'Alumbrado Público LED Acceso Sur', 'Acceso Sur y Rotonda, Candelaria', 'Instalación de 120 columnas metálicas con luminarias LED 150W.', '2026-01-12', '2026-05-30', 'Energía de Misiones (EMSA)', '3764-490112', 1),
('CTR-2026-013', 'Infraestructura Escolar EPET N° 1', 'Av. Lavalle 2500, Posadas', 'Construcción de 4 nuevas aulas y talleres de electromecánica.', '2026-01-18', '2026-08-20', 'Consejo General de Educación', '3764-445113', 1),
('CTR-2026-014', 'Veredas y Espacios Accesibles', 'Casco Céntrico, Puerto Rico', 'Rampas de acceso, baldosas podotáctiles y canteros.', '2026-02-05', '2026-07-31', 'Municipalidad de Puerto Rico', '3743-420114', 1),
('CTR-2026-015', 'Puente sobre Arroyo Garupá', 'Ruta Provincial 206, Profundidad', 'Puente viga de hormigón armado de 35 metros de luz.', '2026-01-25', '2027-02-28', 'Dirección Provincial de Vialidad', '3764-440115', 1),
('CTR-2026-016', 'Paseo Peatonal y Gastronómico', 'Av. San Martín 450, Aristóbulo del Valle', 'Soterrado de cables, veredas de pórfido y pérgolas.', '2026-02-28', '2026-09-30', 'Municipalidad de Aristóbulo', '3755-470116', 1),
('CTR-2026-017', 'Ampliación Edificio Poder Judicial', 'Av. Santa Catalina 1735, Posadas', 'Construcción de tercer piso para juzgados de instrucción.', '2026-01-08', '2026-12-15', 'Poder Judicial de Misiones', '3764-446117', 1),
('CTR-2026-018', 'Defensas de Costa Arroyo Mártires', 'Costanera Oeste, Posadas', 'Gaviones de piedra y pedraplén para protección de márgenes.', '2026-03-10', '2026-11-15', 'Entidad Binacional Yacyretá', '3764-448118', 1),
('CTR-2026-019', 'Planta de Tratamiento Efluentes', 'Parque Industrial, Posadas', 'Reactores biológicos y lagunas de sedimentación.', '2026-01-02', '2027-05-15', 'Parque Industrial Posadas', '3764-449119', 1),
('CTR-2026-020', 'Red Eléctrica Media Tensión', 'Zona Rural Paraje Nemesio Parma', 'Línea aérea trifásica 13.2 kV y transformadores 63 kVA.', '2026-02-12', '2026-08-15', 'Energía de Misiones', '3764-440120', 1),
('CTR-2025-090', 'Refacción Comisaría Seccional 2da', 'Av. Tambor de Tacuarí, Posadas', 'Refacción integral de techos, sanitarios y celdas.', '2025-06-01', '2025-12-20', 'Ministerio de Gobierno', '3764-442090', 0),
('CTR-2025-091', 'Bacheo Asfáltico Av. Uruguay', 'Av. Uruguay e/ Mitre y Quaranta, Posadas', 'Fresado y repavimentación asfáltica urbana.', '2025-08-10', '2025-11-30', 'Municipalidad de Posadas', '3764-440091', 0),
('CTR-2025-092', 'Suministro de Agua Pozo Perforado', 'Paraje Gentil, San Pedro', 'Perforación de 120m, bomba sumergible y tanque elevado.', '2025-05-15', '2025-10-15', 'IMAS Misiones', '3751-470092', 0),
('CTR-2026-021', 'Muelle Flotante de Embarque', 'Puerto de Posadas, Nemesio Parma', 'Estructura metálica naval con pasarela basculante.', '2026-03-01', '2026-10-01', 'Administración Portuaria Posadas', '3764-441021', 1),
('CTR-2026-022', 'Centro de Salud Nivel I', 'Barrio 200 Viviendas, Leandro N. Alem', 'Salas de consulta, enfermería y vacunatorio.', '2026-02-15', '2026-09-01', 'Ministerio de Salud', '3754-420022', 1),
('CTR-2026-023', 'Veredas y Parquización Costanera', 'Costanera Eduardo Arrabal, Puerto Iguazú', 'Paseo costero con luminarias solares y bancos de hormigón.', '2026-01-20', '2026-07-20', 'Municipalidad de Iguazú', '3757-421023', 1),
('CTR-2026-024', 'Desagüe Pluvial Calle Brasil', 'Calle Brasil y Córdoba, Oberá', 'Conducto rectangular de hormigón armado in situ.', '2026-02-01', '2026-08-30', 'Municipalidad de Oberá', '3755-423024', 1),
('CTR-2026-025', 'Pavimento Articulado Intertrabado', 'Barrio Los Lapachos, Jardín América', 'Colocación de adoquines de hormigón 8cm.', '2026-03-12', '2026-10-25', 'Municipalidad de Jardín América', '3743-460025', 1),
('CTR-2026-026', 'Alumbrado Público Barrio Belén', 'Barrio Belén, Itaembé Miní, Posadas', 'Tendido de 2500m de cable preensamblado y luminarias.', '2026-01-15', '2026-06-30', 'EMSA', '3764-440026', 1),
('CTR-2026-027', 'Remodelación Terminal de Ómnibus', 'Ruta 14 y Av. Belgrano, Cerro Azul', 'Refacción de dársenas, boleterías y confitería.', '2026-02-10', '2026-09-15', 'Municipalidad de Cerro Azul', '3755-494027', 1)
ON DUPLICATE KEY UPDATE nombre = VALUES(nombre), direccion = VALUES(direccion), descripcion = VALUES(descripcion), fecha_inicio = VALUES(fecha_inicio), fecha_fin = VALUES(fecha_fin), nombre_cliente = VALUES(nombre_cliente), telefono_cliente = VALUES(telefono_cliente), activo = VALUES(activo);

-- ===== 3. OBREROS (50 obreros) =====
INSERT INTO obreros (nombre, apellido, documento, telefono, fecha_contratacion, fecha_fin, cargo, activo) VALUES
('Luis', 'Benítez', '36123450', '3764-50101', '2025-03-15', NULL, 'Albañil', 1),
('Carlos', 'Gómez', '37234561', '3764-50102', '2025-04-15', NULL, 'Albañil', 1),
('Miguel', 'Rojas', '38345672', '3764-50103', '2025-05-15', NULL, 'Capataz', 1),
('Jorge', 'Ferreyra', '39456783', '3764-50104', '2025-06-15', NULL, 'Electricista', 1),
('Ramón', 'Acosta', '35567894', '3764-50105', '2025-07-15', '2026-12-31', 'Plomero', 1),
('Pedro', 'Insaurralde', '34678905', '3764-50106', '2025-08-15', NULL, 'Pintor', 1),
('Juan', 'Martínez', '40789016', '3764-50107', '2025-09-15', NULL, 'Carpintero', 1),
('Roberto', 'González', '41890127', '3764-50108', '2025-01-15', NULL, 'Soldador', 0),
('Óscar', 'Vargas', '42901238', '3764-50109', '2025-02-15', NULL, 'Operador de maquinaria', 1),
('Héctor', 'Sosa', '33012349', '3764-50110', '2025-03-15', NULL, 'Peón', 1),
('Daniel', 'Romero', '34123450', '3764-50111', '2025-04-15', NULL, 'Albañil', 1),
('Sergio', 'Torres', '35234561', '3764-50112', '2025-05-15', '2026-12-31', 'Electricista', 1),
('Marcelo', 'Ramírez', '36345672', '3764-50113', '2025-06-15', NULL, 'Operador de maquinaria', 1),
('Gustavo', 'Flores', '37456783', '3764-50114', '2025-07-15', NULL, 'Albañil', 1),
('Alberto', 'Díaz', '38567894', '3764-50115', '2025-08-15', NULL, 'Plomero', 1),
('Ricardo', 'Pereyra', '39678905', '3764-50116', '2025-09-15', NULL, 'Soldador', 1),
('Alejandro', 'Ojeda', '40789016', '3764-50117', '2025-01-15', NULL, 'Pintor', 1),
('Fernando', 'Rivero', '41890127', '3764-50118', '2025-02-15', NULL, 'Carpintero', 1),
('Javier', 'Maidana', '42901238', '3764-50119', '2025-03-15', '2026-12-31', 'Capataz', 1),
('Cristian', 'Brítez', '33012349', '3764-50120', '2025-04-15', NULL, 'Peón', 0),
('Víctor', 'Lescano', '34123460', '3764-50121', '2025-05-15', NULL, 'Peón', 1),
('Hugo', 'Aguirre', '35234571', '3764-50122', '2025-06-15', NULL, 'Albañil', 1),
('Diego', 'Juárez', '36345682', '3764-50123', '2025-07-15', NULL, 'Electricista', 1),
('Mario', 'Coronel', '37456793', '3764-50124', '2025-08-15', NULL, 'Operador de maquinaria', 1),
('Pablo', 'Silva', '38567804', '3764-50125', '2025-09-15', NULL, 'Soldador', 1),
('Claudio', 'Luna', '39678915', '3764-50126', '2025-01-15', '2026-12-31', 'Plomero', 1),
('Darío', 'Ibarra', '40789026', '3764-50127', '2025-02-15', NULL, 'Albañil', 1),
('Gabriel', 'Villalba', '41890137', '3764-50128', '2025-03-15', NULL, 'Pintor', 1),
('Fabián', 'Montiel', '42901248', '3764-50129', '2025-04-15', NULL, 'Carpintero', 1),
('Raúl', 'Giménez', '33012359', '3764-50130', '2025-05-15', NULL, 'Peón', 1),
('Adrián', 'Galeano', '34123470', '3764-50131', '2025-06-15', NULL, 'Operador de maquinaria', 1),
('Walter', 'Argüello', '35234581', '3764-50132', '2025-07-15', NULL, 'Albañil', 0),
('Lucas', 'Ávalos', '36345692', '3764-50133', '2025-08-15', '2026-12-31', 'Electricista', 1),
('Martín', 'Cabrera', '37456703', '3764-50134', '2025-09-15', NULL, 'Soldador', 1),
('Nicolás', 'Duarte', '38567814', '3764-50135', '2025-01-15', NULL, 'Plomero', 1),
('Esteban', 'Bordón', '39678925', '3764-50136', '2025-02-15', NULL, 'Albañil', 1),
('Federico', 'Velázquez', '40789036', '3764-50137', '2025-03-15', NULL, 'Capataz', 1),
('Ignacio', 'Cardozo', '41890147', '3764-50138', '2025-04-15', NULL, 'Peón', 1),
('Leonardo', 'Bogado', '42901258', '3764-50139', '2025-05-15', NULL, 'Pintor', 1),
('Sebastián', 'Almada', '33012369', '3764-50140', '2025-06-15', '2026-12-31', 'Carpintero', 1),
('Emiliano', 'Molina', '34123480', '3764-50141', '2025-07-15', NULL, 'Peón', 1),
('Matías', 'Espinoza', '35234591', '3764-50142', '2025-08-15', NULL, 'Albañil', 1),
('Ezequiel', 'Arias', '36345602', '3764-50143', '2025-09-15', NULL, 'Electricista', 1),
('Felipe', 'Melgarejo', '37456713', '3764-50144', '2025-01-15', NULL, 'Operador de maquinaria', 0),
('Andrés', 'Báez', '38567824', '3764-50145', '2025-02-15', NULL, 'Soldador', 1),
('Rubén', 'Guerrero', '39678935', '3764-50146', '2025-03-15', NULL, 'Plomero', 1),
('César', 'Ortiz', '40789046', '3764-50147', '2025-04-15', '2026-12-31', 'Albañil', 1),
('Hernán', 'Burgos', '41890157', '3764-50148', '2025-05-15', NULL, 'Pintor', 1),
('Iván', 'Cáceres', '42901268', '3764-50149', '2025-06-15', NULL, 'Peón', 1),
('Marcos', 'Rolón', '33012379', '3764-50150', '2025-07-15', NULL, 'Otro', 1)
ON DUPLICATE KEY UPDATE nombre = VALUES(nombre), apellido = VALUES(apellido), telefono = VALUES(telefono), cargo = VALUES(cargo), activo = VALUES(activo);

-- ===== 4. CONTRATOS OBREROS (Estados variados: vencidos, por vencer, vigentes) =====
INSERT INTO contrato_obrero (archivo, nombre_archivo, id_obrero, fecha_vencimiento)
SELECT _binary 'PDF_CONTRATO_OBRERO_DEMO', CONCAT('contrato_', o.documento, '_', LOWER(o.apellido), '.pdf'), o.id_obrero,
    CASE
        WHEN o.id_obrero % 5 = 0 THEN DATE_SUB(CURDATE(), INTERVAL (o.id_obrero % 20 + 5) DAY)   -- Vencido
        WHEN o.id_obrero % 5 = 1 THEN DATE_ADD(CURDATE(), INTERVAL (o.id_obrero % 20 + 2) DAY)   -- Por vencer (< 30 días)
        WHEN o.id_obrero % 5 = 2 THEN DATE_ADD(CURDATE(), INTERVAL (o.id_obrero * 3 + 60) DAY)   -- Vigente
        WHEN o.id_obrero % 5 = 3 THEN DATE_ADD(CURDATE(), INTERVAL (o.id_obrero * 5 + 120) DAY)  -- Vigente lejano
        ELSE NULL                                                                                 -- Sin vencimiento
    END
FROM obreros o
WHERE o.id_obrero <= 35
  AND NOT EXISTS (SELECT 1 FROM contrato_obrero WHERE id_obrero = o.id_obrero);

-- ===== 5. CONTRATOS OBRAS (20 contratos adjuntos) =====
INSERT INTO contratos (id_obra, archivo, nombre_archivo, fecha_subida)
SELECT ob.id_obra, _binary 'PDF_CONTRATO_OBRA_DEMO', CONCAT('contrato_', ob.numero_contrata, '.pdf'), ob.fecha_inicio
FROM obras ob
WHERE ob.id_obra <= 20
  AND NOT EXISTS (SELECT 1 FROM contratos WHERE id_obra = ob.id_obra);

-- ===== 6. MAQUINARIA (25 maquinarias pesadas y equipos) =====
INSERT INTO maquinaria (nombre, marca) VALUES
('Excavadora sobre orugas 320D', 'Caterpillar'),
('Retroexcavadora 3CX Eco 4x4', 'JCB'),
('Motoniveladora GD655-5', 'Komatsu'),
('Pala cargadora frontal L90F', 'Volvo'),
('Rodillo compactador monocilíndrico CA250', 'Dynapac'),
('Hormigonera autopropulsada DB 460', 'Fiori'),
('Miniexcavadora 331', 'Bobcat'),
('Camión volquete Trakker 380 6x4', 'Iveco'),
('Grúa móvil RT530E 30T', 'Grove'),
('Autoelevador diésel 3.5T', 'Toyota'),
('Generador insonorizado 100kVA', 'Cummins'),
('Minicargadora sobre ruedas S570', 'Bobcat'),
('Compresor de aire para demolición XAS 88', 'Atlas Copco'),
('Torre de iluminación móvil 4x1000W', 'Generac'),
('Topadora sobre orugas D6T', 'Caterpillar'),
('Camión mixer hormigonero 8m3', 'Mercedes-Benz'),
('Plataforma elevadora tijera GS-3246', 'Genie'),
('Manipulador telescópico MT-X 1440', 'Manitou'),
('Zanjadora autopropulsada RT45', 'Ditch Witch'),
('Martillo demoledor hidráulico HB 2000', 'Atlas Copco'),
('Vibrocompactador de suelo reversible DPU 6555', 'Wacker Neuson'),
('Bomba de hormigón estacionaria BSA 1409 D', 'Putzmeister'),
('Camión regador de agua 10.000L', 'Ford Cargo'),
('Termofusora hidráulica de cañerías 315mm', 'Ritmo'),
('Cortadora de pavimento a disco FS 400', 'Husqvarna');

-- ===== 7. CERTIFICADOS DE MAQUINARIA (Vencidos, Por Vencer <30d, Vigentes) =====
INSERT INTO certificado (archivo, nombre_archivo, id_maquinaria, fecha_vencimiento)
SELECT _binary 'PDF_CERTIFICADO_MAQ_DEMO',
    CONCAT('Cert_Inspeccion_', REPLACE(REPLACE(m.nombre, ' ', '_'), '/', '-'), '.pdf'),
    m.id_maquinaria,
    CASE
        WHEN m.id_maquinaria % 4 = 1 THEN DATE_SUB(CURDATE(), INTERVAL (m.id_maquinaria % 15 + 3) DAY)  -- Vencido (Alerta Roja)
        WHEN m.id_maquinaria % 4 = 2 THEN DATE_ADD(CURDATE(), INTERVAL (m.id_maquinaria % 20 + 5) DAY)  -- Por vencer (<30d Alerta Amarilla)
        WHEN m.id_maquinaria % 4 = 3 THEN DATE_ADD(CURDATE(), INTERVAL (m.id_maquinaria * 5 + 60) DAY)  -- Vigente (Alerta Verde)
        ELSE NULL                                                                                        -- Sin vencimiento
    END
FROM maquinaria m
WHERE NOT EXISTS (SELECT 1 FROM certificado WHERE id_maquinaria = m.id_maquinaria);

-- ===== 8. ASIGNACIONES DE MAQUINARIA A OBRAS =====
INSERT INTO obra_maquinaria (id_obra, id_maquinaria, fecha_asignacion, fecha_retiro)
SELECT ob.id_obra, m.id_maquinaria, '2026-01-20',
    CASE WHEN MOD(ob.id_obra + m.id_maquinaria, 5) = 0 THEN '2026-05-15' ELSE NULL END
FROM (SELECT id_obra FROM obras LIMIT 20) ob
JOIN (SELECT id_maquinaria FROM maquinaria LIMIT 20) m
ON MOD(ob.id_obra, 20) = MOD(m.id_maquinaria, 20)
ON DUPLICATE KEY UPDATE fecha_retiro = VALUES(fecha_retiro);

-- ===== 9. ASISTENCIA / REGISTRO DIARIO DE MAQUINARIA =====
INSERT INTO asistencia_maquinaria (id_obra, id_maquinaria, fecha, hora_salida, hora_devolucion)
SELECT DISTINCT ob.id_obra, m.id_maquinaria, d.fecha, d.hora_salida, d.hora_devolucion
FROM (
    SELECT '2026-01-15' AS fecha, '07:00:00' AS hora_salida, '17:00:00' AS hora_devolucion UNION ALL
    SELECT '2026-01-20' AS fecha, '07:30:00' AS hora_salida, '16:30:00' AS hora_devolucion UNION ALL
    SELECT '2026-01-25' AS fecha, '08:00:00' AS hora_salida, '18:00:00' AS hora_devolucion UNION ALL
    SELECT '2026-02-05' AS fecha, '07:00:00' AS hora_salida, '15:30:00' AS hora_devolucion UNION ALL
    SELECT '2026-02-12' AS fecha, '08:30:00' AS hora_salida, '17:00:00' AS hora_devolucion UNION ALL
    SELECT '2026-02-20' AS fecha, '07:00:00' AS hora_salida, '16:00:00' AS hora_devolucion UNION ALL
    SELECT '2026-03-02' AS fecha, '07:00:00' AS hora_salida, '17:30:00' AS hora_devolucion UNION ALL
    SELECT '2026-03-10' AS fecha, '08:00:00' AS hora_salida, '16:30:00' AS hora_devolucion
) d
CROSS JOIN (SELECT id_obra FROM obras WHERE id_obra BETWEEN 1 AND 5) ob
CROSS JOIN (SELECT id_maquinaria FROM maquinaria WHERE id_maquinaria BETWEEN 1 AND 8) m
WHERE NOT EXISTS (
    SELECT 1 FROM asistencia_maquinaria
    WHERE id_obra = ob.id_obra AND id_maquinaria = m.id_maquinaria AND fecha = d.fecha
)
LIMIT 60;

-- ===== 10. REGISTROS DE ASISTENCIA DE OBREROS (Multi-obra y Multi-fecha) =====
INSERT INTO registros (fecha, hora_entrada, hora_salida, horas_trabajadas, id_obrero, id_obra, id_usuario)
SELECT d.fecha, d.he, d.hs, d.horas, o.id_obrero, ob.id_obra, COALESCE(@capataz_id, @admin_id)
FROM (
    SELECT '2026-01-12' AS fecha, '07:00:00' AS he, '15:30:00' AS hs, 8.5 AS horas UNION ALL
    SELECT '2026-01-13' AS fecha, '07:00:00' AS he, '15:00:00' AS hs, 8.0 AS horas UNION ALL
    SELECT '2026-01-14' AS fecha, '07:00:00' AS he, '16:00:00' AS hs, 9.0 AS horas UNION ALL
    SELECT '2026-01-15' AS fecha, '07:30:00' AS he, '15:30:00' AS hs, 8.0 AS horas UNION ALL
    SELECT '2026-01-16' AS fecha, '07:00:00' AS he, '13:00:00' AS hs, 6.0 AS horas UNION ALL
    SELECT '2026-02-02' AS fecha, '07:00:00' AS he, '15:30:00' AS hs, 8.5 AS horas UNION ALL
    SELECT '2026-02-03' AS fecha, '07:00:00' AS he, '15:00:00' AS hs, 8.0 AS horas UNION ALL
    SELECT '2026-02-04' AS fecha, '08:00:00' AS he, '16:00:00' AS hs, 8.0 AS horas UNION ALL
    SELECT '2026-02-05' AS fecha, '07:00:00' AS he, '17:00:00' AS hs, 10.0 AS horas UNION ALL
    SELECT '2026-02-06' AS fecha, '07:00:00' AS he, '13:00:00' AS hs, 6.0 AS horas UNION ALL
    SELECT '2026-03-02' AS fecha, '07:00:00' AS he, '15:30:00' AS hs, 8.5 AS horas UNION ALL
    SELECT '2026-03-03' AS fecha, '07:00:00' AS he, '15:00:00' AS hs, 8.0 AS horas UNION ALL
    SELECT '2026-03-04' AS fecha, '07:00:00' AS he, '16:00:00' AS hs, 9.0 AS horas UNION ALL
    SELECT '2026-03-05' AS fecha, '07:30:00' AS he, '15:30:00' AS hs, 8.0 AS horas UNION ALL
    SELECT '2026-03-06' AS fecha, '07:00:00' AS he, '13:00:00' AS hs, 6.0 AS horas
) d
CROSS JOIN (SELECT id_obrero FROM obreros WHERE id_obrero BETWEEN 1 AND 25) o
CROSS JOIN (SELECT id_obra FROM obras WHERE id_obra BETWEEN 1 AND 5) ob
WHERE MOD(o.id_obrero, 5) = MOD(ob.id_obra - 1, 5)
LIMIT 250;

-- ===== 11. RECURSOS (Materiales con precio y Herramientas sin precio) =====
INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material) VALUES
(1, NULL, '2026-02-10', 'Cemento Loma Negra Portland CP40 (Bolsa 50kg)', 120, 9800.00, 1),
(2, NULL, '2026-02-10', 'Cal Hidratada El Milagro (Bolsa 25kg)', 80, 5600.00, 1),
(3, NULL, '2026-02-10', 'Hierro conformado ADN 420 8mm (Barra 12m)', 250, 1450.00, 1),
(4, NULL, '2026-02-10', 'Hierro conformado ADN 420 12mm (Barra 12m)', 180, 3200.00, 1),
(5, NULL, '2026-02-10', 'Hierro conformado ADN 420 16mm (Barra 12m)', 95, 5900.00, 1),
(6, NULL, '2026-02-10', 'Arena gruesa lavada de río (m3)', 35, 45000.00, 1),
(7, NULL, '2026-02-10', 'Piedra partida basáltica 6-20 (m3)', 28, 38000.00, 1),
(8, NULL, '2026-02-10', 'Ladrillo cerámico hueco 12x18x33 (Unidad)', 4500, 220.00, 1),
(9, NULL, '2026-02-10', 'Ladrillo cerámico portante 18x19x33 (Unidad)', 2200, 380.00, 1),
(10, NULL, '2026-02-10', 'Malla electrosoldada 15x15 4.2mm (Paño)', 45, 22500.00, 1),
(1, NULL, '2026-02-10', 'Pintura látex exterior Alba blanco 20L', 18, 68000.00, 1),
(2, NULL, '2026-02-10', 'Enduido plástico para exterior 20kg', 12, 18500.00, 1),
(3, NULL, '2026-02-10', 'Membrana asfáltica con aluminio 4mm (Rollo 10m2)', 25, 34000.00, 1),
(4, NULL, '2026-02-10', 'Caño cloacal PVC 110mm x 4m Tigre', 60, 14200.00, 1),
(5, NULL, '2026-02-10', 'Caño termofusión IPS agua 20mm x 4m', 90, 4800.00, 1),
(6, NULL, '2026-02-10', 'Cable unipolar normalizado 2.5mm (Rollo 100m)', 15, 38000.00, 1),
(7, NULL, '2026-02-10', 'Llave termomagnética bipolar Schneider 25A', 14, 12500.00, 1),
(8, NULL, '2026-02-10', 'Disyuntor diferencial bipolar 40A 30mA', 8, 28000.00, 1),
(9, NULL, '2026-02-10', 'Vigueta pretensada de hormigón 4.20m', 60, 9200.00, 1),
(10, NULL, '2026-02-10', 'Telgopor para losa 100x42x10cm (Bovedilla)', 120, 2400.00, 1),
(1, NULL, '2026-02-10', 'Pegamento para cerámicos Klaukol 30kg', 40, 7900.00, 1),
(2, NULL, '2026-02-10', 'Piso cerámico esmaltado 45x45 San Lorenzo (m2)', 150, 6800.00, 1),
(3, NULL, '2026-02-10', 'Adhesivo sellador de poliuretano Sikaflex 11FC', 24, 11500.00, 1),
(4, NULL, '2026-02-10', 'Impermeabilizante para cimientos Sika 1 20L', 10, 31000.00, 1),
(5, NULL, '2026-02-10', 'Chapa galvanizada acanalada C25 6m', 30, 26000.00, 1),
(6, NULL, '2026-02-12', 'Rotomartillo SDS Plus Bosch GBH 2-28', 4, NULL, 0),
(7, NULL, '2026-02-12', 'Amoladora angular 7\" DeWalt DWE490', 6, NULL, 0),
(8, NULL, '2026-02-12', 'Amoladora angular 4.5\" Makita GA4530', 8, NULL, 0),
(9, NULL, '2026-02-12', 'Hormigonera de volteo 130L con motor 3/4 HP', 3, NULL, 0),
(10, NULL, '2026-02-12', 'Sierra circular de mano Makita 5007N 7-1/4\"', 3, NULL, 0),
(1, NULL, '2026-02-12', 'Nivel láser rotativo autonivelante 360° Huepar', 2, NULL, 0),
(2, NULL, '2026-02-12', 'Generador eléctrico portátil 6.5 kVA Gamma', 2, NULL, 0),
(3, NULL, '2026-02-12', 'Vibrador de inmersión para hormigón Lusqtoff 2HP', 3, NULL, 0),
(4, NULL, '2026-02-12', 'Hidrolavadora industrial 2500 PSI Karcher', 2, NULL, 0),
(5, NULL, '2026-02-12', 'Cortadora sensitiva de metales 14\" Stanley', 2, NULL, 0),
(6, NULL, '2026-02-12', 'Andamios tubulares con tablones metálicos (Cuerpo)', 12, NULL, 0),
(7, NULL, '2026-02-12', 'Escalera extensible dieléctrica de fibra 8m', 4, NULL, 0),
(8, NULL, '2026-02-12', 'Soldadora inverter 200A Esab HandyArc', 3, NULL, 0),
(9, NULL, '2026-02-12', 'Termofusora digital para caños 800W Dogo', 4, NULL, 0),
(10, NULL, '2026-02-12', 'Pistola de calor industrial 2000W Bosch', 3, NULL, 0);

-- ===== 12. INTENTOS DE LOGIN (Historial de seguridad) =====
INSERT INTO intentos_login (username, ip_address, fecha, exitoso) VALUES
('admin', '127.0.0.1', '2026-01-10 08:00:15', 1),
('capataz', '127.0.0.1', '2026-01-10 08:15:22', 1),
('supervisor', '192.168.1.45', '2026-01-11 09:02:00', 1),
('admin', '192.168.1.102', '2026-01-12 07:45:10', 1),
('root', '185.220.101.5', '2026-01-15 03:12:44', 0),
('usuario_inexistente', '185.220.101.5', '2026-01-15 03:12:49', 0),
('admin', '185.220.101.5', '2026-01-15 03:13:02', 0),
('admin', '127.0.0.1', '2026-02-01 08:30:00', 1),
('capataz', '192.168.1.88', '2026-02-01 08:35:12', 1),
('juan.perez', '192.168.1.88', '2026-02-02 07:10:05', 1),
('maria.gonzalez', '192.168.1.50', '2026-02-03 08:45:30', 1),
('admin', '127.0.0.1', '2026-02-10 08:01:20', 1),
('invitado', '192.168.1.200', '2026-02-15 14:22:18', 0),
('capataz', '127.0.0.1', '2026-02-20 07:55:40', 1),
('admin', '127.0.0.1', '2026-03-01 08:10:00', 1),
('supervisor', '192.168.1.45', '2026-03-01 08:30:15', 1),
('capataz', '127.0.0.1', '2026-03-02 07:40:55', 1);

-- ===== 13. LOGS DE AUDITORÍA (Historial completo de operaciones en el sistema) =====
INSERT INTO auditoria_logs (id_usuario, usuario, rol, accion, entidad, entidad_id, detalle_json, ip_address, created_at) VALUES
(@admin_id, 'admin', 'Administrador', 'login', 'auth', @admin_id, '{"usuario":"admin"}', '127.0.0.1', '2026-01-10 08:00:15'),
(@capataz_id, 'capataz', 'Capataz', 'login', 'auth', @capataz_id, '{"usuario":"capataz"}', '127.0.0.1', '2026-01-10 08:15:22'),
(@admin_id, 'admin', 'Administrador', 'crear', 'obras', 1, '{"nombre":"Pavimentación Av. Costanera Sur","numero_contrata":"CTR-2026-001"}', '127.0.0.1', '2026-01-10 09:30:00'),
(@admin_id, 'admin', 'Administrador', 'crear', 'obras', 2, '{"nombre":"Construcción Hospital Nivel II","numero_contrata":"CTR-2026-002"}', '127.0.0.1', '2026-01-10 10:15:00'),
(@admin_id, 'admin', 'Administrador', 'crear', 'obreros', 1, '{"nombre":"Luis","apellido":"Benítez","cargo":"Albañil"}', '127.0.0.1', '2026-01-10 11:00:00'),
(@admin_id, 'admin', 'Administrador', 'subir_contrato', 'contrato_obrero', 1, '{"nombre_archivo":"contrato_36123450_benitez.pdf","fecha_vencimiento":"2026-12-31"}', '127.0.0.1', '2026-01-10 11:05:00'),
(@admin_id, 'admin', 'Administrador', 'crear', 'obreros', 2, '{"nombre":"Carlos","apellido":"Gómez","cargo":"Albañil"}', '127.0.0.1', '2026-01-10 11:20:00'),
(@admin_id, 'admin', 'Administrador', 'crear', 'maquinaria', 1, '{"nombre":"Excavadora sobre orugas 320D","marca":"Caterpillar"}', '127.0.0.1', '2026-01-10 12:00:00'),
(@admin_id, 'admin', 'Administrador', 'subir_certificado', 'certificados_maquinaria', 1, '{"nombre_archivo":"Cert_Inspeccion_Excavadora.pdf","id_maquinaria":1}', '127.0.0.1', '2026-01-10 12:10:00'),
(@capataz_id, 'capataz', 'Capataz', 'guardar', 'asistencia', 1, '{"fecha":"2026-01-12","obreros_presentes":8,"horas_totales":68.0}', '127.0.0.1', '2026-01-12 16:00:00'),
(@capataz_id, 'capataz', 'Capataz', 'guardar', 'asistencia', 1, '{"fecha":"2026-01-13","obreros_presentes":8,"horas_totales":64.0}', '127.0.0.1', '2026-01-13 15:30:00'),
(NULL, NULL, NULL, 'login_fallido', 'auth', NULL, '{"usuario":"root","ip":"185.220.101.5"}', '185.220.101.5', '2026-01-15 03:12:44'),
(NULL, NULL, NULL, 'login_fallido', 'auth', NULL, '{"usuario":"admin","ip":"185.220.101.5"}', '185.220.101.5', '2026-01-15 03:13:02'),
(@admin_id, 'admin', 'Administrador', 'editar', 'obras', 1, '{"nombre":"Pavimentación Av. Costanera Sur","contrato_reemplazado":false}', '127.0.0.1', '2026-01-20 10:00:00'),
(@admin_id, 'admin', 'Administrador', 'crear', 'maquinaria', 2, '{"nombre":"Retroexcavadora 3CX Eco 4x4","marca":"JCB"}', '127.0.0.1', '2026-01-20 11:30:00'),
(@admin_id, 'admin', 'Administrador', 'subir_certificado', 'certificados_maquinaria', 2, '{"nombre_archivo":"Cert_VTV_Retroexcavadora.pdf","id_maquinaria":2}', '127.0.0.1', '2026-01-20 11:35:00'),
(@admin_id, 'admin', 'Administrador', 'editar_certificado', 'certificados_maquinaria', 2, '{"fecha_vencimiento":"2026-08-30"}', '127.0.0.1', '2026-01-22 14:00:00'),
(@supervisor_id, 'supervisor', 'Administrador', 'login', 'auth', @supervisor_id, '{"usuario":"supervisor"}', '192.168.1.45', '2026-02-01 08:30:00'),
(@supervisor_id, 'supervisor', 'Administrador', 'exportar', 'todas', NULL, '{"entidades":["usuarios","obras","obreros","registros","recursos","maquinaria","auditoria_logs"]}', '192.168.1.45', '2026-02-01 09:15:00'),
(@admin_id, 'admin', 'Administrador', 'crear', 'usuarios', 4, '{"usuario":"juan.perez","rol":"Capataz"}', '127.0.0.1', '2026-02-01 10:00:00'),
(@admin_id, 'admin', 'Administrador', 'crear', 'usuarios', 5, '{"usuario":"maria.gonzalez","rol":"Administrador"}', '127.0.0.1', '2026-02-01 10:05:00'),
(@capataz_id, 'capataz', 'Capataz', 'guardar', 'asistencia', 2, '{"fecha":"2026-02-02","obreros_presentes":12,"horas_totales":96.0}', '192.168.1.88', '2026-02-02 16:30:00'),
(@admin_id, 'admin', 'Administrador', 'exportar', 'auditoria_logs', NULL, '{"filas":22}', '127.0.0.1', '2026-02-15 11:00:00'),
(@admin_id, 'admin', 'Administrador', 'cambiar_estado', 'obras', 21, '{"nombre":"Refacción Comisaría Seccional 2da","activo":0}', '127.0.0.1', '2026-02-20 15:00:00'),
(@admin_id, 'admin', 'Administrador', 'logout', 'auth', @admin_id, '{"usuario":"admin"}', '127.0.0.1', '2026-03-01 18:00:00');

COMMIT;
