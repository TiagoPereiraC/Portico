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
    $stmt = $pdo->query("SELECT id_obra, nombre FROM obras WHERE activo = 1");
    $obras = $stmt->fetchAll();

    // ================= OBREROS =================
    $searchObrero = trim((string) ($_GET['search_obrero'] ?? ''));
    $obrerosSql = 'SELECT id_obrero, nombre, apellido FROM obreros WHERE activo = 1';
    $obrerosParams = [];

    if ($searchObrero !== '') {
        $obrerosSql .= ' AND (nombre LIKE ? OR apellido LIKE ? OR documento LIKE ?)';
        $searchLike = $searchObrero . '%';
        $obrerosParams = [$searchLike, $searchLike, $searchLike];
    }

    $obrerosSql .= ' ORDER BY nombre';

    $stmt = $pdo->prepare($obrerosSql);
    foreach ($obrerosParams as $index => $value) {
        $stmt->bindValue($index + 1, $value, PDO::PARAM_STR);
    }
    $stmt->execute();
    $obreros = $stmt->fetchAll();

    // ================= MATERIALES =================
    $searchMaterial = trim((string) ($_GET['search_material'] ?? ''));

$matSql = "
    SELECT DISTINCT TRIM(nombre) AS nombre
    FROM recursos
    WHERE es_material = 1
      AND nombre IS NOT NULL
      AND TRIM(nombre) <> ''
";

$matParams = [];

if ($searchMaterial !== '') {
    $matSql .= " AND TRIM(nombre) LIKE ?";
    $matParams[] = '%' . $searchMaterial . '%';
}

$matSql .= " ORDER BY nombre ASC";

$stmt = $pdo->prepare($matSql);

foreach ($matParams as $index => $value) {
    $stmt->bindValue(
        $index + 1,
        $value,
        PDO::PARAM_STR
    );
}

$stmt->execute();

$materiales = $stmt->fetchAll(PDO::FETCH_ASSOC);

    // ================= HERRAMIENTAS =================
    $searchHerramienta = trim(
    (string) ($_GET['search_herramienta'] ?? '')
);

$herrSql = "
    SELECT DISTINCT TRIM(nombre) AS nombre
    FROM recursos
    WHERE es_material = 0
      AND nombre IS NOT NULL
      AND TRIM(nombre) <> ''
";

$herrParams = [];

if ($searchHerramienta !== '') {
    $herrSql .= " AND TRIM(nombre) LIKE ?";
    $herrParams[] = '%' . $searchHerramienta . '%';
}

$herrSql .= " ORDER BY nombre ASC";

$stmt = $pdo->prepare($herrSql);

foreach ($herrParams as $index => $value) {
    $stmt->bindValue(
        $index + 1,
        $value,
        PDO::PARAM_STR
    );
}

$stmt->execute();

$herramientas = $stmt->fetchAll(PDO::FETCH_ASSOC);

    // ================= MAQUINARIA =================
    $searchMaq = trim((string) ($_GET['search_maquinaria'] ?? ''));
    $maqSql = 'SELECT id_maquinaria, nombre, marca FROM maquinaria';
    $maqParams = [];

    if ($searchMaq !== '') {
        $maqSql .= ' WHERE nombre LIKE ? OR marca LIKE ?';
        $maqParams = [$searchMaq . '%', $searchMaq . '%'];
    }

    $maqSql .= ' ORDER BY nombre ASC';

    $stmt = $pdo->prepare($maqSql);
    foreach ($maqParams as $index => $value) {
        $stmt->bindValue($index + 1, $value, PDO::PARAM_STR);
    }
    $stmt->execute();
    $maquinaria = $stmt->fetchAll();

    echo json_encode([
        "obras" => $obras,
        "obreros" => $obreros,
        "materiales" => $materiales,
        "herramientas" => $herramientas,
        "maquinaria" => $maquinaria
    ]);

} catch (Throwable $e) {
    error_log('datos_asistencia.php error: ' . $e->getMessage());
    http_response_code(500);
    echo json_encode([
        "error" => "Error al cargar datos"
    ]);
}