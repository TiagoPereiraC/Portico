<?php

require_once __DIR__ . '/config/db.php';
require_once __DIR__ . '/config/session.php';

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
            responderListado($pdo);
            break;

        case 'POST':
            if (!$esAdmin) {
                http_response_code(403);
                echo json_encode(['error' => 'No tenés permisos para gestionar obreros.']);
                exit;
            }
            validarCsrf();
            $body = leerJson();
            responderGuardado($pdo, $body);
            break;

        case 'DELETE':
            if (!$esAdmin) {
                http_response_code(403);
                echo json_encode(['error' => 'No tenés permisos para gestionar obreros.']);
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
        echo json_encode(['error' => 'Ya existe un obrero con ese documento.']);
        exit;
    }

    error_log('obreros.php PDO error: ' . $e->getMessage());
    http_response_code(500);
    echo json_encode(['error' => 'Error interno del servidor.']);
} catch (Throwable $e) {
    error_log('obreros.php error: ' . $e->getMessage());
    http_response_code(500);
    echo json_encode(['error' => 'Error interno del servidor.']);
}

function responderListado(PDO $pdo): void
{
    $page = max(1, (int) ($_GET['page'] ?? 1));
    $limit = (int) ($_GET['limit'] ?? 10);
    $limit = max(1, min($limit, 100));
    $search = trim((string) ($_GET['search'] ?? ''));

    $where = ['activo = 1'];
    $params = [];

    if ($search !== '') {
        $where[] = '(nombre LIKE ? OR apellido LIKE ? OR documento LIKE ? OR telefono LIKE ?)';
        $searchLike = $search . '%';
        $params = array_merge($params, [$searchLike, $searchLike, $searchLike, $searchLike]);
    }

    $whereSql = ' WHERE ' . implode(' AND ', $where);

    $countStmt = $pdo->prepare('SELECT COUNT(*) FROM obreros' . $whereSql);
    foreach ($params as $index => $value) {
        $countStmt->bindValue($index + 1, $value, PDO::PARAM_STR);
    }
    $countStmt->execute();
    $total = (int) $countStmt->fetchColumn();

    $totalPages = max(1, (int) ceil($total / $limit));
    $page = min($page, $totalPages);
    $offset = ($page - 1) * $limit;

    $stmt = $pdo->prepare(
        'SELECT id_obrero, nombre, apellido, documento, telefono, fecha_contratacion FROM obreros'
        . $whereSql
        . ' ORDER BY id_obrero DESC LIMIT ? OFFSET ?'
    );

    $bindIndex = 1;
    foreach ($params as $value) {
        $stmt->bindValue($bindIndex++, $value, PDO::PARAM_STR);
    }
    $stmt->bindValue($bindIndex++, $limit, PDO::PARAM_INT);
    $stmt->bindValue($bindIndex, $offset, PDO::PARAM_INT);
    $stmt->execute();

    echo json_encode([
        'success' => true,
        'obreros' => $stmt->fetchAll(),
        'total' => $total,
        'page' => $page,
        'per_page' => $limit,
        'total_pages' => $totalPages,
    ]);
}

function responderGuardado(PDO $pdo, array $body): void
{
    $nombre = limpiarTexto($body['nombre'] ?? '', 150, true);
    $apellido = limpiarTexto($body['apellido'] ?? '', 100, false);
    $documento = limpiarTexto($body['documento'] ?? '', 30, true);
    $telefono = limpiarTexto($body['telefono'] ?? '', 30, false);
    $fechaContratacion = normalizarFecha($body['fecha_contratacion'] ?? null);
    $idObrero = isset($body['id_obrero']) && $body['id_obrero'] !== '' ? (int) $body['id_obrero'] : null;

    if ($nombre === '' || $documento === '') {
        throw new InvalidArgumentException('Nombre y documento son obligatorios.');
    }

    $pdo->beginTransaction();

    try {
        if ($idObrero !== null) {
            $stmt = $pdo->prepare('SELECT id_obrero FROM obreros WHERE id_obrero = ? LIMIT 1');
            $stmt->execute([$idObrero]);

            if (!$stmt->fetchColumn()) {
                throw new RuntimeException('El obrero indicado no existe.');
            }

            $stmt = $pdo->prepare(
                'UPDATE obreros SET nombre = ?, apellido = ?, documento = ?, telefono = ?, fecha_contratacion = ? WHERE id_obrero = ?'
            );
            $stmt->execute([$nombre, $apellido, $documento, $telefono, $fechaContratacion, $idObrero]);

            $pdo->commit();

            http_response_code(200);
            echo json_encode([
                'success' => true,
                'message' => 'Obrero actualizado correctamente.',
                'obrero' => obtenerObrero($pdo, $idObrero),
            ]);
            return;
        }

        $stmt = $pdo->prepare(
            'INSERT INTO obreros (nombre, apellido, documento, telefono, fecha_contratacion, activo) VALUES (?, ?, ?, ?, ?, 1)'
        );
        $stmt->execute([$nombre, $apellido, $documento, $telefono, $fechaContratacion]);

        $idObrero = (int) $pdo->lastInsertId();

        $pdo->commit();

        http_response_code(201);
        echo json_encode([
            'success' => true,
            'message' => 'Obrero registrado correctamente.',
            'obrero' => obtenerObrero($pdo, $idObrero),
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
    $idObrero = isset($body['id_obrero']) ? (int) $body['id_obrero'] : 0;
    if ($idObrero <= 0) {
        throw new InvalidArgumentException('Debés indicar un obrero válido.');
    }

    $stmt = $pdo->prepare('UPDATE obreros SET activo = 0 WHERE id_obrero = ?');
    $stmt->execute([$idObrero]);

    if ($stmt->rowCount() === 0) {
        throw new RuntimeException('El obrero indicado no existe.');
    }

    echo json_encode([
        'success' => true,
        'message' => 'Obrero eliminado correctamente.',
    ]);
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

function leerJson(): array
{
    $body = json_decode(file_get_contents('php://input'), true);
    if (!is_array($body)) {
        throw new InvalidArgumentException('Cuerpo de solicitud inválido.');
    }
    return $body;
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

function obtenerObrero(PDO $pdo, int $idObrero): array
{
    $stmt = $pdo->prepare(
        'SELECT id_obrero, nombre, apellido, documento, telefono, fecha_contratacion FROM obreros WHERE id_obrero = ? LIMIT 1'
    );
    $stmt->execute([$idObrero]);

    $obrero = $stmt->fetch();
    if (!$obrero) {
        throw new RuntimeException('El obrero indicado no existe.');
    }

    return $obrero;
}
