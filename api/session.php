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
$respuesta = [
    'autenticado' => $autenticado,
    'user_id'     => $autenticado ? (int) $_SESSION['user_id'] : null,
    'nombre'      => $autenticado ? ($_SESSION['nombre'] ?? '') : '',
    'rol'         => $autenticado ? ($_SESSION['rol'] ?? '') : '',
];

session_write_close();

echo json_encode($respuesta);
