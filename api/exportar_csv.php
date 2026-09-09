<?php

require_once __DIR__ . '/config/db.php';
require_once __DIR__ . '/config/session.php';
require_once __DIR__ . '/config/auditoria.php';

$origin = (isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off' ? 'https' : 'http')
    . '://' . ($_SERVER['HTTP_HOST'] ?? 'localhost');

header("Access-Control-Allow-Origin: {$origin}");
header('Access-Control-Allow-Credentials: true');
header('Access-Control-Allow-Headers: Content-Type, X-CSRF-Token');
header('Access-Control-Allow-Methods: GET, OPTIONS');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405);
    header('Content-Type: application/json');
    echo json_encode(['success' => false, 'error' => 'Método no permitido']);
    exit;
}

iniciarSesion();

if (empty($_SESSION['user_id'])) {
    http_response_code(401);
    header('Content-Type: application/json');
    echo json_encode(['success' => false, 'error' => 'Sesión no válida. Iniciá sesión nuevamente.']);
    exit;
}

$esAdmin = (($_SESSION['rol'] ?? '') === 'Administrador');

// Lista blanca de entidades exportables. Nada de SQL dinámico:
// cada entidad tiene su consulta fija y sus columnas fijas.
$entidades = [
    'usuarios' => [
        'archivo'   => 'usuarios',
        'columnas'  => ['ID', 'Nombre', 'Usuario', 'Correo', 'Rol', 'Activo'],
        'sql'       => 'SELECT id_usuario, nombre, usuario, correo, rol, IF(activo, "Sí", "No")
                        FROM usuarios ORDER BY id_usuario',
    ],
    'obras' => [
        'archivo'   => 'obras',
        'columnas'  => ['ID', 'N° Contrata', 'Nombre', 'Dirección', 'Descripción', 'Fecha inicio', 'Fecha fin', 'Cliente', 'Teléfono', 'Activo'],
        'sql'       => 'SELECT id_obra, numero_contrata, nombre, direccion, descripcion, fecha_inicio, fecha_fin, nombre_cliente, telefono_cliente, IF(activo, "Sí", "No")
                        FROM obras ORDER BY id_obra',
    ],
    'obreros' => [
        'archivo'   => 'obreros',
        'columnas'  => ['ID', 'Nombre', 'Apellido', 'Documento', 'Teléfono', 'Fecha contratación', 'Fecha fin', 'Cargo', 'Activo'],
        'sql'       => 'SELECT id_obrero, nombre, apellido, documento, telefono, fecha_contratacion, fecha_fin, cargo, IF(activo, "Sí", "No")
                        FROM obreros ORDER BY id_obrero',
    ],
    'registros' => [
        'archivo'   => 'registros',
        'columnas'  => ['ID', 'Fecha', 'Obra', 'Obrero', 'Entrada', 'Salida', 'Horas'],
    ],
    'recursos' => [
        'archivo'   => 'recursos',
        'columnas'  => ['ID', 'ID Obra', 'Fecha', 'Nombre', 'Cantidad', 'Precio unitario', 'Es material'],
        'sql'       => 'SELECT id_recurso, id_obra, fecha, nombre, cantidad, precio_unitario, IF(es_material, "Sí", "No")
                        FROM recursos ORDER BY id_recurso',
    ],
    'maquinaria' => [
        'archivo'   => 'maquinaria',
        'columnas'  => ['ID', 'Nombre', 'Marca'],
        'sql'       => 'SELECT id_maquinaria, nombre, marca FROM maquinaria ORDER BY id_maquinaria',
    ],
    'obra_maquinaria' => [
        'archivo'   => 'obra_maquinaria',
        'columnas'  => ['ID', 'ID Obra', 'ID Maquinaria', 'Fecha asignación', 'Fecha retiro'],
        'sql'       => 'SELECT id_obra_maquinaria, id_obra, id_maquinaria, fecha_asignacion, fecha_retiro
                        FROM obra_maquinaria ORDER BY id_obra_maquinaria',
    ],
    'asistencia_maquinaria' => [
        'archivo'   => 'asistencia_maquinaria',
        'columnas'  => ['ID', 'ID Obra', 'ID Maquinaria', 'Fecha', 'Hora salida', 'Hora devolución'],
        'sql'       => 'SELECT id, id_obra, id_maquinaria, fecha, hora_salida, hora_devolucion
                        FROM asistencia_maquinaria ORDER BY id',
    ],
    'intentos_login' => [
        'archivo'    => 'intentos_login',
        'columnas'   => ['ID', 'Usuario', 'IP', 'Fecha', 'Exitoso'],
        'sql'        => 'SELECT id, username, ip_address, fecha, IF(exitoso, "Sí", "No")
                         FROM intentos_login ORDER BY id',
        'solo_admin' => true,
    ],
    'auditoria_logs' => [
        'archivo'    => 'auditoria_logs',
        'columnas'   => ['ID', 'ID Usuario', 'Usuario', 'Rol', 'Acción', 'Entidad', 'Entidad ID', 'Detalle', 'IP', 'Fecha'],
        'sql'        => 'SELECT id_log, id_usuario, usuario, rol, accion, entidad, entidad_id, detalle_json, ip_address, created_at
                         FROM auditoria_logs ORDER BY id_log DESC',
        'solo_admin' => true,
    ],
];

function construirCsv(array $columnas, array $filas): string
{
    $fh = fopen('php://temp', 'r+');
    fwrite($fh, "\xEF\xBB\xBF"); // BOM para que Excel detecte UTF-8
    fputcsv($fh, $columnas);
    foreach ($filas as $fila) {
        fputcsv($fh, $fila);
    }
    rewind($fh);
    $csv = stream_get_contents($fh);
    fclose($fh);
    return $csv;
}

function exportarCsv(string $archivo, string $csv): void
{
    header('Content-Type: text/csv; charset=utf-8');
    header('Content-Disposition: attachment; filename="' . $archivo . '.csv"');
    header('Content-Length: ' . strlen($csv));
    echo $csv;
    exit;
}

function exportarZip(array $archivos): void
{
    $data = construirZip($archivos);

    header('Content-Type: application/zip');
    header('Content-Disposition: attachment; filename="portico_export_' . date('Ymd_His') . '.zip"');
    header('Content-Length: ' . strlen($data));
    echo $data;
    exit;
}

// Genera un ZIP "stored" (sin compresión) sin depender de la extensión ZipArchive.
function construirZip(array $archivos): string
{
    $partesLocales = [];
    $partesCentral = [];
    $offset        = 0;

    $fecha   = getdate();
    $horaDos = ($fecha['hours'] << 11) | ($fecha['minutes'] << 5) | (int) ($fecha['seconds'] / 2);
    $fechaDos = ((($fecha['year'] - 1980) & 0x7f) << 9) | ($fecha['mon'] << 5) | $fecha['mday'];

    foreach ($archivos as $nombre => $contenido) {
        $crc        = crc32($contenido);
        $tamano     = strlen($contenido);
        $longNombre = strlen($nombre);

        $encabezadoLocal = pack('VvvvvvVVVvv',
            0x04034b50, 20, 0x0800, 0, $horaDos, $fechaDos,
            $crc, $tamano, $tamano, $longNombre, 0
        ) . $nombre . $contenido;

        $partesLocales[] = $encabezadoLocal;

        $encabezadoCentral = pack('VvvvvvvVVVvvvvvVV',
            0x02014b50, 20, 20, 0x0800, 0, $horaDos, $fechaDos,
            $crc, $tamano, $tamano, $longNombre, 0, 0, 0, 0, 0, $offset
        ) . $nombre;

        $partesCentral[] = $encabezadoCentral;
        $offset += strlen($encabezadoLocal);
    }

    $directorioCentral = implode('', $partesCentral);

    $fin = pack('VvvvvVVv',
        0x06054b50, 0, 0,
        count($archivos), count($archivos),
        strlen($directorioCentral), $offset, 0
    );

    return implode('', $partesLocales) . $directorioCentral . $fin;
}

try {
    $pdo = conectar();
    $pdo->setAttribute(PDO::ATTR_DEFAULT_FETCH_MODE, PDO::FETCH_ASSOC);

    $entidad = trim((string) ($_GET['entidad'] ?? ''));

    if ($entidad === 'todas') {
        $archivos = [];
        foreach ($entidades as $nombre => $def) {
            if (!empty($def['solo_admin']) && !$esAdmin) {
                continue;
            }

            if ($nombre === 'registros') {
                [$sql, $params] = construirConsultaRegistros();
                $filas = ejecutarFilas($pdo, $sql, $params);
            } else {
                $filas = $pdo->query($def['sql'])->fetchAll(PDO::FETCH_NUM);
            }

            $archivos[$def['archivo'] . '.csv'] = construirCsv($def['columnas'], $filas);
        }

        registrarAuditoria($pdo, 'exportar', 'todas', null, ['entidades' => array_keys($archivos)]);

        exportarZip($archivos);
    }

    if (!isset($entidades[$entidad])) {
        throw new InvalidArgumentException('Entidad no válida. Use "entidad=todas" para exportar todo.');
    }

    $def = $entidades[$entidad];

    if (!empty($def['solo_admin']) && !$esAdmin) {
        http_response_code(403);
        header('Content-Type: application/json');
        echo json_encode(['success' => false, 'error' => 'No tenés permisos para exportar esta entidad.']);
        exit;
    }

    if ($entidad === 'registros') {
        [$sql, $params] = construirConsultaRegistros();
        $filas = ejecutarFilas($pdo, $sql, $params);
    } else {
        $filas = $pdo->query($def['sql'])->fetchAll(PDO::FETCH_NUM);
    }

    registrarAuditoria($pdo, 'exportar', $entidad, null, ['filas' => count($filas)]);

    exportarCsv($def['archivo'], construirCsv($def['columnas'], $filas));

} catch (InvalidArgumentException $e) {
    http_response_code(400);
    header('Content-Type: application/json');
    echo json_encode(['success' => false, 'error' => $e->getMessage()]);
} catch (Throwable $e) {
    error_log('exportar_csv.php error: ' . $e->getMessage());
    http_response_code(500);
    header('Content-Type: application/json');
    echo json_encode(['success' => false, 'error' => 'Error interno del servidor.']);
}

function construirConsultaRegistros(): array
{
    $idObrero = (int) ($_GET['id_obrero'] ?? 0);
    $fechaDesde = trim((string) ($_GET['fecha_desde'] ?? ''));
    $fechaHasta = trim((string) ($_GET['fecha_hasta'] ?? ''));

    $where = [];
    $params = [];

    if ($idObrero > 0) {
        $where[] = 'r.id_obrero = ?';
        $params[] = $idObrero;
    }

    if ($fechaDesde !== '' && $fechaHasta !== '') {
        $where[] = 'r.fecha BETWEEN ? AND ?';
        $params[] = $fechaDesde;
        $params[] = $fechaHasta;
    }

    $whereSql = $where ? ' WHERE ' . implode(' AND ', $where) : '';

    $sql = "SELECT r.id_registro, r.fecha, o.nombre, CONCAT(b.nombre, ' ', COALESCE(b.apellido, '')), r.hora_entrada, r.hora_salida, r.horas_trabajadas
            FROM registros r
            INNER JOIN obras o ON o.id_obra = r.id_obra
            INNER JOIN obreros b ON b.id_obrero = r.id_obrero
            {$whereSql}
            ORDER BY r.fecha DESC, r.id_registro DESC";

    return [$sql, $params];
}

function ejecutarFilas(PDO $pdo, string $sql, array $params): array
{
    $stmt = $pdo->prepare($sql);
    foreach ($params as $index => $value) {
        $stmt->bindValue($index + 1, $value);
    }
    $stmt->execute();
    return $stmt->fetchAll(PDO::FETCH_NUM);
}
