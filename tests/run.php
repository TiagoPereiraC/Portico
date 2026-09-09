<?php
/**
 * Test runner for Portico API
 * Usage: php tests/run.php [--verbose]
 */

define('TESTS_DIR', __DIR__);
define('ROOT_DIR', dirname(__DIR__));

$_SERVER['HTTP_HOST'] = 'localhost';
$_SERVER['HTTPS'] = 'off';

$verbose = in_array('--verbose', $argv ?? []) || in_array('-v', $argv ?? []);

// Iniciar sesion antes de cualquier output
session_start();
$_SESSION['user_id'] = 1;
$_SESSION['rol'] = 'Administrador';

$passed = 0;
$failed = 0;
$errors = [];

function test(string $name, callable $fn): void
{
    global $passed, $failed, $errors, $verbose;

    try {
        $fn();
        $passed++;
        echo "  PASS  {$name}\n";
    } catch (Throwable $e) {
        $failed++;
        $errors[] = [$name, $e->getMessage()];
        echo "  FAIL  {$name}";
        if ($verbose) echo "\n         {$e->getMessage()}";
        echo "\n";
    }
}

function assertTrue($value, string $msg = ''): void
{
    if (!$value) throw new RuntimeException($msg ?: 'Expected true, got falsy');
}

function assertEquals($expected, $actual, string $msg = ''): void
{
    if ($expected !== $actual) throw new RuntimeException($msg ?: "Expected {$expected}, got {$actual}");
}

function assertArrayHasKey($key, array $array): void
{
    if (!array_key_exists($key, $array)) throw new RuntimeException("Array missing key '{$key}'");
}

function assertNotEmpty($value, string $msg = ''): void
{
    if (empty($value)) throw new RuntimeException($msg ?: 'Expected non-empty value');
}

// Iniciar sesion CLI para que los endpoints autenticados funcionen
function capturarApi(string $file): string
{
    ob_start();
    $prev = error_reporting(0);
    require $file;
    error_reporting($prev);
    return ob_get_clean();
}

// ===== INTEGRIDAD DE DATOS =====
echo "\n=== Integridad de datos ===\n";

require_once ROOT_DIR . '/api/config/db.php';

$pdo = conectar();
$pdo->setAttribute(PDO::ATTR_DEFAULT_FETCH_MODE, PDO::FETCH_ASSOC);

test('2+ usuarios', function () use ($pdo) {
    assertTrue($pdo->query("SELECT COUNT(*) FROM usuarios")->fetchColumn() >= 2);
});

test('2+ obras activas', function () use ($pdo) {
    assertTrue($pdo->query("SELECT COUNT(*) FROM obras WHERE activo = 1")->fetchColumn() >= 2);
});

test('4+ obreros activos', function () use ($pdo) {
    assertTrue($pdo->query("SELECT COUNT(*) FROM obreros WHERE activo = 1")->fetchColumn() >= 4);
});

test('10+ registros de asistencia', function () use ($pdo) {
    assertTrue($pdo->query("SELECT COUNT(*) FROM registros")->fetchColumn() >= 10);
});

test('2+ maquinarias', function () use ($pdo) {
    assertTrue($pdo->query("SELECT COUNT(*) FROM maquinaria")->fetchColumn() >= 2);
});

test('1+ obrero con fecha_fin vencida', function () use ($pdo) {
    assertTrue($pdo->query("SELECT COUNT(*) FROM obreros WHERE fecha_fin IS NOT NULL AND fecha_fin < CURDATE()")->fetchColumn() >= 1);
});

test('2+ obreros activos sin fecha_fin', function () use ($pdo) {
    assertTrue($pdo->query("SELECT COUNT(*) FROM obreros WHERE fecha_fin IS NULL AND activo = 1")->fetchColumn() >= 2);
});

// ===== ESQUEMA =====
echo "\n=== Esquema ===\n";

test('obreros tiene columna fecha_fin', function () use ($pdo) {
    $cols = $pdo->query("SHOW COLUMNS FROM obreros")->fetchAll(PDO::FETCH_COLUMN);
    assertTrue(in_array('fecha_fin', $cols));
});

test('registros.id_usuario permite NULL', function () use ($pdo) {
    $col = $pdo->query("SHOW COLUMNS FROM registros WHERE Field = 'id_usuario'")->fetch();
    assertEquals('YES', $col['Null']);
});

test('FK registros->usuarios es SET NULL', function () use ($pdo) {
    $rule = $pdo->query("
        SELECT DELETE_RULE FROM information_schema.REFERENTIAL_CONSTRAINTS
        WHERE CONSTRAINT_SCHEMA = DATABASE() AND TABLE_NAME = 'registros' AND REFERENCED_TABLE_NAME = 'usuarios' LIMIT 1
    ")->fetchColumn();
    assertEquals('SET NULL', $rule);
});

// ===== API: obtener_obrero.php =====
echo "\n=== API: obtener_obrero.php ===\n";

$_SERVER['REQUEST_METHOD'] = 'GET';
$_GET = [];

test('GET lista obreros activos', function () {
    $json = capturarApi(ROOT_DIR . '/api/obtener_obrero.php');
    $data = json_decode($json, true);
    assertTrue($data['success'] ?? false);
    assertNotEmpty($data['obreros']);
});

test('Cada obrero tiene id_obrero y nombre', function () {
    $json = capturarApi(ROOT_DIR . '/api/obtener_obrero.php');
    $data = json_decode($json, true);
    foreach ($data['obreros'] as $o) {
        assertArrayHasKey('id_obrero', $o);
        assertArrayHasKey('nombre', $o);
    }
});

// ===== API: consultas.php =====
echo "\n=== API: consultas.php ===\n";

$_SERVER['REQUEST_METHOD'] = 'GET';

test('Consulta por obrero devuelve resumen y registros', function () use ($pdo) {
    $idObrero = $pdo->query("SELECT id_obrero FROM obreros LIMIT 1")->fetchColumn();
    $_GET = ['id_obrero' => $idObrero, 'fecha_desde' => '', 'fecha_hasta' => ''];
    $json = capturarApi(ROOT_DIR . '/api/consultas.php');
    $data = json_decode($json, true);
    assertTrue($data['success'] ?? false);
    assertArrayHasKey('resumen', $data);
    assertArrayHasKey('registros', $data);
});

test('Sin parametros devuelve error', function () {
    $_GET = ['id_obrero' => 0, 'fecha_desde' => '', 'fecha_hasta' => ''];
    $json = capturarApi(ROOT_DIR . '/api/consultas.php');
    $data = json_decode($json, true);
    assertTrue(!($data['success'] ?? true), 'success debe ser false');
});

test('Registros incluyen campos esperados', function () use ($pdo) {
    $idObrero = $pdo->query("SELECT id_obrero FROM registros LIMIT 1")->fetchColumn();
    $_GET = ['id_obrero' => $idObrero, 'fecha_desde' => '', 'fecha_hasta' => ''];
    $json = capturarApi(ROOT_DIR . '/api/consultas.php');
    $data = json_decode($json, true);
    if (!empty($data['registros'])) {
        foreach (['fecha', 'obra', 'hora_entrada', 'hora_salida', 'horas_trabajadas'] as $field) {
            assertArrayHasKey($field, $data['registros'][0]);
        }
    }
});

// ===== RELACIONES =====
echo "\n=== Relaciones ===\n";

test('Registros sin huerfanos', function () use ($pdo) {
    $inv = $pdo->query("
        SELECT COUNT(*) FROM registros r
        LEFT JOIN obras o ON o.id_obra = r.id_obra
        LEFT JOIN obreros ob ON ob.id_obrero = r.id_obrero
        WHERE o.id_obra IS NULL OR ob.id_obrero IS NULL
    ")->fetchColumn();
    assertEquals(0, (int) $inv);
});

test('obra_maquinaria sin FK rotas', function () use ($pdo) {
    $inv = $pdo->query("
        SELECT COUNT(*) FROM obra_maquinaria om
        LEFT JOIN obras o ON o.id_obra = om.id_obra
        LEFT JOIN maquinaria m ON m.id_maquinaria = om.id_maquinaria
        WHERE o.id_obra IS NULL OR m.id_maquinaria IS NULL
    ")->fetchColumn();
    assertEquals(0, (int) $inv);
});

// ===== RESULTADOS =====
echo "\n========================================\n";
echo "  Total:    " . ($passed + $failed) . "\n";
echo "  Pasaron:  {$passed}\n";
echo "  Fallaron: {$failed}\n";
echo "========================================\n";

if ($failed > 0) {
    echo "\nFallos:\n";
    foreach ($errors as [$name, $msg]) {
        echo "  - {$name}: {$msg}\n";
    }
}

exit($failed > 0 ? 1 : 0);
