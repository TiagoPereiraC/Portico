<?php
require_once __DIR__ . "/config/db.php";
require_once __DIR__ . "/config/session.php";

iniciarSesion();

header('Content-Type: application/json');

if (empty($_SESSION['user_id'])) {
    http_response_code(401);
    echo json_encode(['error' => 'Sesión no válida. Iniciá sesión nuevamente.']);
    exit;
}

try {

    $pdo = conectar();

    // ================= OBRAS =================
    $stmt = $pdo->query("SELECT id_obra, nombre FROM obras");
    $obras = $stmt->fetchAll();

    // ================= OBREROS =================
    $stmt = $pdo->query("SELECT id_obrero, nombre, apellido FROM obreros WHERE activo = 1");
    $obreros = $stmt->fetchAll();

    // ================= MATERIALES =================
    $stmt = $pdo->query("SELECT DISTINCT nombre FROM recursos WHERE es_material = 1");
    $materiales = $stmt->fetchAll();

    // ================= HERRAMIENTAS =================
    $stmt = $pdo->query("SELECT DISTINCT nombre FROM recursos WHERE es_material = 0");
    $herramientas = $stmt->fetchAll();

    echo json_encode([
        "obras" => $obras,
        "obreros" => $obreros,
        "materiales" => $materiales,
        "herramientas" => $herramientas
    ]);

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        "error" => "Error al cargar datos"
    ]);
}