<?php

require_once __DIR__ . '/config/db.php';
require_once __DIR__ . '/config/session.php';

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
    echo json_encode(['success' => false, 'error' => 'Método no permitido.']);
    exit;
}

iniciarSesion();

if (empty($_SESSION['user_id'])) {
    http_response_code(401);
    echo json_encode(['success' => false, 'error' => 'Sesión no válida.']);
    exit;
}

$idUsuario = (int)$_SESSION['user_id'];
$raw = file_get_contents('php://input');
$body = json_decode($raw, true) ?: [];

$tipo = trim($body['tipo'] ?? '');
$idReferencia = (int)($body['id_referencia'] ?? 0);

try {
    $pdo = conectar();
    $pdo->setAttribute(PDO::ATTR_DEFAULT_FETCH_MODE, PDO::FETCH_ASSOC);

    // Asegurar tabla
    $pdo->exec("
        CREATE TABLE IF NOT EXISTS notificaciones_leidas (
            id_usuario INT NOT NULL,
            tipo VARCHAR(20) NOT NULL,
            id_referencia INT NOT NULL,
            fecha_leido DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id_usuario, tipo, id_referencia),
            INDEX idx_notif_usuario (id_usuario)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ");

    if ($tipo === 'todas') {
        // Marcar todas las alertas pendientes de certificados como leídas
        $pdo->prepare("
            INSERT IGNORE INTO notificaciones_leidas (id_usuario, tipo, id_referencia)
            SELECT ?, 'maquinaria', id_certificado
            FROM certificado
            WHERE fecha_vencimiento IS NOT NULL AND fecha_vencimiento <= DATE_ADD(CURDATE(), INTERVAL 30 DAY)
        ")->execute([$idUsuario]);

        // Marcar todas las alertas pendientes de contratos de obreros como leídas
        $pdo->prepare("
            INSERT IGNORE INTO notificaciones_leidas (id_usuario, tipo, id_referencia)
            SELECT ?, 'obrero', id_contrato_obrero
            FROM contrato_obrero
            WHERE fecha_vencimiento IS NOT NULL AND fecha_vencimiento <= DATE_ADD(CURDATE(), INTERVAL 30 DAY)
        ")->execute([$idUsuario]);

        echo json_encode(['success' => true, 'message' => 'Todas las notificaciones fueron marcadas como leídas.']);
        exit;
    }

    if (!in_array($tipo, ['maquinaria', 'obrero'], true) || $idReferencia <= 0) {
        http_response_code(400);
        echo json_encode(['success' => false, 'error' => 'Parámetros inválidos.']);
        exit;
    }

    $stmt = $pdo->prepare("
        INSERT IGNORE INTO notificaciones_leidas (id_usuario, tipo, id_referencia)
        VALUES (?, ?, ?)
    ");
    $stmt->execute([$idUsuario, $tipo, $idReferencia]);

    echo json_encode(['success' => true, 'message' => 'Notificación marcada como leída.']);
} catch (Throwable $e) {
    error_log("marcar_notificacion error: " . $e->getMessage());
    http_response_code(500);
    echo json_encode(['success' => false, 'error' => 'Error al actualizar notificación.']);
}
