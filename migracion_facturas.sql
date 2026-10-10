-- Módulo de Facturas (api/facturas.php + web-ui/Facturas.html)
-- Crea las tablas que el módulo usa y las columnas que le faltaban al esquema:
--   - facturas          : cabecera de cada factura (proveedor, importes, estado, archivo)
--   - factura_detalle   : desglose de ítems de cada factura
--   - obras.porcentaje_gastos_generales : reparto de gastos generales por porcentaje fijo
--   - costos_generales.origen           : distingue costos cargados a mano de los de factura
-- Aplicar UNA sola vez sobre una base existente (ver docs/DOCUMENTACION_TECNICA.md).

ALTER TABLE obras
    ADD COLUMN porcentaje_gastos_generales DECIMAL(5,2) NOT NULL DEFAULT 0.00 AFTER telefono_cliente;

ALTER TABLE costos_generales
    ADD COLUMN origen ENUM('Manual','Factura') NOT NULL DEFAULT 'Manual' AFTER categoria;

CREATE TABLE IF NOT EXISTS facturas (
    id_factura INT AUTO_INCREMENT PRIMARY KEY,
    numero_factura VARCHAR(100) NULL,
    proveedor VARCHAR(150) NOT NULL,
    rut_proveedor VARCHAR(30) NULL,
    fecha_emision DATE NOT NULL,
    subtotal DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    iva DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    total DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    tipo_gasto ENUM('Obra','General') NOT NULL DEFAULT 'General',
    id_obra INT NULL,
    archivo LONGBLOB NULL,
    nombre_archivo VARCHAR(255) NULL,
    tipo_archivo VARCHAR(100) NULL,
    texto_ocr MEDIUMTEXT NULL,
    estado ENUM('Pendiente','Verificada','Anulada') NOT NULL DEFAULT 'Pendiente',
    id_usuario INT NOT NULL,

    INDEX idx_facturas_fecha (fecha_emision),
    INDEX idx_facturas_obra (id_obra),
    INDEX idx_facturas_usuario (id_usuario),
    INDEX idx_facturas_proveedor_numero (proveedor, numero_factura),
    CONSTRAINT fk_facturas_obra FOREIGN KEY (id_obra) REFERENCES obras(id_obra)
        ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT fk_facturas_usuario FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS factura_detalle (
    id_detalle INT AUTO_INCREMENT PRIMARY KEY,
    id_factura INT NOT NULL,
    descripcion VARCHAR(255) NOT NULL,
    cantidad DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    precio_unitario DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    subtotal DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    id_obra INT NULL,

    INDEX idx_factura_detalle_factura (id_factura),
    INDEX idx_factura_detalle_obra (id_obra),
    CONSTRAINT fk_factura_detalle_factura FOREIGN KEY (id_factura) REFERENCES facturas(id_factura)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_factura_detalle_obra FOREIGN KEY (id_obra) REFERENCES obras(id_obra)
        ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
