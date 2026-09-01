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

    $search = trim((string) ($_GET['search'] ?? ''));
    $limit = (int) ($_GET['limit'] ?? 0);
    $limit = max(0, min($limit, 100));

    $where = ['activo = 1'];
    $params = [];

    if ($search !== '') {
        $where[] = '(nombre LIKE ? OR apellido LIKE ? OR documento LIKE ?)';
        $searchLike = $search . '%';
        $params = [$searchLike, $searchLike, $searchLike];
    }

    $whereSql = implode(' AND ', $where);

    $sql = "
        SELECT
            id_obrero,
            nombre,
            apellido
        FROM obreros
        WHERE {$whereSql}
        ORDER BY nombre
    ";

    if ($limit > 0) {
        $sql .= ' LIMIT ?';
        $params[] = $limit;
    }

    $stmt = $pdo->prepare($sql);
    foreach ($params as $index => $value) {
        $stmt->bindValue($index + 1, $value, PDO::PARAM_STR);
    }
    $stmt->execute();

    echo json_encode([
        'success' => true,
        'obreros' => $stmt->fetchAll()
    ]);

} catch (PDOException $e) {
    error_log('obtener_obrero.php PDO error: ' . $e->getMessage());
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'error' => 'Error interno del servidor.'
    ]);
} catch (Throwable $e) {
    error_log('obtener_obrero.php error: ' . $e->getMessage());
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'error' => 'Error interno del servidor.'
    ]);
}
