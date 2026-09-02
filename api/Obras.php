<?php

require_once __DIR__ . '/config/db.php';
require_once __DIR__ . '/config/session.php';
require_once __DIR__ . '/config/auditoria.php';

$origin = (isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off' ? 'https' : 'http')
    . '://' . ($_SERVER['HTTP_HOST'] ?? 'localhost');

header("Access-Control-Allow-Origin: {$origin}");
header('Access-Control-Allow-Credentials: true');
header('Access-Control-Allow-Headers: Content-Type, X-CSRF-Token');
header('Access-Control-Allow-Methods: GET, POST, DELETE, OPTIONS');
header('Content-Type: application/json');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

iniciarSesion();

if (empty($_SESSION['user_id'])) {
    http_response_code(401);
    echo json_encode(['error' => 'Sesión no válida. Iniciá sesión nuevamente.']);
    exit;
}

$esAdmin = ($_SESSION['rol'] ?? '') === 'Administrador';

try {
    $pdo = conectar();

    switch ($_SERVER['REQUEST_METHOD']) {
        case 'GET':
            if (isset($_GET['descargar_contrato'])) {
                responderDescargaContrato($pdo);
                break;
            }
            if (isset($_GET['detalle'])) {
                responderDetalle($pdo);
                break;
            }
            responderListado($pdo);
            break;

        case 'POST':
    validarCsrf();
    $body = leerJson();

    // =====================================================
    // CAMBIAR ESTADO DE LA OBRA
    // =====================================================

    if (($body['accion'] ?? '') === 'cambiar_estado') {

        if (!$esAdmin) {
            http_response_code(403);
            echo json_encode([
                'error' => 'No tenés permisos para gestionar obras.'
            ]);
            exit;
        }

        responderCambioEstado($pdo, $body);
        break;
    }

    // =====================================================
    // COMPLETAR ACTIVIDAD DEL CONTRATO
    // =====================================================

    if (($body['accion'] ?? '') === 'completar_tarea') {

        if (!$esAdmin) {
            http_response_code(403);
            echo json_encode([
                'error' => 'No tenés permisos para gestionar obras.'
            ]);
            exit;
        }

        responderCompletarTarea($pdo, $body);
        break;
    }

    // =====================================================
    // GUARDAR / EDITAR OBRA
    // =====================================================

    if (!$esAdmin) {
        http_response_code(403);
        echo json_encode([
            'error' => 'No tenés permisos para gestionar obras.'
        ]);
        exit;
    }

    responderGuardado($pdo, $body);
    break;

        case 'DELETE':
            if (!$esAdmin) {
                http_response_code(403);
                echo json_encode(['error' => 'No tenés permisos para gestionar obras.']);
                exit;
            }
            validarCsrf();
            $body = leerJson();
            responderEliminacion($pdo, $body);
            break;

        default:
            http_response_code(405);
            echo json_encode(['error' => 'Método no permitido']);
    }
} catch (InvalidArgumentException $e) {
    http_response_code(400);
    echo json_encode(['error' => $e->getMessage()]);
} catch (RuntimeException $e) {
    http_response_code(404);
    echo json_encode(['error' => $e->getMessage()]);
} catch (PDOException $e) {
    if ((int) $e->getCode() === 23000) {
        http_response_code(409);
        echo json_encode(['error' => 'El número de contrata ya existe.']);
        exit;
    }

    error_log('Obras.php PDO error: ' . $e->getMessage());
    http_response_code(500);
    echo json_encode(['error' => 'Error interno del servidor.']);
} catch (Throwable $e) {
    error_log('Obras.php error: ' . $e->getMessage());
    http_response_code(500);
    echo json_encode(['error' => 'Error interno del servidor.']);
}

function responderDetalle(PDO $pdo): void
{
    $idObra = isset($_GET['id_obra']) ? (int) $_GET['id_obra'] : 0;

    if ($idObra <= 0) {
        throw new InvalidArgumentException('Debés indicar una obra válida.');
    }

    $obra = obtenerObra($pdo, $idObra);

    // Materiales
    $stmt = $pdo->prepare(
        'SELECT nombre,
                SUM(cantidad) AS cantidad_total,
                SUM(cantidad * COALESCE(precio_unitario, 0)) AS costo_total
         FROM recursos
         WHERE id_obra = ? AND es_material = 1
         GROUP BY nombre
         ORDER BY nombre'
    );
    $stmt->execute([$idObra]);
    $materiales = $stmt->fetchAll(PDO::FETCH_ASSOC);

    // Herramientas
    $stmt = $pdo->prepare(
        'SELECT nombre, SUM(cantidad) AS cantidad_total
         FROM recursos
         WHERE id_obra = ? AND es_material = 0
         GROUP BY nombre
         ORDER BY nombre'
    );
    $stmt->execute([$idObra]);
    $herramientas = $stmt->fetchAll(PDO::FETCH_ASSOC);

    // Obreros
    $stmt = $pdo->prepare(
        'SELECT obr.id_obrero,
                obr.nombre,
                obr.apellido,
                SUM(reg.horas_trabajadas) AS horas_totales
         FROM registros reg
         INNER JOIN obreros obr
             ON obr.id_obrero = reg.id_obrero
         WHERE reg.id_obra = ?
         GROUP BY obr.id_obrero, obr.nombre, obr.apellido
         ORDER BY obr.apellido, obr.nombre'
    );
    $stmt->execute([$idObra]);
    $obreros = $stmt->fetchAll(PDO::FETCH_ASSOC);

    // Maquinaria
    $stmt = $pdo->prepare(
        'SELECT m.nombre,
                m.marca,
                om.fecha_asignacion,
                om.fecha_retiro
         FROM obra_maquinaria om
         INNER JOIN maquinaria m
             ON m.id_maquinaria = om.id_maquinaria
         WHERE om.id_obra = ?
         ORDER BY om.fecha_asignacion DESC, m.nombre'
    );
    $stmt->execute([$idObra]);
    $maquinaria = $stmt->fetchAll(PDO::FETCH_ASSOC);

    // =====================================================
    // ACTIVIDADES DEL CONTRATO
    // =====================================================

    $stmt = $pdo->prepare(
        'SELECT
    ct.id_tarea,
    ct.id_contrato,
    ct.id_tarea_origen,
    ct.descripcion,
    ct.importe,
    ct.estado,
    ct.fecha_completada
FROM contrato_tareas ct
INNER JOIN contratos c
    ON c.id_contrato = ct.id_contrato
WHERE c.id_obra = ?
ORDER BY ct.id_tarea ASC'
    );

    $stmt->execute([$idObra]);

    $tareas = $stmt->fetchAll(PDO::FETCH_ASSOC);

    echo json_encode([
        'obra' => $obra,
        'materiales' => $materiales,
        'herramientas' => $herramientas,
        'obreros' => $obreros,
        'maquinaria' => $maquinaria,
        'tareas' => $tareas,
    ]);
}

function responderCambioEstado(PDO $pdo, array $body): void
{
    $idObra = isset($body['id_obra']) ? (int) $body['id_obra'] : 0;
    $activo = isset($body['activo']) ? (int) $body['activo'] : null;

    if ($idObra <= 0) {
        throw new InvalidArgumentException('Debés indicar una obra válida.');
    }

    if ($activo !== 0 && $activo !== 1) {
        throw new InvalidArgumentException('El estado de la obra es inválido.');
    }

    $stmt = $pdo->prepare(
        'UPDATE obras SET activo = ? WHERE id_obra = ?'
    );

    $stmt->execute([$activo, $idObra]);

    if ($stmt->rowCount() === 0) {
        // Verificamos si la obra realmente existe.
        $check = $pdo->prepare(
            'SELECT id_obra FROM obras WHERE id_obra = ? LIMIT 1'
        );
        $check->execute([$idObra]);

        if (!$check->fetchColumn()) {
            throw new RuntimeException('La obra indicada no existe.');
        }
    }

    $obra = obtenerObra($pdo, $idObra);

    registrarAuditoria(
        $pdo,
        'cambiar_estado',
        'obras',
        $idObra,
        [
            'nombre' => $obra['nombre'],
            'activo' => $activo
        ]
    );

    echo json_encode([
        'success' => true,
        'message' => 'Estado de la obra actualizado correctamente.',
    ]);
}

function responderCompletarTarea(PDO $pdo, array $body): void
{
    $idTarea = isset($body['id_tarea'])
        ? (int) $body['id_tarea']
        : 0;

    if ($idTarea <= 0) {
        throw new InvalidArgumentException(
            'Debés indicar una actividad válida.'
        );
    }

    // =====================================================
    // VERIFICAR QUE LA ACTIVIDAD EXISTA
    // Y OBTENER LA OBRA A LA QUE PERTENECE
    // =====================================================

    $stmt = $pdo->prepare(
        'SELECT
            ct.id_tarea,
            ct.id_contrato,
            ct.descripcion,
            ct.estado,
            c.id_obra
         FROM contrato_tareas ct
         INNER JOIN contratos c
             ON c.id_contrato = ct.id_contrato
         WHERE ct.id_tarea = ?
         LIMIT 1'
    );

    $stmt->execute([$idTarea]);

    $tarea = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$tarea) {
        throw new RuntimeException(
            'La actividad indicada no existe.'
        );
    }

    // =====================================================
    // SI YA ESTÁ COMPLETADA, NO HACER NADA
    // =====================================================

    if (
        strtolower((string) $tarea['estado']) === 'completada'
    ) {
        echo json_encode([
            'success' => true,
            'message' => 'La actividad ya estaba completada.'
        ]);
        return;
    }

    // =====================================================
    // MARCAR COMO COMPLETADA
    // =====================================================

    $stmt = $pdo->prepare(
        'UPDATE contrato_tareas
         SET estado = ?,
             fecha_completada = CURDATE()
         WHERE id_tarea = ?'
    );

    $stmt->execute([
        'Completada',
        $idTarea
    ]);

    // =====================================================
    // AUDITORÍA
    // =====================================================

    registrarAuditoria(
        $pdo,
        'completar_tarea',
        'contrato_tareas',
        $idTarea,
        [
            'id_obra' => (int) $tarea['id_obra'],
            'descripcion' => $tarea['descripcion'],
            'estado_anterior' => $tarea['estado'],
            'estado_nuevo' => 'Completada'
        ]
    );

    // =====================================================
    // RESPUESTA AL JAVASCRIPT
    // =====================================================

    echo json_encode([
        'success' => true,
        'message' => 'Actividad marcada como completada correctamente.',
        'id_tarea' => $idTarea,
        'estado' => 'Completada',
        'fecha_completada' => date('Y-m-d')
    ]);
}

function responderListado(PDO $pdo): void
{
    $page = max(1, (int) ($_GET['page'] ?? 1));
    $limit = (int) ($_GET['limit'] ?? 10);
    $limit = max(1, min($limit, 100));
    $search = trim((string) ($_GET['search'] ?? ''));
    $status = strtolower(trim((string) ($_GET['status'] ?? 'all')));

    if (!in_array($status, ['all', 'active', 'inactive'], true)) {
        throw new InvalidArgumentException('Filtro de estado inválido.');
    }

    $where = [];
    $params = [];

    if ($search !== '') {
        $where[] = '(o.numero_contrata LIKE ? OR o.nombre LIKE ? OR o.direccion LIKE ? OR o.descripcion LIKE ? OR o.nombre_cliente LIKE ? OR o.telefono_cliente LIKE ?)';
        $searchLike = '%' . $search . '%';
        $params = array_merge($params, [$searchLike, $searchLike, $searchLike, $searchLike, $searchLike, $searchLike]);
    }

    if ($status === 'active') {
        $where[] = 'o.activo = 1';
    } elseif ($status === 'inactive') {
        $where[] = 'o.activo = 0';
    }

    $whereSql = $where ? ' WHERE ' . implode(' AND ', $where) : '';

    $countStmt = $pdo->prepare('SELECT COUNT(*) FROM obras o' . $whereSql);
    foreach ($params as $index => $value) {
        $countStmt->bindValue($index + 1, $value, PDO::PARAM_STR);
    }
    $countStmt->execute();
    $total = (int) $countStmt->fetchColumn();

    $totalPages = max(1, (int) ceil($total / $limit));
    $page = min($page, $totalPages);
    $offset = ($page - 1) * $limit;

    $sql = 'SELECT o.id_obra, o.numero_contrata, o.nombre, o.direccion, o.descripcion, o.fecha_inicio, o.fecha_fin, o.nombre_cliente, o.telefono_cliente,
                   o.activo,
                   c.nombre_archivo AS contrato_nombre_archivo
            FROM obras o
            LEFT JOIN (
                SELECT c1.id_obra, c1.nombre_archivo
                FROM contratos c1
                INNER JOIN (
                    SELECT id_obra, MAX(id_contrato) AS max_id_contrato
                    FROM contratos
                    GROUP BY id_obra
                ) ult ON ult.id_obra = c1.id_obra AND ult.max_id_contrato = c1.id_contrato
            ) c ON c.id_obra = o.id_obra'
        . $whereSql
        . ' ORDER BY o.fecha_inicio DESC, o.nombre ASC LIMIT ? OFFSET ?';

    $stmt = $pdo->prepare($sql);
    $bindIndex = 1;
    foreach ($params as $value) {
        $stmt->bindValue($bindIndex++, $value, PDO::PARAM_STR);
    }
    $stmt->bindValue($bindIndex++, $limit, PDO::PARAM_INT);
    $stmt->bindValue($bindIndex, $offset, PDO::PARAM_INT);
    $stmt->execute();

    echo json_encode([
        'obras' => $stmt->fetchAll(),
        'total' => $total,
        'page' => $page,
        'per_page' => $limit,
        'total_pages' => $totalPages,
    ]);
}

function responderGuardado(PDO $pdo, array $body): void
{
    $payload = validarPayload($body);
    $contrato = extraerContrato($body);
    $tareas = validarTareas($body['tareas'] ?? []);
    $idObra = isset($body['id_obra']) && $body['id_obra'] !== '' ? (int) $body['id_obra'] : null;
    

    $pdo->beginTransaction();

    try {
        if ($idObra !== null) {
            $stmt = $pdo->prepare('SELECT id_obra FROM obras WHERE id_obra = ? LIMIT 1');
            $stmt->execute([$idObra]);

            if (!$stmt->fetchColumn()) {
                throw new RuntimeException('La obra indicada no existe.');
            }

            $stmt = $pdo->prepare(
                'UPDATE obras
                 SET numero_contrata = ?, nombre = ?, direccion = ?, descripcion = ?, fecha_inicio = ?, fecha_fin = ?, nombre_cliente = ?, telefono_cliente = ?, activo = ?
                 WHERE id_obra = ?'
            );
            $stmt->execute([
                $payload['numero_contrata'],
                $payload['nombre'],
                $payload['direccion'],
                $payload['descripcion'],
                $payload['fecha_inicio'],
                $payload['fecha_fin'],
                $payload['nombre_cliente'],
                $payload['telefono_cliente'],
                $payload['activo'],
                $idObra,
            ]);

            if ($contrato !== null) {
                $idContrato = guardarContrato($pdo, $idObra, $contrato);
            } else {
                $idContrato = obtenerIdContrato($pdo, $idObra);
            }

            if (!empty($tareas)) {
                if ($idContrato === null) {
                    throw new InvalidArgumentException(
                        'Para registrar actividades debés cargar primero el contrato.'
                    );
                }

                guardarTareas($pdo, $idContrato, $tareas);
            }

            $pdo->commit();

            $obraRespuesta = obtenerObra($pdo, $idObra);
            registrarAuditoria($pdo, 'editar', 'obras', $idObra, [
                'nombre' => $obraRespuesta['nombre'],
                'contrato_reemplazado' => $contrato !== null,
                'tareas_actualizadas' => count($tareas),
            ]);

            http_response_code(200);
            echo json_encode([
                'success' => true,
                'message' => 'Obra actualizada correctamente.',
                'obra' => $obraRespuesta,
            ]);
            return;
        }

        $stmt = $pdo->prepare(
            'INSERT INTO obras (
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
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)'
        );

        $stmt->execute([
            $payload['numero_contrata'],
            $payload['nombre'],
            $payload['direccion'],
            $payload['descripcion'],
            $payload['fecha_inicio'],
            $payload['fecha_fin'],
            $payload['nombre_cliente'],
            $payload['telefono_cliente'],
            $payload['activo'],
        ]);

        $idObra = (int) $pdo->lastInsertId();

        if ($contrato !== null) {
            $idContrato = guardarContrato($pdo, $idObra, $contrato);
        } else {
            $idContrato = null;
        }

        if (!empty($tareas)) {
            if ($idContrato === null) {
                throw new InvalidArgumentException(
                    'Para registrar actividades debés cargar primero el contrato.'
                );
            }

            guardarTareas($pdo, $idContrato, $tareas);
        }

        $pdo->commit();

        $obraRespuesta = obtenerObra($pdo, $idObra);
        registrarAuditoria($pdo, 'crear', 'obras', $idObra, [
            'nombre' => $obraRespuesta['nombre'],
            'numero_contrata' => $obraRespuesta['numero_contrata'],
            'tareas_creadas' => count($tareas),
        ]);

        http_response_code(201);
        echo json_encode([
            'success' => true,
            'message' => 'Obra guardada correctamente.',
            'obra' => $obraRespuesta,
        ]);
    } catch (Throwable $e) {
        if ($pdo->inTransaction()) {
            $pdo->rollBack();
        }
        throw $e;
    }
}

function responderEliminacion(PDO $pdo, array $body): void
{
    $idObra = isset($body['id_obra']) ? (int) $body['id_obra'] : 0;

    if ($idObra <= 0) {
        throw new InvalidArgumentException('Debés indicar una obra válida.');
    }

    $stmt = $pdo->prepare(
        'SELECT id_obra, nombre
         FROM obras
         WHERE id_obra = ?
         LIMIT 1'
    );
    $stmt->execute([$idObra]);

    $obra = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$obra) {
        throw new RuntimeException('La obra indicada no existe.');
    }

    $pdo->beginTransaction();

    try {
        /*
         * Eliminamos primero los registros relacionados.
         * Esto evita problemas si la base de datos no tiene
         * ON DELETE CASCADE.
         */

        // Contrato
        $pdo->prepare(
            'DELETE FROM contratos WHERE id_obra = ?'
        )->execute([$idObra]);

        // Recursos: materiales y herramientas
        $pdo->prepare(
            'DELETE FROM recursos WHERE id_obra = ?'
        )->execute([$idObra]);

        // Registros de asistencia/trabajo
        $pdo->prepare(
            'DELETE FROM registros WHERE id_obra = ?'
        )->execute([$idObra]);

        // Maquinaria asignada
        $pdo->prepare(
            'DELETE FROM obra_maquinaria WHERE id_obra = ?'
        )->execute([$idObra]);

        // Finalmente la obra
        $pdo->prepare(
            'DELETE FROM obras WHERE id_obra = ?'
        )->execute([$idObra]);

        $pdo->commit();

        registrarAuditoria(
            $pdo,
            'eliminar',
            'obras',
            $idObra,
            ['nombre' => $obra['nombre']]
        );

        echo json_encode([
            'success' => true,
            'message' => 'Obra eliminada correctamente.',
        ]);

    } catch (Throwable $e) {

        if ($pdo->inTransaction()) {
            $pdo->rollBack();
        }

        throw $e;
    }
}

function validarCsrf(): void
{
    $csrfRecibido = $_SERVER['HTTP_X_CSRF_TOKEN'] ?? '';
    $csrfGuardado = $_SESSION['csrf_token'] ?? '';

    if ($csrfGuardado === '' || !hash_equals($csrfGuardado, $csrfRecibido)) {
        http_response_code(403);
        echo json_encode(['error' => 'Token de seguridad inválido. Recargá la página.']);
        exit;
    }
}

function verificarLimitePost(): void
{
    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        $contentLength = (int) ($_SERVER['CONTENT_LENGTH'] ?? 0);
        if ($contentLength > 0 && empty($_POST) && empty($_FILES)) {
            $rawInput = file_get_contents('php://input');
            if ($rawInput === false || strlen($rawInput) === 0) {
                $postMax = ini_get('post_max_size') ?: '8M';
                throw new InvalidArgumentException("El tamaño del archivo o solicitud enviada supera el límite configurado en el servidor (límite post_max_size: {$postMax}).");
            }
        }
    }
}

function leerJson(): array
{
    verificarLimitePost();
    $body = json_decode(file_get_contents('php://input'), true);
    if (!is_array($body)) {
        throw new InvalidArgumentException('Cuerpo de solicitud inválido.');
    }

    return $body;
}

function validarPayload(array $body): array
{
    $numeroContrata = limpiarTexto($body['numero_contrata'] ?? '', 50);
    $nombre = limpiarTexto($body['nombre'] ?? '', 150);
    $direccion = limpiarTexto($body['direccion'] ?? '', 200, false);
    $descripcion = limpiarTexto($body['descripcion'] ?? '', 65535, false);
    $fechaInicio = normalizarFecha($body['fecha_inicio'] ?? null);
    $fechaFin = normalizarFecha($body['fecha_fin'] ?? null);
    $nombreCliente = limpiarTexto($body['nombre_cliente'] ?? '', 150);
    $telefonoCliente = limpiarTexto($body['telefono_cliente'] ?? '', 30, false);
    $activo = isset($body['activo']) ? (int) $body['activo'] : 1;
    $activo = $activo === 1 ? 1 : 0;

    if ($numeroContrata === '' || $nombre === '' || $nombreCliente === '') {
        throw new InvalidArgumentException('Número de contrata, nombre de la obra y cliente son obligatorios.');
    }

    if ($fechaInicio !== null && $fechaFin !== null && $fechaFin < $fechaInicio) {
        throw new InvalidArgumentException('La fecha de fin no puede ser menor a la de inicio.');
    }

    return [
        'numero_contrata' => $numeroContrata,
        'nombre' => $nombre,
        'direccion' => $direccion,
        'descripcion' => $descripcion,
        'fecha_inicio' => $fechaInicio,
        'fecha_fin' => $fechaFin,
        'nombre_cliente' => $nombreCliente,
        'telefono_cliente' => $telefonoCliente,
        'activo' => $activo,
    ];
}

function limpiarTexto(mixed $value, int $maxLength, bool $required = true): ?string
{
    $text = trim((string) $value);
    if ($text === '') {
        return $required ? '' : null;
    }

    $length = function_exists('mb_strlen') ? mb_strlen($text) : strlen($text);
    if ($length > $maxLength) {
        throw new InvalidArgumentException('Uno de los campos supera la longitud permitida.');
    }

    return $text;
}

function normalizarFecha(mixed $value): ?string
{
    $text = trim((string) ($value ?? ''));
    if ($text === '') {
        return null;
    }

    $date = DateTime::createFromFormat('Y-m-d', $text);
    $errors = DateTime::getLastErrors();

    if (!$date || ($errors['warning_count'] ?? 0) > 0 || ($errors['error_count'] ?? 0) > 0) {
        throw new InvalidArgumentException('Formato de fecha inválido.');
    }

    return $date->format('Y-m-d');
}

function obtenerObra(PDO $pdo, int $idObra): array
{
    $stmt = $pdo->prepare(
        'SELECT o.id_obra, o.numero_contrata, o.nombre, o.direccion, o.descripcion, o.fecha_inicio, o.fecha_fin, o.nombre_cliente, o.telefono_cliente,
                o.activo,
                c.nombre_archivo AS contrato_nombre_archivo
         FROM obras o
         LEFT JOIN (
             SELECT c1.id_obra, c1.nombre_archivo
             FROM contratos c1
             INNER JOIN (
                 SELECT id_obra, MAX(id_contrato) AS max_id_contrato
                 FROM contratos
                 GROUP BY id_obra
             ) ult ON ult.id_obra = c1.id_obra AND ult.max_id_contrato = c1.id_contrato
         ) c ON c.id_obra = o.id_obra
         WHERE o.id_obra = ?
         LIMIT 1'
    );
    $stmt->execute([$idObra]);

    $obra = $stmt->fetch();
    if (!$obra) {
        throw new RuntimeException('La obra indicada no existe.');
    }

    return $obra;
}

function responderDescargaContrato(PDO $pdo): void
{
    $idObra = isset($_GET['id_obra']) ? (int) $_GET['id_obra'] : 0;
    if ($idObra <= 0) {
        throw new InvalidArgumentException('Debés indicar una obra válida.');
    }

    $stmt = $pdo->prepare(
        'SELECT nombre_archivo, archivo
         FROM contratos
         WHERE id_obra = ?
         ORDER BY id_contrato DESC
         LIMIT 1'
    );
    $stmt->execute([$idObra]);
    $contrato = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$contrato) {
        throw new RuntimeException('La obra no tiene contrato cargado.');
    }

    $nombreArchivo = $contrato['nombre_archivo'] ?: "contrato-{$idObra}";
    $mime = detectarMimeContrato($nombreArchivo);

    header_remove('Content-Type');
    header('Content-Type: ' . $mime);
    header('Content-Length: ' . strlen($contrato['archivo']));
    header('Content-Disposition: attachment; filename="' . rawurlencode($nombreArchivo) . '"; filename*=UTF-8\'\'' . rawurlencode($nombreArchivo));
    echo $contrato['archivo'];
}

function extraerContrato(array $body): ?array
{
    if (!isset($body['contrato']) || !is_array($body['contrato'])) {
        return null;
    }

    $nombreArchivo = limpiarTexto($body['contrato']['nombre_archivo'] ?? '', 255);
    $contenidoBase64 = trim((string) ($body['contrato']['contenido_base64'] ?? ''));

    if ($nombreArchivo === '' || $contenidoBase64 === '') {
        throw new InvalidArgumentException('El contrato seleccionado es inválido.');
    }

    $archivo = base64_decode($contenidoBase64, true);
    if ($archivo === false) {
        throw new InvalidArgumentException('El contrato seleccionado es inválido.');
    }

    if (strlen($archivo) > 10 * 1024 * 1024) {
        throw new InvalidArgumentException('El contrato no puede superar los 10 MB.');
    }

    return [
        'nombre_archivo' => $nombreArchivo,
        'archivo' => $archivo,
    ];
}

function guardarContrato(PDO $pdo, int $idObra, array $contrato): int
{
    $stmt = $pdo->prepare(
        'SELECT id_contrato
         FROM contratos
         WHERE id_obra = ?
         LIMIT 1'
    );

    $stmt->execute([$idObra]);
    $contratoExistente = $stmt->fetch(PDO::FETCH_ASSOC);

    if ($contratoExistente) {
        $idContrato = (int) $contratoExistente['id_contrato'];

        $stmt = $pdo->prepare(
            'UPDATE contratos
             SET numero_contrato = ?,
                 descripcion = ?,
                 fecha_inicio = ?,
                 fecha_fin = ?,
                 importe_total = ?
             WHERE id_contrato = ?'
        );

        $stmt->execute([
            $contrato['numero_contrato'] ?? null,
            $contrato['descripcion'] ?? null,
            $contrato['fecha_inicio'] ?? null,
            $contrato['fecha_fin'] ?? null,
            $contrato['importe_total'] ?? 0,
            $idContrato
        ]);

        return $idContrato;
    }

    $stmt = $pdo->prepare(
        'INSERT INTO contratos (
            id_obra,
            numero_contrato,
            descripcion,
            fecha_inicio,
            fecha_fin,
            importe_total
         )
         VALUES (?, ?, ?, ?, ?, ?)'
    );

    $stmt->execute([
        $idObra,
        $contrato['numero_contrato'] ?? null,
        $contrato['descripcion'] ?? null,
        $contrato['fecha_inicio'] ?? null,
        $contrato['fecha_fin'] ?? null,
        $contrato['importe_total'] ?? 0
    ]);

    return (int) $pdo->lastInsertId();
}

function obtenerIdContrato(PDO $pdo, int $idObra): ?int
{
    $stmt = $pdo->prepare(
        'SELECT id_contrato
         FROM contratos
         WHERE id_obra = ?
         ORDER BY id_contrato DESC
         LIMIT 1'
    );

    $stmt->execute([$idObra]);

    $idContrato = $stmt->fetchColumn();

    return $idContrato !== false ? (int) $idContrato : null;
}

function validarTareas(mixed $tareas): array
{
    if ($tareas === null || $tareas === '') {
        return [];
    }

    if (!is_array($tareas)) {
        throw new InvalidArgumentException(
            'Las actividades del contrato son inválidas.'
        );
    }

    $resultado = [];

    foreach ($tareas as $tarea) {

        if (!is_array($tarea)) {
            throw new InvalidArgumentException(
                'Una de las actividades es inválida.'
            );
        }

        $descripcion = limpiarTexto(
            $tarea['descripcion'] ?? '',
            255
        );

        if ($descripcion === '') {
            throw new InvalidArgumentException(
                'La descripción de la actividad es obligatoria.'
            );
        }

        $importe = $tarea['importe'] ?? 0;

        if (!is_numeric($importe) || (float)$importe < 0) {
            throw new InvalidArgumentException(
                'El importe de una actividad es inválido.'
            );
        }

        $estado = $tarea['estado'] ?? 'Pendiente';

        if (!in_array(
            $estado,
            ['Pendiente', 'Completada'],
            true
        )) {
            throw new InvalidArgumentException(
                'El estado de una actividad es inválido.'
            );
        }

        $fechaCompletada = null;

        if (
            $estado === 'Completada' &&
            !empty($tarea['fecha_completada'])
        ) {
            $fechaCompletada = normalizarFecha(
                $tarea['fecha_completada']
            );
        }

        $idTareaOrigen = null;

        if (
            isset($tarea['id_tarea_origen']) &&
            $tarea['id_tarea_origen'] !== ''
        ) {
            $idTareaOrigen = (int) $tarea['id_tarea_origen'];

            if ($idTareaOrigen <= 0) {
                $idTareaOrigen = null;
            }
        }

        $resultado[] = [
            'id_tarea_origen' => $idTareaOrigen,
            'descripcion' => $descripcion,
            'importe' => number_format((float)$importe, 2, '.', ''),
            'estado' => $estado,
            'fecha_completada' => $fechaCompletada,
        ];
    }

    return $resultado;
}

function guardarTareas(PDO $pdo, int $idContrato, array $tareas): void
{
    foreach ($tareas as $tarea) {

        $idTarea = isset($tarea['id_tarea'])
            ? (int) $tarea['id_tarea']
            : 0;

        $descripcion = trim(
            (string) ($tarea['descripcion'] ?? '')
        );

        $importe = isset($tarea['importe'])
            ? (float) $tarea['importe']
            : 0;

        $estado = trim(
            (string) ($tarea['estado'] ?? 'Pendiente')
        );

        $fechaCompletada = !empty($tarea['fecha_completada'])
            ? $tarea['fecha_completada']
            : null;

        if ($descripcion === '') {
            continue;
        }

        /*
         * Si la tarea ya existe, se actualiza.
         * Esto permite conservar su id_tarea.
         */
        if ($idTarea > 0) {

            $stmt = $pdo->prepare(
                'SELECT id_tarea, estado, fecha_completada
                 FROM contrato_tareas
                 WHERE id_tarea = ?
                   AND id_contrato = ?
                 LIMIT 1'
            );

            $stmt->execute([
                $idTarea,
                $idContrato
            ]);

            $tareaExistente = $stmt->fetch(PDO::FETCH_ASSOC);

            if ($tareaExistente) {

                /*
                 * Si ya estaba completada, no permitimos
                 * que un guardado normal la vuelva a Pendiente.
                 */
                if (
                    strtolower(
                        (string) $tareaExistente['estado']
                    ) === 'completada'
                ) {
                    $estado = 'Completada';

                    $fechaCompletada =
                        $tareaExistente['fecha_completada']
                        ?: $fechaCompletada;
                }

                $stmt = $pdo->prepare(
                    'UPDATE contrato_tareas
                     SET descripcion = ?,
                         importe = ?,
                         estado = ?,
                         fecha_completada = ?
                     WHERE id_tarea = ?
                       AND id_contrato = ?'
                );

                $stmt->execute([
                    $descripcion,
                    $importe,
                    $estado,
                    $fechaCompletada,
                    $idTarea,
                    $idContrato
                ]);

                continue;
            }
        }

        /*
         * La tarea no existe: se crea.
         */
        $idTareaOrigen = isset($tarea['id_tarea_origen'])
            && $tarea['id_tarea_origen'] !== null
            ? (int) $tarea['id_tarea_origen']
            : null;

        $stmt = $pdo->prepare(
            'INSERT INTO contrato_tareas (
                id_contrato,
                id_tarea_origen,
                descripcion,
                importe,
                estado,
                fecha_completada
             )
             VALUES (?, ?, ?, ?, ?, ?)'
        );

        $stmt->execute([
            $idContrato,
            $idTareaOrigen,
            $descripcion,
            $importe,
            $estado,
            $fechaCompletada
        ]);
    }
}

function detectarMimeContrato(string $nombreArchivo): string
{
    $extension = strtolower(pathinfo($nombreArchivo, PATHINFO_EXTENSION));

    return match ($extension) {
        'pdf' => 'application/pdf',
        'doc' => 'application/msword',
        'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        default => 'application/octet-stream',
    };
}