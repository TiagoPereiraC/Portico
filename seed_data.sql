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

-- Asume que schema.sql ya fue ejecutado.

-- ===== USUARIOS =====
INSERT INTO usuarios (nombre, usuario, password_hash, rol, activo) VALUES
('Administrador', 'admin',   '$2y$12$ATczWwHjwfhi9BVElVybR..BYXJ5X4PFRjjJ9EWR/8Ew3/.hHxItm', 'Administrador', 1),
('Capataz',  'capataz', '$2y$12$eFL7X6dijAsHUsEapoACFOn.9AoS.DBK1wPH4Izh9IxTXCdc4Bmpq', 'Capataz',       1)
ON DUPLICATE KEY UPDATE activo = VALUES(activo);

SET @admin_id = (SELECT id_usuario FROM usuarios WHERE usuario = 'admin' LIMIT 1);
SET @capataz_id = (SELECT id_usuario FROM usuarios WHERE usuario = 'capataz' LIMIT 1);

-- ===== OBRAS (105) =====
INSERT INTO obras (numero_contrata, nombre, direccion, descripcion, fecha_inicio, fecha_fin, nombre_cliente, telefono_cliente, activo)
SELECT * FROM (
    SELECT 'CTR-001' AS nc, 'Pavimentacion Barrio Norte' AS n, 'Barrio Norte, Posadas, Misiones' AS d, 'Pavimentacion de obra en Barrio Norte, Posadas.' AS de, '2026-01-01' AS fi, 2027-07-16 AS ff, 'Municipalidad de Posadas' AS c, '3764-501001' AS t, 1 AS a UNION ALL
    SELECT 'CTR-002' AS nc, 'Construccion Barrio Sur' AS n, 'Av. Cabred 12, Obera' AS d, 'Construccion de obra en Barrio Sur, Obera.' AS de, '2026-02-02' AS fi, 2026-08-17 AS ff, 'IPRODHA' AS c, '3764-501002' AS t, 1 AS a UNION ALL
    SELECT 'CTR-003' AS nc, 'Refaccion Villa Cabello' AS n, 'Av. Trincheras de San Jose 13, Eldorado' AS d, 'Refaccion de obra en Villa Cabello, Eldorado.' AS de, '2026-03-03' AS fi, 2027-09-18 AS ff, 'Vialidad Provincial' AS c, '3764-501003' AS t, 1 AS a UNION ALL
    SELECT 'CTR-004' AS nc, 'Ampliacion Itaembe Guazu' AS n, 'Av. Eva Peron 14, Garupa' AS d, 'Ampliacion de obra en Itaembe Guazu, Garupa.' AS de, '2026-04-04' AS fi, NULL AS ff, 'SAMSA' AS c, '3764-501004' AS t, 1 AS a UNION ALL
    SELECT 'CTR-005' AS nc, 'Cordon Cuneta Miguel Lanus' AS n, 'Miguel Lanus, Apóstoles, Misiones' AS d, 'Cordon Cuneta de obra en Miguel Lanus, Apóstoles.' AS de, '2026-05-05' AS fi, 2027-11-20 AS ff, 'Consejo General de Educacion' AS c, '3764-501005' AS t, 1 AS a UNION ALL
    SELECT 'CTR-006' AS nc, 'Veredas Santa Rita' AS n, 'Santa Rita, Puerto Iguazu, Misiones' AS d, 'Veredas de obra en Santa Rita, Puerto Iguazu.' AS de, '2026-06-06' AS fi, 2026-12-21 AS ff, 'Ministerio de Salud' AS c, '3764-501006' AS t, 1 AS a UNION ALL
    SELECT 'CTR-007' AS nc, 'Desagues Libertad' AS n, 'Libertad, Montecarlo, Misiones' AS d, 'Desagues de obra en Libertad, Montecarlo.' AS de, '2026-07-07' AS fi, 2027-01-22 AS ff, 'Poder Judicial' AS c, '3764-501007' AS t, 1 AS a UNION ALL
    SELECT 'CTR-008' AS nc, 'Iluminacion Fatima' AS n, 'Fatima, San Ignacio, Misiones' AS d, 'Iluminacion de obra en Fatima, San Ignacio.' AS de, '2026-08-08' AS fi, NULL AS ff, 'Ministerio de Gobierno' AS c, '3764-501008' AS t, 1 AS a UNION ALL
    SELECT 'CTR-009' AS nc, 'Red de Agua Los Lapachos' AS n, 'Los Lapachos, Jardin America, Misiones' AS d, 'Red de Agua de obra en Los Lapachos, Jardin America.' AS de, '2026-09-09' AS fi, 2027-03-24 AS ff, 'Direccion de Catastro' AS c, '3764-501009' AS t, 1 AS a UNION ALL
    SELECT 'CTR-010' AS nc, 'Red Cloacal San Isidro' AS n, 'San Isidro, San Pedro, Misiones' AS d, 'Red Cloacal de obra en San Isidro, San Pedro.' AS de, '2026-10-10' AS fi, 2026-04-25 AS ff, 'EBY' AS c, '3764-501010' AS t, 1 AS a UNION ALL
    SELECT 'CTR-011' AS nc, 'Bacheo Las Dolores' AS n, 'Las Dolores, Aristobulo del Valle, Misiones' AS d, 'Bacheo de obra en Las Dolores, Aristobulo del Valle.' AS de, '2026-11-11' AS fi, 2027-05-26 AS ff, 'AFIP' AS c, '3764-501011' AS t, 1 AS a UNION ALL
    SELECT 'CTR-012' AS nc, 'Repavimentacion Villa Urquiza' AS n, 'Villa Urquiza, Cerro Azul, Misiones' AS d, 'Repavimentacion de obra en Villa Urquiza, Cerro Azul.' AS de, '2026-12-12' AS fi, NULL AS ff, 'Ministerio de Cultura' AS c, '3764-501012' AS t, 1 AS a UNION ALL
    SELECT 'CTR-013' AS nc, 'Defensas San Marcos' AS n, 'San Marcos, Campo Grande, Misiones' AS d, 'Defensas de obra en San Marcos, Campo Grande.' AS de, '2026-01-13' AS fi, 2027-07-28 AS ff, 'Ministerio de Desarrollo Social' AS c, '3764-501013' AS t, 1 AS a UNION ALL
    SELECT 'CTR-014' AS nc, 'Puesta en valor 508' AS n, '508, San Vicente, Misiones' AS d, 'Puesta en valor de obra en 508, San Vicente.' AS de, '2026-02-14' AS fi, 2026-08-01 AS ff, 'Parque del Conocimiento' AS c, '3764-501014' AS t, 1 AS a UNION ALL
    SELECT 'CTR-015' AS nc, 'Remodelacion Sesquicentenario' AS n, 'Sesquicentenario, Puerto Rico, Misiones' AS d, 'Remodelacion de obra en Sesquicentenario, Puerto Rico.' AS de, '2026-03-15' AS fi, 2027-09-02 AS ff, 'Correo Argentino' AS c, '3764-501015' AS t, 1 AS a UNION ALL
    SELECT 'CTR-016' AS nc, 'Pavimentacion Aeroclub' AS n, 'Aeroclub, Posadas, Misiones' AS d, 'Pavimentacion de obra en Aeroclub, Posadas.' AS de, '2026-04-16' AS fi, NULL AS ff, 'Gendarmeria Nacional' AS c, '3764-501016' AS t, 1 AS a UNION ALL
    SELECT 'CTR-017' AS nc, 'Construccion Prosol' AS n, 'Av. Bustamante 117, Obera' AS d, 'Construccion de obra en Prosol, Obera.' AS de, '2026-05-17' AS fi, 2027-11-04 AS ff, 'Policia de Misiones' AS c, '3764-501017' AS t, 1 AS a UNION ALL
    SELECT 'CTR-018' AS nc, 'Refaccion Itaembe Mini' AS n, 'Av. Marconi 118, Eldorado' AS d, 'Refaccion de obra en Itaembe Mini, Eldorado.' AS de, '2026-06-18' AS fi, 2026-12-05 AS ff, 'Bomberos Voluntarios' AS c, '3764-501018' AS t, 1 AS a UNION ALL
    SELECT 'CTR-019' AS nc, 'Ampliacion Los Oleros' AS n, 'Av. López Torres 119, Garupa' AS d, 'Ampliacion de obra en Los Oleros, Garupa.' AS de, '2026-07-19' AS fi, 2027-01-06 AS ff, 'Hospital Escuela' AS c, '3764-501019' AS t, 1 AS a UNION ALL
    SELECT 'CTR-020' AS nc, 'Cordon Cuneta Santa Helena' AS n, 'Santa Helena, Apóstoles, Misiones' AS d, 'Cordon Cuneta de obra en Santa Helena, Apóstoles.' AS de, '2026-08-20' AS fi, NULL AS ff, 'Ente Regulador' AS c, '3764-501020' AS t, 1 AS a UNION ALL
    SELECT 'CTR-021' AS nc, 'Veredas Las Rosas' AS n, 'Las Rosas, Puerto Iguazu, Misiones' AS d, 'Veredas de obra en Las Rosas, Puerto Iguazu.' AS de, '2026-09-21' AS fi, 2027-03-08 AS ff, 'Archivo General' AS c, '3764-501021' AS t, 1 AS a UNION ALL
    SELECT 'CTR-022' AS nc, 'Desagues Kennedy' AS n, 'Kennedy, Montecarlo, Misiones' AS d, 'Desagues de obra en Kennedy, Montecarlo.' AS de, '2026-10-22' AS fi, 2026-04-09 AS ff, 'Ministerio de Educacion' AS c, '3764-501022' AS t, 1 AS a UNION ALL
    SELECT 'CTR-023' AS nc, 'Iluminacion 20 de Junio' AS n, '20 de Junio, San Ignacio, Misiones' AS d, 'Iluminacion de obra en 20 de Junio, San Ignacio.' AS de, '2026-11-23' AS fi, 2027-05-10 AS ff, 'Municipalidad de San Ignacio' AS c, '3764-501023' AS t, 1 AS a UNION ALL
    SELECT 'CTR-024' AS nc, 'Red de Agua A4' AS n, 'A4, Jardin America, Misiones' AS d, 'Red de Agua de obra en A4, Jardin America.' AS de, '2026-12-24' AS fi, NULL AS ff, 'IPRODHA' AS c, '3764-501024' AS t, 1 AS a UNION ALL
    SELECT 'CTR-025' AS nc, 'Red Cloacal Yacyreta' AS n, 'Yacyreta, San Pedro, Misiones' AS d, 'Red Cloacal de obra en Yacyreta, San Pedro.' AS de, '2026-01-25' AS fi, 2027-07-12 AS ff, 'Vialidad Provincial' AS c, '3764-501025' AS t, 1 AS a UNION ALL
    SELECT 'CTR-026' AS nc, 'Bacheo 25 de Mayo' AS n, '25 de Mayo, Aristobulo del Valle, Misiones' AS d, 'Bacheo de obra en 25 de Mayo, Aristobulo del Valle.' AS de, '2026-02-26' AS fi, 2026-08-13 AS ff, 'SAMSA' AS c, '3764-501026' AS t, 1 AS a UNION ALL
    SELECT 'CTR-027' AS nc, 'Repavimentacion San Alberto' AS n, 'San Alberto, Cerro Azul, Misiones' AS d, 'Repavimentacion de obra en San Alberto, Cerro Azul.' AS de, '2026-03-27' AS fi, 2027-09-14 AS ff, 'Consejo General de Educacion' AS c, '3764-501027' AS t, 1 AS a UNION ALL
    SELECT 'CTR-028' AS nc, 'Defensas San Roque' AS n, 'San Roque, Campo Grande, Misiones' AS d, 'Defensas de obra en San Roque, Campo Grande.' AS de, '2026-04-28' AS fi, NULL AS ff, 'Ministerio de Salud' AS c, '3764-501028' AS t, 1 AS a UNION ALL
    SELECT 'CTR-029' AS nc, 'Puesta en valor Bicentenario' AS n, 'Bicentenario, San Vicente, Misiones' AS d, 'Puesta en valor de obra en Bicentenario, San Vicente.' AS de, '2026-05-01' AS fi, 2027-11-16 AS ff, 'Poder Judicial' AS c, '3764-501029' AS t, 1 AS a UNION ALL
    SELECT 'CTR-030' AS nc, 'Remodelacion Nuestro Señora' AS n, 'Nuestro Señora, Puerto Rico, Misiones' AS d, 'Remodelacion de obra en Nuestro Señora, Puerto Rico.' AS de, '2026-06-02' AS fi, 2026-12-17 AS ff, 'Ministerio de Gobierno' AS c, '3764-501030' AS t, 1 AS a UNION ALL
    SELECT 'CTR-031' AS nc, 'Pavimentacion El Porvenir' AS n, 'El Porvenir, Posadas, Misiones' AS d, 'Pavimentacion de obra en El Porvenir, Posadas.' AS de, '2026-07-03' AS fi, 2027-01-18 AS ff, 'Direccion de Catastro' AS c, '3764-501031' AS t, 1 AS a UNION ALL
    SELECT 'CTR-032' AS nc, 'Construccion 120 Viviendas' AS n, 'Av. Cabred 132, Obera' AS d, 'Construccion de obra en 120 Viviendas, Obera.' AS de, '2026-08-04' AS fi, NULL AS ff, 'EBY' AS c, '3764-501032' AS t, 1 AS a UNION ALL
    SELECT 'CTR-033' AS nc, 'Refaccion Santa Ana' AS n, 'Av. Trincheras de San Jose 133, Eldorado' AS d, 'Refaccion de obra en Santa Ana, Eldorado.' AS de, '2026-09-05' AS fi, 2027-03-20 AS ff, 'AFIP' AS c, '3764-501033' AS t, 1 AS a UNION ALL
    SELECT 'CTR-034' AS nc, 'Ampliacion Los Cedros' AS n, 'Av. Eva Peron 134, Garupa' AS d, 'Ampliacion de obra en Los Cedros, Garupa.' AS de, '2026-10-06' AS fi, 2026-04-21 AS ff, 'Ministerio de Cultura' AS c, '3764-501034' AS t, 1 AS a UNION ALL
    SELECT 'CTR-035' AS nc, 'Cordon Cuneta Barrio Norte' AS n, 'Barrio Norte, Apóstoles, Misiones' AS d, 'Cordon Cuneta de obra en Barrio Norte, Apóstoles.' AS de, '2026-11-07' AS fi, 2027-05-22 AS ff, 'Ministerio de Desarrollo Social' AS c, '3764-501035' AS t, 1 AS a UNION ALL
    SELECT 'CTR-036' AS nc, 'Veredas Barrio Sur' AS n, 'Barrio Sur, Puerto Iguazu, Misiones' AS d, 'Veredas de obra en Barrio Sur, Puerto Iguazu.' AS de, '2026-12-08' AS fi, NULL AS ff, 'Parque del Conocimiento' AS c, '3764-501036' AS t, 1 AS a UNION ALL
    SELECT 'CTR-037' AS nc, 'Desagues Villa Cabello' AS n, 'Villa Cabello, Montecarlo, Misiones' AS d, 'Desagues de obra en Villa Cabello, Montecarlo.' AS de, '2026-01-09' AS fi, 2027-07-24 AS ff, 'Correo Argentino' AS c, '3764-501037' AS t, 1 AS a UNION ALL
    SELECT 'CTR-038' AS nc, 'Iluminacion Itaembe Guazu' AS n, 'Itaembe Guazu, San Ignacio, Misiones' AS d, 'Iluminacion de obra en Itaembe Guazu, San Ignacio.' AS de, '2026-02-10' AS fi, 2026-08-25 AS ff, 'Gendarmeria Nacional' AS c, '3764-501038' AS t, 1 AS a UNION ALL
    SELECT 'CTR-039' AS nc, 'Red de Agua Miguel Lanus' AS n, 'Miguel Lanus, Jardin America, Misiones' AS d, 'Red de Agua de obra en Miguel Lanus, Jardin America.' AS de, '2026-03-11' AS fi, 2027-09-26 AS ff, 'Policia de Misiones' AS c, '3764-501039' AS t, 1 AS a UNION ALL
    SELECT 'CTR-040' AS nc, 'Red Cloacal Santa Rita' AS n, 'Santa Rita, San Pedro, Misiones' AS d, 'Red Cloacal de obra en Santa Rita, San Pedro.' AS de, '2026-04-12' AS fi, NULL AS ff, 'Bomberos Voluntarios' AS c, '3764-501040' AS t, 1 AS a UNION ALL
    SELECT 'CTR-041' AS nc, 'Bacheo Libertad' AS n, 'Libertad, Aristobulo del Valle, Misiones' AS d, 'Bacheo de obra en Libertad, Aristobulo del Valle.' AS de, '2026-05-13' AS fi, 2027-11-28 AS ff, 'Hospital Escuela' AS c, '3764-501041' AS t, 1 AS a UNION ALL
    SELECT 'CTR-042' AS nc, 'Repavimentacion Fatima' AS n, 'Fatima, Cerro Azul, Misiones' AS d, 'Repavimentacion de obra en Fatima, Cerro Azul.' AS de, '2026-06-14' AS fi, 2026-12-01 AS ff, 'Ente Regulador' AS c, '3764-501042' AS t, 1 AS a UNION ALL
    SELECT 'CTR-043' AS nc, 'Defensas Los Lapachos' AS n, 'Los Lapachos, Campo Grande, Misiones' AS d, 'Defensas de obra en Los Lapachos, Campo Grande.' AS de, '2026-07-15' AS fi, 2027-01-02 AS ff, 'Archivo General' AS c, '3764-501043' AS t, 1 AS a UNION ALL
    SELECT 'CTR-044' AS nc, 'Puesta en valor San Isidro' AS n, 'San Isidro, San Vicente, Misiones' AS d, 'Puesta en valor de obra en San Isidro, San Vicente.' AS de, '2026-08-16' AS fi, NULL AS ff, 'Ministerio de Educacion' AS c, '3764-501044' AS t, 1 AS a UNION ALL
    SELECT 'CTR-045' AS nc, 'Remodelacion Las Dolores' AS n, 'Las Dolores, Puerto Rico, Misiones' AS d, 'Remodelacion de obra en Las Dolores, Puerto Rico.' AS de, '2026-09-17' AS fi, 2027-03-04 AS ff, 'Municipalidad de Puerto Rico' AS c, '3764-501045' AS t, 1 AS a UNION ALL
    SELECT 'CTR-046' AS nc, 'Pavimentacion Villa Urquiza' AS n, 'Villa Urquiza, Posadas, Misiones' AS d, 'Pavimentacion de obra en Villa Urquiza, Posadas.' AS de, '2026-10-18' AS fi, 2026-04-05 AS ff, 'IPRODHA' AS c, '3764-501046' AS t, 1 AS a UNION ALL
    SELECT 'CTR-047' AS nc, 'Construccion San Marcos' AS n, 'Av. Bustamante 147, Obera' AS d, 'Construccion de obra en San Marcos, Obera.' AS de, '2026-11-19' AS fi, 2027-05-06 AS ff, 'Vialidad Provincial' AS c, '3764-501047' AS t, 1 AS a UNION ALL
    SELECT 'CTR-048' AS nc, 'Refaccion 508' AS n, 'Av. Marconi 148, Eldorado' AS d, 'Refaccion de obra en 508, Eldorado.' AS de, '2026-12-20' AS fi, NULL AS ff, 'SAMSA' AS c, '3764-501048' AS t, 1 AS a UNION ALL
    SELECT 'CTR-049' AS nc, 'Ampliacion Sesquicentenario' AS n, 'Av. López Torres 149, Garupa' AS d, 'Ampliacion de obra en Sesquicentenario, Garupa.' AS de, '2026-01-21' AS fi, 2027-07-08 AS ff, 'Consejo General de Educacion' AS c, '3764-501049' AS t, 1 AS a UNION ALL
    SELECT 'CTR-050' AS nc, 'Cordon Cuneta Aeroclub' AS n, 'Aeroclub, Apóstoles, Misiones' AS d, 'Cordon Cuneta de obra en Aeroclub, Apóstoles.' AS de, '2026-02-22' AS fi, 2026-08-09 AS ff, 'Ministerio de Salud' AS c, '3764-501050' AS t, 1 AS a UNION ALL
    SELECT 'CTR-051' AS nc, 'Veredas Prosol' AS n, 'Prosol, Puerto Iguazu, Misiones' AS d, 'Veredas de obra en Prosol, Puerto Iguazu.' AS de, '2026-03-23' AS fi, 2027-09-10 AS ff, 'Poder Judicial' AS c, '3764-501051' AS t, 1 AS a UNION ALL
    SELECT 'CTR-052' AS nc, 'Desagues Itaembe Mini' AS n, 'Itaembe Mini, Montecarlo, Misiones' AS d, 'Desagues de obra en Itaembe Mini, Montecarlo.' AS de, '2026-04-24' AS fi, NULL AS ff, 'Ministerio de Gobierno' AS c, '3764-501052' AS t, 1 AS a UNION ALL
    SELECT 'CTR-053' AS nc, 'Iluminacion Los Oleros' AS n, 'Los Oleros, San Ignacio, Misiones' AS d, 'Iluminacion de obra en Los Oleros, San Ignacio.' AS de, '2026-05-25' AS fi, 2027-11-12 AS ff, 'Direccion de Catastro' AS c, '3764-501053' AS t, 1 AS a UNION ALL
    SELECT 'CTR-054' AS nc, 'Red de Agua Santa Helena' AS n, 'Santa Helena, Jardin America, Misiones' AS d, 'Red de Agua de obra en Santa Helena, Jardin America.' AS de, '2026-06-26' AS fi, 2026-12-13 AS ff, 'EBY' AS c, '3764-501054' AS t, 1 AS a UNION ALL
    SELECT 'CTR-055' AS nc, 'Red Cloacal Las Rosas' AS n, 'Las Rosas, San Pedro, Misiones' AS d, 'Red Cloacal de obra en Las Rosas, San Pedro.' AS de, '2026-07-27' AS fi, 2027-01-14 AS ff, 'AFIP' AS c, '3764-501055' AS t, 1 AS a UNION ALL
    SELECT 'CTR-056' AS nc, 'Bacheo Kennedy' AS n, 'Kennedy, Aristobulo del Valle, Misiones' AS d, 'Bacheo de obra en Kennedy, Aristobulo del Valle.' AS de, '2026-08-28' AS fi, NULL AS ff, 'Ministerio de Cultura' AS c, '3764-501056' AS t, 1 AS a UNION ALL
    SELECT 'CTR-057' AS nc, 'Repavimentacion 20 de Junio' AS n, '20 de Junio, Cerro Azul, Misiones' AS d, 'Repavimentacion de obra en 20 de Junio, Cerro Azul.' AS de, '2026-09-01' AS fi, 2027-03-16 AS ff, 'Ministerio de Desarrollo Social' AS c, '3764-501057' AS t, 1 AS a UNION ALL
    SELECT 'CTR-058' AS nc, 'Defensas A4' AS n, 'A4, Campo Grande, Misiones' AS d, 'Defensas de obra en A4, Campo Grande.' AS de, '2026-10-02' AS fi, 2026-04-17 AS ff, 'Parque del Conocimiento' AS c, '3764-501058' AS t, 1 AS a UNION ALL
    SELECT 'CTR-059' AS nc, 'Puesta en valor Yacyreta' AS n, 'Yacyreta, San Vicente, Misiones' AS d, 'Puesta en valor de obra en Yacyreta, San Vicente.' AS de, '2026-11-03' AS fi, 2027-05-18 AS ff, 'Correo Argentino' AS c, '3764-501059' AS t, 1 AS a UNION ALL
    SELECT 'CTR-060' AS nc, 'Remodelacion 25 de Mayo' AS n, '25 de Mayo, Puerto Rico, Misiones' AS d, 'Remodelacion de obra en 25 de Mayo, Puerto Rico.' AS de, '2026-12-04' AS fi, NULL AS ff, 'Gendarmeria Nacional' AS c, '3764-501060' AS t, 1 AS a UNION ALL
    SELECT 'CTR-061' AS nc, 'Pavimentacion San Alberto' AS n, 'San Alberto, Posadas, Misiones' AS d, 'Pavimentacion de obra en San Alberto, Posadas.' AS de, '2026-01-05' AS fi, 2027-07-20 AS ff, 'Policia de Misiones' AS c, '3764-501061' AS t, 1 AS a UNION ALL
    SELECT 'CTR-062' AS nc, 'Construccion San Roque' AS n, 'Av. Cabred 162, Obera' AS d, 'Construccion de obra en San Roque, Obera.' AS de, '2026-02-06' AS fi, 2026-08-21 AS ff, 'Bomberos Voluntarios' AS c, '3764-501062' AS t, 1 AS a UNION ALL
    SELECT 'CTR-063' AS nc, 'Refaccion Bicentenario' AS n, 'Av. Trincheras de San Jose 163, Eldorado' AS d, 'Refaccion de obra en Bicentenario, Eldorado.' AS de, '2026-03-07' AS fi, 2027-09-22 AS ff, 'Hospital Escuela' AS c, '3764-501063' AS t, 1 AS a UNION ALL
    SELECT 'CTR-064' AS nc, 'Ampliacion Nuestro Señora' AS n, 'Av. Eva Peron 164, Garupa' AS d, 'Ampliacion de obra en Nuestro Señora, Garupa.' AS de, '2026-04-08' AS fi, NULL AS ff, 'Ente Regulador' AS c, '3764-501064' AS t, 1 AS a UNION ALL
    SELECT 'CTR-065' AS nc, 'Cordon Cuneta El Porvenir' AS n, 'El Porvenir, Apóstoles, Misiones' AS d, 'Cordon Cuneta de obra en El Porvenir, Apóstoles.' AS de, '2026-05-09' AS fi, 2027-11-24 AS ff, 'Archivo General' AS c, '3764-501065' AS t, 1 AS a UNION ALL
    SELECT 'CTR-066' AS nc, 'Veredas 120 Viviendas' AS n, '120 Viviendas, Puerto Iguazu, Misiones' AS d, 'Veredas de obra en 120 Viviendas, Puerto Iguazu.' AS de, '2026-06-10' AS fi, 2026-12-25 AS ff, 'Ministerio de Educacion' AS c, '3764-501066' AS t, 1 AS a UNION ALL
    SELECT 'CTR-067' AS nc, 'Desagues Santa Ana' AS n, 'Santa Ana, Montecarlo, Misiones' AS d, 'Desagues de obra en Santa Ana, Montecarlo.' AS de, '2026-07-11' AS fi, 2027-01-26 AS ff, 'Municipalidad de Montecarlo' AS c, '3764-501067' AS t, 1 AS a UNION ALL
    SELECT 'CTR-068' AS nc, 'Iluminacion Los Cedros' AS n, 'Los Cedros, San Ignacio, Misiones' AS d, 'Iluminacion de obra en Los Cedros, San Ignacio.' AS de, '2026-08-12' AS fi, NULL AS ff, 'IPRODHA' AS c, '3764-501068' AS t, 1 AS a UNION ALL
    SELECT 'CTR-069' AS nc, 'Red de Agua Barrio Norte' AS n, 'Barrio Norte, Jardin America, Misiones' AS d, 'Red de Agua de obra en Barrio Norte, Jardin America.' AS de, '2026-09-13' AS fi, 2027-03-28 AS ff, 'Vialidad Provincial' AS c, '3764-501069' AS t, 1 AS a UNION ALL
    SELECT 'CTR-070' AS nc, 'Red Cloacal Barrio Sur' AS n, 'Barrio Sur, San Pedro, Misiones' AS d, 'Red Cloacal de obra en Barrio Sur, San Pedro.' AS de, '2026-10-14' AS fi, 2026-04-01 AS ff, 'SAMSA' AS c, '3764-501070' AS t, 1 AS a UNION ALL
    SELECT 'CTR-071' AS nc, 'Bacheo Villa Cabello' AS n, 'Villa Cabello, Aristobulo del Valle, Misiones' AS d, 'Bacheo de obra en Villa Cabello, Aristobulo del Valle.' AS de, '2026-11-15' AS fi, 2027-05-02 AS ff, 'Consejo General de Educacion' AS c, '3764-501071' AS t, 1 AS a UNION ALL
    SELECT 'CTR-072' AS nc, 'Repavimentacion Itaembe Guazu' AS n, 'Itaembe Guazu, Cerro Azul, Misiones' AS d, 'Repavimentacion de obra en Itaembe Guazu, Cerro Azul.' AS de, '2026-12-16' AS fi, NULL AS ff, 'Ministerio de Salud' AS c, '3764-501072' AS t, 1 AS a UNION ALL
    SELECT 'CTR-073' AS nc, 'Defensas Miguel Lanus' AS n, 'Miguel Lanus, Campo Grande, Misiones' AS d, 'Defensas de obra en Miguel Lanus, Campo Grande.' AS de, '2026-01-17' AS fi, 2027-07-04 AS ff, 'Poder Judicial' AS c, '3764-501073' AS t, 1 AS a UNION ALL
    SELECT 'CTR-074' AS nc, 'Puesta en valor Santa Rita' AS n, 'Santa Rita, San Vicente, Misiones' AS d, 'Puesta en valor de obra en Santa Rita, San Vicente.' AS de, '2026-02-18' AS fi, 2026-08-05 AS ff, 'Ministerio de Gobierno' AS c, '3764-501074' AS t, 1 AS a UNION ALL
    SELECT 'CTR-075' AS nc, 'Remodelacion Libertad' AS n, 'Libertad, Puerto Rico, Misiones' AS d, 'Remodelacion de obra en Libertad, Puerto Rico.' AS de, '2026-03-19' AS fi, 2027-09-06 AS ff, 'Direccion de Catastro' AS c, '3764-501075' AS t, 1 AS a UNION ALL
    SELECT 'CTR-076' AS nc, 'Pavimentacion Fatima' AS n, 'Fatima, Posadas, Misiones' AS d, 'Pavimentacion de obra en Fatima, Posadas.' AS de, '2026-04-20' AS fi, NULL AS ff, 'EBY' AS c, '3764-501076' AS t, 1 AS a UNION ALL
    SELECT 'CTR-077' AS nc, 'Construccion Los Lapachos' AS n, 'Av. Bustamante 177, Obera' AS d, 'Construccion de obra en Los Lapachos, Obera.' AS de, '2026-05-21' AS fi, 2027-11-08 AS ff, 'AFIP' AS c, '3764-501077' AS t, 1 AS a UNION ALL
    SELECT 'CTR-078' AS nc, 'Refaccion San Isidro' AS n, 'Av. Marconi 178, Eldorado' AS d, 'Refaccion de obra en San Isidro, Eldorado.' AS de, '2026-06-22' AS fi, 2026-12-09 AS ff, 'Ministerio de Cultura' AS c, '3764-501078' AS t, 1 AS a UNION ALL
    SELECT 'CTR-079' AS nc, 'Ampliacion Las Dolores' AS n, 'Av. López Torres 179, Garupa' AS d, 'Ampliacion de obra en Las Dolores, Garupa.' AS de, '2026-07-23' AS fi, 2027-01-10 AS ff, 'Ministerio de Desarrollo Social' AS c, '3764-501079' AS t, 1 AS a UNION ALL
    SELECT 'CTR-080' AS nc, 'Cordon Cuneta Villa Urquiza' AS n, 'Villa Urquiza, Apóstoles, Misiones' AS d, 'Cordon Cuneta de obra en Villa Urquiza, Apóstoles.' AS de, '2026-08-24' AS fi, NULL AS ff, 'Parque del Conocimiento' AS c, '3764-501080' AS t, 1 AS a UNION ALL
    SELECT 'CTR-081' AS nc, 'Veredas San Marcos' AS n, 'San Marcos, Puerto Iguazu, Misiones' AS d, 'Veredas de obra en San Marcos, Puerto Iguazu.' AS de, '2026-09-25' AS fi, 2027-03-12 AS ff, 'Correo Argentino' AS c, '3764-501081' AS t, 1 AS a UNION ALL
    SELECT 'CTR-082' AS nc, 'Desagues 508' AS n, '508, Montecarlo, Misiones' AS d, 'Desagues de obra en 508, Montecarlo.' AS de, '2026-10-26' AS fi, 2026-04-13 AS ff, 'Gendarmeria Nacional' AS c, '3764-501082' AS t, 1 AS a UNION ALL
    SELECT 'CTR-083' AS nc, 'Iluminacion Sesquicentenario' AS n, 'Sesquicentenario, San Ignacio, Misiones' AS d, 'Iluminacion de obra en Sesquicentenario, San Ignacio.' AS de, '2026-11-27' AS fi, 2027-05-14 AS ff, 'Policia de Misiones' AS c, '3764-501083' AS t, 1 AS a UNION ALL
    SELECT 'CTR-084' AS nc, 'Red de Agua Aeroclub' AS n, 'Aeroclub, Jardin America, Misiones' AS d, 'Red de Agua de obra en Aeroclub, Jardin America.' AS de, '2026-12-28' AS fi, NULL AS ff, 'Bomberos Voluntarios' AS c, '3764-501084' AS t, 1 AS a UNION ALL
    SELECT 'CTR-085' AS nc, 'Red Cloacal Prosol' AS n, 'Prosol, San Pedro, Misiones' AS d, 'Red Cloacal de obra en Prosol, San Pedro.' AS de, '2026-01-01' AS fi, 2027-07-16 AS ff, 'Hospital Escuela' AS c, '3764-501085' AS t, 1 AS a UNION ALL
    SELECT 'CTR-086' AS nc, 'Bacheo Itaembe Mini' AS n, 'Itaembe Mini, Aristobulo del Valle, Misiones' AS d, 'Bacheo de obra en Itaembe Mini, Aristobulo del Valle.' AS de, '2026-02-02' AS fi, 2026-08-17 AS ff, 'Ente Regulador' AS c, '3764-501086' AS t, 1 AS a UNION ALL
    SELECT 'CTR-087' AS nc, 'Repavimentacion Los Oleros' AS n, 'Los Oleros, Cerro Azul, Misiones' AS d, 'Repavimentacion de obra en Los Oleros, Cerro Azul.' AS de, '2026-03-03' AS fi, 2027-09-18 AS ff, 'Archivo General' AS c, '3764-501087' AS t, 1 AS a UNION ALL
    SELECT 'CTR-088' AS nc, 'Defensas Santa Helena' AS n, 'Santa Helena, Campo Grande, Misiones' AS d, 'Defensas de obra en Santa Helena, Campo Grande.' AS de, '2026-04-04' AS fi, NULL AS ff, 'Ministerio de Educacion' AS c, '3764-501088' AS t, 1 AS a UNION ALL
    SELECT 'CTR-089' AS nc, 'Puesta en valor Las Rosas' AS n, 'Las Rosas, San Vicente, Misiones' AS d, 'Puesta en valor de obra en Las Rosas, San Vicente.' AS de, '2026-05-05' AS fi, 2027-11-20 AS ff, 'Municipalidad de San Vicente' AS c, '3764-501089' AS t, 1 AS a UNION ALL
    SELECT 'CTR-090' AS nc, 'Remodelacion Kennedy' AS n, 'Kennedy, Puerto Rico, Misiones' AS d, 'Remodelacion de obra en Kennedy, Puerto Rico.' AS de, '2026-06-06' AS fi, 2026-12-21 AS ff, 'IPRODHA' AS c, '3764-501090' AS t, 1 AS a UNION ALL
    SELECT 'CTR-091' AS nc, 'Pavimentacion 20 de Junio' AS n, '20 de Junio, Posadas, Misiones' AS d, 'Pavimentacion de obra en 20 de Junio, Posadas.' AS de, '2026-07-07' AS fi, 2027-01-22 AS ff, 'Vialidad Provincial' AS c, '3764-501091' AS t, 1 AS a UNION ALL
    SELECT 'CTR-092' AS nc, 'Construccion A4' AS n, 'Av. Cabred 192, Obera' AS d, 'Construccion de obra en A4, Obera.' AS de, '2026-08-08' AS fi, NULL AS ff, 'SAMSA' AS c, '3764-501092' AS t, 1 AS a UNION ALL
    SELECT 'CTR-093' AS nc, 'Refaccion Yacyreta' AS n, 'Av. Trincheras de San Jose 193, Eldorado' AS d, 'Refaccion de obra en Yacyreta, Eldorado.' AS de, '2026-09-09' AS fi, 2027-03-24 AS ff, 'Consejo General de Educacion' AS c, '3764-501093' AS t, 1 AS a UNION ALL
    SELECT 'CTR-094' AS nc, 'Ampliacion 25 de Mayo' AS n, 'Av. Eva Peron 194, Garupa' AS d, 'Ampliacion de obra en 25 de Mayo, Garupa.' AS de, '2026-10-10' AS fi, 2026-04-25 AS ff, 'Ministerio de Salud' AS c, '3764-501094' AS t, 1 AS a UNION ALL
    SELECT 'CTR-095' AS nc, 'Cordon Cuneta San Alberto' AS n, 'San Alberto, Apóstoles, Misiones' AS d, 'Cordon Cuneta de obra en San Alberto, Apóstoles.' AS de, '2026-11-11' AS fi, 2027-05-26 AS ff, 'Poder Judicial' AS c, '3764-501095' AS t, 1 AS a UNION ALL
    SELECT 'CTR-096' AS nc, 'Veredas San Roque' AS n, 'San Roque, Puerto Iguazu, Misiones' AS d, 'Veredas de obra en San Roque, Puerto Iguazu.' AS de, '2026-12-12' AS fi, NULL AS ff, 'Ministerio de Gobierno' AS c, '3764-501096' AS t, 1 AS a UNION ALL
    SELECT 'CTR-097' AS nc, 'Desagues Bicentenario' AS n, 'Bicentenario, Montecarlo, Misiones' AS d, 'Desagues de obra en Bicentenario, Montecarlo.' AS de, '2026-01-13' AS fi, 2027-07-28 AS ff, 'Direccion de Catastro' AS c, '3764-501097' AS t, 1 AS a UNION ALL
    SELECT 'CTR-098' AS nc, 'Iluminacion Nuestro Señora' AS n, 'Nuestro Señora, San Ignacio, Misiones' AS d, 'Iluminacion de obra en Nuestro Señora, San Ignacio.' AS de, '2026-02-14' AS fi, 2026-08-01 AS ff, 'EBY' AS c, '3764-501098' AS t, 1 AS a UNION ALL
    SELECT 'CTR-099' AS nc, 'Red de Agua El Porvenir' AS n, 'El Porvenir, Jardin America, Misiones' AS d, 'Red de Agua de obra en El Porvenir, Jardin America.' AS de, '2026-03-15' AS fi, 2027-09-02 AS ff, 'AFIP' AS c, '3764-501099' AS t, 1 AS a UNION ALL
    SELECT 'CTR-100' AS nc, 'Red Cloacal 120 Viviendas' AS n, '120 Viviendas, San Pedro, Misiones' AS d, 'Red Cloacal de obra en 120 Viviendas, San Pedro.' AS de, '2026-04-16' AS fi, NULL AS ff, 'Ministerio de Cultura' AS c, '3764-501100' AS t, 1 AS a UNION ALL
    SELECT 'CTR-101' AS nc, 'Bacheo Santa Ana' AS n, 'Santa Ana, Aristobulo del Valle, Misiones' AS d, 'Bacheo de obra en Santa Ana, Aristobulo del Valle.' AS de, '2026-05-17' AS fi, 2027-11-04 AS ff, 'Ministerio de Desarrollo Social' AS c, '3764-501101' AS t, 1 AS a UNION ALL
    SELECT 'CTR-102' AS nc, 'Repavimentacion Los Cedros' AS n, 'Los Cedros, Cerro Azul, Misiones' AS d, 'Repavimentacion de obra en Los Cedros, Cerro Azul.' AS de, '2026-06-18' AS fi, 2026-12-05 AS ff, 'Parque del Conocimiento' AS c, '3764-501102' AS t, 1 AS a UNION ALL
    SELECT 'CTR-103' AS nc, 'Defensas Barrio Norte' AS n, 'Barrio Norte, Campo Grande, Misiones' AS d, 'Defensas de obra en Barrio Norte, Campo Grande.' AS de, '2026-07-19' AS fi, 2027-01-06 AS ff, 'Correo Argentino' AS c, '3764-501103' AS t, 1 AS a UNION ALL
    SELECT 'CTR-104' AS nc, 'Puesta en valor Barrio Sur' AS n, 'Barrio Sur, San Vicente, Misiones' AS d, 'Puesta en valor de obra en Barrio Sur, San Vicente.' AS de, '2026-08-20' AS fi, NULL AS ff, 'Gendarmeria Nacional' AS c, '3764-501104' AS t, 1 AS a UNION ALL
    SELECT 'CTR-105' AS nc, 'Remodelacion Villa Cabello' AS n, 'Villa Cabello, Puerto Rico, Misiones' AS d, 'Remodelacion de obra en Villa Cabello, Puerto Rico.' AS de, '2026-09-21' AS fi, 2027-03-08 AS ff, 'Policia de Misiones' AS c, '3764-501105' AS t, 1 AS a
) t
ON DUPLICATE KEY UPDATE
    nombre = VALUES(nombre),
    direccion = VALUES(direccion),
    descripcion = VALUES(descripcion),
    fecha_inicio = VALUES(fecha_inicio),
    fecha_fin = VALUES(fecha_fin),
    nombre_cliente = VALUES(nombre_cliente),
    telefono_cliente = VALUES(telefono_cliente),
    activo = VALUES(activo);

-- ===== OBREROS (110) =====
INSERT INTO obreros (nombre, apellido, documento, telefono, fecha_contratacion, fecha_fin, cargo, activo)
SELECT * FROM (
    SELECT 'Luis' AS n, 'Benitez' AS a, '40000000' AS d, '3764-600100' AS t, '2025-01-01' AS fc, NULL AS ff, 'Peon' AS c, 1 AS ac UNION ALL
    SELECT 'Carlos' AS n, 'Gomez' AS a, '40011112' AS d, '3764-600101' AS t, '2026-04-08' AS fc, 2027-07-15 AS ff, 'Peon' AS c, 1 AS ac UNION ALL
    SELECT 'Miguel' AS n, 'Rojas' AS a, '40022224' AS d, '3764-600102' AS t, '2025-07-15' AS fc, 2026-08-16 AS ff, 'Peon' AS c, 1 AS ac UNION ALL
    SELECT 'Jorge' AS n, 'Ferreyra' AS a, '40033336' AS d, '3764-600103' AS t, '2026-10-22' AS fc, 2027-09-17 AS ff, 'Albanil' AS c, 1 AS ac UNION ALL
    SELECT 'Ramon' AS n, 'Acosta' AS a, '40044448' AS d, '3764-600104' AS t, '2025-01-01' AS fc, 2026-10-18 AS ff, 'Albanil' AS c, 1 AS ac UNION ALL
    SELECT 'Pedro' AS n, 'Insaurralde' AS a, '40055560' AS d, '3764-600105' AS t, '2026-04-08' AS fc, 2027-11-19 AS ff, 'Albanil' AS c, 1 AS ac UNION ALL
    SELECT 'Juan' AS n, 'Martinez' AS a, '40066672' AS d, '3764-600106' AS t, '2025-07-15' AS fc, 2026-12-20 AS ff, 'Electricista' AS c, 1 AS ac UNION ALL
    SELECT 'Roberto' AS n, 'Gonzalez' AS a, '40077784' AS d, '3764-600107' AS t, '2026-10-22' AS fc, NULL AS ff, 'Electricista' AS c, 1 AS ac UNION ALL
    SELECT 'Oscar' AS n, 'Vargas' AS a, '40088896' AS d, '3764-600108' AS t, '2025-01-01' AS fc, 2026-02-22 AS ff, 'Plomero' AS c, 1 AS ac UNION ALL
    SELECT 'Hector' AS n, 'Sosa' AS a, '40100008' AS d, '3764-600109' AS t, '2026-04-08' AS fc, 2027-03-23 AS ff, 'Plomero' AS c, 1 AS ac UNION ALL
    SELECT 'Daniel' AS n, 'Romero' AS a, '40111120' AS d, '3764-600110' AS t, '2025-07-15' AS fc, 2026-04-24 AS ff, 'Pintor' AS c, 1 AS ac UNION ALL
    SELECT 'Sergio' AS n, 'Torres' AS a, '40122232' AS d, '3764-600111' AS t, '2026-10-22' AS fc, 2027-05-25 AS ff, 'Pintor' AS c, 1 AS ac UNION ALL
    SELECT 'Marcelo' AS n, 'Ramirez' AS a, '40133344' AS d, '3764-600112' AS t, '2025-01-01' AS fc, 2026-06-26 AS ff, 'Carpintero' AS c, 1 AS ac UNION ALL
    SELECT 'Gustavo' AS n, 'Flores' AS a, '40144456' AS d, '3764-600113' AS t, '2026-04-08' AS fc, 2027-07-27 AS ff, 'Carpintero' AS c, 1 AS ac UNION ALL
    SELECT 'Alberto' AS n, 'Diaz' AS a, '40155568' AS d, '3764-600114' AS t, '2025-07-15' AS fc, NULL AS ff, 'Soldador' AS c, 1 AS ac UNION ALL
    SELECT 'Ricardo' AS n, 'Pereyra' AS a, '40166680' AS d, '3764-600115' AS t, '2026-10-22' AS fc, 2027-09-01 AS ff, 'Soldador' AS c, 1 AS ac UNION ALL
    SELECT 'Alejandro' AS n, 'Ojeda' AS a, '40177792' AS d, '3764-600116' AS t, '2025-01-01' AS fc, 2026-10-02 AS ff, 'Operador de maquinaria' AS c, 1 AS ac UNION ALL
    SELECT 'Fernando' AS n, 'Rivero' AS a, '40188904' AS d, '3764-600117' AS t, '2026-04-08' AS fc, 2027-11-03 AS ff, 'Operador de maquinaria' AS c, 1 AS ac UNION ALL
    SELECT 'Javier' AS n, 'Maidana' AS a, '40200016' AS d, '3764-600118' AS t, '2025-07-15' AS fc, 2026-12-04 AS ff, 'Capataz' AS c, 1 AS ac UNION ALL
    SELECT 'Cristian' AS n, 'Britez' AS a, '40211128' AS d, '3764-600119' AS t, '2026-10-22' AS fc, 2027-01-05 AS ff, 'Capataz' AS c, 1 AS ac UNION ALL
    SELECT 'Victor' AS n, 'Lescano' AS a, '40222240' AS d, '3764-600120' AS t, '2025-01-01' AS fc, 2026-02-06 AS ff, 'Peon' AS c, 1 AS ac UNION ALL
    SELECT 'Hugo' AS n, 'Aguirre' AS a, '40233352' AS d, '3764-600121' AS t, '2026-04-08' AS fc, NULL AS ff, 'Peon' AS c, 1 AS ac UNION ALL
    SELECT 'Diego' AS n, 'Juarez' AS a, '40244464' AS d, '3764-600122' AS t, '2025-07-15' AS fc, 2026-04-08 AS ff, 'Peon' AS c, 1 AS ac UNION ALL
    SELECT 'Mario' AS n, 'Coronel' AS a, '40255576' AS d, '3764-600123' AS t, '2026-10-22' AS fc, 2027-05-09 AS ff, 'Albanil' AS c, 1 AS ac UNION ALL
    SELECT 'Pablo' AS n, 'Silva' AS a, '40266688' AS d, '3764-600124' AS t, '2025-01-01' AS fc, 2026-06-10 AS ff, 'Albanil' AS c, 1 AS ac UNION ALL
    SELECT 'Claudio' AS n, 'Luna' AS a, '40277800' AS d, '3764-600125' AS t, '2026-04-08' AS fc, 2027-07-11 AS ff, 'Albanil' AS c, 1 AS ac UNION ALL
    SELECT 'Dario' AS n, 'Ibarra' AS a, '40288912' AS d, '3764-600126' AS t, '2025-07-15' AS fc, 2026-08-12 AS ff, 'Electricista' AS c, 1 AS ac UNION ALL
    SELECT 'Gabriel' AS n, 'Villalba' AS a, '40300024' AS d, '3764-600127' AS t, '2026-10-22' AS fc, 2027-09-13 AS ff, 'Electricista' AS c, 1 AS ac UNION ALL
    SELECT 'Fabian' AS n, 'Montiel' AS a, '40311136' AS d, '3764-600128' AS t, '2025-01-01' AS fc, NULL AS ff, 'Plomero' AS c, 1 AS ac UNION ALL
    SELECT 'Raul' AS n, 'Gimenez' AS a, '40322248' AS d, '3764-600129' AS t, '2026-04-08' AS fc, 2027-11-15 AS ff, 'Plomero' AS c, 1 AS ac UNION ALL
    SELECT 'Adrian' AS n, 'Galeano' AS a, '40333360' AS d, '3764-600130' AS t, '2025-07-15' AS fc, 2026-12-16 AS ff, 'Pintor' AS c, 1 AS ac UNION ALL
    SELECT 'Walter' AS n, 'Arguello' AS a, '40344472' AS d, '3764-600131' AS t, '2026-10-22' AS fc, 2027-01-17 AS ff, 'Pintor' AS c, 1 AS ac UNION ALL
    SELECT 'Lucas' AS n, 'Avalos' AS a, '40355584' AS d, '3764-600132' AS t, '2025-01-01' AS fc, 2026-02-18 AS ff, 'Carpintero' AS c, 1 AS ac UNION ALL
    SELECT 'Martin' AS n, 'Cabrera' AS a, '40366696' AS d, '3764-600133' AS t, '2026-04-08' AS fc, 2027-03-19 AS ff, 'Carpintero' AS c, 1 AS ac UNION ALL
    SELECT 'Nicolas' AS n, 'Duarte' AS a, '40377808' AS d, '3764-600134' AS t, '2025-07-15' AS fc, 2026-04-20 AS ff, 'Soldador' AS c, 1 AS ac UNION ALL
    SELECT 'Esteban' AS n, 'Bordon' AS a, '40388920' AS d, '3764-600135' AS t, '2026-10-22' AS fc, NULL AS ff, 'Soldador' AS c, 1 AS ac UNION ALL
    SELECT 'Federico' AS n, 'Velazquez' AS a, '40400032' AS d, '3764-600136' AS t, '2025-01-01' AS fc, 2026-06-22 AS ff, 'Operador de maquinaria' AS c, 1 AS ac UNION ALL
    SELECT 'Ignacio' AS n, 'Cardozo' AS a, '40411144' AS d, '3764-600137' AS t, '2026-04-08' AS fc, 2027-07-23 AS ff, 'Operador de maquinaria' AS c, 1 AS ac UNION ALL
    SELECT 'Leonardo' AS n, 'Bogado' AS a, '40422256' AS d, '3764-600138' AS t, '2025-07-15' AS fc, 2026-08-24 AS ff, 'Capataz' AS c, 1 AS ac UNION ALL
    SELECT 'Sebastian' AS n, 'Almada' AS a, '40433368' AS d, '3764-600139' AS t, '2026-10-22' AS fc, 2027-09-25 AS ff, 'Capataz' AS c, 1 AS ac UNION ALL
    SELECT 'Emiliano' AS n, 'Molina' AS a, '40444480' AS d, '3764-600140' AS t, '2025-01-01' AS fc, 2026-10-26 AS ff, 'Peon' AS c, 1 AS ac UNION ALL
    SELECT 'Matias' AS n, 'Espinoza' AS a, '40455592' AS d, '3764-600141' AS t, '2026-04-08' AS fc, 2027-11-27 AS ff, 'Peon' AS c, 1 AS ac UNION ALL
    SELECT 'Ezequiel' AS n, 'Arias' AS a, '40466704' AS d, '3764-600142' AS t, '2025-07-15' AS fc, NULL AS ff, 'Peon' AS c, 1 AS ac UNION ALL
    SELECT 'Felipe' AS n, 'Melgarejo' AS a, '40477816' AS d, '3764-600143' AS t, '2026-10-22' AS fc, 2027-01-01 AS ff, 'Albanil' AS c, 1 AS ac UNION ALL
    SELECT 'Andres' AS n, 'Baez' AS a, '40488928' AS d, '3764-600144' AS t, '2025-01-01' AS fc, 2026-02-02 AS ff, 'Albanil' AS c, 1 AS ac UNION ALL
    SELECT 'Ruben' AS n, 'Guerrero' AS a, '40500040' AS d, '3764-600145' AS t, '2026-04-08' AS fc, 2027-03-03 AS ff, 'Albanil' AS c, 1 AS ac UNION ALL
    SELECT 'Cesar' AS n, 'Ortiz' AS a, '40511152' AS d, '3764-600146' AS t, '2025-07-15' AS fc, 2026-04-04 AS ff, 'Electricista' AS c, 1 AS ac UNION ALL
    SELECT 'Hernan' AS n, 'Burgos' AS a, '40522264' AS d, '3764-600147' AS t, '2026-10-22' AS fc, 2027-05-05 AS ff, 'Electricista' AS c, 1 AS ac UNION ALL
    SELECT 'Ivan' AS n, 'Caceres' AS a, '40533376' AS d, '3764-600148' AS t, '2025-01-01' AS fc, 2026-06-06 AS ff, 'Plomero' AS c, 1 AS ac UNION ALL
    SELECT 'Marcos' AS n, 'Rolon' AS a, '40544488' AS d, '3764-600149' AS t, '2026-04-08' AS fc, NULL AS ff, 'Plomero' AS c, 1 AS ac UNION ALL
    SELECT 'Damian' AS n, 'Salinas' AS a, '40555600' AS d, '3764-600150' AS t, '2025-07-15' AS fc, 2026-08-08 AS ff, 'Pintor' AS c, 1 AS ac UNION ALL
    SELECT 'Nestor' AS n, 'Barrios' AS a, '40566712' AS d, '3764-600151' AS t, '2026-10-22' AS fc, 2027-09-09 AS ff, 'Pintor' AS c, 1 AS ac UNION ALL
    SELECT 'Omar' AS n, 'Morinigo' AS a, '40577824' AS d, '3764-600152' AS t, '2025-01-01' AS fc, 2026-10-10 AS ff, 'Carpintero' AS c, 1 AS ac UNION ALL
    SELECT 'Julio' AS n, 'Fernandez' AS a, '40588936' AS d, '3764-600153' AS t, '2026-04-08' AS fc, 2027-11-11 AS ff, 'Carpintero' AS c, 1 AS ac UNION ALL
    SELECT 'Antonio' AS n, 'Vera' AS a, '40600048' AS d, '3764-600154' AS t, '2025-07-15' AS fc, 2026-12-12 AS ff, 'Soldador' AS c, 1 AS ac UNION ALL
    SELECT 'Anibal' AS n, 'Leguizamon' AS a, '40611160' AS d, '3764-600155' AS t, '2026-10-22' AS fc, 2027-01-13 AS ff, 'Soldador' AS c, 1 AS ac UNION ALL
    SELECT 'Luciano' AS n, 'Figueredo' AS a, '40622272' AS d, '3764-600156' AS t, '2025-01-01' AS fc, NULL AS ff, 'Operador de maquinaria' AS c, 1 AS ac UNION ALL
    SELECT 'Gonzalo' AS n, 'Amarilla' AS a, '40633384' AS d, '3764-600157' AS t, '2026-04-08' AS fc, 2027-03-15 AS ff, 'Operador de maquinaria' AS c, 1 AS ac UNION ALL
    SELECT 'Rodrigo' AS n, 'Benítez' AS a, '40644496' AS d, '3764-600158' AS t, '2025-07-15' AS fc, 2026-04-16 AS ff, 'Capataz' AS c, 1 AS ac UNION ALL
    SELECT 'Leandro' AS n, 'Garcia' AS a, '40655608' AS d, '3764-600159' AS t, '2026-10-22' AS fc, 2027-05-17 AS ff, 'Capataz' AS c, 1 AS ac UNION ALL
    SELECT 'Franco' AS n, 'Perez' AS a, '40666720' AS d, '3764-600160' AS t, '2025-01-01' AS fc, 2026-06-18 AS ff, 'Peon' AS c, 1 AS ac UNION ALL
    SELECT 'Alan' AS n, 'Gutierrez' AS a, '40677832' AS d, '3764-600161' AS t, '2026-04-08' AS fc, 2027-07-19 AS ff, 'Peon' AS c, 1 AS ac UNION ALL
    SELECT 'Brian' AS n, 'Medina' AS a, '40688944' AS d, '3764-600162' AS t, '2025-07-15' AS fc, 2026-08-20 AS ff, 'Peon' AS c, 1 AS ac UNION ALL
    SELECT 'Jonathan' AS n, 'Moreno' AS a, '40700056' AS d, '3764-600163' AS t, '2026-10-22' AS fc, NULL AS ff, 'Albanil' AS c, 1 AS ac UNION ALL
    SELECT 'Maximiliano' AS n, 'Alvarez' AS a, '40711168' AS d, '3764-600164' AS t, '2025-01-01' AS fc, 2026-10-22 AS ff, 'Albanil' AS c, 1 AS ac UNION ALL
    SELECT 'Guillermo' AS n, 'Castillo' AS a, '40722280' AS d, '3764-600165' AS t, '2026-04-08' AS fc, 2027-11-23 AS ff, 'Albanil' AS c, 1 AS ac UNION ALL
    SELECT 'Ernesto' AS n, 'Zarate' AS a, '40733392' AS d, '3764-600166' AS t, '2025-07-15' AS fc, 2026-12-24 AS ff, 'Electricista' AS c, 1 AS ac UNION ALL
    SELECT 'Horacio' AS n, 'Paredes' AS a, '40744504' AS d, '3764-600167' AS t, '2026-10-22' AS fc, 2027-01-25 AS ff, 'Electricista' AS c, 1 AS ac UNION ALL
    SELECT 'Enrique' AS n, 'Godoy' AS a, '40755616' AS d, '3764-600168' AS t, '2025-01-01' AS fc, 2026-02-26 AS ff, 'Plomero' AS c, 1 AS ac UNION ALL
    SELECT 'Norberto' AS n, 'Bareiro' AS a, '40766728' AS d, '3764-600169' AS t, '2026-04-08' AS fc, 2027-03-27 AS ff, 'Plomero' AS c, 1 AS ac UNION ALL
    SELECT 'Patricio' AS n, 'Candia' AS a, '40777840' AS d, '3764-600170' AS t, '2025-07-15' AS fc, NULL AS ff, 'Pintor' AS c, 1 AS ac UNION ALL
    SELECT 'Eduardo' AS n, 'Benegas' AS a, '40788952' AS d, '3764-600171' AS t, '2026-10-22' AS fc, 2027-05-01 AS ff, 'Pintor' AS c, 1 AS ac UNION ALL
    SELECT 'Arturo' AS n, 'Quintana' AS a, '40800064' AS d, '3764-600172' AS t, '2025-01-01' AS fc, 2026-06-02 AS ff, 'Carpintero' AS c, 1 AS ac UNION ALL
    SELECT 'Rogelio' AS n, 'Rios' AS a, '40811176' AS d, '3764-600173' AS t, '2026-04-08' AS fc, 2027-07-03 AS ff, 'Carpintero' AS c, 1 AS ac UNION ALL
    SELECT 'Domingo' AS n, 'Maciel' AS a, '40822288' AS d, '3764-600174' AS t, '2025-07-15' AS fc, 2026-08-04 AS ff, 'Soldador' AS c, 1 AS ac UNION ALL
    SELECT 'Ismael' AS n, 'Colman' AS a, '40833400' AS d, '3764-600175' AS t, '2026-10-22' AS fc, 2027-09-05 AS ff, 'Soldador' AS c, 1 AS ac UNION ALL
    SELECT 'Facundo' AS n, 'Villagra' AS a, '40844512' AS d, '3764-600176' AS t, '2025-01-01' AS fc, 2026-10-06 AS ff, 'Operador de maquinaria' AS c, 1 AS ac UNION ALL
    SELECT 'Mauricio' AS n, 'Almiron' AS a, '40855624' AS d, '3764-600177' AS t, '2026-04-08' AS fc, NULL AS ff, 'Operador de maquinaria' AS c, 1 AS ac UNION ALL
    SELECT 'German' AS n, 'Segovia' AS a, '40866736' AS d, '3764-600178' AS t, '2025-07-15' AS fc, 2026-12-08 AS ff, 'Capataz' AS c, 1 AS ac UNION ALL
    SELECT 'Emanuel' AS n, 'Escobar' AS a, '40877848' AS d, '3764-600179' AS t, '2026-10-22' AS fc, 2027-01-09 AS ff, 'Capataz' AS c, 1 AS ac UNION ALL
    SELECT 'Alfredo' AS n, 'Mereles' AS a, '40888960' AS d, '3764-600180' AS t, '2025-01-01' AS fc, 2026-02-10 AS ff, 'Peon' AS c, 1 AS ac UNION ALL
    SELECT 'Osvaldo' AS n, 'Florentin' AS a, '40900072' AS d, '3764-600181' AS t, '2026-04-08' AS fc, 2027-03-11 AS ff, 'Peon' AS c, 1 AS ac UNION ALL
    SELECT 'Elias' AS n, 'Ayala' AS a, '40911184' AS d, '3764-600182' AS t, '2025-07-15' AS fc, 2026-04-12 AS ff, 'Peon' AS c, 1 AS ac UNION ALL
    SELECT 'Saul' AS n, 'Mendoza' AS a, '40922296' AS d, '3764-600183' AS t, '2026-10-22' AS fc, 2027-05-13 AS ff, 'Albanil' AS c, 1 AS ac UNION ALL
    SELECT 'Rolando' AS n, 'Gauto' AS a, '40933408' AS d, '3764-600184' AS t, '2025-01-01' AS fc, NULL AS ff, 'Albanil' AS c, 1 AS ac UNION ALL
    SELECT 'Teodoro' AS n, 'Centurion' AS a, '40944520' AS d, '3764-600185' AS t, '2026-04-08' AS fc, 2027-07-15 AS ff, 'Albanil' AS c, 1 AS ac UNION ALL
    SELECT 'Celso' AS n, 'Sanchez' AS a, '40955632' AS d, '3764-600186' AS t, '2025-07-15' AS fc, 2026-08-16 AS ff, 'Electricista' AS c, 1 AS ac UNION ALL
    SELECT 'Rufino' AS n, 'Pintos' AS a, '40966744' AS d, '3764-600187' AS t, '2026-10-22' AS fc, 2027-09-17 AS ff, 'Electricista' AS c, 1 AS ac UNION ALL
    SELECT 'Genaro' AS n, 'Olmedo' AS a, '40977856' AS d, '3764-600188' AS t, '2025-01-01' AS fc, 2026-10-18 AS ff, 'Plomero' AS c, 1 AS ac UNION ALL
    SELECT 'Lisandro' AS n, 'Caseres' AS a, '40988968' AS d, '3764-600189' AS t, '2026-04-08' AS fc, 2027-11-19 AS ff, 'Plomero' AS c, 1 AS ac UNION ALL
    SELECT 'Nelson' AS n, 'Ferreiro' AS a, '41000080' AS d, '3764-600190' AS t, '2025-07-15' AS fc, 2026-12-20 AS ff, 'Pintor' AS c, 1 AS ac UNION ALL
    SELECT 'Elvio' AS n, 'Samudio' AS a, '41011192' AS d, '3764-600191' AS t, '2026-10-22' AS fc, NULL AS ff, 'Pintor' AS c, 1 AS ac UNION ALL
    SELECT 'Wilfredo' AS n, 'Escalante' AS a, '41022304' AS d, '3764-600192' AS t, '2025-01-01' AS fc, 2026-02-22 AS ff, 'Carpintero' AS c, 1 AS ac UNION ALL
    SELECT 'Ariel' AS n, 'Galeano' AS a, '41033416' AS d, '3764-600193' AS t, '2026-04-08' AS fc, 2027-03-23 AS ff, 'Carpintero' AS c, 1 AS ac UNION ALL
    SELECT 'Cristobal' AS n, 'Caballero' AS a, '41044528' AS d, '3764-600194' AS t, '2025-07-15' AS fc, 2026-04-24 AS ff, 'Soldador' AS c, 1 AS ac UNION ALL
    SELECT 'Nicanor' AS n, 'Funes' AS a, '41055640' AS d, '3764-600195' AS t, '2026-10-22' AS fc, 2027-05-25 AS ff, 'Soldador' AS c, 1 AS ac UNION ALL
    SELECT 'Estanislao' AS n, 'Bordon' AS a, '41066752' AS d, '3764-600196' AS t, '2025-01-01' AS fc, 2026-06-26 AS ff, 'Operador de maquinaria' AS c, 1 AS ac UNION ALL
    SELECT 'Faustino' AS n, 'Bogado' AS a, '41077864' AS d, '3764-600197' AS t, '2026-04-08' AS fc, 2027-07-27 AS ff, 'Operador de maquinaria' AS c, 1 AS ac UNION ALL
    SELECT 'Evaristo' AS n, 'Saucedo' AS a, '41088976' AS d, '3764-600198' AS t, '2025-07-15' AS fc, NULL AS ff, 'Capataz' AS c, 1 AS ac UNION ALL
    SELECT 'Bartolo' AS n, 'Paiva' AS a, '41100088' AS d, '3764-600199' AS t, '2026-10-22' AS fc, 2027-09-01 AS ff, 'Capataz' AS c, 1 AS ac UNION ALL
    SELECT 'Valentin' AS n, 'Chamorro' AS a, '41111100' AS d, '3764-600200' AS t, '2025-01-01' AS fc, 2026-10-02 AS ff, 'Peon' AS c, 1 AS ac UNION ALL
    SELECT 'Silvio' AS n, 'Ovelar' AS a, '41122212' AS d, '3764-600201' AS t, '2026-04-08' AS fc, 2027-11-03 AS ff, 'Peon' AS c, 1 AS ac UNION ALL
    SELECT 'Ramiro' AS n, 'Arizaga' AS a, '41133324' AS d, '3764-600202' AS t, '2025-07-15' AS fc, 2026-12-04 AS ff, 'Peon' AS c, 1 AS ac UNION ALL
    SELECT 'Santos' AS n, 'Villanueva' AS a, '41144436' AS d, '3764-600203' AS t, '2026-10-22' AS fc, 2027-01-05 AS ff, 'Albanil' AS c, 1 AS ac UNION ALL
    SELECT 'Tomas' AS n, 'Bordon' AS a, '41155548' AS d, '3764-600204' AS t, '2025-01-01' AS fc, 2026-02-06 AS ff, 'Albanil' AS c, 1 AS ac UNION ALL
    SELECT 'Benito' AS n, 'Rolon' AS a, '41166660' AS d, '3764-600205' AS t, '2026-04-08' AS fc, NULL AS ff, 'Albanil' AS c, 1 AS ac UNION ALL
    SELECT 'Milton' AS n, 'Avalos' AS a, '41177772' AS d, '3764-600206' AS t, '2025-07-15' AS fc, 2026-04-08 AS ff, 'Electricista' AS c, 1 AS ac UNION ALL
    SELECT 'Alexis' AS n, 'Silvero' AS a, '41188884' AS d, '3764-600207' AS t, '2026-10-22' AS fc, 2027-05-09 AS ff, 'Electricista' AS c, 1 AS ac UNION ALL
    SELECT 'Kevin' AS n, 'Britez' AS a, '41199996' AS d, '3764-600208' AS t, '2025-01-01' AS fc, 2026-06-10 AS ff, 'Plomero' AS c, 1 AS ac UNION ALL
    SELECT 'Brandon' AS n, 'Irala' AS a, '41211108' AS d, '3764-600209' AS t, '2026-04-08' AS fc, 2027-07-11 AS ff, 'Plomero' AS c, 1 AS ac
) t
ON DUPLICATE KEY UPDATE
    nombre = VALUES(nombre),
    apellido = VALUES(apellido),
    telefono = VALUES(telefono),
    fecha_contratacion = VALUES(fecha_contratacion),
    fecha_fin = VALUES(fecha_fin),
    cargo = VALUES(cargo),
    activo = VALUES(activo);

-- Ajustar estados de contrato: vencidos, por vencer, vigentes
UPDATE obreros SET fecha_fin = DATE_SUB(CURDATE(), INTERVAL (id_obrero * 7 + 1) DAY)  WHERE id_obrero % 7 = 1 AND id_obrero <= 50;
UPDATE obreros SET fecha_fin = DATE_ADD(CURDATE(), INTERVAL (id_obrero * 3 + 1) DAY)  WHERE id_obrero % 7 = 2 AND id_obrero <= 50;
UPDATE obreros SET fecha_fin = DATE_ADD(CURDATE(), INTERVAL (id_obrero * 12 + 90) DAY) WHERE id_obrero % 7 = 3 AND id_obrero <= 50;
UPDATE obreros SET fecha_fin = NULL WHERE id_obrero % 7 = 4 AND id_obrero <= 50;

-- ===== MAQUINARIA (110) =====
INSERT INTO maquinaria (nombre, marca)
SELECT * FROM (
    SELECT 'Retroexcavadora 320D_0' AS n, 'Caterpillar' AS m UNION ALL
    SELECT 'Retroexcavadora JS140_1' AS n, 'JCB' AS m UNION ALL
    SELECT 'Retroexcavadora 430F_2' AS n, 'Caterpillar' AS m UNION ALL
    SELECT 'Retroexcavadora B95C_3' AS n, 'Case' AS m UNION ALL
    SELECT 'Hormigonera H-250_4' AS n, 'Sthilmaq' AS m UNION ALL
    SELECT 'Hormigonera ZO-350_5' AS n, 'Zhongong' AS m UNION ALL
    SELECT 'Hormigonera KZ-400_6' AS n, 'Kamaz' AS m UNION ALL
    SELECT 'Hormigonera SH-500_7' AS n, 'Sthilmaq' AS m UNION ALL
    SELECT 'Compactador CV-90_8' AS n, 'Wacker Neuson' AS m UNION ALL
    SELECT 'Compactador CS44B_9' AS n, 'Caterpillar' AS m UNION ALL
    SELECT 'Compactador BW174_10' AS n, 'Bomag' AS m UNION ALL
    SELECT 'Compactador SD100_11' AS n, 'Dynapac' AS m UNION ALL
    SELECT 'Camion Volcador 6x4_12' AS n, 'Mercedes Benz' AS m UNION ALL
    SELECT 'Camion Volcador 8x4_13' AS n, 'Volvo' AS m UNION ALL
    SELECT 'Camion Volcador FH_14' AS n, 'Volvo' AS m UNION ALL
    SELECT 'Camion Volcador Atego_15' AS n, 'Mercedes Benz' AS m UNION ALL
    SELECT 'Camioneta Hilux_16' AS n, 'Toyota' AS m UNION ALL
    SELECT 'Camioneta Ranger_17' AS n, 'Ford' AS m UNION ALL
    SELECT 'Camioneta Amarok_18' AS n, 'Volkswagen' AS m UNION ALL
    SELECT 'Motoniveladora 140K_19' AS n, 'Caterpillar' AS m UNION ALL
    SELECT 'Motoniveladora G940_20' AS n, 'XCMG' AS m UNION ALL
    SELECT 'Motoniveladora 120M_21' AS n, 'Caterpillar' AS m UNION ALL
    SELECT 'Motoniveladora RG140_22' AS n, 'Sany' AS m UNION ALL
    SELECT 'Topadora D6T_23' AS n, 'Caterpillar' AS m UNION ALL
    SELECT 'Topadora D65EX_24' AS n, 'Komatsu' AS m UNION ALL
    SELECT 'Topadora SD16_25' AS n, 'Shantui' AS m UNION ALL
    SELECT 'Cargador Frontal 966M_26' AS n, 'Caterpillar' AS m UNION ALL
    SELECT 'Cargador Frontal WA380_27' AS n, 'Komatsu' AS m UNION ALL
    SELECT 'Cargador Frontal ZL50GN_28' AS n, 'LiuGong' AS m UNION ALL
    SELECT 'Cargador Frontal 938M_29' AS n, 'Caterpillar' AS m UNION ALL
    SELECT 'Minicargador 246D_30' AS n, 'Caterpillar' AS m UNION ALL
    SELECT 'Minicargador S650_31' AS n, 'Bobcat' AS m UNION ALL
    SELECT 'Minicargador SR200_32' AS n, 'Case' AS m UNION ALL
    SELECT 'Excavadora 320D_33' AS n, 'Caterpillar' AS m UNION ALL
    SELECT 'Excavadora PC200_34' AS n, 'Komatsu' AS m UNION ALL
    SELECT 'Excavadora CX210_35' AS n, 'Case' AS m UNION ALL
    SELECT 'Excavadora EC220_36' AS n, 'Volvo' AS m UNION ALL
    SELECT 'Vibroapisonador AP500_37' AS n, 'Caterpillar' AS m UNION ALL
    SELECT 'Vibroapisonador AB700_38' AS n, 'Bomag' AS m UNION ALL
    SELECT 'Vibroapisonador PG2100_39' AS n, 'Wacker Neuson' AS m UNION ALL
    SELECT 'Grua Telescopica 5500_40' AS n, 'Manitou' AS m UNION ALL
    SELECT 'Grua Telescopica MT732_41' AS n, 'Manitou' AS m UNION ALL
    SELECT 'Grua Telescopica TH627_42' AS n, 'Cat Lift' AS m UNION ALL
    SELECT 'Planta Asfaltica MDM-60_43' AS n, 'Marini' AS m UNION ALL
    SELECT 'Planta Asfaltica TBA-200_44' AS n, 'Ammann' AS m UNION ALL
    SELECT 'Planta Asfaltica SB-160_45' AS n, 'Ciber' AS m UNION ALL
    SELECT 'Pavimentadora AP655_46' AS n, 'Caterpillar' AS m UNION ALL
    SELECT 'Pavimentadora F8W_47' AS n, 'Vogele' AS m UNION ALL
    SELECT 'Pavimentadora DF145_48' AS n, 'Dynapac' AS m UNION ALL
    SELECT 'Rodillo Neumatico PS150_49' AS n, 'Caterpillar' AS m UNION ALL
    SELECT 'Rodillo Neumatico CP24_50' AS n, 'Dynapac' AS m UNION ALL
    SELECT 'Rodillo Tandem CB10_51' AS n, 'Caterpillar' AS m UNION ALL
    SELECT 'Rodillo Tandem HD130_52' AS n, 'Hamm' AS m UNION ALL
    SELECT 'Zanjadora RT450_53' AS n, 'Ditch Witch' AS m UNION ALL
    SELECT 'Zanjadora T755_54' AS n, 'Vermeer' AS m UNION ALL
    SELECT 'Zanjadora FX30_55' AS n, 'Tesmec' AS m UNION ALL
    SELECT 'Perforadora 2020D_56' AS n, 'Ditch Witch' AS m UNION ALL
    SELECT 'Perforadora JT30_57' AS n, 'Ditch Witch' AS m UNION ALL
    SELECT 'Perforadora D24x40_58' AS n, 'Vermeer' AS m UNION ALL
    SELECT 'Martillo Hidraulico H130_59' AS n, 'Caterpillar' AS m UNION ALL
    SELECT 'Martillo Hidraulico HB3600_60' AS n, 'Atlas Copco' AS m UNION ALL
    SELECT 'Martillo Hidraulico BR4099_61' AS n, 'Furukawa' AS m UNION ALL
    SELECT 'Bomba de Agua QLD300_62' AS n, 'Honda' AS m UNION ALL
    SELECT 'Bomba de Agua WP30X_63' AS n, 'Honda' AS m UNION ALL
    SELECT 'Bomba de Agua PTX300_64' AS n, 'Tsunami' AS m UNION ALL
    SELECT 'Grupo Electrogeno 80kVA_65' AS n, 'Cummins' AS m UNION ALL
    SELECT 'Grupo Electrogeno 150kVA_66' AS n, 'Caterpillar' AS m UNION ALL
    SELECT 'Grupo Electrogeno 300kVA_67' AS n, 'Perkins' AS m UNION ALL
    SELECT 'Grupo Electrogeno 50kVA_68' AS n, 'FG Wilson' AS m UNION ALL
    SELECT 'Torre de Iluminacion LTN8_69' AS n, 'Atlas Copco' AS m UNION ALL
    SELECT 'Torre de Iluminacion HiLight_70' AS n, 'Atlas Copco' AS m UNION ALL
    SELECT 'Torre de Iluminacion VT4_71' AS n, 'Wacker Neuson' AS m UNION ALL
    SELECT 'Compresor XAS185_72' AS n, 'Atlas Copco' AS m UNION ALL
    SELECT 'Compresor P185_73' AS n, 'Ingersoll Rand' AS m UNION ALL
    SELECT 'Compresor MD300_74' AS n, 'Sullair' AS m UNION ALL
    SELECT 'Soldadora BIG 40_75' AS n, 'Miller' AS m UNION ALL
    SELECT 'Soldadora Ranger 305G_76' AS n, 'Lincoln Electric' AS m UNION ALL
    SELECT 'Soldadora Vantage 400_77' AS n, 'Lincoln Electric' AS m UNION ALL
    SELECT 'Mezcladora Cemento 1BAG_78' AS n, 'Sthilmaq' AS m UNION ALL
    SELECT 'Mezcladora CM250_79' AS n, 'Belle' AS m UNION ALL
    SELECT 'Mezcladora JZC350_80' AS n, 'Fiori' AS m UNION ALL
    SELECT 'Elevador de Tijera 1930ES_81' AS n, 'Genie' AS m UNION ALL
    SELECT 'Elevador de Tijera GS3246_82' AS n, 'Genie' AS m UNION ALL
    SELECT 'Plataforma Articulada Z45_83' AS n, 'Genie' AS m UNION ALL
    SELECT 'Plataforma Articulada S65_84' AS n, 'Genie' AS m UNION ALL
    SELECT 'Manipulador 9038_85' AS n, 'Dieci' AS m UNION ALL
    SELECT 'Manipulador MLT635_86' AS n, 'Manitou' AS m UNION ALL
    SELECT 'Hormigonera Portatil M9_87' AS n, 'Sthilmaq' AS m UNION ALL
    SELECT 'Desmalezadora MT-1300_88' AS n, 'Metalfor' AS m UNION ALL
    SELECT 'Apisonador BT60_89' AS n, 'Wacker Neuson' AS m UNION ALL
    SELECT 'Apisonador LTX-80_90' AS n, 'Makita' AS m UNION ALL
    SELECT 'Motocompresor 5HP_91' AS n, 'Lusqtoff' AS m UNION ALL
    SELECT 'Cortadora de Asfalto FS513_92' AS n, 'STIHL' AS m UNION ALL
    SELECT 'Cortadora de Hormigon TS800_93' AS n, 'STIHL' AS m UNION ALL
    SELECT 'Placa Compactadora BPU3750_94' AS n, 'Wacker Neuson' AS m UNION ALL
    SELECT 'Placa Compactadora MVH306_95' AS n, 'Mikasa' AS m UNION ALL
    SELECT 'Placa Compactadora LTV6K_96' AS n, 'Dynapac' AS m UNION ALL
    SELECT 'Retroexcavadora 3CX_97' AS n, 'JCB' AS m UNION ALL
    SELECT 'Retroexcavadora WB97S_98' AS n, 'Case' AS m UNION ALL
    SELECT 'Retroexcavadora 432F_99' AS n, 'Caterpillar' AS m UNION ALL
    SELECT 'Camion Mixer 6m3_100' AS n, 'IVECO' AS m UNION ALL
    SELECT 'Camion Mixer 8m3_101' AS n, 'Mercedes Benz' AS m UNION ALL
    SELECT 'Camion Mixer 10m3_102' AS n, 'Scania' AS m UNION ALL
    SELECT 'Camion Regador 12000L_103' AS n, 'Mercedes Benz' AS m UNION ALL
    SELECT 'Camion Regador 15000L_104' AS n, 'Volkswagen' AS m UNION ALL
    SELECT 'Barredora B6_105' AS n, 'Dulevo' AS m UNION ALL
    SELECT 'Barredora CityCat_106' AS n, 'Bucher' AS m UNION ALL
    SELECT 'Pala Retroexcavadora 3D_107' AS n, 'New Holland' AS m UNION ALL
    SELECT 'Pala Retroexcavadora 415F2_108' AS n, 'Caterpillar' AS m UNION ALL
    SELECT 'Pala Frontal L60H_109' AS n, 'Volvo' AS m
) t
WHERE NOT EXISTS (
    SELECT 1 FROM maquinaria WHERE nombre = t.n AND marca = t.m
);

-- ===== CONTRATOS OBREROS (30, con estados variados) =====
INSERT INTO contrato_obrero (archivo, nombre_archivo, id_obrero, fecha_vencimiento)
SELECT _binary 'PDF demo' AS archivo, CONCAT('contrato_', o.nombre, '_', o.apellido, '.pdf') AS na, o.id_obrero,
    CASE
        WHEN o.id_obrero % 4 = 0 THEN DATE_SUB(CURDATE(), INTERVAL (o.id_obrero % 60 + 1) DAY)   -- vencido
        WHEN o.id_obrero % 4 = 1 THEN DATE_ADD(CURDATE(), INTERVAL (o.id_obrero % 25 + 1) DAY)   -- por vencer (< 30 días)
        WHEN o.id_obrero % 4 = 2 THEN DATE_ADD(CURDATE(), INTERVAL (o.id_obrero * 2 + 45) DAY)   -- vigente
        ELSE NULL                                                                                  -- sin vencimiento
    END AS fv
FROM obreros o
WHERE o.id_obrero <= 30
  AND o.activo = 1
  AND NOT EXISTS (
      SELECT 1 FROM contrato_obrero WHERE id_obrero = o.id_obrero
  );

-- ===== REGISTROS DE ASISTENCIA (~210) =====
-- Distribuye registros entre las primeras 10 obras y los primeros 40 obrerosINSERT INTO registros (fecha, hora_entrada, hora_salida, horas_trabajadas, id_obrero, id_obra, id_usuario)
SELECT DISTINCT d.fecha, d.hora_entrada, d.hora_salida, d.horas, o.id_obrero, ob.id_obra, COALESCE(@capataz_id, @admin_id)
FROM (
    SELECT '2026-01-02' AS fecha, '06:00:00' AS hora_entrada, '14:00:00' AS hora_salida, 7 AS horas, '40000000' AS doc UNION ALL
    SELECT '2026-03-05' AS fecha, '07:00:00' AS hora_entrada, '15:00:00' AS hora_salida, 7.5 AS horas, '40011118' AS doc UNION ALL
    SELECT '2026-05-08' AS fecha, '08:00:00' AS hora_entrada, '16:00:00' AS hora_salida, 8 AS horas, '40022236' AS doc UNION ALL
    SELECT '2026-01-11' AS fecha, '09:00:00' AS hora_entrada, '17:00:00' AS hora_salida, 8.5 AS horas, '40033354' AS doc UNION ALL
    SELECT '2026-03-14' AS fecha, '06:00:00' AS hora_entrada, '14:00:00' AS hora_salida, 7 AS horas, '40044472' AS doc UNION ALL
    SELECT '2026-05-17' AS fecha, '07:00:00' AS hora_entrada, '15:00:00' AS hora_salida, 7.5 AS horas, '40055590' AS doc UNION ALL
    SELECT '2026-01-20' AS fecha, '08:00:00' AS hora_entrada, '16:00:00' AS hora_salida, 8 AS horas, '40066708' AS doc UNION ALL
    SELECT '2026-03-23' AS fecha, '09:00:00' AS hora_entrada, '17:00:00' AS hora_salida, 8.5 AS horas, '40077826' AS doc UNION ALL
    SELECT '2026-05-26' AS fecha, '06:00:00' AS hora_entrada, '14:00:00' AS hora_salida, 7 AS horas, '40088944' AS doc UNION ALL
    SELECT '2026-01-01' AS fecha, '07:00:00' AS hora_entrada, '15:00:00' AS hora_salida, 7.5 AS horas, '40100062' AS doc UNION ALL
    SELECT '2026-03-04' AS fecha, '08:00:00' AS hora_entrada, '16:00:00' AS hora_salida, 8 AS horas, '40111180' AS doc UNION ALL
    SELECT '2026-05-07' AS fecha, '09:00:00' AS hora_entrada, '17:00:00' AS hora_salida, 8.5 AS horas, '40122298' AS doc UNION ALL
    SELECT '2026-01-10' AS fecha, '06:00:00' AS hora_entrada, '14:00:00' AS hora_salida, 7 AS horas, '40133416' AS doc UNION ALL
    SELECT '2026-03-13' AS fecha, '07:00:00' AS hora_entrada, '15:00:00' AS hora_salida, 7.5 AS horas, '40144534' AS doc UNION ALL
    SELECT '2026-05-16' AS fecha, '08:00:00' AS hora_entrada, '16:00:00' AS hora_salida, 8 AS horas, '40155652' AS doc UNION ALL
    SELECT '2026-01-19' AS fecha, '09:00:00' AS hora_entrada, '17:00:00' AS hora_salida, 8.5 AS horas, '40166670' AS doc UNION ALL
    SELECT '2026-03-22' AS fecha, '06:00:00' AS hora_entrada, '14:00:00' AS hora_salida, 7 AS horas, '40177788' AS doc UNION ALL
    SELECT '2026-05-25' AS fecha, '07:00:00' AS hora_entrada, '15:00:00' AS hora_salida, 7.5 AS horas, '40188906' AS doc UNION ALL
    SELECT '2026-01-28' AS fecha, '08:00:00' AS hora_entrada, '16:00:00' AS hora_salida, 8 AS horas, '40200024' AS doc UNION ALL
    SELECT '2026-03-03' AS fecha, '09:00:00' AS hora_entrada, '17:00:00' AS hora_salida, 8.5 AS horas, '40211142' AS doc UNION ALL
    SELECT '2026-05-06' AS fecha, '06:00:00' AS hora_entrada, '14:00:00' AS hora_salida, 7 AS horas, '40222260' AS doc UNION ALL
    SELECT '2026-01-09' AS fecha, '07:00:00' AS hora_entrada, '15:00:00' AS hora_salida, 7.5 AS horas, '40233378' AS doc UNION ALL
    SELECT '2026-03-12' AS fecha, '08:00:00' AS hora_entrada, '16:00:00' AS hora_salida, 8 AS horas, '40244496' AS doc UNION ALL
    SELECT '2026-05-15' AS fecha, '09:00:00' AS hora_entrada, '17:00:00' AS hora_salida, 8.5 AS horas, '40255614' AS doc UNION ALL
    SELECT '2026-01-18' AS fecha, '06:00:00' AS hora_entrada, '14:00:00' AS hora_salida, 7 AS horas, '40266732' AS doc UNION ALL
    SELECT '2026-03-21' AS fecha, '07:00:00' AS hora_entrada, '15:00:00' AS hora_salida, 7.5 AS horas, '40277850' AS doc UNION ALL
    SELECT '2026-05-24' AS fecha, '08:00:00' AS hora_entrada, '16:00:00' AS hora_salida, 8 AS horas, '40288968' AS doc UNION ALL
    SELECT '2026-01-27' AS fecha, '09:00:00' AS hora_entrada, '17:00:00' AS hora_salida, 8.5 AS horas, '40300086' AS doc UNION ALL
    SELECT '2026-03-02' AS fecha, '06:00:00' AS hora_entrada, '14:00:00' AS hora_salida, 7 AS horas, '40311204' AS doc UNION ALL
    SELECT '2026-05-05' AS fecha, '07:00:00' AS hora_entrada, '15:00:00' AS hora_salida, 7.5 AS horas, '40322222' AS doc UNION ALL
    SELECT '2026-01-08' AS fecha, '08:00:00' AS hora_entrada, '16:00:00' AS hora_salida, 8 AS horas, '40333340' AS doc UNION ALL
    SELECT '2026-03-11' AS fecha, '09:00:00' AS hora_entrada, '17:00:00' AS hora_salida, 8.5 AS horas, '40344458' AS doc UNION ALL
    SELECT '2026-05-14' AS fecha, '06:00:00' AS hora_entrada, '14:00:00' AS hora_salida, 7 AS horas, '40355576' AS doc UNION ALL
    SELECT '2026-01-17' AS fecha, '07:00:00' AS hora_entrada, '15:00:00' AS hora_salida, 7.5 AS horas, '40366694' AS doc UNION ALL
    SELECT '2026-03-20' AS fecha, '08:00:00' AS hora_entrada, '16:00:00' AS hora_salida, 8 AS horas, '40377812' AS doc UNION ALL
    SELECT '2026-05-23' AS fecha, '09:00:00' AS hora_entrada, '17:00:00' AS hora_salida, 8.5 AS horas, '40388930' AS doc UNION ALL
    SELECT '2026-01-26' AS fecha, '06:00:00' AS hora_entrada, '14:00:00' AS hora_salida, 7 AS horas, '40400048' AS doc UNION ALL
    SELECT '2026-03-01' AS fecha, '07:00:00' AS hora_entrada, '15:00:00' AS hora_salida, 7.5 AS horas, '40411166' AS doc UNION ALL
    SELECT '2026-05-04' AS fecha, '08:00:00' AS hora_entrada, '16:00:00' AS hora_salida, 8 AS horas, '40422284' AS doc UNION ALL
    SELECT '2026-01-07' AS fecha, '09:00:00' AS hora_entrada, '17:00:00' AS hora_salida, 8.5 AS horas, '40433402' AS doc UNION ALL
    SELECT '2026-03-10' AS fecha, '06:00:00' AS hora_entrada, '14:00:00' AS hora_salida, 7 AS horas, '40000080' AS doc UNION ALL
    SELECT '2026-05-13' AS fecha, '07:00:00' AS hora_entrada, '15:00:00' AS hora_salida, 7.5 AS horas, '40011198' AS doc UNION ALL
    SELECT '2026-01-16' AS fecha, '08:00:00' AS hora_entrada, '16:00:00' AS hora_salida, 8 AS horas, '40022316' AS doc UNION ALL
    SELECT '2026-03-19' AS fecha, '09:00:00' AS hora_entrada, '17:00:00' AS hora_salida, 8.5 AS horas, '40033334' AS doc UNION ALL
    SELECT '2026-05-22' AS fecha, '06:00:00' AS hora_entrada, '14:00:00' AS hora_salida, 7 AS horas, '40044452' AS doc UNION ALL
    SELECT '2026-01-25' AS fecha, '07:00:00' AS hora_entrada, '15:00:00' AS hora_salida, 7.5 AS horas, '40055570' AS doc UNION ALL
    SELECT '2026-03-28' AS fecha, '08:00:00' AS hora_entrada, '16:00:00' AS hora_salida, 8 AS horas, '40066688' AS doc UNION ALL
    SELECT '2026-05-03' AS fecha, '09:00:00' AS hora_entrada, '17:00:00' AS hora_salida, 8.5 AS horas, '40077806' AS doc UNION ALL
    SELECT '2026-01-06' AS fecha, '06:00:00' AS hora_entrada, '14:00:00' AS hora_salida, 7 AS horas, '40088924' AS doc UNION ALL
    SELECT '2026-03-09' AS fecha, '07:00:00' AS hora_entrada, '15:00:00' AS hora_salida, 7.5 AS horas, '40100042' AS doc UNION ALL
    SELECT '2026-05-12' AS fecha, '08:00:00' AS hora_entrada, '16:00:00' AS hora_salida, 8 AS horas, '40111160' AS doc UNION ALL
    SELECT '2026-01-15' AS fecha, '09:00:00' AS hora_entrada, '17:00:00' AS hora_salida, 8.5 AS horas, '40122278' AS doc UNION ALL
    SELECT '2026-03-18' AS fecha, '06:00:00' AS hora_entrada, '14:00:00' AS hora_salida, 7 AS horas, '40133396' AS doc UNION ALL
    SELECT '2026-05-21' AS fecha, '07:00:00' AS hora_entrada, '15:00:00' AS hora_salida, 7.5 AS horas, '40144514' AS doc UNION ALL
    SELECT '2026-01-24' AS fecha, '08:00:00' AS hora_entrada, '16:00:00' AS hora_salida, 8 AS horas, '40155632' AS doc UNION ALL
    SELECT '2026-03-27' AS fecha, '09:00:00' AS hora_entrada, '17:00:00' AS hora_salida, 8.5 AS horas, '40166750' AS doc UNION ALL
    SELECT '2026-05-02' AS fecha, '06:00:00' AS hora_entrada, '14:00:00' AS hora_salida, 7 AS horas, '40177868' AS doc UNION ALL
    SELECT '2026-01-05' AS fecha, '07:00:00' AS hora_entrada, '15:00:00' AS hora_salida, 7.5 AS horas, '40188986' AS doc UNION ALL
    SELECT '2026-03-08' AS fecha, '08:00:00' AS hora_entrada, '16:00:00' AS hora_salida, 8 AS horas, '40200004' AS doc UNION ALL
    SELECT '2026-05-11' AS fecha, '09:00:00' AS hora_entrada, '17:00:00' AS hora_salida, 8.5 AS horas, '40211122' AS doc UNION ALL
    SELECT '2026-01-14' AS fecha, '06:00:00' AS hora_entrada, '14:00:00' AS hora_salida, 7 AS horas, '40222240' AS doc UNION ALL
    SELECT '2026-03-17' AS fecha, '07:00:00' AS hora_entrada, '15:00:00' AS hora_salida, 7.5 AS horas, '40233358' AS doc UNION ALL
    SELECT '2026-05-20' AS fecha, '08:00:00' AS hora_entrada, '16:00:00' AS hora_salida, 8 AS horas, '40244476' AS doc UNION ALL
    SELECT '2026-01-23' AS fecha, '09:00:00' AS hora_entrada, '17:00:00' AS hora_salida, 8.5 AS horas, '40255594' AS doc UNION ALL
    SELECT '2026-03-26' AS fecha, '06:00:00' AS hora_entrada, '14:00:00' AS hora_salida, 7 AS horas, '40266712' AS doc UNION ALL
    SELECT '2026-05-01' AS fecha, '07:00:00' AS hora_entrada, '15:00:00' AS hora_salida, 7.5 AS horas, '40277830' AS doc UNION ALL
    SELECT '2026-01-04' AS fecha, '08:00:00' AS hora_entrada, '16:00:00' AS hora_salida, 8 AS horas, '40288948' AS doc UNION ALL
    SELECT '2026-03-07' AS fecha, '09:00:00' AS hora_entrada, '17:00:00' AS hora_salida, 8.5 AS horas, '40300066' AS doc UNION ALL
    SELECT '2026-05-10' AS fecha, '06:00:00' AS hora_entrada, '14:00:00' AS hora_salida, 7 AS horas, '40311184' AS doc UNION ALL
    SELECT '2026-01-13' AS fecha, '07:00:00' AS hora_entrada, '15:00:00' AS hora_salida, 7.5 AS horas, '40322302' AS doc UNION ALL
    SELECT '2026-03-16' AS fecha, '08:00:00' AS hora_entrada, '16:00:00' AS hora_salida, 8 AS horas, '40333420' AS doc UNION ALL
    SELECT '2026-05-19' AS fecha, '09:00:00' AS hora_entrada, '17:00:00' AS hora_salida, 8.5 AS horas, '40344538' AS doc UNION ALL
    SELECT '2026-01-22' AS fecha, '06:00:00' AS hora_entrada, '14:00:00' AS hora_salida, 7 AS horas, '40355556' AS doc UNION ALL
    SELECT '2026-03-25' AS fecha, '07:00:00' AS hora_entrada, '15:00:00' AS hora_salida, 7.5 AS horas, '40366674' AS doc UNION ALL
    SELECT '2026-05-28' AS fecha, '08:00:00' AS hora_entrada, '16:00:00' AS hora_salida, 8 AS horas, '40377792' AS doc UNION ALL
    SELECT '2026-01-03' AS fecha, '09:00:00' AS hora_entrada, '17:00:00' AS hora_salida, 8.5 AS horas, '40388910' AS doc UNION ALL
    SELECT '2026-03-06' AS fecha, '06:00:00' AS hora_entrada, '14:00:00' AS hora_salida, 7 AS horas, '40400028' AS doc UNION ALL
    SELECT '2026-05-09' AS fecha, '07:00:00' AS hora_entrada, '15:00:00' AS hora_salida, 7.5 AS horas, '40411146' AS doc UNION ALL
    SELECT '2026-01-12' AS fecha, '08:00:00' AS hora_entrada, '16:00:00' AS hora_salida, 8 AS horas, '40422264' AS doc UNION ALL
    SELECT '2026-03-15' AS fecha, '09:00:00' AS hora_entrada, '17:00:00' AS hora_salida, 8.5 AS horas, '40433382' AS doc UNION ALL
    SELECT '2026-05-18' AS fecha, '06:00:00' AS hora_entrada, '14:00:00' AS hora_salida, 7 AS horas, '40000060' AS doc UNION ALL
    SELECT '2026-01-21' AS fecha, '07:00:00' AS hora_entrada, '15:00:00' AS hora_salida, 7.5 AS horas, '40011178' AS doc UNION ALL
    SELECT '2026-03-24' AS fecha, '08:00:00' AS hora_entrada, '16:00:00' AS hora_salida, 8 AS horas, '40022296' AS doc UNION ALL
    SELECT '2026-05-27' AS fecha, '09:00:00' AS hora_entrada, '17:00:00' AS hora_salida, 8.5 AS horas, '40033414' AS doc UNION ALL
    SELECT '2026-01-02' AS fecha, '06:00:00' AS hora_entrada, '14:00:00' AS hora_salida, 7 AS horas, '40044532' AS doc UNION ALL
    SELECT '2026-03-05' AS fecha, '07:00:00' AS hora_entrada, '15:00:00' AS hora_salida, 7.5 AS horas, '40055650' AS doc UNION ALL
    SELECT '2026-05-08' AS fecha, '08:00:00' AS hora_entrada, '16:00:00' AS hora_salida, 8 AS horas, '40066668' AS doc UNION ALL
    SELECT '2026-01-11' AS fecha, '09:00:00' AS hora_entrada, '17:00:00' AS hora_salida, 8.5 AS horas, '40077786' AS doc UNION ALL
    SELECT '2026-03-14' AS fecha, '06:00:00' AS hora_entrada, '14:00:00' AS hora_salida, 7 AS horas, '40088904' AS doc UNION ALL
    SELECT '2026-05-17' AS fecha, '07:00:00' AS hora_entrada, '15:00:00' AS hora_salida, 7.5 AS horas, '40100022' AS doc UNION ALL
    SELECT '2026-01-20' AS fecha, '08:00:00' AS hora_entrada, '16:00:00' AS hora_salida, 8 AS horas, '40111140' AS doc UNION ALL
    SELECT '2026-03-23' AS fecha, '09:00:00' AS hora_entrada, '17:00:00' AS hora_salida, 8.5 AS horas, '40122258' AS doc UNION ALL
    SELECT '2026-05-26' AS fecha, '06:00:00' AS hora_entrada, '14:00:00' AS hora_salida, 7 AS horas, '40133376' AS doc UNION ALL
    SELECT '2026-01-01' AS fecha, '07:00:00' AS hora_entrada, '15:00:00' AS hora_salida, 7.5 AS horas, '40144494' AS doc UNION ALL
    SELECT '2026-03-04' AS fecha, '08:00:00' AS hora_entrada, '16:00:00' AS hora_salida, 8 AS horas, '40155612' AS doc UNION ALL
    SELECT '2026-05-07' AS fecha, '09:00:00' AS hora_entrada, '17:00:00' AS hora_salida, 8.5 AS horas, '40166730' AS doc UNION ALL
    SELECT '2026-01-10' AS fecha, '06:00:00' AS hora_entrada, '14:00:00' AS hora_salida, 7 AS horas, '40177848' AS doc UNION ALL
    SELECT '2026-03-13' AS fecha, '07:00:00' AS hora_entrada, '15:00:00' AS hora_salida, 7.5 AS horas, '40188966' AS doc UNION ALL
    SELECT '2026-05-16' AS fecha, '08:00:00' AS hora_entrada, '16:00:00' AS hora_salida, 8 AS horas, '40200084' AS doc UNION ALL
    SELECT '2026-01-19' AS fecha, '09:00:00' AS hora_entrada, '17:00:00' AS hora_salida, 8.5 AS horas, '40211202' AS doc UNION ALL
    SELECT '2026-03-22' AS fecha, '06:00:00' AS hora_entrada, '14:00:00' AS hora_salida, 7 AS horas, '40222220' AS doc UNION ALL
    SELECT '2026-05-25' AS fecha, '07:00:00' AS hora_entrada, '15:00:00' AS hora_salida, 7.5 AS horas, '40233338' AS doc UNION ALL
    SELECT '2026-01-28' AS fecha, '08:00:00' AS hora_entrada, '16:00:00' AS hora_salida, 8 AS horas, '40244456' AS doc UNION ALL
    SELECT '2026-03-03' AS fecha, '09:00:00' AS hora_entrada, '17:00:00' AS hora_salida, 8.5 AS horas, '40255574' AS doc UNION ALL
    SELECT '2026-05-06' AS fecha, '06:00:00' AS hora_entrada, '14:00:00' AS hora_salida, 7 AS horas, '40266692' AS doc UNION ALL
    SELECT '2026-01-09' AS fecha, '07:00:00' AS hora_entrada, '15:00:00' AS hora_salida, 7.5 AS horas, '40277810' AS doc UNION ALL
    SELECT '2026-03-12' AS fecha, '08:00:00' AS hora_entrada, '16:00:00' AS hora_salida, 8 AS horas, '40288928' AS doc UNION ALL
    SELECT '2026-05-15' AS fecha, '09:00:00' AS hora_entrada, '17:00:00' AS hora_salida, 8.5 AS horas, '40300046' AS doc UNION ALL
    SELECT '2026-01-18' AS fecha, '06:00:00' AS hora_entrada, '14:00:00' AS hora_salida, 7 AS horas, '40311164' AS doc UNION ALL
    SELECT '2026-03-21' AS fecha, '07:00:00' AS hora_entrada, '15:00:00' AS hora_salida, 7.5 AS horas, '40322282' AS doc UNION ALL
    SELECT '2026-05-24' AS fecha, '08:00:00' AS hora_entrada, '16:00:00' AS hora_salida, 8 AS horas, '40333400' AS doc UNION ALL
    SELECT '2026-01-27' AS fecha, '09:00:00' AS hora_entrada, '17:00:00' AS hora_salida, 8.5 AS horas, '40344518' AS doc UNION ALL
    SELECT '2026-03-02' AS fecha, '06:00:00' AS hora_entrada, '14:00:00' AS hora_salida, 7 AS horas, '40355636' AS doc UNION ALL
    SELECT '2026-05-05' AS fecha, '07:00:00' AS hora_entrada, '15:00:00' AS hora_salida, 7.5 AS horas, '40366754' AS doc UNION ALL
    SELECT '2026-01-08' AS fecha, '08:00:00' AS hora_entrada, '16:00:00' AS hora_salida, 8 AS horas, '40377872' AS doc UNION ALL
    SELECT '2026-03-11' AS fecha, '09:00:00' AS hora_entrada, '17:00:00' AS hora_salida, 8.5 AS horas, '40388890' AS doc UNION ALL
    SELECT '2026-05-14' AS fecha, '06:00:00' AS hora_entrada, '14:00:00' AS hora_salida, 7 AS horas, '40400008' AS doc UNION ALL
    SELECT '2026-01-17' AS fecha, '07:00:00' AS hora_entrada, '15:00:00' AS hora_salida, 7.5 AS horas, '40411126' AS doc UNION ALL
    SELECT '2026-03-20' AS fecha, '08:00:00' AS hora_entrada, '16:00:00' AS hora_salida, 8 AS horas, '40422244' AS doc UNION ALL
    SELECT '2026-05-23' AS fecha, '09:00:00' AS hora_entrada, '17:00:00' AS hora_salida, 8.5 AS horas, '40433362' AS doc UNION ALL
    SELECT '2026-01-26' AS fecha, '06:00:00' AS hora_entrada, '14:00:00' AS hora_salida, 7 AS horas, '40000040' AS doc UNION ALL
    SELECT '2026-03-01' AS fecha, '07:00:00' AS hora_entrada, '15:00:00' AS hora_salida, 7.5 AS horas, '40011158' AS doc UNION ALL
    SELECT '2026-05-04' AS fecha, '08:00:00' AS hora_entrada, '16:00:00' AS hora_salida, 8 AS horas, '40022276' AS doc UNION ALL
    SELECT '2026-01-07' AS fecha, '09:00:00' AS hora_entrada, '17:00:00' AS hora_salida, 8.5 AS horas, '40033394' AS doc UNION ALL
    SELECT '2026-03-10' AS fecha, '06:00:00' AS hora_entrada, '14:00:00' AS hora_salida, 7 AS horas, '40044512' AS doc UNION ALL
    SELECT '2026-05-13' AS fecha, '07:00:00' AS hora_entrada, '15:00:00' AS hora_salida, 7.5 AS horas, '40055630' AS doc UNION ALL
    SELECT '2026-01-16' AS fecha, '08:00:00' AS hora_entrada, '16:00:00' AS hora_salida, 8 AS horas, '40066748' AS doc UNION ALL
    SELECT '2026-03-19' AS fecha, '09:00:00' AS hora_entrada, '17:00:00' AS hora_salida, 8.5 AS horas, '40077866' AS doc UNION ALL
    SELECT '2026-05-22' AS fecha, '06:00:00' AS hora_entrada, '14:00:00' AS hora_salida, 7 AS horas, '40088984' AS doc UNION ALL
    SELECT '2026-01-25' AS fecha, '07:00:00' AS hora_entrada, '15:00:00' AS hora_salida, 7.5 AS horas, '40100002' AS doc UNION ALL
    SELECT '2026-03-28' AS fecha, '08:00:00' AS hora_entrada, '16:00:00' AS hora_salida, 8 AS horas, '40111120' AS doc UNION ALL
    SELECT '2026-05-03' AS fecha, '09:00:00' AS hora_entrada, '17:00:00' AS hora_salida, 8.5 AS horas, '40122238' AS doc UNION ALL
    SELECT '2026-01-06' AS fecha, '06:00:00' AS hora_entrada, '14:00:00' AS hora_salida, 7 AS horas, '40133356' AS doc UNION ALL
    SELECT '2026-03-09' AS fecha, '07:00:00' AS hora_entrada, '15:00:00' AS hora_salida, 7.5 AS horas, '40144474' AS doc UNION ALL
    SELECT '2026-05-12' AS fecha, '08:00:00' AS hora_entrada, '16:00:00' AS hora_salida, 8 AS horas, '40155592' AS doc UNION ALL
    SELECT '2026-01-15' AS fecha, '09:00:00' AS hora_entrada, '17:00:00' AS hora_salida, 8.5 AS horas, '40166710' AS doc UNION ALL
    SELECT '2026-03-18' AS fecha, '06:00:00' AS hora_entrada, '14:00:00' AS hora_salida, 7 AS horas, '40177828' AS doc UNION ALL
    SELECT '2026-05-21' AS fecha, '07:00:00' AS hora_entrada, '15:00:00' AS hora_salida, 7.5 AS horas, '40188946' AS doc UNION ALL
    SELECT '2026-01-24' AS fecha, '08:00:00' AS hora_entrada, '16:00:00' AS hora_salida, 8 AS horas, '40200064' AS doc UNION ALL
    SELECT '2026-03-27' AS fecha, '09:00:00' AS hora_entrada, '17:00:00' AS hora_salida, 8.5 AS horas, '40211182' AS doc UNION ALL
    SELECT '2026-05-02' AS fecha, '06:00:00' AS hora_entrada, '14:00:00' AS hora_salida, 7 AS horas, '40222300' AS doc UNION ALL
    SELECT '2026-01-05' AS fecha, '07:00:00' AS hora_entrada, '15:00:00' AS hora_salida, 7.5 AS horas, '40233418' AS doc UNION ALL
    SELECT '2026-03-08' AS fecha, '08:00:00' AS hora_entrada, '16:00:00' AS hora_salida, 8 AS horas, '40244536' AS doc UNION ALL
    SELECT '2026-05-11' AS fecha, '09:00:00' AS hora_entrada, '17:00:00' AS hora_salida, 8.5 AS horas, '40255554' AS doc UNION ALL
    SELECT '2026-01-14' AS fecha, '06:00:00' AS hora_entrada, '14:00:00' AS hora_salida, 7 AS horas, '40266672' AS doc UNION ALL
    SELECT '2026-03-17' AS fecha, '07:00:00' AS hora_entrada, '15:00:00' AS hora_salida, 7.5 AS horas, '40277790' AS doc UNION ALL
    SELECT '2026-05-20' AS fecha, '08:00:00' AS hora_entrada, '16:00:00' AS hora_salida, 8 AS horas, '40288908' AS doc UNION ALL
    SELECT '2026-01-23' AS fecha, '09:00:00' AS hora_entrada, '17:00:00' AS hora_salida, 8.5 AS horas, '40300026' AS doc UNION ALL
    SELECT '2026-03-26' AS fecha, '06:00:00' AS hora_entrada, '14:00:00' AS hora_salida, 7 AS horas, '40311144' AS doc UNION ALL
    SELECT '2026-05-01' AS fecha, '07:00:00' AS hora_entrada, '15:00:00' AS hora_salida, 7.5 AS horas, '40322262' AS doc UNION ALL
    SELECT '2026-01-04' AS fecha, '08:00:00' AS hora_entrada, '16:00:00' AS hora_salida, 8 AS horas, '40333380' AS doc UNION ALL
    SELECT '2026-03-07' AS fecha, '09:00:00' AS hora_entrada, '17:00:00' AS hora_salida, 8.5 AS horas, '40344498' AS doc UNION ALL
    SELECT '2026-05-10' AS fecha, '06:00:00' AS hora_entrada, '14:00:00' AS hora_salida, 7 AS horas, '40355616' AS doc UNION ALL
    SELECT '2026-01-13' AS fecha, '07:00:00' AS hora_entrada, '15:00:00' AS hora_salida, 7.5 AS horas, '40366734' AS doc UNION ALL
    SELECT '2026-03-16' AS fecha, '08:00:00' AS hora_entrada, '16:00:00' AS hora_salida, 8 AS horas, '40377852' AS doc UNION ALL
    SELECT '2026-05-19' AS fecha, '09:00:00' AS hora_entrada, '17:00:00' AS hora_salida, 8.5 AS horas, '40388970' AS doc UNION ALL
    SELECT '2026-01-22' AS fecha, '06:00:00' AS hora_entrada, '14:00:00' AS hora_salida, 7 AS horas, '40400088' AS doc UNION ALL
    SELECT '2026-03-25' AS fecha, '07:00:00' AS hora_entrada, '15:00:00' AS hora_salida, 7.5 AS horas, '40411206' AS doc UNION ALL
    SELECT '2026-05-28' AS fecha, '08:00:00' AS hora_entrada, '16:00:00' AS hora_salida, 8 AS horas, '40422224' AS doc UNION ALL
    SELECT '2026-01-03' AS fecha, '09:00:00' AS hora_entrada, '17:00:00' AS hora_salida, 8.5 AS horas, '40433342' AS doc UNION ALL
    SELECT '2026-03-06' AS fecha, '06:00:00' AS hora_entrada, '14:00:00' AS hora_salida, 7 AS horas, '40000020' AS doc UNION ALL
    SELECT '2026-05-09' AS fecha, '07:00:00' AS hora_entrada, '15:00:00' AS hora_salida, 7.5 AS horas, '40011138' AS doc UNION ALL
    SELECT '2026-01-12' AS fecha, '08:00:00' AS hora_entrada, '16:00:00' AS hora_salida, 8 AS horas, '40022256' AS doc UNION ALL
    SELECT '2026-03-15' AS fecha, '09:00:00' AS hora_entrada, '17:00:00' AS hora_salida, 8.5 AS horas, '40033374' AS doc UNION ALL
    SELECT '2026-05-18' AS fecha, '06:00:00' AS hora_entrada, '14:00:00' AS hora_salida, 7 AS horas, '40044492' AS doc UNION ALL
    SELECT '2026-01-21' AS fecha, '07:00:00' AS hora_entrada, '15:00:00' AS hora_salida, 7.5 AS horas, '40055610' AS doc UNION ALL
    SELECT '2026-03-24' AS fecha, '08:00:00' AS hora_entrada, '16:00:00' AS hora_salida, 8 AS horas, '40066728' AS doc UNION ALL
    SELECT '2026-05-27' AS fecha, '09:00:00' AS hora_entrada, '17:00:00' AS hora_salida, 8.5 AS horas, '40077846' AS doc UNION ALL
    SELECT '2026-01-02' AS fecha, '06:00:00' AS hora_entrada, '14:00:00' AS hora_salida, 7 AS horas, '40088964' AS doc UNION ALL
    SELECT '2026-03-05' AS fecha, '07:00:00' AS hora_entrada, '15:00:00' AS hora_salida, 7.5 AS horas, '40100082' AS doc UNION ALL
    SELECT '2026-05-08' AS fecha, '08:00:00' AS hora_entrada, '16:00:00' AS hora_salida, 8 AS horas, '40111200' AS doc UNION ALL
    SELECT '2026-01-11' AS fecha, '09:00:00' AS hora_entrada, '17:00:00' AS hora_salida, 8.5 AS horas, '40122318' AS doc UNION ALL
    SELECT '2026-03-14' AS fecha, '06:00:00' AS hora_entrada, '14:00:00' AS hora_salida, 7 AS horas, '40133336' AS doc UNION ALL
    SELECT '2026-05-17' AS fecha, '07:00:00' AS hora_entrada, '15:00:00' AS hora_salida, 7.5 AS horas, '40144454' AS doc UNION ALL
    SELECT '2026-01-20' AS fecha, '08:00:00' AS hora_entrada, '16:00:00' AS hora_salida, 8 AS horas, '40155572' AS doc UNION ALL
    SELECT '2026-03-23' AS fecha, '09:00:00' AS hora_entrada, '17:00:00' AS hora_salida, 8.5 AS horas, '40166690' AS doc UNION ALL
    SELECT '2026-05-26' AS fecha, '06:00:00' AS hora_entrada, '14:00:00' AS hora_salida, 7 AS horas, '40177808' AS doc UNION ALL
    SELECT '2026-01-01' AS fecha, '07:00:00' AS hora_entrada, '15:00:00' AS hora_salida, 7.5 AS horas, '40188926' AS doc UNION ALL
    SELECT '2026-03-04' AS fecha, '08:00:00' AS hora_entrada, '16:00:00' AS hora_salida, 8 AS horas, '40200044' AS doc UNION ALL
    SELECT '2026-05-07' AS fecha, '09:00:00' AS hora_entrada, '17:00:00' AS hora_salida, 8.5 AS horas, '40211162' AS doc UNION ALL
    SELECT '2026-01-10' AS fecha, '06:00:00' AS hora_entrada, '14:00:00' AS hora_salida, 7 AS horas, '40222280' AS doc UNION ALL
    SELECT '2026-03-13' AS fecha, '07:00:00' AS hora_entrada, '15:00:00' AS hora_salida, 7.5 AS horas, '40233398' AS doc UNION ALL
    SELECT '2026-05-16' AS fecha, '08:00:00' AS hora_entrada, '16:00:00' AS hora_salida, 8 AS horas, '40244516' AS doc UNION ALL
    SELECT '2026-01-19' AS fecha, '09:00:00' AS hora_entrada, '17:00:00' AS hora_salida, 8.5 AS horas, '40255634' AS doc UNION ALL
    SELECT '2026-03-22' AS fecha, '06:00:00' AS hora_entrada, '14:00:00' AS hora_salida, 7 AS horas, '40266752' AS doc UNION ALL
    SELECT '2026-05-25' AS fecha, '07:00:00' AS hora_entrada, '15:00:00' AS hora_salida, 7.5 AS horas, '40277870' AS doc UNION ALL
    SELECT '2026-01-28' AS fecha, '08:00:00' AS hora_entrada, '16:00:00' AS hora_salida, 8 AS horas, '40288888' AS doc UNION ALL
    SELECT '2026-03-03' AS fecha, '09:00:00' AS hora_entrada, '17:00:00' AS hora_salida, 8.5 AS horas, '40300006' AS doc UNION ALL
    SELECT '2026-05-06' AS fecha, '06:00:00' AS hora_entrada, '14:00:00' AS hora_salida, 7 AS horas, '40311124' AS doc UNION ALL
    SELECT '2026-01-09' AS fecha, '07:00:00' AS hora_entrada, '15:00:00' AS hora_salida, 7.5 AS horas, '40322242' AS doc UNION ALL
    SELECT '2026-03-12' AS fecha, '08:00:00' AS hora_entrada, '16:00:00' AS hora_salida, 8 AS horas, '40333360' AS doc UNION ALL
    SELECT '2026-05-15' AS fecha, '09:00:00' AS hora_entrada, '17:00:00' AS hora_salida, 8.5 AS horas, '40344478' AS doc UNION ALL
    SELECT '2026-01-18' AS fecha, '06:00:00' AS hora_entrada, '14:00:00' AS hora_salida, 7 AS horas, '40355596' AS doc UNION ALL
    SELECT '2026-03-21' AS fecha, '07:00:00' AS hora_entrada, '15:00:00' AS hora_salida, 7.5 AS horas, '40366714' AS doc UNION ALL
    SELECT '2026-05-24' AS fecha, '08:00:00' AS hora_entrada, '16:00:00' AS hora_salida, 8 AS horas, '40377832' AS doc UNION ALL
    SELECT '2026-01-27' AS fecha, '09:00:00' AS hora_entrada, '17:00:00' AS hora_salida, 8.5 AS horas, '40388950' AS doc UNION ALL
    SELECT '2026-03-02' AS fecha, '06:00:00' AS hora_entrada, '14:00:00' AS hora_salida, 7 AS horas, '40400068' AS doc UNION ALL
    SELECT '2026-05-05' AS fecha, '07:00:00' AS hora_entrada, '15:00:00' AS hora_salida, 7.5 AS horas, '40411186' AS doc UNION ALL
    SELECT '2026-01-08' AS fecha, '08:00:00' AS hora_entrada, '16:00:00' AS hora_salida, 8 AS horas, '40422304' AS doc UNION ALL
    SELECT '2026-03-11' AS fecha, '09:00:00' AS hora_entrada, '17:00:00' AS hora_salida, 8.5 AS horas, '40433422' AS doc UNION ALL
    SELECT '2026-05-14' AS fecha, '06:00:00' AS hora_entrada, '14:00:00' AS hora_salida, 7 AS horas, '40000000' AS doc UNION ALL
    SELECT '2026-01-17' AS fecha, '07:00:00' AS hora_entrada, '15:00:00' AS hora_salida, 7.5 AS horas, '40011118' AS doc UNION ALL
    SELECT '2026-03-20' AS fecha, '08:00:00' AS hora_entrada, '16:00:00' AS hora_salida, 8 AS horas, '40022236' AS doc UNION ALL
    SELECT '2026-05-23' AS fecha, '09:00:00' AS hora_entrada, '17:00:00' AS hora_salida, 8.5 AS horas, '40033354' AS doc UNION ALL
    SELECT '2026-01-26' AS fecha, '06:00:00' AS hora_entrada, '14:00:00' AS hora_salida, 7 AS horas, '40044472' AS doc UNION ALL
    SELECT '2026-03-01' AS fecha, '07:00:00' AS hora_entrada, '15:00:00' AS hora_salida, 7.5 AS horas, '40055590' AS doc UNION ALL
    SELECT '2026-05-04' AS fecha, '08:00:00' AS hora_entrada, '16:00:00' AS hora_salida, 8 AS horas, '40066708' AS doc UNION ALL
    SELECT '2026-01-07' AS fecha, '09:00:00' AS hora_entrada, '17:00:00' AS hora_salida, 8.5 AS horas, '40077826' AS doc UNION ALL
    SELECT '2026-03-10' AS fecha, '06:00:00' AS hora_entrada, '14:00:00' AS hora_salida, 7 AS horas, '40088944' AS doc UNION ALL
    SELECT '2026-05-13' AS fecha, '07:00:00' AS hora_entrada, '15:00:00' AS hora_salida, 7.5 AS horas, '40100062' AS doc
) d
JOIN obreros o ON o.documento = d.doc
CROSS JOIN (SELECT id_obra FROM obras WHERE numero_contrata = 'CTR-001' LIMIT 1) ob
WHERE COALESCE(@capataz_id, @admin_id) IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM registros r
      WHERE r.fecha = d.fecha AND r.id_obrero = o.id_obrero AND r.id_obra = ob.id_obra
  )
LIMIT 220;

-- ===== RECURSOS =====
SET @r1 = (SELECT id_registro FROM registros ORDER BY id_registro ASC LIMIT 1);

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Cemento Portland', 40, 9800, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;
INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Hierro ADN 420', 120, 1450, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;
INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Arena lavada', 18, 42000, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;
INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Piedra partida 6-20', 12, 35000, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;
INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Cal hidraulica', 25, 5600, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;
INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Malla electrosoldada', 80, 2200, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;
INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Ladrillo hueco 12x18x33', 5000, 180, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;
INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Membrana hidrofuga', 35, 4800, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;
INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Clavos de 2 pulgadas', 15, 850, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;
INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Alambre de atar N16', 20, 1200, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;
INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Viga de madera 3x4', 50, 3200, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;
INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Arena de rio', 20, 28000, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;
INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Pintura latex blanca', 60, 12500, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;
INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Pintura latex celeste', 45, 12500, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;
INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Enduido plastico', 30, 4200, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;
INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Ceramica esmaltada 40x40', 120, 2800, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;
INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Pegamento para ceramica', 25, 1800, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;
INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Pastina blanca', 10, 980, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;
INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Yeso Paris', 30, 1500, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;
INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Alambre tejido romboidal', 40, 3600, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;
INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Bloque de cemento 13x19x39', 600, 350, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;
INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Vidrio templado 8mm', 20, 8500, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;
INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Caño estructural 50x30', 75, 5800, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;
INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Perfil C 80x40', 45, 9200, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;
INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Chapas trapezoidales 5m', 40, 15000, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;
INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Canalon de chapa galvanizada', 30, 4200, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;
INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Teja colonial', 800, 220, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;
INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Adhesivo para PVC', 8, 3500, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;
INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Caño de PVC 110mm', 60, 2400, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;
INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Cable unipolar 2.5mm', 500, 780, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;
INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Llave termica 2x25A', 15, 3200, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;
INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Tomacorriente doble', 40, 1200, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;
INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Tablero electrico 12 polos', 5, 8500, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;
INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Caño de polipropileno 20mm', 200, 450, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;
INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Grifería mezcladora', 10, 12000, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;
INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Inodoro pedestal', 12, 18000, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;
INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Lavatorio de pedestal', 12, 9500, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;
INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Puerta placa interior 80cm', 15, 16000, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;
INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Marco metalico 80cm', 15, 4500, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;
INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Ventana de aluminio 1.2x1.2m', 20, 22000, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;
INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Calefon a gas 14L', 5, 45000, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;
INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Revestimiento piedra natural', 80, 3800, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;
INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Bacha de acero inoxidable', 8, 15000, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;
INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Mesada de granito 1.8m', 6, 35000, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;
INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Flete de materiales', 1, 25000, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;
INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Contenedor de escombros', 3, 18000, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;
INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Acero inoxidable perfil L', 30, 6800, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;
INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Impermeabilizante Sika 20L', 15, 22000, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;
INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Sellador de juntas', 12, 2800, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;
INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Luminaria LED panel 40W', 50, 4500, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;
INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Reflector LED 200W', 10, 8500, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;
INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Reja metalica desplegada', 25, 7500, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;
INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Perfil aluminio 3m', 40, 5200, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;
INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Tanque de agua 1000L', 8, 18000, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;
INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Bomba centrifuga 1HP', 6, 32000, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;
INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Cable subterraneo 6mm', 300, 1500, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;
INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Pintura asfaltica 20L', 10, 18000, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;
INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Geotextil no tejido 200gr', 200, 320, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;
INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Tubo corrugado 200mm', 80, 1800, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Cemento Portland', 40, 9800, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Hierro ADN 420', 120, 1450, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Arena lavada', 18, 42000, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Piedra partida 6-20', 12, 35000, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Cal hidraulica', 25, 5600, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Malla electrosoldada', 80, 2200, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Ladrillo hueco 12x18x33', 5000, 180, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Membrana hidrofuga', 35, 4800, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Clavos de 2 pulgadas', 15, 850, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Alambre de atar N16', 20, 1200, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Viga de madera 3x4', 50, 3200, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Arena de rio', 20, 28000, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Pintura latex blanca', 60, 12500, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Pintura latex celeste', 45, 12500, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Enduido plastico', 30, 4200, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Ceramica esmaltada 40x40', 120, 2800, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Pegamento para ceramica', 25, 1800, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Pastina blanca', 10, 980, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Yeso Paris', 30, 1500, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Alambre tejido romboidal', 40, 3600, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Bloque de cemento 13x19x39', 600, 350, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Vidrio templado 8mm', 20, 8500, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Caño estructural 50x30', 75, 5800, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Perfil C 80x40', 45, 9200, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Chapas trapezoidales 5m', 40, 15000, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Canalon de chapa galvanizada', 30, 4200, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Teja colonial', 800, 220, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Adhesivo para PVC', 8, 3500, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Caño de PVC 110mm', 60, 2400, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Cable unipolar 2.5mm', 500, 780, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Llave termica 2x25A', 15, 3200, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Tomacorriente doble', 40, 1200, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Tablero electrico 12 polos', 5, 8500, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Caño de polipropileno 20mm', 200, 450, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Grifería mezcladora', 10, 12000, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Inodoro pedestal', 12, 18000, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Lavatorio de pedestal', 12, 9500, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Puerta placa interior 80cm', 15, 16000, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Marco metalico 80cm', 15, 4500, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Ventana de aluminio 1.2x1.2m', 20, 22000, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Calefon a gas 14L', 5, 45000, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Revestimiento piedra natural', 80, 3800, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Bacha de acero inoxidable', 8, 15000, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Mesada de granito 1.8m', 6, 35000, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Flete de materiales', 1, 25000, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Contenedor de escombros', 3, 18000, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Acero inoxidable perfil L', 30, 6800, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Impermeabilizante Sika 20L', 15, 22000, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Sellador de juntas', 12, 2800, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Luminaria LED panel 40W', 50, 4500, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Reflector LED 200W', 10, 8500, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Reja metalica desplegada', 25, 7500, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Perfil aluminio 3m', 40, 5200, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Tanque de agua 1000L', 8, 18000, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Bomba centrifuga 1HP', 6, 32000, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Cable subterraneo 6mm', 300, 1500, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Pintura asfaltica 20L', 10, 18000, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Geotextil no tejido 200gr', 200, 320, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Tubo corrugado 200mm', 80, 1800, 1
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Amoladora angular 7\"', 1, 0
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Martillo demoledor', 2, 0
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Taladro percutor', 3, 0
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Sierra circular 7-1/4\"', 4, 0
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Vibrador de hormigon', 5, 0
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Rodillo profesional 25cm', 6, 0
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Lijadora orbital', 7, 0
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Hidrolavadora 2000PSI', 8, 0
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Generador electrico 3kVA', 9, 0
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Escalera extensible 6m', 10, 0
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Andamio tubular 2 cuerpos', 11, 0
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Mezcladora de pintura', 12, 0
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Pistola de calor', 13, 0
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Detector de metales', 14, 0
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Cortadora de ceramica', 15, 0
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Pulidora angular', 16, 0
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Llave de impacto', 17, 0
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Compresor portatil', 18, 0
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Rotomartillo SDS', 19, 0
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, es_material)
SELECT ob.id_obra, @r1, '2026-03-03', 'Nivel laser rotativo', 20, 0
FROM obras ob WHERE ob.numero_contrata = 'CTR-001' LIMIT 1;

-- ===== OBRA_MAQUINARIA (30) =====
INSERT INTO obra_maquinaria (id_obra, id_maquinaria, fecha_asignacion, fecha_retiro)
SELECT ob.id_obra, m.id_maquinaria, '2026-01-15', NULL
FROM (SELECT id_obra FROM obras LIMIT 30) ob
JOIN (SELECT id_maquinaria FROM maquinaria LIMIT 30) m
ON MOD(ob.id_obra, 30) = MOD(m.id_maquinaria, 30)
ON DUPLICATE KEY UPDATE fecha_retiro = VALUES(fecha_retiro);

-- ===== CERTIFICADOS (20, con estados variados) =====
INSERT INTO certificado (archivo, nombre_archivo, id_maquinaria, fecha_vencimiento)
SELECT _binary 'PDF demo', CONCAT('cert_', m.nombre, '.pdf'), m.id_maquinaria,
    CASE
        WHEN m.id_maquinaria % 5 = 0 THEN DATE_SUB(CURDATE(), INTERVAL (m.id_maquinaria + 1) DAY)    -- vencido
        WHEN m.id_maquinaria % 5 = 1 THEN DATE_ADD(CURDATE(), INTERVAL (m.id_maquinaria % 20 + 1) DAY)  -- por vencer (< 30 días)
        WHEN m.id_maquinaria % 5 = 2 THEN DATE_ADD(CURDATE(), INTERVAL (m.id_maquinaria * 3 + 45) DAY)  -- vigente
        WHEN m.id_maquinaria % 5 = 3 THEN DATE_ADD(CURDATE(), INTERVAL (m.id_maquinaria * 8 + 60) DAY)  -- vigente lejano
        ELSE NULL                                                                                         -- sin vencimiento
    END
FROM maquinaria m WHERE m.id_maquinaria <= 20
AND NOT EXISTS (SELECT 1 FROM certificado WHERE id_maquinaria = m.id_maquinaria);

-- ===== ASISTENCIA MAQUINARIA (50) =====
INSERT INTO asistencia_maquinaria (id_obra, id_maquinaria, fecha, hora_salida, hora_devolucion)
SELECT DISTINCT ob.id_obra, m.id_maquinaria, d.fecha, d.hora_salida, d.hora_devolucion
FROM (
    SELECT '2026-01-02' AS fecha, '07:00:00' AS hora_salida, '15:00:00' AS hora_devolucion UNION ALL
    SELECT '2026-01-12' AS fecha, '09:00:00' AS hora_salida, '17:00:00' AS hora_devolucion UNION ALL
    SELECT '2026-01-22' AS fecha, '08:00:00' AS hora_salida, '15:00:00' AS hora_devolucion UNION ALL
    SELECT '2026-02-04' AS fecha, '07:00:00' AS hora_salida, '17:00:00' AS hora_devolucion UNION ALL
    SELECT '2026-02-14' AS fecha, '09:00:00' AS hora_salida, '15:00:00' AS hora_devolucion UNION ALL
    SELECT '2026-02-24' AS fecha, '08:00:00' AS hora_salida, '17:00:00' AS hora_devolucion UNION ALL
    SELECT '2026-03-04' AS fecha, '07:00:00' AS hora_salida, '16:00:00' AS hora_devolucion UNION ALL
    SELECT '2026-03-14' AS fecha, '09:00:00' AS hora_salida, '18:00:00' AS hora_devolucion UNION ALL
    SELECT '2026-03-24' AS fecha, '08:00:00' AS hora_salida, '15:00:00' AS hora_devolucion UNION ALL
    SELECT '2026-04-04' AS fecha, '07:00:00' AS hora_salida, '17:00:00' AS hora_devolucion UNION ALL
    SELECT '2026-04-14' AS fecha, '09:00:00' AS hora_salida, '16:00:00' AS hora_devolucion UNION ALL
    SELECT '2026-04-24' AS fecha, '08:00:00' AS hora_salida, '18:00:00' AS hora_devolucion UNION ALL
    SELECT '2026-05-04' AS fecha, '07:00:00' AS hora_salida, '15:00:00' AS hora_devolucion UNION ALL
    SELECT '2026-05-14' AS fecha, '09:00:00' AS hora_salida, '17:00:00' AS hora_devolucion UNION ALL
    SELECT '2026-05-24' AS fecha, '08:00:00' AS hora_salida, '16:00:00' AS hora_devolucion UNION ALL
    SELECT '2026-06-04' AS fecha, '07:00:00' AS hora_salida, '18:00:00' AS hora_devolucion UNION ALL
    SELECT '2026-06-14' AS fecha, '09:00:00' AS hora_salida, '15:00:00' AS hora_devolucion UNION ALL
    SELECT '2026-06-24' AS fecha, '08:00:00' AS hora_salida, '17:00:00' AS hora_devolucion
) d
CROSS JOIN (SELECT id_obra FROM obras WHERE id_obra BETWEEN 1 AND 3) ob
CROSS JOIN (SELECT id_maquinaria FROM maquinaria WHERE id_maquinaria BETWEEN 1 AND 5) m
WHERE NOT EXISTS (
    SELECT 1 FROM asistencia_maquinaria
    WHERE id_obra = ob.id_obra AND id_maquinaria = m.id_maquinaria AND fecha = d.fecha
)
LIMIT 50;

-- ===== INTENTOS_LOGIN =====
INSERT INTO intentos_login (username, ip_address, fecha, exitoso)
SELECT 'admin', '127.0.0.1', '2026-01-02 06:00:00', 1
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM intentos_login WHERE username = 'admin' AND fecha = '2026-01-02 06:00:00');
INSERT INTO intentos_login (username, ip_address, fecha, exitoso)
SELECT 'capataz', '127.0.0.1', '2026-02-06 07:03:00', 1
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM intentos_login WHERE username = 'capataz' AND fecha = '2026-02-06 07:03:00');
INSERT INTO intentos_login (username, ip_address, fecha, exitoso)
SELECT 'admin', '127.0.0.1', '2026-03-10 08:06:00', 1
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM intentos_login WHERE username = 'admin' AND fecha = '2026-03-10 08:06:00');
INSERT INTO intentos_login (username, ip_address, fecha, exitoso)
SELECT 'capataz', '127.0.0.1', '2026-04-14 09:09:00', 1
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM intentos_login WHERE username = 'capataz' AND fecha = '2026-04-14 09:09:00');
INSERT INTO intentos_login (username, ip_address, fecha, exitoso)
SELECT 'admin', '127.0.0.1', '2026-05-18 10:12:00', 1
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM intentos_login WHERE username = 'admin' AND fecha = '2026-05-18 10:12:00');
INSERT INTO intentos_login (username, ip_address, fecha, exitoso)
SELECT 'capataz', '127.0.0.1', '2026-06-22 11:15:00', 1
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM intentos_login WHERE username = 'capataz' AND fecha = '2026-06-22 11:15:00');
INSERT INTO intentos_login (username, ip_address, fecha, exitoso)
SELECT 'admin', '127.0.0.1', '2026-01-26 12:18:00', 1
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM intentos_login WHERE username = 'admin' AND fecha = '2026-01-26 12:18:00');
INSERT INTO intentos_login (username, ip_address, fecha, exitoso)
SELECT 'capataz', '127.0.0.1', '2026-02-02 13:21:00', 1
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM intentos_login WHERE username = 'capataz' AND fecha = '2026-02-02 13:21:00');
INSERT INTO intentos_login (username, ip_address, fecha, exitoso)
SELECT 'admin', '127.0.0.1', '2026-03-06 14:24:00', 1
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM intentos_login WHERE username = 'admin' AND fecha = '2026-03-06 14:24:00');
INSERT INTO intentos_login (username, ip_address, fecha, exitoso)
SELECT 'capataz', '127.0.0.1', '2026-04-10 15:27:00', 1
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM intentos_login WHERE username = 'capataz' AND fecha = '2026-04-10 15:27:00');
INSERT INTO intentos_login (username, ip_address, fecha, exitoso)
SELECT 'admin', '127.0.0.1', '2026-05-14 16:30:00', 1
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM intentos_login WHERE username = 'admin' AND fecha = '2026-05-14 16:30:00');
INSERT INTO intentos_login (username, ip_address, fecha, exitoso)
SELECT 'capataz', '127.0.0.1', '2026-06-18 17:33:00', 1
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM intentos_login WHERE username = 'capataz' AND fecha = '2026-06-18 17:33:00');
INSERT INTO intentos_login (username, ip_address, fecha, exitoso)
SELECT 'admin', '127.0.0.1', '2026-01-22 06:36:00', 1
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM intentos_login WHERE username = 'admin' AND fecha = '2026-01-22 06:36:00');
INSERT INTO intentos_login (username, ip_address, fecha, exitoso)
SELECT 'capataz', '127.0.0.1', '2026-02-26 07:39:00', 1
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM intentos_login WHERE username = 'capataz' AND fecha = '2026-02-26 07:39:00');
INSERT INTO intentos_login (username, ip_address, fecha, exitoso)
SELECT 'admin', '127.0.0.1', '2026-03-02 08:42:00', 1
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM intentos_login WHERE username = 'admin' AND fecha = '2026-03-02 08:42:00');
INSERT INTO intentos_login (username, ip_address, fecha, exitoso)
SELECT 'capataz', '127.0.0.1', '2026-04-06 09:45:00', 1
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM intentos_login WHERE username = 'capataz' AND fecha = '2026-04-06 09:45:00');
INSERT INTO intentos_login (username, ip_address, fecha, exitoso)
SELECT 'admin', '127.0.0.1', '2026-05-10 10:48:00', 1
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM intentos_login WHERE username = 'admin' AND fecha = '2026-05-10 10:48:00');
INSERT INTO intentos_login (username, ip_address, fecha, exitoso)
SELECT 'capataz', '127.0.0.1', '2026-06-14 11:51:00', 1
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM intentos_login WHERE username = 'capataz' AND fecha = '2026-06-14 11:51:00');
INSERT INTO intentos_login (username, ip_address, fecha, exitoso)
SELECT 'admin', '127.0.0.1', '2026-01-18 12:54:00', 0
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM intentos_login WHERE username = 'admin' AND fecha = '2026-01-18 12:54:00');
INSERT INTO intentos_login (username, ip_address, fecha, exitoso)
SELECT 'capataz', '127.0.0.1', '2026-02-22 13:57:00', 0
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM intentos_login WHERE username = 'capataz' AND fecha = '2026-02-22 13:57:00');

-- ===== CONTRATOS OBRAS (20) =====
INSERT INTO contratos (id_obra, archivo, nombre_archivo, fecha_subida)
SELECT ob.id_obra, _binary 'PDF demo', CONCAT('contrato-', ob.numero_contrata, '.pdf'), ob.fecha_inicio
FROM obras ob WHERE ob.id_obra <= 20
AND NOT EXISTS (SELECT 1 FROM contratos WHERE id_obra = ob.id_obra AND nombre_archivo = CONCAT('contrato-', ob.numero_contrata, '.pdf'));

COMMIT;

