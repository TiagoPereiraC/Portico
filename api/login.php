<?php

require_once __DIR__ . '/config/db.php';
require_once __DIR__ . '/config/session.php';

// CORS: misma origin
$origin = (isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off' ? 'https' : 'http')
        . '://' . ($_SERVER['HTTP_HOST'] ?? 'localhost');

header("Access-Control-Allow-Origin: {$origin}");
header('Access-Control-Allow-Credentials: true');
header('Access-Control-Allow-Headers: Content-Type, X-CSRF-Token');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Content-Type: application/json');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    exit(json_encode(['error' => 'Método no permitido']));
}

iniciarSesion();

// Validación CSRF
$csrfRecibido = $_SERVER['HTTP_X_CSRF_TOKEN'] ?? '';
$csrfGuardado = $_SESSION['csrf_token'] ?? '';

if ($csrfGuardado === '' || !hash_equals($csrfGuardado, $csrfRecibido)) {
    http_response_code(403);
    exit(json_encode(['error' => 'Token de seguridad inválido. Recargá la página.']));
}

// Parseo del body JSON 
$body = json_decode(file_get_contents('php://input'), true);

if (!is_array($body)) {
    http_response_code(400);
    exit(json_encode(['error' => 'Cuerpo de solicitud inválido']));
}

$username = trim((string)($body['usuario'] ?? ''));
$password = (string)($body['password'] ?? '');

if ($username === '' || $password === '') {
    http_response_code(400);
    exit(json_encode(['error' => 'Todos los campos son requeridos']));
}

// Límites de longitud iguales a las columnas del schema
if (strlen($username) > 50 || strlen($password) > 255) {
    http_response_code(400);
    exit(json_encode(['error' => 'Datos inválidos']));
}

// IP del solicitante (sin confiar en headers de proxy)
$ip = filter_var($_SERVER['REMOTE_ADDR'] ?? '0.0.0.0', FILTER_VALIDATE_IP)
    ?: '0.0.0.0';

// Rate limiting 
try {
    $pdo = conectar();
} catch (Throwable $e) {
    error_log('DB connection error: ' . $e->getMessage());
    http_response_code(503);
    exit(json_encode(['error' => 'Servicio no disponible. Intente más tarde.']));
}

// 5 fallos por usuario en 15 min > bloquear ese usuario
$stmt = $pdo->prepare(
    'SELECT COUNT(*) FROM intentos_login
     WHERE username = ? AND exitoso = 0
     AND fecha > DATE_SUB(NOW(), INTERVAL 15 MINUTE)'
);
$stmt->execute([$username]);
if ((int) $stmt->fetchColumn() >= 5) {
    http_response_code(429);
    exit(json_encode(['error' => 'Cuenta bloqueada temporalmente. Intentá en 15 minutos.']));
}

// 20 intentos por IP en 15 min > bloquear esa IP
$stmt = $pdo->prepare(
    'SELECT COUNT(*) FROM intentos_login
     WHERE ip_address = ?
     AND fecha > DATE_SUB(NOW(), INTERVAL 15 MINUTE)'
);
$stmt->execute([$ip]);
if ((int) $stmt->fetchColumn() >= 20) {
    http_response_code(429);
    exit(json_encode(['error' => 'Demasiados intentos desde esta red. Intentá más tarde.']));
}

// Búsqueda del usuario
$stmt = $pdo->prepare(
    'SELECT id_usuario, nombre, usuario, password_hash, rol, activo
     FROM usuarios WHERE usuario = ? LIMIT 1'
);
$stmt->execute([$username]);
$user = $stmt->fetch();

// password_verify() trabaja con hashes bcrypt/argon2 generados por password_hash()
$valido = $user
    && (bool) $user['activo']
    && password_verify($password, $user['password_hash']);

// Registrar intento (siempre, para auditoría y rate limiting)
$pdo->prepare(
    'INSERT INTO intentos_login (username, ip_address, fecha, exitoso)
     VALUES (?, ?, NOW(), ?)'
)->execute([$username, $ip, $valido ? 1 : 0]);

// Respuesta genérica en fallo (no filtrar si fue usuario o contraseña)
if (!$valido) {
    http_response_code(401);
    exit(json_encode(['error' => 'Usuario o contraseña incorrectos']));
}

// Login exitoso: sesión segura
// Regenerar ID de sesión para prevenir session fixation
session_regenerate_id(true);

$_SESSION['user_id'] = $user['id_usuario'];
$_SESSION['nombre']  = $user['nombre'];
$_SESSION['usuario'] = $user['usuario'];
$_SESSION['rol']     = $user['rol'];
$_SESSION['ip']      = $ip;

// Invalidar el CSRF token usado; el cliente pedirá uno nuevo en la próxima solicitud
unset($_SESSION['csrf_token']);

echo json_encode([
    'success' => true,
    'user_id' => (int) $user['id_usuario'],
    'nombre' => $user['nombre'],
    'rol' => $user['rol'],
]);
