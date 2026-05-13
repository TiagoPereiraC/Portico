<?php

require_once __DIR__ . '/config/session.php';

$origin = (isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off' ? 'https' : 'http')
    . '://' . ($_SERVER['HTTP_HOST'] ?? 'localhost');

header("Access-Control-Allow-Origin: {$origin}");
header('Access-Control-Allow-Credentials: true');
header('Access-Control-Allow-Headers: Content-Type');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Content-Type: application/json');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

iniciarSesion();

$autenticado = !empty($_SESSION['user_id']);

if ($autenticado) {
    echo json_encode([
        'autenticado' => true,
        'user_id'     => (int) $_SESSION['user_id'],
        'nombre'      => $_SESSION['nombre'] ?? '',
        'rol'         => $_SESSION['rol'] ?? '',
    ]);
} else {
    echo json_encode([
        'autenticado' => false,
        'user_id'     => null,
        'nombre'      => '',
        'rol'         => '',
    ]);
}
