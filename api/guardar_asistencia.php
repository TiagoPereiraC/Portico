<?php
require_once __DIR__ . "/config/db.php";
require_once __DIR__ . "/config/session.php";

iniciarSesion();

header('Content-Type: application/json');

if ($_SERVER["REQUEST_METHOD"] !== "POST") {
    http_response_code(405);
    echo json_encode(["success" => false, "error" => "Método no permitido."]);
    exit;
}

if (empty($_SESSION['user_id'])) {
    http_response_code(401);
    echo json_encode(["success" => false, "error" => "Sesión no válida. Iniciá sesión nuevamente."]);
    exit;
}

$rol = $_SESSION['rol'] ?? '';
if ($rol !== 'Administrador' && $rol !== 'Capataz') {
    http_response_code(403);
    echo json_encode(["success" => false, "error" => "No tenés permisos para registrar asistencia."]);
    exit;
}

try {
    $pdo = conectar();
    $pdo->beginTransaction();

    $id_obra = isset($_POST['id_obra']) && is_numeric($_POST['id_obra']) ? (int) $_POST['id_obra'] : null;
    $fecha = isset($_POST['fecha']) ? trim((string) $_POST['fecha']) : null;
    $id_usuario = (int) $_SESSION['user_id'];

    if (!$id_obra || !$fecha || !preg_match('/^\d{4}-\d{2}-\d{2}$/', $fecha)) {
        throw new Exception("Datos incompletos o inválidos.");
    }

    // ===== ASISTENCIA =====
    if (!empty($_POST['obreros']) && is_array($_POST['obreros'])) {
        $stmt = $pdo->prepare("
            INSERT INTO registros
            (fecha, hora_entrada, hora_salida, horas_trabajadas, id_obrero, id_obra, id_usuario)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        ");

        foreach ($_POST['obreros'] as $id_obrero) {
            $id_obrero = (int) $id_obrero;
            $entrada = isset($_POST['hora_entrada'][$id_obrero]) ? trim((string) $_POST['hora_entrada'][$id_obrero]) : null;
            $salida = isset($_POST['hora_salida'][$id_obrero]) ? trim((string) $_POST['hora_salida'][$id_obrero]) : null;

            if (!$entrada || !$salida || !preg_match('/^\d{2}:\d{2}$/', $entrada) || !preg_match('/^\d{2}:\d{2}$/', $salida)) {
                throw new Exception("Horas de entrada/salida inválidas para el obrero {$id_obrero}.");
            }

            $horas = (strtotime($salida) - strtotime($entrada)) / 3600;
            if ($horas < 0) {
                throw new Exception("La hora de salida debe ser mayor a la de entrada.");
            }

            $stmt->execute([
                $fecha,
                $entrada,
                $salida,
                $horas,
                $id_obrero,
                $id_obra,
                $id_usuario
            ]);
        }
    }

    // ===== MATERIALES =====
    if (!empty($_POST['material_nombre']) && is_array($_POST['material_nombre'])) {
        $stmt = $pdo->prepare("
            INSERT INTO recursos (id_obra, fecha, nombre, cantidad, precio_unitario, es_material)
            VALUES (?, ?, ?, ?, ?, 1)
        ");

        for ($i = 0; $i < count($_POST['material_nombre']); $i++) {
            $nombre = isset($_POST['material_nombre'][$i]) ? trim((string) $_POST['material_nombre'][$i]) : '';
            $cantidad = isset($_POST['material_cantidad'][$i]) && is_numeric($_POST['material_cantidad'][$i]) ? (float) $_POST['material_cantidad'][$i] : null;
            $precio = isset($_POST['material_costo'][$i]) && is_numeric($_POST['material_costo'][$i]) ? (float) $_POST['material_costo'][$i] : null;

            if ($nombre === '' || $cantidad === null || $cantidad <= 0) {
                throw new Exception("Material inválido en la fila " . ($i + 1) . ".");
            }

            $stmt->execute([
                $id_obra,
                $fecha,
                $nombre,
                $cantidad,
                $precio,
            ]);
        }
    }

    // ===== HERRAMIENTAS =====
    if (!empty($_POST['herramienta_nombre']) && is_array($_POST['herramienta_nombre'])) {
        $stmt = $pdo->prepare("
            INSERT INTO recursos (id_obra, fecha, nombre, cantidad, es_material)
            VALUES (?, ?, ?, ?, 0)
        ");

        for ($i = 0; $i < count($_POST['herramienta_nombre']); $i++) {
            $nombre = isset($_POST['herramienta_nombre'][$i]) ? trim((string) $_POST['herramienta_nombre'][$i]) : '';
            $cantidad = isset($_POST['herramienta_cantidad'][$i]) && is_numeric($_POST['herramienta_cantidad'][$i]) ? (float) $_POST['herramienta_cantidad'][$i] : null;

            if ($nombre === '' || $cantidad === null || $cantidad <= 0) {
                throw new Exception("Herramienta inválida en la fila " . ($i + 1) . ".");
            }

            $stmt->execute([
                $id_obra,
                $fecha,
                $nombre,
                $cantidad,
            ]);
        }
    }

    // ===== MAQUINARIA =====
    if (!empty($_POST['maquinaria']) && is_array($_POST['maquinaria'])) {
        $stmt = $pdo->prepare("
            INSERT IGNORE INTO asistencia_maquinaria (id_obra, id_maquinaria, fecha)
            VALUES (?, ?, ?)
        ");

        foreach ($_POST['maquinaria'] as $id_maquinaria) {
            $id_maquinaria = (int) $id_maquinaria;
            if ($id_maquinaria > 0) {
                $stmt->execute([$id_obra, $id_maquinaria, $fecha]);
            }
        }
    }

    $pdo->commit();

    echo json_encode([
        "success" => true,
        "message" => "Asistencia guardada correctamente"
    ]);
} catch (Exception $e) {
    if (isset($pdo) && $pdo->inTransaction()) {
        $pdo->rollBack();
    }

    http_response_code(500);
    echo json_encode([
        "success" => false,
        "error" => $e->getMessage()
    ]);
}
?>