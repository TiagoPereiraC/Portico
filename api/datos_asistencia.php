<?php
require_once __DIR__ . "/config/db.php";
require_once __DIR__ . "/config/session.php";

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

iniciarSesion();

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

    // ================= MAQUINARIA =================
    $stmt = $pdo->query("SELECT id_maquinaria, nombre, marca FROM maquinaria ORDER BY nombre ASC");
    $maquinaria = $stmt->fetchAll();

    echo json_encode([
        "obras" => $obras,
        "obreros" => $obreros,
        "materiales" => $materiales,
        "herramientas" => $herramientas,
        "maquinaria" => $maquinaria
    ]);

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        "error" => "Error al cargar datos"
    ]);
}