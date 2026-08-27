<?php
require_once __DIR__ . "/config/db.php";
require_once __DIR__ . "/config/session.php";
require_once __DIR__ . "/config/utils.php";
require_once __DIR__ . "/config/auditoria.php";

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

iniciarSesion();

if ($_SERVER["REQUEST_METHOD"] !== "POST") {
    http_response_code(405);
    echo json_encode(["success" => false, "error" => "Método no permitido."]);
    exit;
}

validarCsrf();

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

    validarEntradaAsistencia($id_obra, $fecha);

    guardarObreros($pdo, $fecha, $id_obra, $id_usuario);
    guardarMateriales($pdo, $fecha, $id_obra);
    guardarMaquinaria($pdo, $fecha, $id_obra);
    guardarCombustible($pdo, $fecha, $id_obra);
    finalizarObra($pdo, $fecha, $id_obra);

    $obraFinalizada = (isset($_POST['finaliza']) && in_array(strtolower(trim((string) $_POST['finaliza'])), ['si', 'sí'], true));
    $totalObreros = count($_POST['obreros'] ?? []);
    $totalMateriales = count($_POST['material_nombre'] ?? []);
    $totalHerramientas = count($_POST['herramienta_nombre'] ?? []);
    $totalMaquinaria = count($_POST['maquinaria'] ?? []);
    $totalCombustible = count(array_filter($_POST['litros'] ?? [], function($v) { return (float)$v > 0; }));

    registrarAuditoria($pdo, 'guardar', 'asistencia', $id_obra, [
        'id_obra' => $id_obra,
        'fecha' => $fecha,
        'obreros' => $totalObreros,
        'materiales' => $totalMateriales,
        'herramientas' => $totalHerramientas,
        'maquinarias' => $totalMaquinaria,
        'combustible_items' => $totalCombustible,
        'obra_finalizada' => $obraFinalizada,
    ]);

    $pdo->commit();

    echo json_encode([
        "success" => true,
        "message" => "Asistencia guardada correctamente"
    ]);
} catch (InvalidArgumentException $e) {
    if (isset($pdo) && $pdo->inTransaction()) {
        $pdo->rollBack();
    }

    http_response_code(400);
    echo json_encode([
        "success" => false,
        "error" => $e->getMessage()
    ]);
} catch (Throwable $e) {
    if (isset($pdo) && $pdo->inTransaction()) {
        $pdo->rollBack();
    }

    http_response_code(500);
    echo json_encode([
        "success" => false,
        "error" => $e->getMessage()
    ]);
}

function validarEntradaAsistencia(?int $id_obra, ?string $fecha): void
{
    if (!$id_obra || !$fecha || !preg_match('/^\d{4}-\d{2}-\d{2}$/', $fecha)) {
        throw new InvalidArgumentException("Datos incompletos o inválidos.");
    }
}

function calcularHoras(string $entrada, string $salida): float
{
    $horas = (strtotime($salida) - strtotime($entrada)) / 3600;
    if ($horas < 0) {
        throw new InvalidArgumentException("La hora de salida debe ser mayor a la de entrada.");
    }
    return $horas;
}

function guardarObreros(PDO $pdo, string $fecha, int $id_obra, int $id_usuario): void
{
    if (empty($_POST['obreros']) || !is_array($_POST['obreros'])) {
        return;
    }

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
            throw new InvalidArgumentException("Horas de entrada/salida inválidas para el obrero {$id_obrero}.");
        }

        $horas = calcularHoras($entrada, $salida);

        $stmt->execute([$fecha, $entrada, $salida, $horas, $id_obrero, $id_obra, $id_usuario]);
    }
}

function guardarMateriales(PDO $pdo, string $fecha, int $id_obra): void
{
    if (empty($_POST['material_nombre']) || !is_array($_POST['material_nombre'])) {
        return;
    }

    $stmt = $pdo->prepare("
        INSERT INTO recursos (id_obra, fecha, nombre, cantidad, precio_unitario, es_material)
        VALUES (?, ?, ?, ?, ?, 1)
    ");

    for ($i = 0; $i < count($_POST['material_nombre']); $i++) {
        $nombre = isset($_POST['material_nombre'][$i]) ? trim((string) $_POST['material_nombre'][$i]) : '';
        $cantidad = isset($_POST['material_cantidad'][$i]) && is_numeric($_POST['material_cantidad'][$i]) ? (float) $_POST['material_cantidad'][$i] : null;
        $precio = isset($_POST['material_costo'][$i]) && is_numeric($_POST['material_costo'][$i]) ? (float) $_POST['material_costo'][$i] : null;

            if ($nombre === '' || $cantidad === null || $cantidad <= 0) {
                throw new InvalidArgumentException("Material inválido en la fila " . ($i + 1) . ".");
            }

        $stmt->execute([$id_obra, $fecha, $nombre, $cantidad, $precio]);
    }
}

function guardarHerramientas(PDO $pdo, string $fecha, int $id_obra): void
{
    if (empty($_POST['herramienta_nombre']) || !is_array($_POST['herramienta_nombre'])) {
        return;
    }

    $stmt = $pdo->prepare("
        INSERT INTO recursos (id_obra, fecha, nombre, cantidad, es_material)
        VALUES (?, ?, ?, ?, 0)
    ");

    for ($i = 0; $i < count($_POST['herramienta_nombre']); $i++) {
        $nombre = isset($_POST['herramienta_nombre'][$i]) ? trim((string) $_POST['herramienta_nombre'][$i]) : '';
        $cantidad = isset($_POST['herramienta_cantidad'][$i]) && is_numeric($_POST['herramienta_cantidad'][$i]) ? (float) $_POST['herramienta_cantidad'][$i] : null;

            if ($nombre === '' || $cantidad === null || $cantidad <= 0) {
                throw new InvalidArgumentException("Herramienta inválida en la fila " . ($i + 1) . ".");
            }

        $stmt->execute([$id_obra, $fecha, $nombre, $cantidad]);
    }
}

function guardarMaquinaria(PDO $pdo, string $fecha, int $id_obra): void
{
    if (empty($_POST['maquinaria']) || !is_array($_POST['maquinaria'])) {
        return;
    }

    $stmtObra = $pdo->prepare("
        INSERT IGNORE INTO obra_maquinaria
        (id_obra, id_maquinaria, fecha_asignacion)
        VALUES (?, ?, ?)
    ");

    $stmtAsistencia = $pdo->prepare("
        INSERT INTO asistencia_maquinaria
        (id_obra, id_maquinaria, fecha, hora_salida, hora_devolucion)
        VALUES (?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            hora_salida = VALUES(hora_salida),
            hora_devolucion = VALUES(hora_devolucion)
    ");

    foreach ($_POST['maquinaria'] as $id_maquinaria) {

        $id_maquinaria = (int) $id_maquinaria;

        if ($id_maquinaria <= 0) {
            continue;
        }

        $salida = isset($_POST['retiro_maquinaria'][$id_maquinaria])
            ? trim((string) $_POST['retiro_maquinaria'][$id_maquinaria])
            : null;

        $retorno = isset($_POST['devolucion_maquinaria'][$id_maquinaria])
            ? trim((string) $_POST['devolucion_maquinaria'][$id_maquinaria])
            : null;

        if (!$salida || !$retorno) {
            throw new InvalidArgumentException(
                "Faltan horarios de maquinaria ID {$id_maquinaria}."
            );
        }

        if (!preg_match('/^\d{2}:\d{2}$/', $salida) ||
            !preg_match('/^\d{2}:\d{2}$/', $retorno)) {
            throw new InvalidArgumentException(
                "Horarios inválidos en maquinaria ID {$id_maquinaria}."
            );
        }

        if (strtotime($retorno) < strtotime($salida)) {
            throw new InvalidArgumentException(
                "La devolución no puede ser antes de la salida (maquinaria ID {$id_maquinaria})."
            );
        }

        $stmtObra->execute([$id_obra, $id_maquinaria, $fecha]);

        $stmtAsistencia->execute([$id_obra, $id_maquinaria, $fecha, $salida, $retorno]);
    }
}

function guardarCombustible(PDO $pdo, string $fecha, int $id_obra): void
{
    if (empty($_POST['litros']) || !is_array($_POST['litros'])) {
        return;
    }

    // Asegurar que la tabla existe si no fue creada previamente
    $pdo->exec("
        CREATE TABLE IF NOT EXISTS combustible (
            id_combustible INT(11) NOT NULL AUTO_INCREMENT,
            nombre_combustible VARCHAR(50) NOT NULL DEFAULT 'Diesel',
            litros DECIMAL(10,2) NOT NULL DEFAULT 0.00,
            precio_unitario DECIMAL(10,2) NOT NULL DEFAULT 0.00,
            precio_total DECIMAL(10,2) NOT NULL DEFAULT 0.00,
            fecha DATE NOT NULL,
            id_obra INT(11) NOT NULL,
            id_maquinaria INT(11) NOT NULL,
            PRIMARY KEY (id_combustible),
            KEY fk_combustible_obra (id_obra),
            KEY fk_combustible_maquinaria (id_maquinaria)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
    ");

    $stmt = $pdo->prepare("
        INSERT INTO combustible
        (nombre_combustible, litros, precio_unitario, precio_total, fecha, id_obra, id_maquinaria)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ");

    foreach ($_POST['litros'] as $id_maquinaria => $litros) {
        $litros = (float) $litros;
        if ($litros <= 0) {
            continue;
        }

        $nombre_combustible = isset($_POST['nombre_combustible'][$id_maquinaria])
            ? trim((string) $_POST['nombre_combustible'][$id_maquinaria])
            : 'Diesel';

        $precio_total = isset($_POST['precio_total'][$id_maquinaria]) && is_numeric($_POST['precio_total'][$id_maquinaria])
            ? (float) $_POST['precio_total'][$id_maquinaria]
            : 0.0;

        $precio_unitario = ($litros > 0) ? round($precio_total / $litros, 2) : 0.0;

        $stmt->execute([
            $nombre_combustible,
            $litros,
            $precio_unitario,
            $precio_total,
            $fecha,
            $id_obra,
            (int) $id_maquinaria
        ]);
    }
}

function finalizarObra(PDO $pdo, string $fecha, int $id_obra): void
{
    $finaliza = isset($_POST['finaliza']) ? trim((string) $_POST['finaliza']) : 'No';
    if (strtolower($finaliza) === 'si' || $finaliza === 'Sí') {
        $stmt = $pdo->prepare("UPDATE obras SET fecha_fin = ? WHERE id_obra = ?");
        $stmt->execute([$fecha, $id_obra]);
        registrarAuditoria($pdo, 'finalizar_obra', 'obras', $id_obra, ['fecha_fin' => $fecha]);
    }
}

