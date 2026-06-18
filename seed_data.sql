USE portico;

START TRANSACTION;

-- Este archivo asume que schema.sql ya fue ejecutado.
-- Inserta datos de ejemplo y evita duplicados al volver a correrlo.

-- Usuarios primero: necesarios para los registros de asistencia
INSERT INTO usuarios (nombre, usuario, password_hash, rol, activo) VALUES
('Administrador', 'admin',   '$2y$12$ATczWwHjwfhi9BVElVybR..BYXJ5X4PFRjjJ9EWR/8Ew3/.hHxItm', 'Administrador', 1),
('Capataz',  'capataz', '$2y$12$eFL7X6dijAsHUsEapoACFOn.9AoS.DBK1wPH4Izh9IxTXCdc4Bmpq', 'Capataz',       1)
ON DUPLICATE KEY UPDATE activo = VALUES(activo);

SET @admin_id = (SELECT id_usuario FROM usuarios WHERE usuario = 'admin' LIMIT 1);
SET @capataz_id = (SELECT id_usuario FROM usuarios WHERE usuario = 'capataz' LIMIT 1);

INSERT INTO obras (
    numero_contrata,
    nombre,
    direccion,
    descripcion,
    fecha_inicio,
    fecha_fin,
    nombre_cliente,
    telefono_cliente,
    activo
)
VALUES
    (
        'CTR-001',
        'Edificio Costanera Norte',
        'Av. Costanera 1540, Posadas',
        'Construccion de edificio administrativo y deposito.',
        '2026-01-15',
        '2026-12-20',
        'Municipalidad de Posadas',
        '3764-555001',
        1
    ),
    (
        'CTR-002',
        'Pavimentacion Barrio San Jorge',
        'Barrio San Jorge, Posadas',
        'Pavimentacion y mejora de desagues pluviales.',
        '2026-02-10',
        '2026-09-30',
        'Instituto Provincial de Desarrollo Habitacional',
        '3764-555002',
        1
    ),
    (
        'CTR-003',
        'Refaccion Escuela N 42',
        'Calle 12 esq. 45, Garupa',
        'Refaccion integral de aulas y patio cubierto.',
        '2026-04-01',
        NULL,
        'Consejo General de Educacion',
        '3764-555003',
        1
    )
ON DUPLICATE KEY UPDATE
    nombre = VALUES(nombre),
    direccion = VALUES(direccion),
    descripcion = VALUES(descripcion),
    fecha_inicio = VALUES(fecha_inicio),
    fecha_fin = VALUES(fecha_fin),
    nombre_cliente = VALUES(nombre_cliente),
    telefono_cliente = VALUES(telefono_cliente),
    activo = VALUES(activo);

SET @obra_1 = (SELECT id_obra FROM obras WHERE numero_contrata = 'CTR-001' LIMIT 1);
SET @obra_2 = (SELECT id_obra FROM obras WHERE numero_contrata = 'CTR-002' LIMIT 1);
SET @obra_3 = (SELECT id_obra FROM obras WHERE numero_contrata = 'CTR-003' LIMIT 1);

INSERT INTO obreros (
    nombre,
    apellido,
    documento,
    telefono,
    fecha_contratacion,
    fecha_fin,
    activo
)
VALUES
    ('Luis', 'Benitez', '40111222', '3764-600101', '2025-11-10', '2026-03-15', 1),
    ('Carlos', 'Gomez', '38999111', '3764-600102', '2025-10-05', DATE_ADD(CURDATE(), INTERVAL 15 DAY), 1),
    ('Miguel', 'Rojas', '41222333', '3764-600103', '2026-01-08', NULL, 1),
    ('Jorge', 'Ferreyra', '37888444', '3764-600104', '2026-02-01', DATE_ADD(CURDATE(), INTERVAL 45 DAY), 1),
    ('Ramon', 'Acosta', '42333444', '3764-600105', '2026-03-01', NULL, 1),
    ('Pedro', 'Insaurralde', '43444555', '3764-600106', '2026-04-10', NULL, 1)
ON DUPLICATE KEY UPDATE
    nombre = VALUES(nombre),
    apellido = VALUES(apellido),
    telefono = VALUES(telefono),
    fecha_contratacion = VALUES(fecha_contratacion),
    fecha_fin = VALUES(fecha_fin),
    activo = VALUES(activo);

SET @obrero_1 = (SELECT id_obrero FROM obreros WHERE documento = '40111222' LIMIT 1);
SET @obrero_2 = (SELECT id_obrero FROM obreros WHERE documento = '38999111' LIMIT 1);
SET @obrero_3 = (SELECT id_obrero FROM obreros WHERE documento = '41222333' LIMIT 1);
SET @obrero_4 = (SELECT id_obrero FROM obreros WHERE documento = '37888444' LIMIT 1);
SET @obrero_5 = (SELECT id_obrero FROM obreros WHERE documento = '42333444' LIMIT 1);
SET @obrero_6 = (SELECT id_obrero FROM obreros WHERE documento = '43444555' LIMIT 1);

INSERT INTO contrato_obrero (archivo, fecha_vencimiento, id_obrero)
SELECT _binary 'Contrato demo de Luis Benitez', '2026-12-31', @obrero_1
FROM DUAL
WHERE @obrero_1 IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM contrato_obrero WHERE id_obrero = @obrero_1
  );

INSERT INTO contrato_obrero (archivo, fecha_vencimiento, id_obrero)
SELECT _binary 'Contrato demo de Carlos Gomez', '2026-11-30', @obrero_2
FROM DUAL
WHERE @obrero_2 IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM contrato_obrero WHERE id_obrero = @obrero_2
  );

INSERT INTO contratos (id_obra, archivo, nombre_archivo, fecha_subida)
SELECT @obra_1, _binary 'Contrato PDF demo obra CTR-001', 'contrato-ctr-001.pdf', '2026-01-16'
FROM DUAL
WHERE @obra_1 IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM contratos WHERE id_obra = @obra_1 AND nombre_archivo = 'contrato-ctr-001.pdf'
  );

INSERT INTO contratos (id_obra, archivo, nombre_archivo, fecha_subida)
SELECT @obra_2, _binary 'Contrato PDF demo obra CTR-002', 'contrato-ctr-002.pdf', '2026-02-12'
FROM DUAL
WHERE @obra_2 IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM contratos WHERE id_obra = @obra_2 AND nombre_archivo = 'contrato-ctr-002.pdf'
  );

INSERT INTO maquinaria (nombre, marca)
SELECT 'Retroexcavadora 320D', 'Caterpillar'
FROM DUAL
WHERE NOT EXISTS (
    SELECT 1 FROM maquinaria WHERE nombre = 'Retroexcavadora 320D' AND marca = 'Caterpillar'
);

INSERT INTO maquinaria (nombre, marca)
SELECT 'Hormigonera H-250', 'Sthilmaq'
FROM DUAL
WHERE NOT EXISTS (
    SELECT 1 FROM maquinaria WHERE nombre = 'Hormigonera H-250' AND marca = 'Sthilmaq'
);

INSERT INTO maquinaria (nombre, marca)
SELECT 'Compactador CV-90', 'Wacker Neuson'
FROM DUAL
WHERE NOT EXISTS (
    SELECT 1 FROM maquinaria WHERE nombre = 'Compactador CV-90' AND marca = 'Wacker Neuson'
);

SET @maq_1 = (SELECT id_maquinaria FROM maquinaria WHERE nombre = 'Retroexcavadora 320D' AND marca = 'Caterpillar' LIMIT 1);
SET @maq_2 = (SELECT id_maquinaria FROM maquinaria WHERE nombre = 'Hormigonera H-250' AND marca = 'Sthilmaq' LIMIT 1);
SET @maq_3 = (SELECT id_maquinaria FROM maquinaria WHERE nombre = 'Compactador CV-90' AND marca = 'Wacker Neuson' LIMIT 1);

INSERT INTO obra_maquinaria (id_obra, id_maquinaria, fecha_asignacion, fecha_retiro)
VALUES
    (@obra_1, @maq_1, '2026-01-20', NULL),
    (@obra_1, @maq_2, '2026-02-05', NULL),
    (@obra_2, @maq_3, '2026-02-20', NULL),
    (@obra_3, @maq_2, '2026-04-05', NULL)
ON DUPLICATE KEY UPDATE
    fecha_retiro = VALUES(fecha_retiro);

INSERT INTO certificado (archivo, nombre_archivo, id_maquinaria, fecha_vencimiento)
SELECT _binary 'Certificado tecnico demo retroexcavadora', 'certificado_retroexcavadora_demo.pdf', @maq_1, '2026-12-31'
FROM DUAL
WHERE @maq_1 IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM certificado WHERE id_maquinaria = @maq_1
  );

-- ===== REGISTROS DE ASISTENCIA =====
-- Obra 1 (CTR-001) - multiples fechas y obreros
INSERT INTO registros (fecha, hora_entrada, hora_salida, horas_trabajadas, id_obrero, id_obra, id_usuario)
SELECT d.fecha, d.hora_entrada, d.hora_salida, d.horas, d.id_obrero, @obra_1, COALESCE(@capataz_id, @admin_id)
FROM (
    SELECT '2026-03-03' AS fecha, '07:30:00' AS hora_entrada, '16:30:00' AS hora_salida, 9.00 AS horas, @obrero_1 AS id_obrero UNION ALL
    SELECT '2026-03-03', '07:30:00', '16:00:00', 8.50, @obrero_2 UNION ALL
    SELECT '2026-03-04', '08:00:00', '17:00:00', 9.00, @obrero_1 UNION ALL
    SELECT '2026-03-04', '08:00:00', '16:30:00', 8.50, @obrero_2 UNION ALL
    SELECT '2026-03-05', '07:00:00', '15:00:00', 8.00, @obrero_1 UNION ALL
    SELECT '2026-03-05', '07:00:00', '15:30:00', 8.50, @obrero_2 UNION ALL
    SELECT '2026-03-10', '07:30:00', '17:00:00', 9.50, @obrero_1 UNION ALL
    SELECT '2026-03-10', '08:00:00', '16:00:00', 8.00, @obrero_4 UNION ALL
    SELECT '2026-03-12', '07:00:00', '16:30:00', 9.50, @obrero_1 UNION ALL
    SELECT '2026-03-12', '07:00:00', '16:00:00', 9.00, @obrero_4
) d
WHERE @obra_1 IS NOT NULL
  AND d.id_obrero IS NOT NULL
  AND COALESCE(@capataz_id, @admin_id) IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM registros r
      WHERE r.fecha = d.fecha AND r.id_obrero = d.id_obrero AND r.id_obra = @obra_1
  );

-- Obra 2 (CTR-002) - multiples fechas y obreros
INSERT INTO registros (fecha, hora_entrada, hora_salida, horas_trabajadas, id_obrero, id_obra, id_usuario)
SELECT d.fecha, d.hora_entrada, d.hora_salida, d.horas, d.id_obrero, @obra_2, COALESCE(@capataz_id, @admin_id)
FROM (
    SELECT '2026-03-04' AS fecha, '08:00:00' AS hora_entrada, '17:00:00' AS hora_salida, 9.00 AS horas, @obrero_3 AS id_obrero UNION ALL
    SELECT '2026-03-05', '08:00:00', '16:00:00', 8.00, @obrero_3 UNION ALL
    SELECT '2026-03-06', '07:30:00', '17:00:00', 9.50, @obrero_3 UNION ALL
    SELECT '2026-03-06', '07:30:00', '16:30:00', 9.00, @obrero_5 UNION ALL
    SELECT '2026-03-07', '07:00:00', '15:00:00', 8.00, @obrero_5 UNION ALL
    SELECT '2026-04-01', '08:00:00', '17:00:00', 9.00, @obrero_3 UNION ALL
    SELECT '2026-04-01', '08:00:00', '16:30:00', 8.50, @obrero_5 UNION ALL
    SELECT '2026-04-02', '07:00:00', '16:00:00', 9.00, @obrero_3
) d
WHERE @obra_2 IS NOT NULL
  AND d.id_obrero IS NOT NULL
  AND COALESCE(@capataz_id, @admin_id) IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM registros r
      WHERE r.fecha = d.fecha AND r.id_obrero = d.id_obrero AND r.id_obra = @obra_2
  );

-- Obra 3 (CTR-003) - obra mas reciente
INSERT INTO registros (fecha, hora_entrada, hora_salida, horas_trabajadas, id_obrero, id_obra, id_usuario)
SELECT d.fecha, d.hora_entrada, d.hora_salida, d.horas, d.id_obrero, @obra_3, COALESCE(@capataz_id, @admin_id)
FROM (
    SELECT '2026-04-02' AS fecha, '07:30:00' AS hora_entrada, '16:00:00' AS hora_salida, 8.50 AS horas, @obrero_6 AS id_obrero UNION ALL
    SELECT '2026-04-03', '08:00:00', '17:00:00', 9.00, @obrero_6 UNION ALL
    SELECT '2026-04-03', '08:00:00', '16:30:00', 8.50, @obrero_4 UNION ALL
    SELECT '2026-04-04', '07:00:00', '16:00:00', 9.00, @obrero_6 UNION ALL
    SELECT '2026-04-04', '07:00:00', '15:30:00', 8.50, @obrero_4
) d
WHERE @obra_3 IS NOT NULL
  AND d.id_obrero IS NOT NULL
  AND COALESCE(@capataz_id, @admin_id) IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM registros r
      WHERE r.fecha = d.fecha AND r.id_obrero = d.id_obrero AND r.id_obra = @obra_3
  );

-- ===== RECURSOS (materiales + herramientas) =====
SET @reg_1_1 = (SELECT id_registro FROM registros WHERE fecha = '2026-03-03' AND id_obrero = @obrero_1 AND id_obra = @obra_1 LIMIT 1);
SET @reg_1_2 = (SELECT id_registro FROM registros WHERE fecha = '2026-03-04' AND id_obrero = @obrero_1 AND id_obra = @obra_1 LIMIT 1);
SET @reg_2_1 = (SELECT id_registro FROM registros WHERE fecha = '2026-03-06' AND id_obrero = @obrero_3 AND id_obra = @obra_2 LIMIT 1);
SET @reg_3_1 = (SELECT id_registro FROM registros WHERE fecha = '2026-04-02' AND id_obrero = @obrero_6 AND id_obra = @obra_3 LIMIT 1);

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT @obra_1, @reg_1_1, '2026-03-03', 'Cemento Portland', 40.00, 9800.00, 1 FROM DUAL
WHERE @reg_1_1 IS NOT NULL AND NOT EXISTS (SELECT 1 FROM recursos WHERE id_obra = @obra_1 AND id_registro = @reg_1_1 AND nombre = 'Cemento Portland' AND es_material = 1);

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT @obra_1, @reg_1_1, '2026-03-03', 'Hierro ADN 420', 120.00, 1450.00, 1 FROM DUAL
WHERE @reg_1_1 IS NOT NULL AND NOT EXISTS (SELECT 1 FROM recursos WHERE id_obra = @obra_1 AND id_registro = @reg_1_1 AND nombre = 'Hierro ADN 420' AND es_material = 1);

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT @obra_2, @reg_2_1, '2026-03-06', 'Arena lavada', 18.00, 42000.00, 1 FROM DUAL
WHERE @reg_2_1 IS NOT NULL AND NOT EXISTS (SELECT 1 FROM recursos WHERE id_obra = @obra_2 AND id_registro = @reg_2_1 AND nombre = 'Arena lavada' AND es_material = 1);

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT @obra_2, @reg_2_1, '2026-03-06', 'Piedra partida', 12.00, 35000.00, 1 FROM DUAL
WHERE @reg_2_1 IS NOT NULL AND NOT EXISTS (SELECT 1 FROM recursos WHERE id_obra = @obra_2 AND id_registro = @reg_2_1 AND nombre = 'Piedra partida' AND es_material = 1);

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT @obra_3, @reg_3_1, '2026-04-02', 'Pintura latex blanca', 60.00, 12500.00, 1 FROM DUAL
WHERE @reg_3_1 IS NOT NULL AND NOT EXISTS (SELECT 1 FROM recursos WHERE id_obra = @obra_3 AND id_registro = @reg_3_1 AND nombre = 'Pintura latex blanca' AND es_material = 1);

-- Herramientas
INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, es_material)
SELECT @obra_1, @reg_1_1, '2026-03-03', 'Amoladora angular', 2.00, 0 FROM DUAL
WHERE @reg_1_1 IS NOT NULL AND NOT EXISTS (SELECT 1 FROM recursos WHERE id_obra = @obra_1 AND id_registro = @reg_1_1 AND nombre = 'Amoladora angular' AND es_material = 0);

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, es_material)
SELECT @obra_1, @reg_1_2, '2026-03-04', 'Martillo demoledor', 1.00, 0 FROM DUAL
WHERE @reg_1_2 IS NOT NULL AND NOT EXISTS (SELECT 1 FROM recursos WHERE id_obra = @obra_1 AND id_registro = @reg_1_2 AND nombre = 'Martillo demoledor' AND es_material = 0);

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, es_material)
SELECT @obra_2, @reg_2_1, '2026-03-06', 'Vibrador de hormigon', 1.00, 0 FROM DUAL
WHERE @reg_2_1 IS NOT NULL AND NOT EXISTS (SELECT 1 FROM recursos WHERE id_obra = @obra_2 AND id_registro = @reg_2_1 AND nombre = 'Vibrador de hormigon' AND es_material = 0);

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, es_material)
SELECT @obra_3, @reg_3_1, '2026-04-02', 'Rodillo profesional', 3.00, 0 FROM DUAL
WHERE @reg_3_1 IS NOT NULL AND NOT EXISTS (SELECT 1 FROM recursos WHERE id_obra = @obra_3 AND id_registro = @reg_3_1 AND nombre = 'Rodillo profesional' AND es_material = 0);

INSERT INTO intentos_login (username, ip_address, fecha, exitoso)
SELECT 'admin', '127.0.0.1', '2026-03-01 08:30:00', 1
FROM DUAL
WHERE NOT EXISTS (
    SELECT 1 FROM intentos_login WHERE username = 'admin' AND ip_address = '127.0.0.1' AND fecha = '2026-03-01 08:30:00'
);

INSERT INTO intentos_login (username, ip_address, fecha, exitoso)
SELECT 'capataz', '127.0.0.1', '2026-03-02 07:55:00', 1
FROM DUAL
WHERE NOT EXISTS (
    SELECT 1 FROM intentos_login WHERE username = 'capataz' AND ip_address = '127.0.0.1' AND fecha = '2026-03-02 07:55:00'
);

COMMIT;
