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

iniciarSesion();

if (empty($_SESSION['user_id'])) {
    http_response_code(401);
    echo json_encode(['error' => 'Sesión no válida. Iniciá sesión nuevamente.']);
    exit;
}

$dias = isset($_GET['dias']) ? (int) $_GET['dias'] : 30;
$dias = max(1, min($dias, 365));

try {
    $pdo = conectar();

    $stmt = $pdo->prepare(
        'SELECT c.id_certificado, c.nombre_archivo, c.fecha_vencimiento,
                m.id_maquinaria, m.nombre AS nombre_maquinaria, m.marca,
                DATEDIFF(c.fecha_vencimiento, CURDATE()) AS dias_restantes
         FROM certificado c
         JOIN maquinaria m ON c.id_maquinaria = m.id_maquinaria
         WHERE c.fecha_vencimiento IS NOT NULL
           AND c.fecha_vencimiento <= DATE_ADD(CURDATE(), INTERVAL ? DAY)
         ORDER BY c.fecha_vencimiento ASC'
    );
    $stmt->execute([$dias]);
    $alertas = $stmt->fetchAll();

    $hoy = date('Y-m-d');
    $expirados = array_filter($alertas, fn($a) => $a['fecha_vencimiento'] < $hoy);
    $proximos = array_filter($alertas, fn($a) => $a['fecha_vencimiento'] >= $hoy);

    echo json_encode([
        'success' => true,
        'dias_consulta' => $dias,
        'total' => count($alertas),
        'expirados' => count($expirados),
        'proximos' => count($proximos),
        'alertas' => $alertas,
    ]);
} catch (Throwable $e) {
    error_log('alertas_certificados.php error: ' . $e->getMessage());
    http_response_code(500);
    echo json_encode(['error' => 'Error interno del servidor.']);
}
