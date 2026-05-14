USE portico;

START TRANSACTION;

-- Este archivo asume que schema.sql ya fue ejecutado.
-- Inserta datos de ejemplo y evita duplicados al volver a correrlo.

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

INSERT INTO obreros (
    nombre,
    apellido,
    documento,
    telefono,
    fecha_contratacion,
    activo
)
VALUES
    ('Luis', 'Benitez', '40111222', '3764-600101', '2025-11-10', 1),
    ('Carlos', 'Gomez', '38999111', '3764-600102', '2025-10-05', 1),
    ('Miguel', 'Rojas', '41222333', '3764-600103', '2026-01-08', 1),
    ('Jorge', 'Ferreyra', '37888444', '3764-600104', '2026-02-01', 1)
ON DUPLICATE KEY UPDATE
    nombre = VALUES(nombre),
    apellido = VALUES(apellido),
    telefono = VALUES(telefono),
    fecha_contratacion = VALUES(fecha_contratacion),
    activo = VALUES(activo);

SET @obrero_1 = (SELECT id_obrero FROM obreros WHERE documento = '40111222' LIMIT 1);
SET @obrero_2 = (SELECT id_obrero FROM obreros WHERE documento = '38999111' LIMIT 1);
SET @obrero_3 = (SELECT id_obrero FROM obreros WHERE documento = '41222333' LIMIT 1);
SET @obrero_4 = (SELECT id_obrero FROM obreros WHERE documento = '37888444' LIMIT 1);

INSERT INTO contrato_obrero (archivo, fecha_vencimiento, id_obrero)
SELECT _binary 'Contrato demo de Luis Benitez', '2026-12-31', @obrero_1
FROM DUAL
WHERE @obrero_1 IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM contrato_obrero
      WHERE id_obrero = @obrero_1
  );

INSERT INTO contrato_obrero (archivo, fecha_vencimiento, id_obrero)
SELECT _binary 'Contrato demo de Carlos Gomez', '2026-11-30', @obrero_2
FROM DUAL
WHERE @obrero_2 IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM contrato_obrero
      WHERE id_obrero = @obrero_2
  );

INSERT INTO contratos (id_obra, archivo, nombre_archivo, fecha_subida)
SELECT @obra_1, _binary 'Contrato PDF demo obra CTR-001', 'contrato-ctr-001.pdf', '2026-01-16'
FROM DUAL
WHERE @obra_1 IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM contratos
      WHERE id_obra = @obra_1
        AND nombre_archivo = 'contrato-ctr-001.pdf'
  );

INSERT INTO contratos (id_obra, archivo, nombre_archivo, fecha_subida)
SELECT @obra_2, _binary 'Contrato PDF demo obra CTR-002', 'contrato-ctr-002.pdf', '2026-02-12'
FROM DUAL
WHERE @obra_2 IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM contratos
      WHERE id_obra = @obra_2
        AND nombre_archivo = 'contrato-ctr-002.pdf'
  );

INSERT INTO maquinaria (nombre, marca)
SELECT 'Retroexcavadora 320D', 'Caterpillar'
FROM DUAL
WHERE NOT EXISTS (
    SELECT 1
    FROM maquinaria
    WHERE nombre = 'Retroexcavadora 320D'
      AND marca = 'Caterpillar'
);

INSERT INTO maquinaria (nombre, marca)
SELECT 'Hormigonera H-250', 'Sthilmaq'
FROM DUAL
WHERE NOT EXISTS (
    SELECT 1
    FROM maquinaria
    WHERE nombre = 'Hormigonera H-250'
      AND marca = 'Sthilmaq'
);

INSERT INTO maquinaria (nombre, marca)
SELECT 'Compactador CV-90', 'Wacker Neuson'
FROM DUAL
WHERE NOT EXISTS (
    SELECT 1
    FROM maquinaria
    WHERE nombre = 'Compactador CV-90'
      AND marca = 'Wacker Neuson'
);

SET @maq_1 = (
    SELECT id_maquinaria
    FROM maquinaria
    WHERE nombre = 'Retroexcavadora 320D' AND marca = 'Caterpillar'
    LIMIT 1
);
SET @maq_2 = (
    SELECT id_maquinaria
    FROM maquinaria
    WHERE nombre = 'Hormigonera H-250' AND marca = 'Sthilmaq'
    LIMIT 1
);
SET @maq_3 = (
    SELECT id_maquinaria
    FROM maquinaria
    WHERE nombre = 'Compactador CV-90' AND marca = 'Wacker Neuson'
    LIMIT 1
);

INSERT INTO obra_maquinaria (id_obra, id_maquinaria, fecha_asignacion, fecha_retiro)
VALUES
    (@obra_1, @maq_1, '2026-01-20', NULL),
    (@obra_1, @maq_2, '2026-02-05', NULL),
    (@obra_2, @maq_3, '2026-02-20', NULL)
ON DUPLICATE KEY UPDATE
    fecha_retiro = VALUES(fecha_retiro);

SET @obra_maq_1 = (
    SELECT id_obra_maquinaria
    FROM obra_maquinaria
    WHERE id_obra = @obra_1 AND id_maquinaria = @maq_1 AND fecha_asignacion = '2026-01-20'
    LIMIT 1
);

INSERT INTO certificado (archivo, id_obra_maquinaria)
SELECT _binary 'Certificado tecnico demo retroexcavadora', @obra_maq_1
FROM DUAL
WHERE @obra_maq_1 IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM certificado
      WHERE id_obra_maquinaria = @obra_maq_1
  );

INSERT INTO registros (
    fecha,
    hora_entrada,
    hora_salida,
    horas_trabajadas,
    id_obrero,
    id_obra,
    id_usuario
)
SELECT '2026-03-03', '07:30:00', '16:30:00', 9.00, @obrero_1, @obra_1, COALESCE(@capataz_id, @admin_id)
FROM DUAL
WHERE @obrero_1 IS NOT NULL
  AND @obra_1 IS NOT NULL
  AND COALESCE(@capataz_id, @admin_id) IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM registros
      WHERE fecha = '2026-03-03'
        AND hora_entrada = '07:30:00'
        AND hora_salida = '16:30:00'
        AND id_obrero = @obrero_1
        AND id_obra = @obra_1
  );

INSERT INTO registros (
    fecha,
    hora_entrada,
    hora_salida,
    horas_trabajadas,
    id_obrero,
    id_obra,
    id_usuario
)
SELECT '2026-03-03', '07:30:00', '16:00:00', 8.50, @obrero_2, @obra_1, COALESCE(@capataz_id, @admin_id)
FROM DUAL
WHERE @obrero_2 IS NOT NULL
  AND @obra_1 IS NOT NULL
  AND COALESCE(@capataz_id, @admin_id) IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM registros
      WHERE fecha = '2026-03-03'
        AND hora_entrada = '07:30:00'
        AND hora_salida = '16:00:00'
        AND id_obrero = @obrero_2
        AND id_obra = @obra_1
  );

INSERT INTO registros (
    fecha,
    hora_entrada,
    hora_salida,
    horas_trabajadas,
    id_obrero,
    id_obra,
    id_usuario
)
SELECT '2026-03-04', '08:00:00', '17:00:00', 9.00, @obrero_3, @obra_2, COALESCE(@capataz_id, @admin_id)
FROM DUAL
WHERE @obrero_3 IS NOT NULL
  AND @obra_2 IS NOT NULL
  AND COALESCE(@capataz_id, @admin_id) IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM registros
      WHERE fecha = '2026-03-04'
        AND hora_entrada = '08:00:00'
        AND hora_salida = '17:00:00'
        AND id_obrero = @obrero_3
        AND id_obra = @obra_2
  );

SET @registro_1 = (
    SELECT id_registro
    FROM registros
    WHERE fecha = '2026-03-03'
      AND id_obrero = @obrero_1
      AND id_obra = @obra_1
    LIMIT 1
);

SET @registro_2 = (
    SELECT id_registro
    FROM registros
    WHERE fecha = '2026-03-03'
      AND id_obrero = @obrero_2
      AND id_obra = @obra_1
    LIMIT 1
);

SET @registro_3 = (
    SELECT id_registro
    FROM registros
    WHERE fecha = '2026-03-04'
      AND id_obrero = @obrero_3
      AND id_obra = @obra_2
    LIMIT 1
);

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT @obra_1, @registro_1, '2026-03-03', 'Cemento Portland', 40.00, 9800.00, 1
FROM DUAL
WHERE @obra_1 IS NOT NULL
  AND @registro_1 IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM recursos
      WHERE id_obra = @obra_1
        AND id_registro = @registro_1
        AND fecha = '2026-03-03'
        AND nombre = 'Cemento Portland'
        AND es_material = 1
  );

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT @obra_1, @registro_2, '2026-03-03', 'Hierro ADN 420', 120.00, 1450.00, 1
FROM DUAL
WHERE @obra_1 IS NOT NULL
  AND @registro_2 IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM recursos
      WHERE id_obra = @obra_1
        AND id_registro = @registro_2
        AND fecha = '2026-03-03'
        AND nombre = 'Hierro ADN 420'
        AND es_material = 1
  );

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT @obra_2, @registro_3, '2026-03-04', 'Arena lavada', 18.00, 42000.00, 1
FROM DUAL
WHERE @obra_2 IS NOT NULL
  AND @registro_3 IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM recursos
      WHERE id_obra = @obra_2
        AND id_registro = @registro_3
        AND fecha = '2026-03-04'
        AND nombre = 'Arena lavada'
        AND es_material = 1
  );

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT @obra_1, @registro_1, '2026-03-03', 'Amoladora angular', 2.00, NULL, 0
FROM DUAL
WHERE @obra_1 IS NOT NULL
  AND @registro_1 IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM recursos
      WHERE id_obra = @obra_1
        AND id_registro = @registro_1
        AND fecha = '2026-03-03'
        AND nombre = 'Amoladora angular'
        AND es_material = 0
  );

INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material)
SELECT @obra_2, @registro_3, '2026-03-04', 'Vibrador de hormigon', 1.00, NULL, 0
FROM DUAL
WHERE @obra_2 IS NOT NULL
  AND @registro_3 IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM recursos
      WHERE id_obra = @obra_2
        AND id_registro = @registro_3
        AND fecha = '2026-03-04'
        AND nombre = 'Vibrador de hormigon'
        AND es_material = 0
  );

INSERT INTO intentos_login (username, ip_address, fecha, exitoso)
SELECT 'admin', '127.0.0.1', '2026-03-01 08:30:00', 1
FROM DUAL
WHERE NOT EXISTS (
    SELECT 1
    FROM intentos_login
    WHERE username = 'admin'
      AND ip_address = '127.0.0.1'
      AND fecha = '2026-03-01 08:30:00'
);

INSERT INTO intentos_login (username, ip_address, fecha, exitoso)
SELECT 'capataz', '127.0.0.1', '2026-03-02 07:55:00', 1
FROM DUAL
WHERE NOT EXISTS (
    SELECT 1
    FROM intentos_login
    WHERE username = 'capataz'
      AND ip_address = '127.0.0.1'
      AND fecha = '2026-03-02 07:55:00'
);

COMMIT;