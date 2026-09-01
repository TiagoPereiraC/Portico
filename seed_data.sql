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

USE portico;

START TRANSACTION;

-- =============================================================================
-- 1. USUARIOS (6 usuarios)
-- =============================================================================
INSERT INTO usuarios (id_usuario, nombre, usuario, password_hash, correo, rol, activo) VALUES
(1, 'Administrador Principal', 'admin', '$2y$12$KKDvf8gV1uJvDOal4pwqpeSNPIaNkbeVxaVzF7qOps3UwIHoUe0.q', 'admin@portico.local', 'Administrador', 1),
(2, 'Capataz General', 'capataz', '$2y$12$eFL7X6dijAsHUsEapoACFOn.9AoS.DBK1wPH4Izh9IxTXCdc4Bmpq', 'capataz@portico.local', 'Capataz', 1),
(3, 'Supervisor de Obra', 'supervisor', '$2y$12$KKDvf8gV1uJvDOal4pwqpeSNPIaNkbeVxaVzF7qOps3UwIHoUe0.q', 'supervisor@portico.local', 'Administrador', 1),
(4, 'Juan Pérez', 'juan.perez', '$2y$12$eFL7X6dijAsHUsEapoACFOn.9AoS.DBK1wPH4Izh9IxTXCdc4Bmpq', 'juan.perez@portico.local', 'Capataz', 1),
(5, 'María González', 'maria.gonzalez', '$2y$12$KKDvf8gV1uJvDOal4pwqpeSNPIaNkbeVxaVzF7qOps3UwIHoUe0.q', 'maria.gonzalez@portico.local', 'Administrador', 1),
(6, 'Roberto Gómez', 'roberto.gomez', '$2y$12$eFL7X6dijAsHUsEapoACFOn.9AoS.DBK1wPH4Izh9IxTXCdc4Bmpq', 'roberto.gomez@portico.local', 'Capataz', 1)
ON DUPLICATE KEY UPDATE
    nombre = VALUES(nombre),
    password_hash = VALUES(password_hash),
    correo = VALUES(correo),
    rol = VALUES(rol),
    activo = VALUES(activo);

-- ===== 2. OBRAS (35 obras) =====
INSERT INTO obras (numero_contrata, nombre, direccion, descripcion, fecha_inicio, fecha_fin, nombre_cliente, telefono_cliente, activo) VALUES
('CTR-2026-001', 'Pavimentación Av. Costanera Sur Tramo I', 'Av. Costanera Sur y Av. Mitre, Posadas', 'Pavimentación con hormigón H30, cordón cuneta y desagües.', '2026-01-10', '2026-11-20', 'Municipalidad de Posadas', '3764-440101', 1),
('CTR-2026-002', 'Construcción Hospital Nivel II Garupá', 'Av. Las Américas 1450, Garupá', 'Edificación de hospital de mediana complejidad con salas de internación.', '2026-01-15', '2027-05-30', 'Ministerio de Salud Pública', '3764-440102', 1),
('CTR-2026-003', 'Ampliación Red de Agua Potable B° Belgrano', 'Barrio Belgrano, Oberá', 'Tendido de 4500m de cañerías PEAD y 320 conexiones domiciliarias.', '2026-02-01', '2026-10-15', 'SAMSA / IPRODHA', '3755-420203', 1),
('CTR-2026-004', 'Remodelación Pasarelas Circuito Superior', 'Parque Nacional Iguazú, Puerto Iguazú', 'Reparación y refuerzo estructural de pasarelas y balcones turísticos.', '2026-02-10', '2026-09-30', 'Dirección Nacional de Parques', '3757-490304', 1),
('CTR-2026-005', 'Cordón Cuneta y Badenes B° San Martín', 'Barrio San Martín, Apóstoles', 'Construcción de cordón cuneta y empedrado en 18 cuadras.', '2026-03-01', '2026-11-15', 'Municipalidad de Apóstoles', '3758-422405', 1),
('CTR-2026-006', 'Red Cloacal Troncal Colector Este', 'Av. Libertador 890, San Vicente', 'Instalación de colectores cloacales primarios y estación de bombeo.', '2026-03-15', '2027-02-20', 'EPRAC Misiones', '3755-460506', 1),
('CTR-2026-007', 'Puesta en Valor y Veredas Plaza Central', 'Av. El Libertador y San Martín, Montecarlo', 'Recambio de veredas de pórfido, luminarias LED y fuentes ornamentales.', '2026-01-20', '2026-07-15', 'Municipalidad de Montecarlo', '3751-480607', 1),
('CTR-2026-008', 'Desagües Pluviales Cuenca Arroyo Piray', 'Ruta Prov. 12 km 1520, Eldorado', 'Canalización de hormigón armado y entubado para control de crecidas.', '2026-02-15', '2026-12-10', 'Dirección Provincial de Vialidad', '3751-430708', 1),
('CTR-2026-009', 'Construcción 50 Viviendas Sustentables', 'Barrio Itaembé Guazú Sector 5, Posadas', 'Viviendas bioclimáticas con termotanques solares e infraestructura vial.', '2026-01-05', '2027-04-01', 'IPRODHA', '3764-447809', 1),
('CTR-2026-010', 'Centro Comunitario y Polideportivo Municipal', 'Av. Quiroga 320, San Ignacio', 'Tinglado metálico parabólico, cancha multideporte y vestuarios.', '2026-02-20', '2026-11-30', 'Ministerio de Desarrollo Social', '3764-470910', 1),
('CTR-2026-011', 'Repavimentación Asfáltica Ruta Costera 2', 'Tramo Panambí - Santa Rita', 'Fresado, bacheo profundo y carpeta asfáltica en caliente de 5cm.', '2026-03-05', '2026-12-20', 'Vialidad Provincial', '3755-499111', 1),
('CTR-2026-012', 'Alumbrado Público LED y Línea Aérea', 'Acceso Sur y Rotonda, Candelaria', 'Instalación de 140 columnas metálicas de 9m con luminarias LED 150W.', '2026-01-12', '2026-06-30', 'Energía de Misiones (EMSA)', '3764-490112', 1),
('CTR-2026-013', 'Ampliación Talleres Técnicos EPET N° 1', 'Av. Lavalle 2500, Posadas', 'Construcción de 4 nuevas aulas-taller de electromecánica y robótica.', '2026-01-18', '2026-09-20', 'Consejo General de Educación', '3764-445113', 1),
('CTR-2026-014', 'Veredas Accesibles y Rampas Casco Céntrico', 'Casco Céntrico, Puerto Rico', 'Rampas de acceso universal, baldosas guía podotáctiles y canteros.', '2026-02-05', '2026-08-31', 'Municipalidad de Puerto Rico', '3743-420114', 1),
('CTR-2026-015', 'Nuevo Puente Hormigón s/ Arroyo Garupá', 'Ruta Provincial 206, Profundidad', 'Puente viga de hormigón pretensado de 42m de longitud y defensas.', '2026-01-25', '2027-03-28', 'Dirección Provincial de Vialidad', '3764-440115', 1),
('CTR-2026-016', 'Paseo Peatonal y Gastronómico Urbano', 'Av. San Martín 450, Aristóbulo del Valle', 'Soterrado de tendido eléctrico, veredas de adoquín y pérgolas.', '2026-02-28', '2026-10-30', 'Municipalidad de Aristóbulo', '3755-470116', 1),
('CTR-2026-017', 'Ampliación Edificio Tribunales Juzgados', 'Av. Santa Catalina 1735, Posadas', 'Construcción de tercer piso con salas de audiencia y defensorías.', '2026-01-08', '2026-12-15', 'Poder Judicial de Misiones', '3764-446117', 1),
('CTR-2026-018', 'Defensas Costeras y Pedraplén Arroyo Mártires', 'Costanera Oeste, Posadas', 'Muros de gaviones con colchonetas de piedra y parquizado de ribera.', '2026-03-10', '2026-11-15', 'Entidad Binacional Yacyretá', '3764-448118', 1),
('CTR-2026-019', 'Planta de Tratamiento Efluentes Industriales', 'Parque Industrial, Posadas', 'Reactores biológicos anaeróbicos y lagunas de pulido.', '2026-01-02', '2027-06-15', 'Parque Industrial Posadas', '3764-449119', 1),
('CTR-2026-020', 'Tendido Eléctrico Rural Media Tensión 13.2kV', 'Zona Rural Paraje Nemesio Parma', 'Línea aérea trifásica 13.2 kV y 4 subestaciones transformadoras.', '2026-02-12', '2026-09-15', 'Energía de Misiones', '3764-440120', 1),
('CTR-2026-021', 'Muelle Flotante de Cargas Nemesio Parma', 'Puerto de Posadas, Nemesio Parma', 'Estructura metálica naval pesada con grúa puente y pasarela.', '2026-03-01', '2026-11-01', 'Administración Portuaria Posadas', '3764-441021', 1),
('CTR-2026-022', 'Centro de Salud CAPS Nivel I B° 200 Viv.', 'Barrio 200 Viviendas, Leandro N. Alem', 'Consultorios médicos, odontología, enfermería y sala de espera.', '2026-02-15', '2026-09-30', 'Ministerio de Salud', '3754-420022', 1),
('CTR-2026-023', 'Veredas y Parquización Costanera Eduardo Arrabal', 'Costanera Eduardo Arrabal, Puerto Iguazú', 'Paseo peatonal ribereño con bicisendas y miradores solares.', '2026-01-20', '2026-08-20', 'Municipalidad de Iguazú', '3757-421023', 1),
('CTR-2026-024', 'Desagüe Pluvial Colector Calle Brasil', 'Calle Brasil y Córdoba, Oberá', 'Conducto cajón de hormigón armado de 2.00m x 1.50m.', '2026-02-01', '2026-09-30', 'Municipalidad de Oberá', '3755-423024', 1),
('CTR-2026-025', 'Pavimento Intertrabado Adoquinado B° Los Lapachos', 'Barrio Los Lapachos, Jardín América', 'Colocación de adoquines de hormigón bicapa de alto tránsito.', '2026-03-12', '2026-11-25', 'Municipalidad de Jardín América', '3743-460025', 1),
('CTR-2026-026', 'Alumbrado Público y Tendido B° Belén', 'Barrio Belén, Itaembé Miní, Posadas', 'Tendido de 3200m de cable preensamblado y 90 artefactos LED.', '2026-01-15', '2026-07-30', 'EMSA', '3764-440026', 1),
('CTR-2026-027', 'Remodelación Integral Terminal de Ómnibus', 'Ruta 14 y Av. Belgrano, Cerro Azul', 'Refacción de dársenas, sanitarios accesibles y boleterías.', '2026-02-10', '2026-10-15', 'Municipalidad de Cerro Azul', '3755-494027', 1),
('CTR-2026-028', 'Centro Cívico y Registro de las Personas', 'Av. Formosa 350, Campo Grande', 'Edificio institucional de 450 m2 cubiertos y estacionamiento.', '2026-03-01', '2026-12-15', 'Ministerio de Gobierno', '3755-480028', 1),
('CTR-2026-029', 'Reparación de Colector Cloacal B° Santa Rita', 'Av. Chacabuco y Monseñor D Andrea, Posadas', 'Reemplazo de cañería colectora de 400mm por rotura estructural.', '2026-04-01', '2026-09-15', 'SAMSA', '3764-440029', 1),
('CTR-2026-030', 'Construcción Playón Deportivo y Vestuarios', 'Barrio 80 Viviendas, San Pedro', 'Cancha de básquet/futsal con cerco perimetral e iluminación.', '2026-03-20', '2026-10-30', 'Municipalidad de San Pedro', '3751-470030', 1),
('CTR-2025-085', 'Refacción Comisaría Seccional 2da', 'Av. Tambor de Tacuarí, Posadas', 'Refacción integral de cubiertas, sanitarios, celdas e instalación eléctrica.', '2025-06-01', '2025-12-20', 'Ministerio de Gobierno', '3764-442085', 0),
('CTR-2025-086', 'Bacheo Asfáltico Integral Av. Uruguay', 'Av. Uruguay e/ Mitre y Quaranta, Posadas', 'Fresado y reposición de carpeta asfáltica en caliente.', '2025-08-10', '2025-11-30', 'Municipalidad de Posadas', '3764-440086', 0),
('CTR-2025-087', 'Perforación de Agua y Tanque Elevado', 'Paraje Gentil, San Pedro', 'Pozo profundo de 130m, bomba sumergible trifásica y tanque 20.000L.', '2025-05-15', '2025-10-15', 'IMAS Misiones', '3751-470087', 0),
('CTR-2025-088', 'Construcción Veredas Paseo Los Pioneros', 'Av. San Martín 1200, Montecarlo', 'Veredas peatonales con barandas metálicas y bancos de madera.', '2025-07-01', '2025-11-15', 'Municipalidad de Montecarlo', '3751-480088', 0),
('CTR-2025-089', 'Muro de Contención y Desagüe Pluvial', 'Barrio Lomas del Mirador, Posadas', 'Muro de gravedad de hormigón ciclópeo para contención de talud.', '2025-04-10', '2025-09-25', 'IPRODHA', '3764-440089', 0)
ON DUPLICATE KEY UPDATE nombre = VALUES(nombre), direccion = VALUES(direccion), descripcion = VALUES(descripcion), fecha_inicio = VALUES(fecha_inicio), fecha_fin = VALUES(fecha_fin), nombre_cliente = VALUES(nombre_cliente), telefono_cliente = VALUES(telefono_cliente), activo = VALUES(activo);

-- ===== 3. OBREROS (55 obreros) =====
INSERT INTO obreros (nombre, apellido, documento, telefono, fecha_contratacion, fecha_fin, cargo, activo) VALUES
('Luis', 'Benítez', '35123450', '3764-60101', '2025-06-10', NULL, 'Albañil', 1),
('Carlos', 'Gómez', '36234561', '3764-60102', '2025-07-10', NULL, 'Albañil', 1),
('Miguel', 'Rojas', '37345672', '3764-60103', '2025-08-10', NULL, 'Capataz', 1),
('Jorge', 'Ferreyra', '38456783', '3764-60104', '2025-01-10', NULL, 'Electricista', 1),
('Ramón', 'Acosta', '34567894', '3764-60105', '2025-02-10', NULL, 'Plomero', 1),
('Pedro', 'Insaurralde', '33678905', '3764-60106', '2025-03-10', NULL, 'Pintor', 1),
('Juan', 'Martínez', '39789016', '3764-60107', '2025-04-10', NULL, 'Carpintero', 1),
('Roberto', 'González', '40890127', '3764-60108', '2025-05-10', '2026-12-31', 'Soldador', 1),
('Óscar', 'Vargas', '41901238', '3764-60109', '2025-06-10', NULL, 'Operador de maquinaria', 1),
('Héctor', 'Sosa', '32012349', '3764-60110', '2025-07-10', NULL, 'Peón', 1),
('Daniel', 'Romero', '33123450', '3764-60111', '2025-08-10', NULL, 'Albañil', 1),
('Sergio', 'Torres', '34234561', '3764-60112', '2025-01-10', '2026-06-30', 'Electricista', 0),
('Marcelo', 'Ramírez', '35345672', '3764-60113', '2025-02-10', NULL, 'Operador de maquinaria', 1),
('Gustavo', 'Flores', '36456783', '3764-60114', '2025-03-10', NULL, 'Albañil', 1),
('Alberto', 'Díaz', '37567894', '3764-60115', '2025-04-10', NULL, 'Plomero', 1),
('Ricardo', 'Pereyra', '38678905', '3764-60116', '2025-05-10', NULL, 'Soldador', 1),
('Alejandro', 'Ojeda', '39789016', '3764-60117', '2025-06-10', '2026-12-31', 'Pintor', 1),
('Fernando', 'Rivero', '40890127', '3764-60118', '2025-07-10', NULL, 'Carpintero', 1),
('Javier', 'Maidana', '41901238', '3764-60119', '2025-08-10', NULL, 'Capataz', 1),
('Cristian', 'Brítez', '32012349', '3764-60120', '2025-01-10', NULL, 'Peón', 1),
('Víctor', 'Lescano', '33123460', '3764-60121', '2025-02-10', NULL, 'Peón', 1),
('Hugo', 'Aguirre', '34234571', '3764-60122', '2025-03-10', NULL, 'Albañil', 1),
('Diego', 'Juárez', '35345682', '3764-60123', '2025-04-10', NULL, 'Electricista', 1),
('Mario', 'Coronel', '36456793', '3764-60124', '2025-05-10', NULL, 'Operador de maquinaria', 1),
('Pablo', 'Silva', '37567804', '3764-60125', '2025-06-10', NULL, 'Soldador', 1),
('Claudio', 'Luna', '38678915', '3764-60126', '2025-07-10', '2026-12-31', 'Plomero', 0),
('Darío', 'Ibarra', '39789026', '3764-60127', '2025-08-10', NULL, 'Albañil', 1),
('Gabriel', 'Villalba', '40890137', '3764-60128', '2025-01-10', NULL, 'Pintor', 1),
('Fabián', 'Montiel', '41901248', '3764-60129', '2025-02-10', NULL, 'Carpintero', 1),
('Raúl', 'Giménez', '32012359', '3764-60130', '2025-03-10', NULL, 'Peón', 1),
('Adrián', 'Galeano', '33123470', '3764-60131', '2025-04-10', NULL, 'Operador de maquinaria', 1),
('Walter', 'Argüello', '34234581', '3764-60132', '2025-05-10', NULL, 'Albañil', 1),
('Lucas', 'Ávalos', '35345692', '3764-60133', '2025-06-10', NULL, 'Electricista', 1),
('Martín', 'Cabrera', '36456703', '3764-60134', '2025-07-10', NULL, 'Soldador', 1),
('Nicolás', 'Duarte', '37567814', '3764-60135', '2025-08-10', '2026-12-31', 'Plomero', 1),
('Esteban', 'Bordón', '38678925', '3764-60136', '2025-01-10', NULL, 'Albañil', 1),
('Federico', 'Velázquez', '39789036', '3764-60137', '2025-02-10', NULL, 'Capataz', 1),
('Ignacio', 'Cardozo', '40890147', '3764-60138', '2025-03-10', NULL, 'Peón', 1),
('Leonardo', 'Bogado', '41901258', '3764-60139', '2025-04-10', NULL, 'Pintor', 1),
('Sebastián', 'Almada', '32012369', '3764-60140', '2025-05-10', NULL, 'Carpintero', 0),
('Emiliano', 'Molina', '33123480', '3764-60141', '2025-06-10', NULL, 'Peón', 1),
('Matías', 'Espinoza', '34234591', '3764-60142', '2025-07-10', NULL, 'Albañil', 1),
('Ezequiel', 'Arias', '35345602', '3764-60143', '2025-08-10', NULL, 'Electricista', 1),
('Felipe', 'Melgarejo', '36456713', '3764-60144', '2025-01-10', '2026-12-31', 'Operador de maquinaria', 1),
('Andrés', 'Báez', '37567824', '3764-60145', '2025-02-10', NULL, 'Soldador', 1),
('Rubén', 'Guerrero', '38678935', '3764-60146', '2025-03-10', NULL, 'Plomero', 1),
('César', 'Ortiz', '39789046', '3764-60147', '2025-04-10', NULL, 'Albañil', 1),
('Hernán', 'Burgos', '40890157', '3764-60148', '2025-05-10', NULL, 'Pintor', 1),
('Iván', 'Cáceres', '41901268', '3764-60149', '2025-06-10', NULL, 'Peón', 1),
('Marcos', 'Rolón', '32012379', '3764-60150', '2025-07-10', NULL, 'Otro', 1),
('Damián', 'Salinas', '33123490', '3764-60151', '2025-08-10', NULL, 'Peón', 1),
('Néstor', 'Barrios', '34234501', '3764-60152', '2025-01-10', NULL, 'Albañil', 1),
('Omar', 'Morínigo', '35345612', '3764-60153', '2025-02-10', '2026-12-31', 'Electricista', 1),
('Julio', 'Fernández', '36456723', '3764-60154', '2025-03-10', NULL, 'Soldador', 0),
('Antonio', 'Vera', '37567834', '3764-60155', '2025-04-10', NULL, 'Capataz', 1)
ON DUPLICATE KEY UPDATE nombre = VALUES(nombre), apellido = VALUES(apellido), telefono = VALUES(telefono), cargo = VALUES(cargo), fecha_contratacion = VALUES(fecha_contratacion), fecha_fin = VALUES(fecha_fin), activo = VALUES(activo);

-- ===== 4. CONTRATOS OBREROS =====
INSERT INTO contrato_obrero (archivo, nombre_archivo, id_obrero, fecha_vencimiento)
SELECT _binary 'PDF_CONTRATO_OBRERO_DEMO_2026',
    CONCAT('contrato_', o.documento, '_', LOWER(o.apellido), '.pdf'),
    o.id_obrero,
    CASE
        WHEN o.id_obrero % 5 = 1 THEN DATE_SUB(CURDATE(), INTERVAL (o.id_obrero % 20 + 5) DAY)
        WHEN o.id_obrero % 5 = 2 THEN DATE_ADD(CURDATE(), INTERVAL (o.id_obrero % 20 + 3) DAY)
        WHEN o.id_obrero % 5 = 3 THEN DATE_ADD(CURDATE(), INTERVAL (o.id_obrero * 4 + 60) DAY)
        WHEN o.id_obrero % 5 = 4 THEN DATE_ADD(CURDATE(), INTERVAL (o.id_obrero * 6 + 120) DAY)
        ELSE NULL
    END
FROM obreros o
WHERE o.id_obrero <= 45
  AND NOT EXISTS (SELECT 1 FROM contrato_obrero WHERE id_obrero = o.id_obrero);

-- ===== 5. CONTRATOS OBRAS =====
INSERT INTO contratos (id_obra, archivo, nombre_archivo, fecha_subida)
SELECT ob.id_obra, _binary 'PDF_CONTRATO_OBRA_OFICIAL_2026', CONCAT('contrato_', ob.numero_contrata, '.pdf'), ob.fecha_inicio
FROM obras ob
WHERE NOT EXISTS (SELECT 1 FROM contratos WHERE id_obra = ob.id_obra);

-- ===== 6. MAQUINARIA (25 maquinarias) =====
INSERT INTO maquinaria (nombre, marca) VALUES
('Excavadora sobre orugas 320D', 'Caterpillar'),
('Retroexcavadora 3CX Eco 4x4', 'JCB'),
('Motoniveladora GD655-5', 'Komatsu'),
('Pala cargadora frontal L90F', 'Volvo'),
('Rodillo compactador monocilíndrico CA250', 'Dynapac'),
('Hormigonera autopropulsada DB 460', 'Fiori'),
('Miniexcavadora 331', 'Bobcat'),
('Camión volquete Trakker 380 6x4', 'Iveco'),
('Grúa móvil telescópica RT530E 30T', 'Grove'),
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
('Vibrocompactador reversible DPU 6555', 'Wacker Neuson'),
('Bomba de hormigón estacionaria BSA 1409', 'Putzmeister'),
('Camión cisterna regador 10.000L', 'Ford Cargo'),
('Termofusora hidráulica de cañerías 315mm', 'Ritmo'),
('Cortadora de pavimento a disco FS 400', 'Husqvarna');

-- ===== 7. CERTIFICADOS DE MAQUINARIA =====
INSERT INTO certificado (archivo, nombre_archivo, id_maquinaria, fecha_vencimiento)
SELECT _binary 'PDF_CERTIFICADO_TECNICO_MAQUINARIA_2026',
    CONCAT('Cert_Inspeccion_', REPLACE(REPLACE(m.nombre, ' ', '_'), '/', '-'), '.pdf'),
    m.id_maquinaria,
    CASE
        WHEN m.id_maquinaria % 4 = 1 THEN DATE_SUB(CURDATE(), INTERVAL (m.id_maquinaria % 15 + 4) DAY)
        WHEN m.id_maquinaria % 4 = 2 THEN DATE_ADD(CURDATE(), INTERVAL (m.id_maquinaria % 20 + 4) DAY)
        WHEN m.id_maquinaria % 4 = 3 THEN DATE_ADD(CURDATE(), INTERVAL (m.id_maquinaria * 6 + 60) DAY)
        ELSE NULL
    END
FROM maquinaria m
WHERE NOT EXISTS (SELECT 1 FROM certificado WHERE id_maquinaria = m.id_maquinaria);

-- ===== 8. ASIGNACIONES (obra_maquinaria) =====
INSERT INTO obra_maquinaria (id_obra, id_maquinaria, fecha_asignacion, fecha_retiro)
SELECT ob.id_obra, m.id_maquinaria, '2026-01-20',
    CASE WHEN MOD(ob.id_obra + m.id_maquinaria, 4) = 0 THEN '2026-06-30' ELSE NULL END
FROM (SELECT id_obra FROM obras WHERE activo = 1 LIMIT 20) ob
JOIN (SELECT id_maquinaria FROM maquinaria LIMIT 20) m
ON MOD(ob.id_obra, 20) = MOD(m.id_maquinaria, 20)
ON DUPLICATE KEY UPDATE fecha_retiro = VALUES(fecha_retiro);

-- ===== 9. ASISTENCIA DE MAQUINARIA =====
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
    SELECT '2026-03-10' AS fecha, '08:00:00' AS hora_salida, '16:30:00' AS hora_devolucion UNION ALL
    SELECT '2026-04-05' AS fecha, '07:00:00' AS hora_salida, '17:00:00' AS hora_devolucion UNION ALL
    SELECT '2026-05-12' AS fecha, '07:30:00' AS hora_salida, '16:30:00' AS hora_devolucion UNION ALL
    SELECT '2026-06-08' AS fecha, '08:00:00' AS hora_salida, '17:00:00' AS hora_devolucion UNION ALL
    SELECT '2026-07-15' AS fecha, '07:00:00' AS hora_salida, '16:00:00' AS hora_devolucion UNION ALL
    SELECT '2026-08-03' AS fecha, '07:00:00' AS hora_salida, '17:30:00' AS hora_devolucion UNION ALL
    SELECT '2026-08-18' AS fecha, '07:30:00' AS hora_salida, '16:30:00' AS hora_devolucion
) d
CROSS JOIN (SELECT id_obra FROM obras WHERE id_obra BETWEEN 1 AND 6) ob
CROSS JOIN (SELECT id_maquinaria FROM maquinaria WHERE id_maquinaria BETWEEN 1 AND 10) m
WHERE NOT EXISTS (
    SELECT 1 FROM asistencia_maquinaria
    WHERE id_obra = ob.id_obra AND id_maquinaria = m.id_maquinaria AND fecha = d.fecha
)
LIMIT 80;

-- ===== 10. REGISTROS DE ASISTENCIA =====
INSERT INTO registros (fecha, hora_entrada, hora_salida, horas_trabajadas, id_obrero, id_obra, id_usuario)
SELECT d.fecha, d.he, d.hs, d.horas, o.id_obrero, ob.id_obra, 2
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
    SELECT '2026-03-06' AS fecha, '07:00:00' AS he, '13:00:00' AS hs, 6.0 AS horas UNION ALL
    SELECT '2026-04-06' AS fecha, '07:00:00' AS he, '15:30:00' AS hs, 8.5 AS horas UNION ALL
    SELECT '2026-04-07' AS fecha, '07:00:00' AS he, '15:00:00' AS hs, 8.0 AS horas UNION ALL
    SELECT '2026-04-08' AS fecha, '07:30:00' AS he, '16:00:00' AS hs, 8.5 AS horas UNION ALL
    SELECT '2026-05-04' AS fecha, '07:00:00' AS he, '15:00:00' AS hs, 8.0 AS horas UNION ALL
    SELECT '2026-05-05' AS fecha, '07:00:00' AS he, '16:00:00' AS hs, 9.0 AS horas UNION ALL
    SELECT '2026-06-01' AS fecha, '07:00:00' AS he, '15:30:00' AS hs, 8.5 AS horas UNION ALL
    SELECT '2026-06-02' AS fecha, '07:30:00' AS he, '15:30:00' AS hs, 8.0 AS horas UNION ALL
    SELECT '2026-07-06' AS fecha, '07:00:00' AS he, '15:00:00' AS hs, 8.0 AS horas UNION ALL
    SELECT '2026-07-07' AS fecha, '07:00:00' AS he, '16:00:00' AS hs, 9.0 AS horas UNION ALL
    SELECT '2026-08-03' AS fecha, '07:00:00' AS he, '15:30:00' AS hs, 8.5 AS horas UNION ALL
    SELECT '2026-08-04' AS fecha, '07:00:00' AS he, '15:00:00' AS hs, 8.0 AS horas UNION ALL
    SELECT '2026-08-05' AS fecha, '07:30:00' AS he, '16:00:00' AS hs, 8.5 AS horas UNION ALL
    SELECT '2026-08-24' AS fecha, '07:00:00' AS he, '15:30:00' AS hs, 8.5 AS horas UNION ALL
    SELECT '2026-08-25' AS fecha, '07:00:00' AS he, '15:00:00' AS hs, 8.0 AS horas
) d
CROSS JOIN (SELECT id_obrero FROM obreros WHERE id_obrero BETWEEN 1 AND 30) o
CROSS JOIN (SELECT id_obra FROM obras WHERE id_obra BETWEEN 1 AND 6) ob
WHERE MOD(o.id_obrero, 6) = MOD(ob.id_obra - 1, 6)
LIMIT 350;

-- ===== 11. RECURSOS =====
INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material) VALUES
(1, NULL, '2026-03-10', 'Cemento Loma Negra Portland CP40 (Bolsa 50kg)', 180, 9800.00, 1),
(2, NULL, '2026-03-10', 'Cal Hidratada El Milagro (Bolsa 25kg)', 120, 5600.00, 1),
(3, NULL, '2026-03-10', 'Hierro conformado ADN 420 8mm (Barra 12m)', 350, 1450.00, 1),
(4, NULL, '2026-03-10', 'Hierro conformado ADN 420 12mm (Barra 12m)', 240, 3200.00, 1),
(5, NULL, '2026-03-10', 'Hierro conformado ADN 420 16mm (Barra 12m)', 140, 5900.00, 1),
(6, NULL, '2026-03-10', 'Arena gruesa lavada de río (m3)', 45, 45000.00, 1),
(7, NULL, '2026-03-10', 'Piedra partida basáltica 6-20 (m3)', 38, 38000.00, 1),
(8, NULL, '2026-03-10', 'Ladrillo cerámico hueco 12x18x33 (Unidad)', 6000, 220.00, 1),
(9, NULL, '2026-03-10', 'Ladrillo cerámico portante 18x19x33 (Unidad)', 3500, 380.00, 1),
(10, NULL, '2026-03-10', 'Malla electrosoldada 15x15 4.2mm (Paño 2x5m)', 65, 22500.00, 1),
(11, NULL, '2026-03-10', 'Pintura látex exterior Alba blanco 20L', 28, 68000.00, 1),
(12, NULL, '2026-03-10', 'Enduido plástico exterior 20kg', 20, 18500.00, 1),
(1, NULL, '2026-03-10', 'Membrana asfáltica con aluminio 4mm (Rollo 10m2)', 35, 34000.00, 1),
(2, NULL, '2026-03-10', 'Caño cloacal PVC 110mm x 4m Tigre', 85, 14200.00, 1),
(3, NULL, '2026-03-10', 'Caño termofusión IPS agua 20mm x 4m', 120, 4800.00, 1),
(4, NULL, '2026-03-10', 'Cable unipolar normalizado 2.5mm Prysmian (Rollo 100m)', 22, 38000.00, 1),
(5, NULL, '2026-03-10', 'Llave termomagnética bipolar Schneider 25A', 20, 12500.00, 1),
(6, NULL, '2026-03-10', 'Disyuntor diferencial bipolar 40A 30mA', 12, 28000.00, 1),
(7, NULL, '2026-03-10', 'Vigueta pretensada de hormigón 4.20m', 80, 9200.00, 1),
(8, NULL, '2026-03-10', 'Bovedilla de telgopor para losa 100x42x10cm', 160, 2400.00, 1),
(9, NULL, '2026-03-10', 'Pegamento para cerámicos Klaukol 30kg', 60, 7900.00, 1),
(10, NULL, '2026-03-10', 'Piso cerámico esmaltado 45x45 San Lorenzo (m2)', 220, 6800.00, 1),
(11, NULL, '2026-03-10', 'Adhesivo sellador de poliuretano Sikaflex 11FC', 36, 11500.00, 1),
(12, NULL, '2026-03-10', 'Impermeabilizante para cimientos Sika 1 20L', 15, 31000.00, 1),
(1, NULL, '2026-03-10', 'Chapa galvanizada acanalada C25 6m', 45, 26000.00, 1),
(2, NULL, '2026-03-12', 'Rotomartillo SDS Plus Bosch GBH 2-28', 5, NULL, 0),
(3, NULL, '2026-03-12', 'Amoladora angular 7\" DeWalt DWE490', 8, NULL, 0),
(4, NULL, '2026-03-12', 'Amoladora angular 4.5\" Makita GA4530', 10, NULL, 0),
(5, NULL, '2026-03-12', 'Hormigonera de volteo 130L con motor 3/4 HP', 4, NULL, 0),
(6, NULL, '2026-03-12', 'Sierra circular de mano Makita 5007N 7-1/4\"', 4, NULL, 0),
(7, NULL, '2026-03-12', 'Nivel láser rotativo autonivelante 360° Huepar', 3, NULL, 0),
(8, NULL, '2026-03-12', 'Generador eléctrico portátil 6.5 kVA Gamma', 3, NULL, 0),
(9, NULL, '2026-03-12', 'Vibrador de inmersión para hormigón Lusqtoff 2HP', 4, NULL, 0),
(10, NULL, '2026-03-12', 'Hidrolavadora industrial 2500 PSI Karcher', 3, NULL, 0),
(11, NULL, '2026-03-12', 'Cortadora sensitiva de metales 14\" Stanley', 3, NULL, 0),
(12, NULL, '2026-03-12', 'Andamios tubulares con tablones metálicos (Cuerpo)', 16, NULL, 0),
(1, NULL, '2026-03-12', 'Escalera extensible dieléctrica de fibra 8m', 6, NULL, 0),
(2, NULL, '2026-03-12', 'Soldadora inverter 200A Esab HandyArc', 4, NULL, 0),
(3, NULL, '2026-03-12', 'Termofusora digital para caños 800W Dogo', 5, NULL, 0),
(4, NULL, '2026-03-12', 'Pistola de calor industrial 2000W Bosch', 4, NULL, 0);

-- ===== 12. INTENTOS DE LOGIN =====
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
('admin', '127.0.0.1', '2026-03-01 08:01:20', 1),
('invitado', '192.168.1.200', '2026-04-15 14:22:18', 0),
('capataz', '127.0.0.1', '2026-05-20 07:55:40', 1),
('admin', '127.0.0.1', '2026-06-01 08:10:00', 1),
('supervisor', '192.168.1.45', '2026-07-01 08:30:15', 1),
('roberto.gomez', '192.168.1.92', '2026-08-01 07:45:10', 1),
('admin', '127.0.0.1', '2026-08-26 08:00:00', 1),
('capataz', '127.0.0.1', '2026-08-26 08:15:00', 1);

-- ===== 13. LOGS DE AUDITORÍA =====
INSERT INTO auditoria_logs (id_usuario, usuario, rol, accion, entidad, entidad_id, detalle_json, ip_address, created_at) VALUES
(1, 'admin', 'Administrador', 'login', 'auth', 1, '{"usuario":"admin"}', '127.0.0.1', '2026-01-10 08:00:15'),
(2, 'capataz', 'Capataz', 'login', 'auth', 2, '{"usuario":"capataz"}', '127.0.0.1', '2026-01-10 08:15:22'),
(1, 'admin', 'Administrador', 'crear', 'obras', 1, '{"nombre":"Pavimentacion Av. Costanera Sur","numero_contrata":"CTR-2026-001"}', '127.0.0.1', '2026-01-10 09:30:00'),
(1, 'admin', 'Administrador', 'crear', 'obras', 2, '{"nombre":"Construccion Hospital Nivel II","numero_contrata":"CTR-2026-002"}', '127.0.0.1', '2026-01-10 10:15:00'),
(1, 'admin', 'Administrador', 'crear', 'obreros', 1, '{"nombre":"Luis","apellido":"Benitez","cargo":"Albanil"}', '127.0.0.1', '2026-01-10 11:00:00'),
(1, 'admin', 'Administrador', 'subir_contrato', 'contrato_obrero', 1, '{"nombre_archivo":"contrato_35123450_benitez.pdf","fecha_vencimiento":"2026-12-31"}', '127.0.0.1', '2026-01-10 11:05:00'),
(1, 'admin', 'Administrador', 'crear', 'obreros', 2, '{"nombre":"Carlos","apellido":"Gomez","cargo":"Albanil"}', '127.0.0.1', '2026-01-10 11:20:00'),
(1, 'admin', 'Administrador', 'crear', 'maquinaria', 1, '{"nombre":"Excavadora sobre orugas 320D","marca":"Caterpillar"}', '127.0.0.1', '2026-01-10 12:00:00'),
(1, 'admin', 'Administrador', 'subir_certificado', 'certificados_maquinaria', 1, '{"nombre_archivo":"Cert_Inspeccion_Excavadora.pdf","id_maquinaria":1}', '127.0.0.1', '2026-01-10 12:10:00'),
(2, 'capataz', 'Capataz', 'guardar', 'asistencia', 1, '{"fecha":"2026-01-12","obreros_presentes":8,"horas_totales":68.0}', '127.0.0.1', '2026-01-12 16:00:00');

INSERT INTO auditoria_logs (id_usuario, usuario, rol, accion, entidad, entidad_id, detalle_json, ip_address, created_at) VALUES
(2, 'capataz', 'Capataz', 'guardar', 'asistencia', 1, '{"fecha":"2026-01-13","obreros_presentes":8,"horas_totales":64.0}', '127.0.0.1', '2026-01-13 15:30:00'),
(NULL, NULL, NULL, 'login_fallido', 'auth', NULL, '{"usuario":"root","ip":"185.220.101.5"}', '185.220.101.5', '2026-01-15 03:12:44'),
(NULL, NULL, NULL, 'login_fallido', 'auth', NULL, '{"usuario":"admin","ip":"185.220.101.5"}', '185.220.101.5', '2026-01-15 03:13:02'),
(1, 'admin', 'Administrador', 'editar', 'obras', 1, '{"nombre":"Pavimentacion Av. Costanera Sur","contrato_reemplazado":false}', '127.0.0.1', '2026-01-20 10:00:00'),
(1, 'admin', 'Administrador', 'crear', 'maquinaria', 2, '{"nombre":"Retroexcavadora 3CX Eco 4x4","marca":"JCB"}', '127.0.0.1', '2026-01-20 11:30:00'),
(1, 'admin', 'Administrador', 'subir_certificado', 'certificados_maquinaria', 2, '{"nombre_archivo":"Cert_VTV_Retroexcavadora.pdf","id_maquinaria":2}', '127.0.0.1', '2026-01-20 11:35:00'),
(1, 'admin', 'Administrador', 'editar_certificado', 'certificados_maquinaria', 2, '{"fecha_vencimiento":"2026-09-30"}', '127.0.0.1', '2026-01-22 14:00:00'),
(3, 'supervisor', 'Administrador', 'login', 'auth', 3, '{"usuario":"supervisor"}', '192.168.1.45', '2026-02-01 08:30:00'),
(3, 'supervisor', 'Administrador', 'exportar', 'todas', NULL, '{"entidades":["usuarios","obras","obreros","registros","recursos","maquinaria","auditoria_logs"]}', '192.168.1.45', '2026-02-01 09:15:00'),
(1, 'admin', 'Administrador', 'crear', 'usuarios', 4, '{"usuario":"juan.perez","rol":"Capataz"}', '127.0.0.1', '2026-02-01 10:00:00');

INSERT INTO auditoria_logs (id_usuario, usuario, rol, accion, entidad, entidad_id, detalle_json, ip_address, created_at) VALUES
(1, 'admin', 'Administrador', 'crear', 'usuarios', 5, '{"usuario":"maria.gonzalez","rol":"Administrador"}', '127.0.0.1', '2026-02-01 10:05:00'),
(2, 'capataz', 'Capataz', 'guardar', 'asistencia', 2, '{"fecha":"2026-02-02","obreros_presentes":12,"horas_totales":96.0}', '192.168.1.88', '2026-02-02 16:30:00'),
(1, 'admin', 'Administrador', 'exportar', 'auditoria_logs', NULL, '{"filas":22}', '127.0.0.1', '2026-02-15 11:00:00'),
(1, 'admin', 'Administrador', 'cambiar_estado', 'obras', 31, '{"nombre":"Refaccion Comisaria Seccional 2da","activo":0}', '127.0.0.1', '2026-02-20 15:00:00'),
(1, 'admin', 'Administrador', 'crear', 'usuarios', 6, '{"usuario":"roberto.gomez","rol":"Capataz"}', '127.0.0.1', '2026-03-01 09:00:00'),
(1, 'admin', 'Administrador', 'crear', 'maquinaria', 8, '{"nombre":"Camion volquete Trakker 380 6x4","marca":"Iveco"}', '127.0.0.1', '2026-03-10 11:00:00'),
(2, 'capataz', 'Capataz', 'guardar', 'asistencia', 3, '{"fecha":"2026-04-06","obreros_presentes":10,"horas_totales":85.0}', '127.0.0.1', '2026-04-06 16:00:00'),
(4, 'juan.perez', 'Capataz', 'guardar', 'asistencia', 4, '{"fecha":"2026-05-04","obreros_presentes":14,"horas_totales":112.0}', '192.168.1.88', '2026-05-04 16:30:00'),
(5, 'maria.gonzalez', 'Administrador', 'exportar', 'obras', NULL, '{"filas":35}', '192.168.1.50', '2026-06-15 10:30:00'),
(1, 'admin', 'Administrador', 'subir_certificado', 'certificados_maquinaria', 5, '{"nombre_archivo":"Cert_CA250_Dynapac.pdf","id_maquinaria":5}', '127.0.0.1', '2026-07-10 14:20:00'),
(2, 'capataz', 'Capataz', 'guardar', 'asistencia', 5, '{"fecha":"2026-08-24","obreros_presentes":15,"horas_totales":120.0}', '127.0.0.1', '2026-08-24 16:00:00'),
(1, 'admin', 'Administrador', 'logout', 'auth', 1, '{"usuario":"admin"}', '127.0.0.1', '2026-08-26 18:00:00');

-- ===== 14. TAREAS DE CONTRATOS (contrato_tareas) =====
INSERT INTO contrato_tareas (id_contrato, id_tarea_origen, descripcion, importe, estado, fecha_completada) VALUES
(1, NULL, 'Replanteo topográfico y cartel de obra', 450000.00, 'Completada', '2026-01-15'),
(1, NULL, 'Movimiento de suelo, excavación y desmonte', 1850000.00, 'Completada', '2026-02-10'),
(1, NULL, 'Subbase de suelo cemento compactada e=15cm', 3200000.00, 'Completada', '2026-03-20'),
(1, NULL, 'Pavimento de hormigón H30 con pasadores e=18cm', 8900000.00, 'Pendiente', NULL),
(1, NULL, 'Cordón cuneta y badenes de escurrimiento', 2400000.00, 'Pendiente', NULL),
(1, NULL, 'Señalización vial horizontal y vertical', 850000.00, 'Pendiente', NULL),

(2, NULL, 'Instalación de obrador, cerco y servicios provisorios', 650000.00, 'Completada', '2026-01-25'),
(2, NULL, 'Excavaciones masivas para bases y vigas de fundación', 2100000.00, 'Completada', '2026-02-28'),
(2, NULL, 'Estructura resistente de H°A° planta baja y losa', 14500000.00, 'Pendiente', NULL),
(2, NULL, 'Mampostería exterior de ladrillo cerámico portante', 8200000.00, 'Pendiente', NULL),
(2, NULL, 'Instalaciones troncales de gases medicinales y sanitarias', 6800000.00, 'Pendiente', NULL),

(3, NULL, 'Apertura de zanja para tendido de red troncal', 1200000.00, 'Completada', '2026-02-15'),
(3, NULL, 'Tendido de cañería PEAD 110mm por electrofusión', 4500000.00, 'Completada', '2026-04-10'),
(3, NULL, 'Instalación de 320 conexiones domiciliarias y cajas', 3800000.00, 'Pendiente', NULL),
(3, NULL, 'Pruebas de presión hidráulica y desinfección', 950000.00, 'Pendiente', NULL),

(4, NULL, 'Desmontaje de pasarelas deterioradas y retiro', 850000.00, 'Completada', '2026-02-25'),
(4, NULL, 'Recalce y refuerzo de pilotes de H°A° en lecho', 3400000.00, 'Completada', '2026-04-30'),
(4, NULL, 'Montaje de pórticos y vigas de acero galvanizado', 7200000.00, 'Pendiente', NULL),
(4, NULL, 'Colocación de rejillas de tránsito y barandas', 2900000.00, 'Pendiente', NULL),

(5, NULL, 'Nivelación, perfilado y compactación de subrasante', 780000.00, 'Completada', '2026-03-15'),
(5, NULL, 'Hormigonado de cordón cuneta en 18 cuadras', 4200000.00, 'Completada', '2026-06-20'),
(5, NULL, 'Colocación de empedrado basáltico trabado', 5600000.00, 'Pendiente', NULL),

(6, NULL, 'Replanteo planialtimétrico y sondeos de interferencias', 680000.00, 'Completada', '2026-03-20'),
(6, NULL, 'Excavación a cielo abierto para colector principal e=3.5m', 2950000.00, 'Completada', '2026-04-15'),
(6, NULL, 'Instalación de cañerías de PVC cloacal de 315mm', 5400000.00, 'Pendiente', NULL),
(6, NULL, 'Construcción de bocas de registro de hormigón armado', 3100000.00, 'Pendiente', NULL),
(6, NULL, 'Ejecución de estación elevadora y bombas sumergibles', 7800000.00, 'Pendiente', NULL),
(6, NULL, 'Pruebas hidráulicas de estanqueidad y empalme a red', 1250000.00, 'Pendiente', NULL),

(7, NULL, 'Demolición de pisos existentes y retiro de escombros', 850000.00, 'Completada', '2026-02-05'),
(7, NULL, 'Contrapiso de hormigón H13 con malla sima', 2300000.00, 'Completada', '2026-03-10'),
(7, NULL, 'Colocación de baldosas graníticas y baldosas podotáctiles', 4100000.00, 'Pendiente', NULL),
(7, NULL, 'Instalación subterránea de ductos y 40 farolas LED', 3200000.00, 'Pendiente', NULL),
(7, NULL, 'Pérgolas de madera dura, bancos y cestos de residuos', 1950000.00, 'Pendiente', NULL),
(7, NULL, 'Parquización, siembra de césped y canteros florales', 980000.00, 'Pendiente', NULL),

(8, NULL, 'Limpieza de traza y desmonte de vegetación', 750000.00, 'Completada', '2026-02-28'),
(8, NULL, 'Excavación masiva para canal aliviador', 3600000.00, 'Completada', '2026-04-05'),
(8, NULL, 'Hormigonado de solera y muros laterales de canal H21', 8900000.00, 'Pendiente', NULL),
(8, NULL, 'Colocación de tubos de hormigón premoldeado Ø1200', 6200000.00, 'Pendiente', NULL),
(8, NULL, 'Badenes y sumideros de captación pluvial urbana', 2450000.00, 'Pendiente', NULL),
(8, NULL, 'Colchonetas de piedra embolsada en desembocadura', 1800000.00, 'Pendiente', NULL),

(9, NULL, 'Movimiento de suelo y nivelación de 50 plateas', 4200000.00, 'Completada', '2026-01-28'),
(9, NULL, 'Hormigonado de plateas de fundación con instalaciones', 12800000.00, 'Completada', '2026-03-15'),
(9, NULL, 'Mampostería de bloques de hormigón celular curado', 18500000.00, 'Pendiente', NULL),
(9, NULL, 'Estructura de techo en perfiles C y chapa trapezoidal', 14200000.00, 'Pendiente', NULL),
(9, NULL, 'Instalación eléctrica, agua, cloacas y termotanques solares', 16900000.00, 'Pendiente', NULL),
(9, NULL, 'Revoques, revestimientos cerámicos y pintura látex exterior', 9600000.00, 'Pendiente', NULL),

(10, NULL, 'Nivelación de terreno y excavación de pozos de bases', 920000.00, 'Completada', '2026-03-05'),
(10, NULL, 'Hormigón armado en bases aisladas y vigas de arriostre', 3400000.00, 'Completada', '2026-04-20'),
(10, NULL, 'Fabricación y montaje de estructura metálica reticulada', 9800000.00, 'Pendiente', NULL),
(10, NULL, 'Cubierta de chapa con aislación térmica de lana de vidrio', 5600000.00, 'Pendiente', NULL),
(10, NULL, 'Piso alisado de microcemento con demarcación reglamentaria', 4200000.00, 'Pendiente', NULL),
(10, NULL, 'Construcción de módulo de vestuarios y sanitarios accesibles', 6700000.00, 'Pendiente', NULL),

(11, NULL, 'Fresado de carpeta asfáltica deteriorada e=4cm', 3800000.00, 'Completada', '2026-03-25'),
(11, NULL, 'Bacheo superficial y profundo con mezcla en caliente', 6400000.00, 'Completada', '2026-05-10'),
(11, NULL, 'Riego de liga con emulsión asfáltica catiónica', 2100000.00, 'Pendiente', NULL),
(11, NULL, 'Provisión y distribución de carpeta de concreto asfáltico 5cm', 18900000.00, 'Pendiente', NULL),
(11, NULL, 'Limpieza y perfilado de banquinas y cunetas laterales', 3200000.00, 'Pendiente', NULL),
(11, NULL, 'Pintura termoplástica reflectante y tachas viales', 2800000.00, 'Pendiente', NULL),

(12, NULL, 'Apertura de pozos y hormigonado de bases cilíndricas', 1450000.00, 'Completada', '2026-02-05'),
(12, NULL, 'Montaje de 140 columnas metálicas de acero de 9m', 4800000.00, 'Completada', '2026-03-30'),
(12, NULL, 'Tendido de 4800m de cable de aluminio preensamblado', 3900000.00, 'Completada', '2026-05-15'),
(12, NULL, 'Instalación y conexión de artefactos LED 150W IP66', 5200000.00, 'Pendiente', NULL),
(12, NULL, 'Montaje de tableros de comando con fotocélulas y disyuntores', 1650000.00, 'Pendiente', NULL),
(12, NULL, 'Medición de resistencia de puesta a tierra y puesta en servicio', 850000.00, 'Pendiente', NULL),

(13, NULL, 'Demolición parcial y apertura de vanos en muros existentes', 680000.00, 'Completada', '2026-02-12'),
(13, NULL, 'Fundaciones corridas y encadenado inferior de H°A°', 2800000.00, 'Completada', '2026-03-28'),
(13, NULL, 'Mampostería de elevación de ladrillos cerámicos huecos', 4500000.00, 'Completada', '2026-05-20'),
(13, NULL, 'Cubierta metálica con chapa U-45 autoportante', 3900000.00, 'Pendiente', NULL),
(13, NULL, 'Instalación eléctrica trifásica industrial para maquinarias', 5400000.00, 'Pendiente', NULL),
(13, NULL, 'Pisos de alta resistencia mecánica y pintura epoxi', 3100000.00, 'Pendiente', NULL),

(14, NULL, 'Aserrado y demolición de veredas y cordones existentes', 980000.00, 'Completada', '2026-02-22'),
(14, NULL, 'Contrapiso de hormigón armado H17 e=10cm', 2600000.00, 'Completada', '2026-04-10'),
(14, NULL, 'Ejecución de 48 rampas de esquina con pendiente reglamentaria', 3400000.00, 'Pendiente', NULL),
(14, NULL, 'Colocación de baldosas podotáctiles de advertencia y guía', 4200000.00, 'Pendiente', NULL),
(14, NULL, 'Reubicación de tapas de registro de servicios y sumideros', 1200000.00, 'Pendiente', NULL),

(15, NULL, 'Construcción de ataguías y desvío provisorio de cauce', 3200000.00, 'Completada', '2026-02-20'),
(15, NULL, 'Pilotaje perforado de gran diámetro en estribos y pilas', 14500000.00, 'Completada', '2026-05-15'),
(15, NULL, 'Encofrado y hormigonado de cabezales y pilas centrales', 11200000.00, 'Pendiente', NULL),
(15, NULL, 'Montaje de 12 vigas pretensadas de 21m con grúa de 70T', 18600000.00, 'Pendiente', NULL),
(15, NULL, 'Hormigonado de losa de tablero y carpeta de desgaste', 9800000.00, 'Pendiente', NULL),
(15, NULL, 'Defensas tipo New Jersey, juntas de dilatación y barandas', 4700000.00, 'Pendiente', NULL),

(16, NULL, 'Zanjeo y soterrado de redes eléctricas y telecomunicaciones', 3400000.00, 'Completada', '2026-03-20'),
(16, NULL, 'Bases de hormigón y colocación de adoquines intertrabados', 6800000.00, 'Completada', '2026-05-25'),
(16, NULL, 'Instalación de pérgolas metálicas y decks de madera tratada', 5200000.00, 'Pendiente', NULL),
(16, NULL, 'Sistema de iluminación ambiental cálida y columnas LED', 3900000.00, 'Pendiente', NULL),
(16, NULL, 'Mobiliario urbano: mesas gastronómicas, bancos y bebederos', 2900000.00, 'Pendiente', NULL),

(17, NULL, 'Refuerzo estructural de columnas y losa de piso inferior', 4900000.00, 'Completada', '2026-02-01'),
(17, NULL, 'Montaje de estructura liviana Steel Frame tercer piso', 12400000.00, 'Completada', '2026-04-15'),
(17, NULL, 'Cerramientos exteriores en placas cementicias y aislación', 7800000.00, 'Pendiente', NULL),
(17, NULL, 'Divisiones interiores en tabiquería Durlock acústico', 6500000.00, 'Pendiente', NULL),
(17, NULL, 'Sistema central de climatización VRF y ventilación', 11800000.00, 'Pendiente', NULL),
(17, NULL, 'Cableado estructurado de datos, audio de salas y seguridad', 5600000.00, 'Pendiente', NULL),

(18, NULL, 'Dragado de borde y preparación de lecho ribereño', 4500000.00, 'Completada', '2026-03-30'),
(18, NULL, 'Colocación de geotextil no tejido de alta resistencia', 2100000.00, 'Completada', '2026-05-10'),
(18, NULL, 'Armado y llenado de gaviones de alambre galvanizado con piedra', 11400000.00, 'Pendiente', NULL),
(18, NULL, 'Colchonetas tipo Reno en taludes de escurrimiento', 6800000.00, 'Pendiente', NULL),
(18, NULL, 'Relleno compactado detrás de muro y sendero superior', 5200000.00, 'Pendiente', NULL),

(19, NULL, 'Excavación masiva para reactores y piletas de decantación', 5600000.00, 'Completada', '2026-02-15'),
(19, NULL, 'Hormigonado de plateas y tabiques de H°A° impermeable', 19800000.00, 'Pendiente', NULL),
(19, NULL, 'Instalación de geomembranas de PEAD 1.5mm termosoldadas', 8200000.00, 'Pendiente', NULL),
(19, NULL, 'Montaje electromecánico de aireadores y bombas dosificadoras', 14500000.00, 'Pendiente', NULL),
(19, NULL, 'Tendido de cañerías de impulsión y manifold de distribución', 7600000.00, 'Pendiente', NULL),

(20, NULL, 'Apertura de picada y limpieza de servidumbre de paso', 2400000.00, 'Completada', '2026-03-05'),
(20, NULL, 'Izaje de 85 postes de hormigón armado y madera tratada', 5900000.00, 'Completada', '2026-04-30'),
(20, NULL, 'Tendido y tensado de conductor de aleación de aluminio Almelec', 8400000.00, 'Pendiente', NULL),
(20, NULL, 'Montaje de 4 subestaciones transformadoras bipostes de 63kVA', 6700000.00, 'Pendiente', NULL),
(20, NULL, 'Seccionadores fusibles, descargadores y conexionado rural', 2900000.00, 'Pendiente', NULL),

(21, NULL, 'Fabricación de pontones flotantes de acero naval', 18900000.00, 'Completada', '2026-04-10'),
(21, NULL, 'Hincado de pilotes guía de acero rellenos de hormigón', 12400000.00, 'Pendiente', NULL),
(21, NULL, 'Montaje de pasarela articulada de acceso de 35m', 9800000.00, 'Pendiente', NULL),
(21, NULL, 'Instalación de defensas elásticas y bitas de amarre 50T', 4500000.00, 'Pendiente', NULL),
(21, NULL, 'Sistema de balizamiento náutico e iluminación de cubierta', 3200000.00, 'Pendiente', NULL),

(22, NULL, 'Nivelación y replanteo de edificio sanitario', 650000.00, 'Completada', '2026-03-01'),
(22, NULL, 'Vigas de fundación y pilotines de hormigón armado', 3100000.00, 'Completada', '2026-04-15'),
(22, NULL, 'Mampostería de ladrillos cerámicos y revoque hidrófugo', 5800000.00, 'Pendiente', NULL),
(22, NULL, 'Instalaciones sanitarias especiales y gases médicos', 4900000.00, 'Pendiente', NULL),
(22, NULL, 'Carpinterías de aluminio anodizado y vidrios laminados', 3700000.00, 'Pendiente', NULL),

(23, NULL, 'Limpieza de franja ribereña y nivelación de suelo', 1200000.00, 'Completada', '2026-02-15'),
(23, NULL, 'Hormigonado de veredas peatonales y circuito de bicisenda', 7400000.00, 'Completada', '2026-04-25'),
(23, NULL, 'Pintura epoxi reflectante en bicisenda y cartelería', 2300000.00, 'Pendiente', NULL),
(23, NULL, 'Colocación de 60 luminarias solares autónomas', 5600000.00, 'Pendiente', NULL),
(23, NULL, 'Parquización con especies nativas y riego por goteo', 3100000.00, 'Pendiente', NULL),

(24, NULL, 'Rotura de pavimento y excavación en trinchera', 2800000.00, 'Completada', '2026-02-25'),
(24, NULL, 'Colocación de conductos premoldeados tipo cajón 2.0x1.5m', 9400000.00, 'Completada', '2026-05-15'),
(24, NULL, 'Hormigonado de cámaras de enlace y sumideros transversales', 3800000.00, 'Pendiente', NULL),
(24, NULL, 'Relleno con suelo cemento compactado y repavimentación', 4600000.00, 'Pendiente', NULL),

(25, NULL, 'Perfilado de calzada y excavación de caja e=30cm', 2100000.00, 'Completada', '2026-04-05'),
(25, NULL, 'Subbase de tosca cementada compactada al 98% Proctor', 4900000.00, 'Completada', '2026-05-30'),
(25, NULL, 'Colocación de adoquines de hormigón bicapa holandés', 9800000.00, 'Pendiente', NULL),
(25, NULL, 'Hormigonado de cordones de confinamiento y badenes', 3200000.00, 'Pendiente', NULL),

(26, NULL, 'Plantado de 90 postes de madera tratada con crucetas', 2800000.00, 'Completada', '2026-02-10'),
(26, NULL, 'Tendido de 3200m de cable preensamblado 4x50mm', 4600000.00, 'Completada', '2026-04-15'),
(26, NULL, 'Montaje de 90 artefactos de alumbrado público LED 100W', 3900000.00, 'Pendiente', NULL),
(26, NULL, 'Puesta a tierra individual y tablero de comando', 1400000.00, 'Pendiente', NULL),

(27, NULL, 'Demolición de pisos interiores y sanitarios antiguos', 1100000.00, 'Completada', '2026-03-01'),
(27, NULL, 'Nuevos pisos graníticos de alto tránsito en hall central', 4300000.00, 'Completada', '2026-05-10'),
(27, NULL, 'Readecuación de 10 dársenas con pavimento de H° H30', 6800000.00, 'Pendiente', NULL),
(27, NULL, 'Instalación de nuevos sanitarios accesibles y boleterías', 5200000.00, 'Pendiente', NULL),

(28, NULL, 'Excavaciones para zapatas corridas y pilotines', 950000.00, 'Completada', '2026-03-25'),
(28, NULL, 'Estructura de hormigón armado vigas y losas alivianadas', 8700000.00, 'Pendiente', NULL),
(28, NULL, 'Mamposterías de ladrillos cerámicos y revoques interiores', 5400000.00, 'Pendiente', NULL),
(28, NULL, 'Instalaciones eléctricas, sanitarias y red de climatización', 7200000.00, 'Pendiente', NULL),

(29, NULL, 'Apertura de zanja de emergencia en calzada urbana', 1850000.00, 'Completada', '2026-04-10'),
(29, NULL, 'Retiro de cañería colapsada y entibado de zanja', 2400000.00, 'Completada', '2026-05-05'),
(29, NULL, 'Instalación de cañería cloacal de PVC corrugado Ø400', 4900000.00, 'Pendiente', NULL),
(29, NULL, 'Reconstrucción de cámara de inspección y tapado', 2100000.00, 'Pendiente', NULL),

(30, NULL, 'Nivelación de terreno y base granular compactada', 1400000.00, 'Completada', '2026-04-05'),
(30, NULL, 'Piso de hormigón peinado H21 con junta de dilatación', 5800000.00, 'Pendiente', NULL),
(30, NULL, 'Cerco perimetral olímpico con alambre romboidal', 3200000.00, 'Pendiente', NULL),
(30, NULL, 'Torres de iluminación con reflectores LED y arcos/tableros', 2600000.00, 'Pendiente', NULL),

(31, NULL, 'Demolición de cielorrasos y revoques con humedad', 650000.00, 'Completada', '2025-06-20'),
(31, NULL, 'Reemplazo de cubierta de techo y canaletas de desagüe', 3400000.00, 'Completada', '2025-08-15'),
(31, NULL, 'Instalación eléctrica completa embutida con jabalinas', 2800000.00, 'Completada', '2025-10-10'),
(31, NULL, 'Pintura general sintética y látex lavable en celdas y oficinas', 1900000.00, 'Completada', '2025-12-15'),

(32, NULL, 'Fresado de deformaciones y ahuellamientos en calzada', 2900000.00, 'Completada', '2025-08-25'),
(32, NULL, 'Bacheo profundo con hormigón de fraguado rápido H30', 4800000.00, 'Completada', '2025-09-30'),
(32, NULL, 'Carpeta asfáltica de terminación en caliente de 5cm', 7200000.00, 'Completada', '2025-11-20'),

(33, NULL, 'Perforación hidrogeológica entubada de 130m de profundidad', 4600000.00, 'Completada', '2025-06-30'),
(33, NULL, 'Instalación de bomba sumergible trifásica de 7.5HP', 3100000.00, 'Completada', '2025-08-10'),
(33, NULL, 'Montaje de torre metálica y tanque cisterna de 20.000L', 5400000.00, 'Completada', '2025-10-05'),

(34, NULL, 'Movimiento de suelo y contrapiso de hormigón', 1800000.00, 'Completada', '2025-07-25'),
(34, NULL, 'Colocación de losetas atérmicas y barandas de seguridad', 3200000.00, 'Completada', '2025-09-15'),
(34, NULL, 'Instalación de luminarias peatonales y bancos de plaza', 2100000.00, 'Completada', '2025-11-10'),

(35, NULL, 'Excavación al pie de talud y perfilado de terreno', 1500000.00, 'Completada', '2025-05-10'),
(35, NULL, 'Muro de contención de hormigón ciclópeo con barbacanas', 5900000.00, 'Completada', '2025-07-20'),
(35, NULL, 'Canal colector pluvial superior y disipador de energía', 2600000.00, 'Completada', '2025-09-18');

-- ===== 15. COMBUSTIBLE (combustible) =====
INSERT INTO combustible (nombre_combustible, litros, precio_unitario, precio_total, fecha, id_obra, id_maquinaria) VALUES
('Diesel', 180.00, 1180.00, 212400.00, '2026-01-15', 1, 1),
('Diesel', 120.00, 1180.00, 141600.00, '2026-01-20', 1, 8),
('Diesel', 250.00, 1195.00, 298750.00, '2026-02-05', 2, 1),
('Diesel', 150.00, 1195.00, 179250.00, '2026-02-12', 2, 2),
('Nafta', 45.00, 1250.00, 56250.00, '2026-02-15', 3, 11),
('Diesel', 90.00, 1210.00, 108900.00, '2026-03-02', 4, 7),
('Diesel', 200.00, 1220.00, 244000.00, '2026-03-10', 5, 5),
('Nafta', 60.00, 1260.00, 75600.00, '2026-04-05', 1, 13),
('Diesel', 140.00, 1230.00, 172200.00, '2026-05-12', 2, 4),
('Diesel', 220.00, 1240.00, 272800.00, '2026-06-08', 3, 15),
('Nafta', 50.00, 1280.00, 64000.00, '2026-07-15', 4, 11),
('Diesel', 160.00, 1250.00, 200000.00, '2026-08-03', 5, 8),
('Diesel', 175.00, 1260.00, 220500.00, '2026-08-18', 1, 1),
('Nafta', 40.00, 1290.00, 51600.00, '2026-08-25', 2, 14);

COMMIT;
