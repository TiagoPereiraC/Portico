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

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405);
    echo json_encode(['success' => false, 'error' => 'Método no permitido']);
    exit;
}

iniciarSesion();

if (empty($_SESSION['user_id'])) {
    http_response_code(401);
    echo json_encode(['success' => false, 'error' => 'Sesión no válida. Iniciá sesión nuevamente.']);
    exit;
}

try {

    $pdo = conectar();
    $pdo->setAttribute(PDO::ATTR_DEFAULT_FETCH_MODE, PDO::FETCH_ASSOC);

    $idObrero = (int)($_GET['id_obrero'] ?? 0);
    $fechaDesde = trim($_GET['fecha_desde'] ?? '');
    $fechaHasta = trim($_GET['fecha_hasta'] ?? '');
    $page = max(1, (int) ($_GET['page'] ?? 1));
    $limit = (int) ($_GET['limit'] ?? 10);
    $limit = max(1, min($limit, 100));

    $where = [];
    $paramsResumen = [];
    $paramsListado = [];

    if ($idObrero > 0) {
        $where[] = 'r.id_obrero = ?';
        $paramsResumen[] = $idObrero;
        $paramsListado[] = $idObrero;
    }

    if ($fechaDesde !== '' && $fechaHasta !== '') {
        $where[] = 'r.fecha BETWEEN ? AND ?';
        $paramsResumen[] = $fechaDesde;
        $paramsResumen[] = $fechaHasta;
        $paramsListado[] = $fechaDesde;
        $paramsListado[] = $fechaHasta;
    }

    if (empty($where)) {
        throw new InvalidArgumentException('Seleccione al menos un obrero o un período.');
    }

    $whereSql = implode(' AND ', $where);

    $stmtResumen = $pdo->prepare("
        SELECT
            COUNT(DISTINCT id_obra) AS total_obras,
            COUNT(*) AS dias_trabajados,
            COALESCE(SUM(horas_trabajadas),0) AS total_horas
        FROM registros r
        WHERE {$whereSql}
    ");
    $stmtResumen->execute($paramsResumen);
    $resumen = $stmtResumen->fetch();

    $countStmt = $pdo->prepare("
        SELECT COUNT(*)
        FROM registros r
        INNER JOIN obras o ON o.id_obra = r.id_obra
        WHERE {$whereSql}
    ");
    $countStmt->execute($paramsListado);
    $total = (int) $countStmt->fetchColumn();

    $totalPages = max(1, (int) ceil($total / $limit));
    $page = min($page, $totalPages);
    $offset = ($page - 1) * $limit;

    $sqlListado = "
        SELECT
            r.fecha,
            o.nombre AS obra,
            r.hora_entrada,
            r.hora_salida,
            r.horas_trabajadas
        FROM registros r
        INNER JOIN obras o
            ON o.id_obra = r.id_obra
        WHERE {$whereSql}
        ORDER BY r.fecha DESC
        LIMIT ? OFFSET ?
    ";

    $stmt = $pdo->prepare($sqlListado);
    $bindIndex = 1;
    foreach ($paramsListado as $value) {
        $stmt->bindValue($bindIndex++, $value, PDO::PARAM_STR);
    }
    $stmt->bindValue($bindIndex++, $limit, PDO::PARAM_INT);
    $stmt->bindValue($bindIndex, $offset, PDO::PARAM_INT);
    $stmt->execute();

    echo json_encode([
        'success' => true,
        'resumen' => $resumen,
        'registros' => $stmt->fetchAll(),
        'total' => $total,
        'page' => $page,
        'per_page' => $limit,
        'total_pages' => $totalPages,
    ]);

} catch (InvalidArgumentException $e) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'error' => $e->getMessage()
    ]);
} catch (PDOException $e) {
    error_log('consultas.php PDO error: ' . $e->getMessage());
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'error' => 'Error interno del servidor.'
    ]);
} catch (Throwable $e) {
    error_log('consultas.php error: ' . $e->getMessage());
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'error' => 'Error interno del servidor.'
    ]);
}
