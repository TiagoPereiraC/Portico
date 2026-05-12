<?php

require_once __DIR__ . '/config/db.php';
require_once __DIR__ . '/config/session.php';

$origin = (isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off' ? 'https' : 'http')
        . '://' . ($_SERVER['HTTP_HOST'] ?? 'localhost');

header("Access-Control-Allow-Origin: {$origin}");
header('Access-Control-Allow-Credentials: true');
header('Access-Control-Allow-Headers: Content-Type, X-CSRF-Token');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Content-Type: application/json');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

iniciarSesion();

if (empty($_SESSION['user_id'])) {
    responder(401, ['error' => 'Sesión no válida. Iniciá sesión nuevamente.']);
}

if (($_SESSION['rol'] ?? '') !== 'Administrador') {
    responder(403, ['error' => 'No tenés permisos para gestionar usuarios.']);
}

$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';

if ($method !== 'GET') {
    validarCsrf();
}

try {
    $pdo = conectar();
} catch (Throwable $e) {
    error_log('DB connection error: ' . $e->getMessage());
    responder(503, ['error' => 'Servicio no disponible. Intente más tarde.']);
}

switch ($method) {
    case 'GET':
        manejarGet($pdo);
        break;
    case 'POST':
        manejarPost($pdo);
        break;
    case 'PUT':
        manejarPut($pdo);
        break;
    case 'DELETE':
        manejarDelete($pdo);
        break;
    default:
        responder(405, ['error' => 'Método no permitido']);
}

function validarCsrf(): void
{
    $csrfRecibido = $_SERVER['HTTP_X_CSRF_TOKEN'] ?? '';
    $csrfGuardado = $_SESSION['csrf_token'] ?? '';

    if ($csrfGuardado === '' || !hash_equals($csrfGuardado, $csrfRecibido)) {
        responder(403, ['error' => 'Token de seguridad inválido. Recargá la página.']);
    }
}

function manejarGet(PDO $pdo): void
{
    $id = isset($_GET['id']) ? (int) $_GET['id'] : 0;

    if ($id > 0) {
        $stmt = $pdo->prepare(
            'SELECT id_usuario, nombre, usuario, rol, activo
             FROM usuarios
             WHERE id_usuario = ?
             LIMIT 1'
        );
        $stmt->execute([$id]);
        $user = $stmt->fetch();

        if (!$user) {
            responder(404, ['error' => 'Usuario no encontrado.']);
        }

        $user['id_usuario'] = (int) $user['id_usuario'];
        $user['activo'] = (int) $user['activo'];
        responder(200, ['success' => true, 'user' => $user]);
    }

    $stmt = $pdo->query(
        'SELECT id_usuario, nombre, usuario, rol, activo
         FROM usuarios
         ORDER BY id_usuario ASC'
    );

    $users = [];
    while ($row = $stmt->fetch()) {
        $users[] = [
            'id_usuario' => (int) $row['id_usuario'],
            'nombre' => $row['nombre'],
            'usuario' => $row['usuario'],
            'rol' => $row['rol'],
            'activo' => (int) $row['activo'],
        ];
    }

    responder(200, ['success' => true, 'users' => $users]);
}

function manejarPost(PDO $pdo): void
{
    $body = leerJson();
    [$nombre, $usuario, $password, $rol] = validarPayloadCreacion($body);

    $stmt = $pdo->prepare('SELECT id_usuario FROM usuarios WHERE usuario = ? LIMIT 1');
    $stmt->execute([$usuario]);
    if ($stmt->fetch()) {
        responder(409, ['error' => 'El nombre de usuario ya está registrado.']);
    }

    $passwordHash = password_hash($password, PASSWORD_DEFAULT);

    $stmt = $pdo->prepare(
        'INSERT INTO usuarios (nombre, usuario, password_hash, rol, activo)
         VALUES (?, ?, ?, ?, 1)'
    );
    $stmt->execute([$nombre, $usuario, $passwordHash, $rol]);

    responder(201, [
        'success' => true,
        'message' => "Usuario '{$usuario}' creado correctamente.",
        'user_id' => (int) $pdo->lastInsertId(),
    ]);
}

function manejarPut(PDO $pdo): void
{
    $body = leerJson();

    $id = isset($body['id_usuario']) ? (int) $body['id_usuario'] : 0;
    if ($id <= 0) {
        responder(400, ['error' => 'ID de usuario inválido.']);
    }

    [$nombre, $usuario, $rol, $nuevaPassword] = validarPayloadActualizacion($body);

    $stmt = $pdo->prepare('SELECT id_usuario FROM usuarios WHERE id_usuario = ? LIMIT 1');
    $stmt->execute([$id]);
    if (!$stmt->fetch()) {
        responder(404, ['error' => 'Usuario no encontrado.']);
    }

    $stmt = $pdo->prepare('SELECT id_usuario FROM usuarios WHERE usuario = ? AND id_usuario <> ? LIMIT 1');
    $stmt->execute([$usuario, $id]);
    if ($stmt->fetch()) {
        responder(409, ['error' => 'El nombre de usuario ya está en uso por otra cuenta.']);
    }

    if ($nuevaPassword !== '') {
        $stmt = $pdo->prepare(
            'UPDATE usuarios
             SET nombre = ?, usuario = ?, rol = ?, password_hash = ?
             WHERE id_usuario = ?'
        );
        $stmt->execute([
            $nombre,
            $usuario,
            $rol,
            password_hash($nuevaPassword, PASSWORD_DEFAULT),
            $id,
        ]);
    } else {
        $stmt = $pdo->prepare(
            'UPDATE usuarios
             SET nombre = ?, usuario = ?, rol = ?
             WHERE id_usuario = ?'
        );
        $stmt->execute([$nombre, $usuario, $rol, $id]);
    }

    responder(200, ['success' => true, 'message' => 'Usuario actualizado correctamente.']);
}

function manejarDelete(PDO $pdo): void
{
    $body = leerJson();
    $id = isset($body['id_usuario']) ? (int) $body['id_usuario'] : 0;

    if ($id <= 0) {
        responder(400, ['error' => 'ID de usuario inválido.']);
    }

    $stmt = $pdo->prepare('SELECT usuario FROM usuarios WHERE id_usuario = ? LIMIT 1');
    $stmt->execute([$id]);
    $user = $stmt->fetch();
    if (!$user) {
        responder(404, ['error' => 'Usuario no encontrado.']);
    }

    $stmt = $pdo->prepare('DELETE FROM usuarios WHERE id_usuario = ?');
    $stmt->execute([$id]);

    responder(200, [
        'success' => true,
        'message' => "Usuario '{$user['usuario']}' eliminado correctamente.",
    ]);
}

function leerJson(): array
{
    $body = json_decode(file_get_contents('php://input'), true);

    if (!is_array($body)) {
        responder(400, ['error' => 'Cuerpo de solicitud inválido.']);
    }

    return $body;
}

function validarPayloadCreacion(array $body): array
{
    $nombre = trim((string) ($body['nombre'] ?? ''));
    $usuario = trim((string) ($body['usuario'] ?? ''));
    $password = (string) ($body['password'] ?? '');
    $rol = (string) ($body['rol'] ?? '');

    validarNombre($nombre);
    validarUsuario($usuario);
    validarPassword($password, true);
    validarRol($rol);

    return [$nombre, $usuario, $password, $rol];
}

function validarPayloadActualizacion(array $body): array
{
    $nombre = trim((string) ($body['nombre'] ?? ''));
    $usuario = trim((string) ($body['usuario'] ?? ''));
    $rol = (string) ($body['rol'] ?? '');
    $nuevaPassword = (string) ($body['nueva_password'] ?? '');

    validarNombre($nombre);
    validarUsuario($usuario);
    validarRol($rol);
    validarPassword($nuevaPassword, false);

    return [$nombre, $usuario, $rol, $nuevaPassword];
}

function validarNombre(string $nombre): void
{
    if ($nombre === '') {
        responder(400, ['error' => 'El nombre completo es obligatorio.']);
    }

    if (stringLength($nombre) > 100) {
        responder(400, ['error' => 'El nombre completo es demasiado largo.']);
    }
}

function validarUsuario(string $usuario): void
{
    if ($usuario === '') {
        responder(400, ['error' => 'El nombre de usuario es obligatorio.']);
    }

    if (stringLength($usuario) > 50) {
        responder(400, ['error' => 'El nombre de usuario es demasiado largo.']);
    }
}

function validarPassword(string $password, bool $required): void
{
    if ($password === '') {
        if ($required) {
            responder(400, ['error' => 'La contraseña es obligatoria.']);
        }
        return;
    }

    if (strlen($password) < 6) {
        responder(400, ['error' => 'La contraseña debe tener al menos 6 caracteres.']);
    }

    if (strlen($password) > 255) {
        responder(400, ['error' => 'La contraseña es demasiado larga.']);
    }
}

function validarRol(string $rol): void
{
    if (!in_array($rol, ['Administrador', 'Capataz'], true)) {
        responder(400, ['error' => 'Seleccione un rol válido.']);
    }
}

function responder(int $status, array $payload): void
{
    http_response_code($status);
    echo json_encode($payload);
    exit;
}

function stringLength(string $value): int
{
    if (function_exists('mb_strlen')) {
        return mb_strlen($value);
    }

    return strlen($value);
}