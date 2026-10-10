<?php

require_once __DIR__ . '/config/db.php';
require_once __DIR__ . '/config/session.php';

header('Content-Type: application/json');
header('Cache-Control: no-store');

iniciarSesion();

if (empty($_SESSION['user_id'])) {
    http_response_code(401);
    echo json_encode(['success' => false, 'db' => null, 'error' => 'Sesión no válida.']);
    exit;
}

try {
    $pdo = conectar();
    $pdo->query('SELECT 1');

    echo json_encode(['success' => true, 'db' => true]);
} catch (Throwable $e) {
    error_log('health.php DB error: ' . $e->getMessage());

    http_response_code(503);
    echo json_encode(['success' => false, 'db' => false, 'error' => 'Base de datos sin conexión.']);
}
