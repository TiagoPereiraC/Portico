<?php

require_once __DIR__ . '/config/db.php';
require_once __DIR__ . '/config/session.php';

$origin = (isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off' ? 'https' : 'http')
    . '://' . ($_SERVER['HTTP_HOST'] ?? 'localhost');

header("Access-Control-Allow-Origin: {$origin}");
header('Access-Control-Allow-Credentials: true');
header('Access-Control-Allow-Headers: Content-Type, X-CSRF-Token');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Content-Type: application/json');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

if (($_SERVER['REQUEST_METHOD'] ?? 'GET') !== 'GET') {
    http_response_code(405);
    exit(json_encode(['error' => 'Método no permitido']));
}

iniciarSesion();

if (empty($_SESSION['user_id'])) {
    http_response_code(401);
    exit(json_encode(['error' => 'Sesión no válida. Iniciá sesión nuevamente.']));
}

if (($_SESSION['rol'] ?? '') !== 'Administrador') {
    http_response_code(403);
    exit(json_encode(['error' => 'No tenés permisos para consultar auditoría.']));
}

try {
    $pdo = conectar();

    $page = max(1, (int) ($_GET['page'] ?? 1));
    $limit = (int) ($_GET['limit'] ?? 20);
    $limit = max(1, min($limit, 100));

    $usuario = trim((string) ($_GET['usuario'] ?? ''));
    $accion = trim((string) ($_GET['accion'] ?? ''));
    $entidad = trim((string) ($_GET['entidad'] ?? ''));
    $fechaDesde = normalizarFechaFiltro($_GET['fecha_desde'] ?? null);
    $fechaHasta = normalizarFechaFiltro($_GET['fecha_hasta'] ?? null);

    $where = [];
    $params = [];

    if ($usuario !== '') {
        $where[] = 'usuario LIKE ?';
        $params[] = '%' . $usuario . '%';
    }

    if ($accion !== '') {
        $where[] = 'accion = ?';
        $params[] = $accion;
    }

    if ($entidad !== '') {
        $where[] = 'entidad = ?';
        $params[] = $entidad;
    }

    if ($fechaDesde !== null) {
        $where[] = 'DATE(created_at) >= ?';
        $params[] = $fechaDesde;
    }

    if ($fechaHasta !== null) {
        $where[] = 'DATE(created_at) <= ?';
        $params[] = $fechaHasta;
    }

    $whereSql = $where ? ' WHERE ' . implode(' AND ', $where) : '';

    $countStmt = $pdo->prepare('SELECT COUNT(*) FROM auditoria_logs' . $whereSql);
    $countStmt->execute($params);
    $total = (int) $countStmt->fetchColumn();

    $totalPages = max(1, (int) ceil($total / $limit));
    $page = min($page, $totalPages);
    $offset = ($page - 1) * $limit;

    $stmt = $pdo->prepare(
        'SELECT id_log, id_usuario, usuario, rol, accion, entidad, entidad_id, detalle_json, ip_address, created_at
         FROM auditoria_logs'
        . $whereSql
        . ' ORDER BY created_at DESC, id_log DESC LIMIT ? OFFSET ?'
    );

    $bindIndex = 1;
    foreach ($params as $value) {
        $stmt->bindValue($bindIndex++, $value, PDO::PARAM_STR);
    }
    $stmt->bindValue($bindIndex++, $limit, PDO::PARAM_INT);
    $stmt->bindValue($bindIndex, $offset, PDO::PARAM_INT);
    $stmt->execute();

    $logs = [];
    while ($row = $stmt->fetch()) {
        $logs[] = [
            'id_log' => (int) $row['id_log'],
            'id_usuario' => $row['id_usuario'] !== null ? (int) $row['id_usuario'] : null,
            'usuario' => $row['usuario'],
            'rol' => $row['rol'],
            'accion' => $row['accion'],
            'entidad' => $row['entidad'],
            'entidad_id' => $row['entidad_id'] !== null ? (int) $row['entidad_id'] : null,
            'detalle' => decodificarDetalle($row['detalle_json'] ?? null),
            'ip_address' => $row['ip_address'],
            'created_at' => $row['created_at'],
        ];
    }

    echo json_encode([
        'success' => true,
        'logs' => $logs,
        'filters' => [
            'acciones' => obtenerValoresFiltro($pdo, 'accion'),
            'entidades' => obtenerValoresFiltro($pdo, 'entidad'),
        ],
        'total' => $total,
        'page' => $page,
        'per_page' => $limit,
        'total_pages' => $totalPages,
    ]);
} catch (InvalidArgumentException $e) {
    http_response_code(400);
    echo json_encode(['error' => $e->getMessage()]);
} catch (Throwable $e) {
    error_log('auditoria.php error: ' . $e->getMessage());
    http_response_code(500);
    echo json_encode(['error' => 'Error interno del servidor.']);
}

function normalizarFechaFiltro(mixed $value): ?string
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

function decodificarDetalle(?string $detalleJson): ?array
{
    if ($detalleJson === null || $detalleJson === '') {
        return null;
    }

    $detalle = json_decode($detalleJson, true);
    return is_array($detalle) ? $detalle : null;
}

function obtenerValoresFiltro(PDO $pdo, string $field): array
{
    if (!in_array($field, ['accion', 'entidad'], true)) {
        return [];
    }

    $stmt = $pdo->query("SELECT DISTINCT {$field} FROM auditoria_logs WHERE {$field} IS NOT NULL AND {$field} <> '' ORDER BY {$field} ASC");
    return $stmt->fetchAll(PDO::FETCH_COLUMN);
}