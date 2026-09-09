-- phpMyAdmin SQL Dump
-- version 5.2.0
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1:3306
-- Generation Time: Sep 01, 2026 at 11:06 PM
-- Server version: 8.0.31
-- PHP Version: 8.0.26

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `portico`
--

-- --------------------------------------------------------

--
-- Table structure for table `asistencia_maquinaria`
--

DROP TABLE IF EXISTS `asistencia_maquinaria`;
CREATE TABLE IF NOT EXISTS `asistencia_maquinaria` (
  `id` int NOT NULL AUTO_INCREMENT,
  `id_obra` int NOT NULL,
  `id_maquinaria` int NOT NULL,
  `fecha` date NOT NULL,
  `hora_salida` time NOT NULL,
  `hora_devolucion` time DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_asistencia_maquinaria` (`id_obra`,`id_maquinaria`,`fecha`),
  KEY `id_maquinaria` (`id_maquinaria`)
) ENGINE=MyISAM AUTO_INCREMENT=9 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping data for table `asistencia_maquinaria`
--

INSERT INTO `asistencia_maquinaria` (`id`, `id_obra`, `id_maquinaria`, `fecha`, `hora_salida`, `hora_devolucion`) VALUES
(1, 1, 3, '2026-06-26', '08:00:00', '12:00:00'),
(2, 1, 1, '2026-06-26', '08:00:00', '14:09:00'),
(3, 3, 1, '2026-06-26', '10:00:00', '15:00:00'),
(4, 1, 2, '2026-06-26', '10:00:00', '15:00:00'),
(5, 3, 2, '2026-06-30', '13:03:00', '17:00:00'),
(6, 2, 3, '2026-06-30', '08:00:00', '19:00:00'),
(7, 1, 3, '2026-06-30', '10:00:00', '14:00:00'),
(8, 3, 3, '2026-06-30', '10:00:00', '17:00:00');

-- --------------------------------------------------------

--
-- Table structure for table `auditoria_logs`
--

DROP TABLE IF EXISTS `auditoria_logs`;
CREATE TABLE IF NOT EXISTS `auditoria_logs` (
  `id_log` int NOT NULL AUTO_INCREMENT,
  `id_usuario` int DEFAULT NULL,
  `usuario` varchar(50) DEFAULT NULL,
  `rol` varchar(20) DEFAULT NULL,
  `accion` varchar(20) NOT NULL,
  `entidad` varchar(50) NOT NULL,
  `entidad_id` int DEFAULT NULL,
  `detalle_json` text,
  `ip_address` varchar(45) DEFAULT NULL,
  `created_at` datetime NOT NULL,
  PRIMARY KEY (`id_log`),
  KEY `idx_accion` (`accion`),
  KEY `idx_entidad` (`entidad`),
  KEY `idx_created_at` (`created_at`),
  KEY `id_usuario` (`id_usuario`)
) ENGINE=MyISAM AUTO_INCREMENT=15 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping data for table `auditoria_logs`
--

INSERT INTO `auditoria_logs` (`id_log`, `id_usuario`, `usuario`, `rol`, `accion`, `entidad`, `entidad_id`, `detalle_json`, `ip_address`, `created_at`) VALUES
(1, 1, 'admin', 'Administrador', 'login', 'auth', 1, '{\"usuario\":\"admin\"}', '::1', '2026-08-21 16:14:32'),
(2, 1, 'admin', 'Administrador', 'login', 'auth', 1, '{\"usuario\":\"admin\"}', '::1', '2026-08-22 17:06:25'),
(3, 1, 'admin', 'Administrador', 'login', 'auth', 1, '{\"usuario\":\"admin\"}', '::1', '2026-08-23 18:45:30'),
(4, 1, 'admin', 'Administrador', 'login', 'auth', 1, '{\"usuario\":\"admin\"}', '::1', '2026-08-24 20:29:59'),
(5, 1, 'admin', 'Administrador', 'login', 'auth', 1, '{\"usuario\":\"admin\"}', '::1', '2026-08-26 18:33:16'),
(6, 1, 'admin', 'Administrador', 'editar', 'obras', 4, '{\"nombre\":\"Prueba1\",\"contrato_reemplazado\":true,\"tareas_actualizadas\":3}', '::1', '2026-08-26 19:43:51'),
(7, 1, 'admin', 'Administrador', 'crear', 'obras', 4, '{\"nombre\":\"Prueba1\",\"numero_contrata\":\"CTR-004\"}', '::1', '2026-08-26 19:43:51'),
(8, 1, 'admin', 'Administrador', 'editar', 'obras', 5, '{\"nombre\":\"Prueba2\",\"contrato_reemplazado\":true,\"tareas_actualizadas\":3}', '::1', '2026-08-26 20:52:12'),
(9, 1, 'admin', 'Administrador', 'crear', 'obras', 5, '{\"nombre\":\"Prueba2\",\"numero_contrata\":\"CTR-005\"}', '::1', '2026-08-26 20:52:12'),
(10, 1, 'admin', 'Administrador', 'login', 'auth', 1, '{\"usuario\":\"admin\"}', '::1', '2026-09-01 19:16:55'),
(11, 1, 'admin', 'Administrador', 'completar_tarea', 'contrato_tareas', 5, '{\"id_obra\":5,\"descripcion\":\"T2\",\"estado_anterior\":\"Pendiente\",\"estado_nuevo\":\"Completada\"}', '::1', '2026-09-01 19:41:28'),
(12, 1, 'admin', 'Administrador', 'editar', 'obreros', 6, '{\"nombre\":\"Pedro\",\"apellido\":\"Insaurralde\"}', '::1', '2026-09-01 19:46:23'),
(13, 1, 'admin', 'Administrador', 'editar', 'obreros', 6, '{\"nombre\":\"Pedro\",\"apellido\":\"Insaurralde\"}', '::1', '2026-09-01 19:46:39'),
(14, 1, 'admin', 'Administrador', 'guardar', 'asistencia', 2, '{\"id_obra\":2,\"fecha\":\"2026-09-01\",\"obreros\":1,\"materiales\":1,\"herramientas\":0,\"maquinarias\":0,\"combustible_items\":0,\"obra_finalizada\":false}', '::1', '2026-09-01 19:54:33');

-- --------------------------------------------------------

--
-- Table structure for table `certificado`
--

DROP TABLE IF EXISTS `certificado`;
CREATE TABLE IF NOT EXISTS `certificado` (
  `id_certificado` int NOT NULL AUTO_INCREMENT,
  `archivo` longblob NOT NULL,
  `nombre_archivo` varchar(255) DEFAULT NULL,
  `id_maquinaria` int NOT NULL,
  `fecha_vencimiento` date DEFAULT NULL,
  PRIMARY KEY (`id_certificado`),
  KEY `id_maquinaria` (`id_maquinaria`)
) ENGINE=MyISAM AUTO_INCREMENT=7 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping data for table `certificado`
--


-- --------------------------------------------------------

--
-- Table structure for table `combustible`
--

DROP TABLE IF EXISTS `combustible`;
CREATE TABLE IF NOT EXISTS `combustible` (
  `id_combustible` int NOT NULL AUTO_INCREMENT,
  `nombre_combustible` varchar(50) NOT NULL,
  `litros` decimal(10,2) NOT NULL,
  `precio_unitario` decimal(10,2) NOT NULL,
  `precio_total` decimal(12,2) NOT NULL,
  `fecha` date NOT NULL,
  `id_obra` int NOT NULL,
  `id_maquinaria` int NOT NULL,
  `id_factura` int DEFAULT NULL,
  PRIMARY KEY (`id_combustible`),
  KEY `id_obra` (`id_obra`),
  KEY `id_maquinaria` (`id_maquinaria`),
  KEY `id_factura` (`id_factura`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Table structure for table `contratos`
--

DROP TABLE IF EXISTS `contratos`;
CREATE TABLE IF NOT EXISTS `contratos` (
  `id_contrato` int NOT NULL AUTO_INCREMENT,
  `id_obra` int NOT NULL,
  `archivo` longblob NOT NULL,
  `nombre_archivo` varchar(255) DEFAULT NULL,
  `fecha_subida` date NOT NULL,
  `id_contrato_origen` int DEFAULT NULL,
  `estado` enum('Activo','Cerrado') NOT NULL DEFAULT 'Activo',
  `fecha_cierre` date DEFAULT NULL,
  `monto_total` decimal(12,2) NOT NULL DEFAULT '0.00',
  `monto_liquidado` decimal(12,2) NOT NULL DEFAULT '0.00',
  PRIMARY KEY (`id_contrato`),
  KEY `id_obra` (`id_obra`),
  KEY `fk_contrato_origen` (`id_contrato_origen`)
) ENGINE=MyISAM AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping data for table `contratos`
--

INSERT INTO `contratos` (`id_contrato`, `id_obra`, `archivo`, `nombre_archivo`, `fecha_subida`, `id_contrato_origen`, `estado`, `fecha_cierre`, `monto_total`, `monto_liquidado`) VALUES

-- --------------------------------------------------------

--
-- Table structure for table `contrato_obrero`
--

DROP TABLE IF EXISTS `contrato_obrero`;
CREATE TABLE IF NOT EXISTS `contrato_obrero` (
  `id_contrato_obrero` int NOT NULL AUTO_INCREMENT,
  `archivo` longblob NOT NULL,
  `nombre_archivo` varchar(255) DEFAULT NULL,
  `id_obrero` int NOT NULL,
  `fecha_vencimiento` date DEFAULT NULL,
  PRIMARY KEY (`id_contrato_obrero`),
  KEY `id_obrero` (`id_obrero`)
) ENGINE=MyISAM AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping data for table `contrato_obrero`
--

INSERT INTO `contrato_obrero` (`id_contrato_obrero`, `archivo`, `nombre_archivo`, `id_obrero`, `fecha_vencimiento`) VALUES

-- --------------------------------------------------------

--
-- Table structure for table `contrato_tareas`
--

DROP TABLE IF EXISTS `contrato_tareas`;
CREATE TABLE IF NOT EXISTS `contrato_tareas` (
  `id_tarea` int NOT NULL AUTO_INCREMENT,
  `id_contrato` int NOT NULL,
  `id_tarea_origen` int DEFAULT NULL,
  `descripcion` varchar(255) NOT NULL,
  `importe` decimal(12,2) NOT NULL DEFAULT '0.00',
  `estado` enum('Pendiente','Completada') NOT NULL DEFAULT 'Pendiente',
  `fecha_completada` date DEFAULT NULL,
  PRIMARY KEY (`id_tarea`),
  KEY `id_contrato` (`id_contrato`),
  KEY `id_tarea_origen` (`id_tarea_origen`)
) ENGINE=MyISAM AUTO_INCREMENT=7 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping data for table `contrato_tareas`
--

INSERT INTO `contrato_tareas` (`id_tarea`, `id_contrato`, `id_tarea_origen`, `descripcion`, `importe`, `estado`, `fecha_completada`) VALUES
(1, 3, NULL, 'Tarea1', '110.00', 'Pendiente', NULL),
(2, 3, NULL, 'Tarea2', '200.00', 'Pendiente', NULL),
(3, 3, NULL, 'Tarea3', '300.00', 'Pendiente', NULL),
(4, 4, NULL, 'T1', '50.00', 'Pendiente', NULL),
(5, 4, NULL, 'T2', '100.00', 'Completada', '2026-09-01'),
(6, 4, NULL, 'T3', '340.00', 'Pendiente', NULL);

-- --------------------------------------------------------

--
-- Table structure for table `costos_generales`
--

DROP TABLE IF EXISTS `costos_generales`;
CREATE TABLE IF NOT EXISTS `costos_generales` (
  `id_costo_general` int NOT NULL AUTO_INCREMENT,
  `concepto` varchar(150) NOT NULL,
  `categoria` enum('Fijo','Variable') NOT NULL,
  `periodo` date NOT NULL,
  `monto` decimal(12,2) NOT NULL,
  `fecha_registro` date NOT NULL,
  `id_usuario` int NOT NULL,
  PRIMARY KEY (`id_costo_general`),
  KEY `id_usuario` (`id_usuario`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Table structure for table `intentos_login`
--

DROP TABLE IF EXISTS `intentos_login`;
CREATE TABLE IF NOT EXISTS `intentos_login` (
  `id` int NOT NULL AUTO_INCREMENT,
  `username` varchar(50) NOT NULL,
  `ip_address` varchar(45) NOT NULL,
  `fecha` datetime NOT NULL,
  `exitoso` tinyint(1) DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `idx_username_fecha` (`username`,`fecha`),
  KEY `idx_ip_fecha` (`ip_address`,`fecha`)
) ENGINE=MyISAM AUTO_INCREMENT=45 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping data for table `intentos_login`
--

INSERT INTO `intentos_login` (`id`, `username`, `ip_address`, `fecha`, `exitoso`) VALUES
(1, 'admin', '127.0.0.1', '2026-03-01 08:30:00', 1),
(2, 'capataz', '127.0.0.1', '2026-03-02 07:55:00', 1),
(3, 'capataz', '::1', '2026-06-23 21:09:51', 1),
(4, 'capataz', '::1', '2026-06-26 12:22:01', 1),
(5, 'admin', '::1', '2026-06-26 12:49:28', 1),
(6, 'capataz', '::1', '2026-06-26 13:55:20', 1),
(7, 'capataz', '::1', '2026-06-26 14:10:03', 1),
(8, 'admin', '::1', '2026-06-26 14:11:27', 1),
(9, 'capataz', '::1', '2026-06-26 17:14:40', 1),
(10, 'admin123', '::1', '2026-06-26 17:24:31', 0),
(11, 'admin', '::1', '2026-06-26 17:24:40', 1),
(12, 'capataz', '::1', '2026-06-26 17:33:47', 1),
(13, 'admin', '::1', '2026-06-26 17:34:47', 1),
(14, 'capataz', '::1', '2026-06-26 17:42:15', 0),
(15, 'capataz', '::1', '2026-06-26 17:42:22', 1),
(16, 'admin', '::1', '2026-06-26 17:49:44', 1),
(17, 'capataz', '::1', '2026-06-29 20:11:56', 1),
(18, 'admin', '::1', '2026-06-29 20:15:39', 1),
(19, 'capataz', '::1', '2026-06-29 20:33:12', 1),
(20, 'admin', '::1', '2026-06-29 20:35:37', 1),
(21, 'admin', '::1', '2026-06-30 14:02:17', 1),
(22, 'capataz', '::1', '2026-06-30 14:02:33', 1),
(23, 'capataz', '::1', '2026-06-30 14:07:06', 1),
(24, 'captaz', '::1', '2026-06-30 14:08:14', 0),
(25, 'capataz', '::1', '2026-06-30 14:08:34', 1),
(26, 'admin', '::1', '2026-06-30 14:12:57', 1),
(27, 'admin', '::1', '2026-06-30 17:48:53', 1),
(28, 'capataz', '::1', '2026-06-30 18:03:49', 1),
(29, 'admin', '::1', '2026-06-30 18:13:36', 1),
(30, 'capataz', '::1', '2026-06-30 19:08:24', 1),
(31, 'admin', '::1', '2026-06-30 19:24:11', 1),
(32, 'capataz', '::1', '2026-06-30 19:49:21', 1),
(33, 'admin', '::1', '2026-06-30 20:02:46', 1),
(34, 'capataz', '::1', '2026-06-30 20:09:00', 1),
(35, 'admin', '::1', '2026-06-30 20:41:14', 1),
(36, 'capataz', '::1', '2026-06-30 21:42:26', 1),
(37, 'admin', '::1', '2026-06-30 21:48:16', 1),
(38, 'admin', '::1', '2026-07-01 18:44:47', 1),
(39, 'admin', '::1', '2026-08-21 16:14:32', 1),
(40, 'admin', '::1', '2026-08-22 17:06:25', 1),
(41, 'admin', '::1', '2026-08-23 18:45:30', 1),
(42, 'admin', '::1', '2026-08-24 20:29:59', 1),
(43, 'admin', '::1', '2026-08-26 18:33:16', 1),
(44, 'admin', '::1', '2026-09-01 19:16:55', 1);

-- --------------------------------------------------------

--
-- Table structure for table `maquinaria`
--

DROP TABLE IF EXISTS `maquinaria`;
CREATE TABLE IF NOT EXISTS `maquinaria` (
  `id_maquinaria` int NOT NULL AUTO_INCREMENT,
  `nombre` varchar(150) NOT NULL,
  `marca` varchar(100) DEFAULT NULL,
  PRIMARY KEY (`id_maquinaria`)
) ENGINE=MyISAM AUTO_INCREMENT=8 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping data for table `maquinaria`
--

INSERT INTO `maquinaria` (`id_maquinaria`, `nombre`, `marca`) VALUES
(1, 'Retroexcavadora 320D', 'Caterpillar'),
(2, 'Hormigonera H-250', 'SthilmaqAAA'),
(3, 'Compactador CV-90', 'Wacker Neuson'),
(4, 'ff', 'ter'),
(5, 'gg', 'gfsg'),
(6, 'rr', 'yyy'),
(7, 'EE', 'DD');

-- --------------------------------------------------------

--
-- Table structure for table `obras`
--

DROP TABLE IF EXISTS `obras`;
CREATE TABLE IF NOT EXISTS `obras` (
  `id_obra` int NOT NULL AUTO_INCREMENT,
  `numero_contrata` varchar(50) NOT NULL,
  `nombre` varchar(150) NOT NULL,
  `direccion` varchar(200) DEFAULT NULL,
  `descripcion` text,
  `fecha_inicio` date DEFAULT NULL,
  `fecha_fin` date DEFAULT NULL,
  `nombre_cliente` varchar(150) NOT NULL,
  `telefono_cliente` varchar(30) DEFAULT NULL,
  `activo` tinyint(1) DEFAULT '1',
  PRIMARY KEY (`id_obra`),
  UNIQUE KEY `numero_contrata` (`numero_contrata`)
) ENGINE=MyISAM AUTO_INCREMENT=6 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping data for table `obras`
--

INSERT INTO `obras` (`id_obra`, `numero_contrata`, `nombre`, `direccion`, `descripcion`, `fecha_inicio`, `fecha_fin`, `nombre_cliente`, `telefono_cliente`, `activo`) VALUES
(1, 'CTR-001', 'Edificio Costanera Norte', 'Av. Costanera 1540, Posadas', 'Construccion de edificio administrativo y deposito.', '2026-01-15', '2026-12-20', 'Municipalidad de Posadas', '3764-555001', 1),
(2, 'CTR-002', 'Pavimentacion Barrio San Jorge', 'Barrio San Jorge, Posadas', 'Pavimentacion y mejora de desagues pluviales.', '2026-02-10', '2026-09-30', 'Instituto Provincial de Desarrollo Habitacional', '3764-555002', 1),
(3, 'CTR-003', 'Refaccion Escuela N 42', 'Calle 12 esq. 45, Garupa', 'Refaccion integral de aulas y patio cubierto.', '2026-04-01', NULL, 'Consejo General de Educacion', '3764-555003', 1),
(4, 'CTR-004', 'Prueba1', 'Direccion1', 'Prueba con los datos de actividades', '2026-08-26', NULL, 'Cliente1', '12345678', 1),
(5, 'CTR-005', 'Prueba2', 'Direccion2', 'Prueba de codigo2', '2026-08-26', NULL, 'Cliente2', '987654321', 1);

-- --------------------------------------------------------

--
-- Table structure for table `obra_maquinaria`
--

DROP TABLE IF EXISTS `obra_maquinaria`;
CREATE TABLE IF NOT EXISTS `obra_maquinaria` (
  `id_obra_maquinaria` int NOT NULL AUTO_INCREMENT,
  `id_obra` int NOT NULL,
  `id_maquinaria` int NOT NULL,
  `fecha_asignacion` date DEFAULT NULL,
  `fecha_retiro` date DEFAULT NULL,
  PRIMARY KEY (`id_obra_maquinaria`),
  UNIQUE KEY `uq_obra_maquinaria` (`id_obra`,`id_maquinaria`,`fecha_asignacion`),
  KEY `id_maquinaria` (`id_maquinaria`)
) ENGINE=MyISAM AUTO_INCREMENT=14 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping data for table `obra_maquinaria`
--

INSERT INTO `obra_maquinaria` (`id_obra_maquinaria`, `id_obra`, `id_maquinaria`, `fecha_asignacion`, `fecha_retiro`) VALUES
(1, 1, 1, '2026-01-20', NULL),
(2, 1, 2, '2026-02-05', NULL),
(3, 2, 3, '2026-02-20', NULL),
(4, 3, 2, '2026-04-05', NULL),
(5, 3, 3, '2026-06-26', NULL),
(6, 2, 3, '2026-06-26', NULL),
(7, 1, 3, '2026-06-26', NULL),
(8, 1, 1, '2026-06-26', NULL),
(9, 3, 1, '2026-06-26', NULL),
(10, 1, 2, '2026-06-26', NULL),
(11, 3, 2, '2026-06-30', NULL),
(12, 2, 3, '2026-06-30', NULL),
(13, 1, 3, '2026-06-30', NULL);

-- --------------------------------------------------------

--
-- Table structure for table `obreros`
--

DROP TABLE IF EXISTS `obreros`;
CREATE TABLE IF NOT EXISTS `obreros` (
  `id_obrero` int NOT NULL AUTO_INCREMENT,
  `nombre` varchar(150) NOT NULL,
  `apellido` varchar(100) DEFAULT NULL,
  `documento` varchar(30) NOT NULL,
  `telefono` varchar(30) DEFAULT NULL,
  `fecha_contratacion` date DEFAULT NULL,
  `fecha_fin` date DEFAULT NULL,
  `activo` tinyint(1) DEFAULT '1',
  `cargo` enum('Albañil','Capataz','Electricista','Plomero','Pintor','Carpintero','Soldador','Operador de maquinaria','Peón','Otro') NOT NULL DEFAULT 'Peón',
  PRIMARY KEY (`id_obrero`),
  UNIQUE KEY `documento` (`documento`)
) ENGINE=MyISAM AUTO_INCREMENT=10 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping data for table `obreros`
--

INSERT INTO `obreros` (`id_obrero`, `nombre`, `apellido`, `documento`, `telefono`, `fecha_contratacion`, `fecha_fin`, `activo`, `cargo`) VALUES
(1, 'Luis', 'Benitez', '40111222', '3764-600101', '2025-11-10', '2026-03-15', 1, 'Peón'),
(2, 'Carlos', 'Gomez', '38999111', '3764-600102', '2025-10-05', '2026-04-22', 1, 'Peón'),
(3, 'Miguel', 'Rojas', '41222333', '3764-600103', '2026-01-08', '2026-07-02', 1, 'Peón'),
(4, 'Jorge', 'Ferreyra', '37888444', '3764-600104', '2026-02-01', '2026-08-07', 1, 'Peón'),
(5, 'Ramon', 'Acosta', '42333444', '3764-600105', '2026-03-01', '2026-07-05', 1, 'Peón'),
(6, 'Pedro', 'Insaurralde', '43444555', '3764-600106', '2026-04-10', '2026-09-18', 1, 'Peón'),
(7, 'JUAN', 'CARLOS', '765431122', '786543', '0444-03-03', '0044-04-04', 0, 'Peón'),
(8, 'Irina', 'Muñoz Braceiro', '8765437777', '5444545', '2026-04-01', '2027-03-23', 0, 'Operador de maquinaria'),
(9, 'FF', 'RRR', '654', '45656', '2026-09-19', '2027-07-23', 1, 'Albañil');

-- --------------------------------------------------------

--
-- Table structure for table `partes_diarios`
--

DROP TABLE IF EXISTS `partes_diarios`;
CREATE TABLE IF NOT EXISTS `partes_diarios` (
  `id_parte` int NOT NULL AUTO_INCREMENT,
  `id_obra` int NOT NULL,
  `id_maquinaria` int NOT NULL,
  `id_usuario` int NOT NULL,
  `fecha` date NOT NULL,
  `horas_trabajadas` decimal(5,2) DEFAULT '0.00',
  `horas_paradas` decimal(5,2) DEFAULT '0.00',
  `litros_combustible` decimal(10,2) DEFAULT '0.00',
  `observaciones` text,
  PRIMARY KEY (`id_parte`),
  KEY `id_obra` (`id_obra`),
  KEY `id_maquinaria` (`id_maquinaria`),
  KEY `id_usuario` (`id_usuario`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Table structure for table `recursos`
--

DROP TABLE IF EXISTS `recursos`;
CREATE TABLE IF NOT EXISTS `recursos` (
  `id_recurso` int NOT NULL AUTO_INCREMENT,
  `id_obra` int NOT NULL,
  `id_registro` int DEFAULT NULL,
  `fecha` date NOT NULL,
  `nombre` varchar(150) NOT NULL,
  `cantidad` decimal(10,2) NOT NULL,
  `precio_unitario` decimal(10,2) DEFAULT NULL,
  `es_material` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id_recurso`),
  KEY `id_obra` (`id_obra`),
  KEY `id_registro` (`id_registro`)
) ENGINE=MyISAM AUTO_INCREMENT=50 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping data for table `recursos`
--

INSERT INTO `recursos` (`id_recurso`, `id_obra`, `id_registro`, `fecha`, `nombre`, `cantidad`, `precio_unitario`, `es_material`) VALUES
(1, 1, 1, '2026-03-03', 'Cemento Portland', '40.00', '9800.00', 1),
(2, 1, 1, '2026-03-03', 'Hierro ADN 420', '120.00', '1450.00', 1),
(3, 2, 13, '2026-03-06', 'Arena lavada', '18.00', '42000.00', 1),
(4, 2, 13, '2026-03-06', 'Piedra partida', '12.00', '35000.00', 1),
(5, 3, 19, '2026-04-02', 'Pintura latex blanca', '60.00', '12500.00', 1),
(6, 1, 1, '2026-03-03', 'Amoladora angular', '2.00', NULL, 0),
(7, 1, 3, '2026-03-04', 'Martillo demoledor', '1.00', NULL, 0),
(8, 2, 13, '2026-03-06', 'Vibrador de hormigon', '1.00', NULL, 0),
(9, 3, 19, '2026-04-02', 'Rodillo profesional', '3.00', NULL, 0),
(10, 3, NULL, '2026-06-26', 'Arena lavada', '20.00', '12.00', 1),
(11, 3, NULL, '2026-06-26', 'Hierro ADN 420', '12.00', '30.00', 1),
(12, 3, NULL, '2026-06-26', 'Ladrillos', '50.00', '10.00', 1),
(13, 3, NULL, '2026-06-26', 'Amoladora angular', '2.00', NULL, 0),
(14, 3, NULL, '2026-06-26', 'Vibrador de hormigon', '5.00', NULL, 0),
(15, 3, NULL, '2026-06-26', 'Elevador de carga', '1.00', NULL, 0),
(16, 2, NULL, '2026-06-26', 'Hierro ADN 420', '22.00', '12.00', 1),
(17, 2, NULL, '2026-06-26', 'Arena lavada', '10.00', '5.00', 1),
(18, 2, NULL, '2026-06-26', 'Portland', '4.00', '12.00', 1),
(19, 2, NULL, '2026-06-26', 'Amoladora angular', '11.00', NULL, 0),
(20, 2, NULL, '2026-06-26', 'Grua', '1.00', NULL, 0),
(21, 1, NULL, '2026-06-26', 'Hierro ADN 420', '12.00', '1.00', 1),
(22, 1, NULL, '2026-06-26', 'Martillo demoledor', '3.00', NULL, 0),
(23, 1, NULL, '2026-06-26', 'Amoladora angular', '3.00', NULL, 0),
(24, 1, NULL, '2026-06-26', 'Arena lavada', '20.00', '1.00', 1),
(25, 1, NULL, '2026-06-26', 'Vibrador de hormigon', '20.00', NULL, 0),
(26, 1, NULL, '2026-06-26', 'Hierro ADN 420', '20.00', '10.00', 1),
(27, 1, NULL, '2026-06-26', 'Piedra partida', '10.00', '15.00', 1),
(28, 1, NULL, '2026-06-26', 'Vibrador de hormigon', '2.00', NULL, 0),
(29, 3, NULL, '2026-06-26', 'Hierro ADN 420', '2.00', '54.00', 1),
(30, 3, NULL, '2026-06-26', 'Martillo demoledor', '2.00', NULL, 0),
(31, 1, NULL, '2026-06-26', 'Hierro ADN 420', '12.00', '8.00', 1),
(32, 1, NULL, '2026-06-26', 'Rodillo profesional', '2.00', NULL, 0),
(33, 3, NULL, '2026-06-30', 'Hierro ADN 420', '3.00', '12.00', 1),
(34, 3, NULL, '2026-06-30', 'Amoladora angular', '3.00', NULL, 0),
(35, 2, NULL, '2026-06-30', 'Cemento Portland', '3.00', '1.00', 1),
(36, 2, NULL, '2026-06-30', 'Martillo demoledor', '5.00', NULL, 0),
(37, 2, NULL, '2026-06-30', 'Hierro ADN 420', '3.00', '1.00', 1),
(38, 2, NULL, '2026-06-30', 'Rodillo profesional', '5.00', NULL, 0),
(39, 1, NULL, '2026-06-30', 'Hierro ADN 420', '3.00', '6.00', 1),
(40, 1, NULL, '2026-06-30', 'Martillo demoledor', '7.00', NULL, 0),
(41, 2, NULL, '2026-06-30', 'Hierro ADN 420', '4.00', '2.00', 1),
(42, 2, NULL, '2026-06-30', 'Amoladora angular', '8.00', NULL, 0),
(43, 2, NULL, '2026-06-30', 'Cemento Portland', '5.00', '10.00', 1),
(44, 2, NULL, '2026-06-30', 'Martillo demoledor', '4.00', NULL, 0),
(45, 3, NULL, '2026-06-30', 'Hierro ADN 420', '4.00', '8.00', 1),
(46, 3, NULL, '2026-06-30', 'Martillo demoledor', '8.00', NULL, 0),
(47, 3, NULL, '2026-06-30', 'Cemento Portland', '4.00', '2.00', 1),
(48, 3, NULL, '2026-06-30', 'Martillo demoledor', '3.00', NULL, 0),
(49, 2, NULL, '2026-09-01', 'Cemento Portland', '5.00', '34.00', 1);

-- --------------------------------------------------------

--
-- Table structure for table `registros`
--

DROP TABLE IF EXISTS `registros`;
CREATE TABLE IF NOT EXISTS `registros` (
  `id_registro` int NOT NULL AUTO_INCREMENT,
  `fecha` date NOT NULL,
  `hora_entrada` time NOT NULL,
  `hora_salida` time NOT NULL,
  `horas_trabajadas` decimal(5,2) DEFAULT NULL,
  `id_obrero` int NOT NULL,
  `id_obra` int NOT NULL,
  `id_usuario` int DEFAULT NULL,
  PRIMARY KEY (`id_registro`),
  KEY `id_obrero` (`id_obrero`),
  KEY `id_obra` (`id_obra`),
  KEY `id_usuario` (`id_usuario`)
) ENGINE=MyISAM AUTO_INCREMENT=46 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping data for table `registros`
--

INSERT INTO `registros` (`id_registro`, `fecha`, `hora_entrada`, `hora_salida`, `horas_trabajadas`, `id_obrero`, `id_obra`, `id_usuario`) VALUES
(1, '2026-03-03', '07:30:00', '16:30:00', '9.00', 1, 1, 2),
(2, '2026-03-03', '07:30:00', '16:00:00', '8.50', 2, 1, 2),
(3, '2026-03-04', '08:00:00', '17:00:00', '9.00', 1, 1, 2),
(4, '2026-03-04', '08:00:00', '16:30:00', '8.50', 2, 1, 2),
(5, '2026-03-05', '07:00:00', '15:00:00', '8.00', 1, 1, 2),
(6, '2026-03-05', '07:00:00', '15:30:00', '8.50', 2, 1, 2),
(7, '2026-03-10', '07:30:00', '17:00:00', '9.50', 1, 1, 2),
(8, '2026-03-10', '08:00:00', '16:00:00', '8.00', 4, 1, 2),
(9, '2026-03-12', '07:00:00', '16:30:00', '9.50', 1, 1, 2),
(10, '2026-03-12', '07:00:00', '16:00:00', '9.00', 4, 1, 2),
(11, '2026-03-04', '08:00:00', '17:00:00', '9.00', 3, 2, 2),
(12, '2026-03-05', '08:00:00', '16:00:00', '8.00', 3, 2, 2),
(13, '2026-03-06', '07:30:00', '17:00:00', '9.50', 3, 2, 2),
(14, '2026-03-06', '07:30:00', '16:30:00', '9.00', 5, 2, 2),
(15, '2026-03-07', '07:00:00', '15:00:00', '8.00', 5, 2, 2),
(16, '2026-04-01', '08:00:00', '17:00:00', '9.00', 3, 2, 2),
(17, '2026-04-01', '08:00:00', '16:30:00', '8.50', 5, 2, 2),
(18, '2026-04-02', '07:00:00', '16:00:00', '9.00', 3, 2, 2),
(19, '2026-04-02', '07:30:00', '16:00:00', '8.50', 6, 3, 2),
(20, '2026-04-03', '08:00:00', '17:00:00', '9.00', 6, 3, 2),
(21, '2026-04-03', '08:00:00', '16:30:00', '8.50', 4, 3, 2),
(22, '2026-04-04', '07:00:00', '16:00:00', '9.00', 6, 3, 2),
(23, '2026-04-04', '07:00:00', '15:30:00', '8.50', 4, 3, 2),
(24, '2026-06-26', '09:00:00', '15:30:00', '6.50', 3, 3, 2),
(25, '2026-06-26', '08:30:00', '16:00:00', '7.50', 1, 3, 2),
(26, '2026-06-26', '12:00:00', '16:00:00', '4.00', 1, 2, 2),
(27, '2026-06-26', '08:30:00', '18:00:00', '9.50', 2, 2, 2),
(28, '2026-06-26', '10:00:00', '17:07:00', '7.12', 2, 1, 2),
(29, '2026-06-26', '12:00:00', '16:00:00', '4.00', 1, 1, 2),
(30, '2026-06-26', '10:00:00', '17:00:00', '7.00', 1, 1, 2),
(31, '2026-06-26', '09:00:00', '16:00:00', '7.00', 2, 1, 2),
(32, '2026-06-26', '10:30:00', '17:00:00', '6.50', 4, 1, 2),
(33, '2026-06-26', '08:30:00', '15:00:00', '6.50', 5, 3, 2),
(34, '2026-06-26', '11:11:00', '19:00:00', '7.82', 4, 3, 2),
(35, '2026-06-26', '09:00:00', '16:00:00', '7.00', 2, 1, 2),
(36, '2026-06-30', '10:00:00', '16:00:00', '6.00', 3, 1, 2),
(37, '2026-06-30', '10:00:00', '16:00:00', '6.00', 1, 3, 2),
(38, '2026-06-30', '09:00:00', '14:00:00', '5.00', 2, 2, 2),
(39, '2026-06-30', '04:06:00', '15:06:00', '11.00', 1, 2, 2),
(40, '2026-06-30', '08:00:00', '17:00:00', '9.00', 4, 1, 2),
(41, '2026-06-30', '10:04:00', '17:09:00', '7.08', 3, 2, 2),
(42, '2026-06-30', '07:00:00', '15:00:00', '8.00', 3, 2, 2),
(43, '2026-06-30', '10:00:00', '18:00:00', '8.00', 2, 3, 2),
(44, '2026-06-30', '08:00:00', '14:00:00', '6.00', 1, 3, 2),
(45, '2026-09-01', '12:00:00', '16:00:00', '4.00', 9, 2, 1);

-- --------------------------------------------------------

--
-- Table structure for table `usuarios`
--

DROP TABLE IF EXISTS `usuarios`;
CREATE TABLE IF NOT EXISTS `usuarios` (
  `id_usuario` int NOT NULL AUTO_INCREMENT,
  `nombre` varchar(100) NOT NULL,
  `usuario` varchar(50) NOT NULL,
  `password_hash` varchar(255) NOT NULL,
  `correo` varchar(150) DEFAULT NULL,
  `rol` enum('Administrador','Capataz') NOT NULL,
  `activo` tinyint(1) DEFAULT '1',
  PRIMARY KEY (`id_usuario`),
  UNIQUE KEY `usuario` (`usuario`),
  UNIQUE KEY `correo` (`correo`)
) ENGINE=MyISAM AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping data for table `usuarios`
--

INSERT INTO `usuarios` (`id_usuario`, `nombre`, `usuario`, `password_hash`, `correo`, `rol`, `activo`) VALUES
(1, 'Administrador', 'admin', '$2y$12$ATczWwHjwfhi9BVElVybR..BYXJ5X4PFRjjJ9EWR/8Ew3/.hHxItm', NULL, 'Administrador', 1),
(2, 'Capataz', 'capataz', '$2y$12$eFL7X6dijAsHUsEapoACFOn.9AoS.DBK1wPH4Izh9IxTXCdc4Bmpq', NULL, 'Capataz', 1),
(3, 'Irina Muñoz Braceiro', 'Irina', '$2y$12$N3/WG6/bCbwM8wcvh81SPudLT.6pt39p4qsJgJA52Gz2Wda.wlehi', NULL, 'Administrador', 1);
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
