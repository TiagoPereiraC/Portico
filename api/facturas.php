<?php
declare(strict_types=1);

require_once __DIR__ . '/config/db.php';
require_once __DIR__ . '/config/session.php';
require_once __DIR__ . '/config/auditoria.php';

const MAX_ARCHIVO_BYTES = 8 * 1024 * 1024;
const DEBUG = false;

ini_set('display_errors', '0');

$origin = (isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off' ? 'https' : 'http')
    . '://' . ($_SERVER['HTTP_HOST'] ?? 'localhost');

header("Access-Control-Allow-Origin: {$origin}");
header('Access-Control-Allow-Credentials: true');
header('Access-Control-Allow-Headers: Content-Type, X-CSRF-Token');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');
header('X-Content-Type-Options: nosniff');

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

if (($_SESSION['rol'] ?? '') !== 'Administrador') {
    http_response_code(403);
    echo json_encode(['error' => 'No tenés permisos para gestionar facturas.']);
    exit;
}

$usuario = ['id' => (int) $_SESSION['user_id']];

/* ------------------------------------------------------------------ */
/* UTILIDADES                                                          */
/* ------------------------------------------------------------------ */

function responder(array $datos, int $codigo = 200): void
{
    http_response_code($codigo);

    echo json_encode(
        $datos,
        JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_PARTIAL_OUTPUT_ON_ERROR
    );

    exit;
}

function fallar(string $mensaje, int $codigo = 400): void
{
    responder(['success' => false, 'error' => $mensaje], $codigo);
}

function validarCsrf(): void
{
    $csrfRecibido = $_SERVER['HTTP_X_CSRF_TOKEN'] ?? '';
    $csrfGuardado = $_SESSION['csrf_token'] ?? '';

    if ($csrfGuardado === '' || !hash_equals($csrfGuardado, $csrfRecibido)) {
        http_response_code(403);
        echo json_encode(['error' => 'Token de seguridad inválido. Recargá la página.']);
        exit;
    }
}

function exigirMetodo(string $metodo): void
{
    if (($_SERVER['REQUEST_METHOD'] ?? '') !== $metodo) {
        fallar('Método no permitido.', 405);
    }
}

function leerJson(): array
{
    $crudo = file_get_contents('php://input');
    $datos = json_decode($crudo === false ? '' : $crudo, true);

    return is_array($datos) ? $datos : [];
}

function cortar(string $valor, int $maximo): string
{
    if (function_exists('mb_substr')) {
        return mb_substr($valor, 0, $maximo);
    }

    if (preg_match('/^.{0,' . $maximo . '}/us', $valor, $m) === 1) {
        return $m[0];
    }

    return substr($valor, 0, $maximo);
}

function texto($valor, int $maximo): string
{
    if (!is_scalar($valor)) {
        return '';
    }

    return cortar(trim((string) $valor), $maximo);
}

function numeroValido($valor): bool
{
    return is_numeric($valor) && is_finite((float) $valor);
}

function fechaValida(string $fecha): bool
{
    if (!preg_match('/^(\d{4})-(\d{2})-(\d{2})$/', $fecha, $m)) {
        return false;
    }

    return checkdate((int) $m[2], (int) $m[3], (int) $m[1]);
}

/* ------------------------------------------------------------------ */
/* LISTAR Y OBRAS                                                      */
/* ------------------------------------------------------------------ */

function accionListar(PDO $pdo): void
{
    exigirMetodo('GET');

    $filas = $pdo->query(
        'SELECT f.id_factura, f.numero_factura, f.proveedor,
                f.rut_proveedor AS rut_dni, f.fecha_emision,
                f.subtotal, f.iva, f.total, f.tipo_gasto, f.id_obra,
                o.nombre AS obra, f.estado, f.nombre_archivo, f.tipo_archivo
           FROM facturas f
           LEFT JOIN obras o ON o.id_obra = f.id_obra
          ORDER BY f.fecha_emision DESC, f.id_factura DESC
          LIMIT 2000'
    )->fetchAll();

    foreach ($filas as &$fila) {
        $fila['id_factura'] = (int) $fila['id_factura'];
        $fila['id_obra'] = $fila['id_obra'] !== null ? (int) $fila['id_obra'] : null;
        $fila['subtotal'] = (float) $fila['subtotal'];
        $fila['iva'] = (float) $fila['iva'];
        $fila['total'] = (float) $fila['total'];
    }
    unset($fila);

    responder(['success' => true, 'facturas' => $filas]);
}

function accionObras(PDO $pdo): void
{
    exigirMetodo('GET');

    $obras = $pdo->query(
        'SELECT id_obra, nombre FROM obras WHERE activo = 1 ORDER BY nombre'
    )->fetchAll();

    foreach ($obras as &$obra) {
        $obra['id_obra'] = (int) $obra['id_obra'];
    }
    unset($obra);

    responder(['success' => true, 'obras' => $obras]);
}

function accionArchivo(PDO $pdo): void
{
    exigirMetodo('GET');

    $id = (int) ($_GET['id'] ?? 0);

    if ($id <= 0) {
        fallar('Factura inválida.');
    }

    $st = $pdo->prepare(
        'SELECT archivo, nombre_archivo, tipo_archivo FROM facturas WHERE id_factura = ?'
    );
    $st->execute([$id]);
    $fila = $st->fetch();

    if (!$fila) {
        fallar('La factura no existe.', 404);
    }

    if ($fila['archivo'] === null || $fila['archivo'] === '') {
        fallar('Esta factura no tiene un archivo adjunto.', 404);
    }

    $permitidos = ['application/pdf', 'image/jpeg', 'image/png', 'image/webp'];
    $tipo = in_array($fila['tipo_archivo'], $permitidos, true)
        ? $fila['tipo_archivo']
        : 'application/octet-stream';

    $nombre = rawurlencode((string) ($fila['nombre_archivo'] ?: 'factura-' . $id));

    header('Content-Type: ' . $tipo);
    header("Content-Disposition: inline; filename*=UTF-8''" . $nombre);
    header('Content-Length: ' . strlen($fila['archivo']));

    http_response_code(200);
    echo $fila['archivo'];
    exit;
}

/* ------------------------------------------------------------------ */
/* GUARDAR                                                             */
/* ------------------------------------------------------------------ */

function detectarMime(string $ruta): string
{
    if (class_exists('finfo')) {
        return (string) (new finfo(FILEINFO_MIME_TYPE))->file($ruta);
    }

    $cabecera = (string) file_get_contents($ruta, false, null, 0, 12);

    if (strncmp($cabecera, '%PDF', 4) === 0) {
        return 'application/pdf';
    }

    if (strncmp($cabecera, "\xFF\xD8\xFF", 3) === 0) {
        return 'image/jpeg';
    }

    if (strncmp($cabecera, "\x89PNG\r\n\x1A\n", 8) === 0) {
        return 'image/png';
    }

    if (strncmp($cabecera, 'RIFF', 4) === 0 && substr($cabecera, 8, 4) === 'WEBP') {
        return 'image/webp';
    }

    return 'application/octet-stream';
}

function mensajeSubida(int $codigo): string
{
    switch ($codigo) {
        case UPLOAD_ERR_INI_SIZE:
        case UPLOAD_ERR_FORM_SIZE:
            return 'El archivo supera el tamaño máximo permitido por el servidor '
                . '(revisá upload_max_filesize y post_max_size en php.ini).';
        case UPLOAD_ERR_PARTIAL:
            return 'El archivo se subió de forma incompleta. Intentá de nuevo.';
        default:
            return 'No se pudo subir el archivo.';
    }
}

function accionGuardar(PDO $pdo, array $u): void
{
    exigirMetodo('POST');

    $numero = texto($_POST['numero_factura'] ?? '', 100);
    $proveedor = texto($_POST['proveedor'] ?? '', 150);
    $rut = texto($_POST['rut_dni'] ?? '', 30);
    $fecha = texto($_POST['fecha_emision'] ?? '', 10);
    $tipo = texto($_POST['tipo_gasto'] ?? 'General', 20);
    $textoOcr = cortar((string) ($_POST['texto_ocr'] ?? ''), 60000);

    $estado = texto($_POST['estado'] ?? 'Pendiente', 20);

    if (!in_array($estado, ['Pendiente', 'Verificada'], true)) {
        $estado = 'Pendiente';
    }

    if ($proveedor === '') {
        fallar('Ingresá el proveedor de la factura.');
    }

    if (!fechaValida($fecha)) {
        fallar('La fecha de emisión no es válida.');
    }

    if (!in_array($tipo, ['Obra', 'General'], true)) {
        fallar('El tipo de gasto no es válido.');
    }

    $idObra = null;

    if ($tipo === 'Obra') {
        $idObraCrudo = $_POST['id_obra'] ?? '';

        if (!ctype_digit((string) $idObraCrudo) || (int) $idObraCrudo <= 0) {
            fallar('Seleccioná la obra asociada.');
        }

        $st = $pdo->prepare('SELECT id_obra FROM obras WHERE id_obra = ?');
        $st->execute([(int) $idObraCrudo]);

        if (!$st->fetch()) {
            fallar('La obra seleccionada no existe.');
        }

        $idObra = (int) $idObraCrudo;
    }

    /* Detalle: el servidor recalcula los importes, no confía en los del navegador */

    $itemsCrudos = json_decode((string) ($_POST['items'] ?? '[]'), true);

    if (!is_array($itemsCrudos) || count($itemsCrudos) === 0) {
        fallar('Agregá al menos un ítem.');
    }

    if (count($itemsCrudos) > 500) {
        fallar('La factura tiene demasiados ítems.');
    }

    $items = [];
    $subtotal = 0.0;

    foreach ($itemsCrudos as $item) {
        if (!is_array($item)) {
            fallar('El detalle de la factura no es válido.');
        }

        $cantidad = $item['cantidad'] ?? null;
        $precio = $item['precio_unitario'] ?? null;

        if (!numeroValido($cantidad) || !numeroValido($precio)) {
            fallar('Hay ítems con cantidad o precio inválidos.');
        }

        $cantidad = round((float) $cantidad, 2);
        $precio = round((float) $precio, 2);

        if ($cantidad <= 0 || $precio < 0 || $cantidad > 99999999.99 || $precio > 9999999999.99) {
            fallar('Hay ítems con cantidad o precio fuera de rango.');
        }

        $importe = round($cantidad * $precio, 2);

        if ($importe > 9999999999.99) {
            fallar('El importe de un ítem es demasiado grande.');
        }

        $descripcion = texto($item['descripcion'] ?? '', 255);

        $items[] = [
            'descripcion' => $descripcion !== '' ? $descripcion : 'Sin descripción',
            'cantidad' => $cantidad,
            'precio_unitario' => $precio,
            'subtotal' => $importe,
        ];

        $subtotal += $importe;
    }

    $subtotal = round($subtotal, 2);

    $iva = $_POST['iva'] ?? 0;

    if (!numeroValido($iva) || (float) $iva < 0) {
        fallar('El IVA no es válido.');
    }

    $iva = round((float) $iva, 2);
    $total = round($subtotal + $iva, 2);

    if ($total > 9999999999.99) {
        fallar('El total de la factura es demasiado grande.');
    }

    /* Evita cargar dos veces la misma factura (se contaría dos veces el gasto) */

    if ($numero !== '') {
        $st = $pdo->prepare(
            "SELECT id_factura FROM facturas
              WHERE proveedor = ? AND numero_factura = ? AND estado <> 'Anulada'
              LIMIT 1"
        );
        $st->execute([$proveedor, $numero]);

        if ($st->fetch()) {
            fallar('Ya existe una factura de este proveedor con ese número.', 409);
        }
    }

    /* Archivo adjunto (opcional) */

    $contenido = null;
    $nombreArchivo = null;
    $tipoArchivo = null;

    if (isset($_FILES['archivo']) && $_FILES['archivo']['error'] !== UPLOAD_ERR_NO_FILE) {
        $archivo = $_FILES['archivo'];

        if ($archivo['error'] !== UPLOAD_ERR_OK) {
            fallar(mensajeSubida((int) $archivo['error']));
        }

        if ($archivo['size'] > MAX_ARCHIVO_BYTES) {
            fallar('El archivo supera los 8 MB permitidos.');
        }

        $mime = detectarMime($archivo['tmp_name']);

        $permitidos = ['application/pdf', 'image/jpeg', 'image/png', 'image/webp'];

        if (!in_array($mime, $permitidos, true)) {
            fallar('Formato de archivo no permitido. Usá PDF, JPG, PNG o WEBP.');
        }

        $contenido = file_get_contents($archivo['tmp_name']);

        if ($contenido === false) {
            fallar('No se pudo leer el archivo subido.');
        }

        $nombreArchivo = texto(basename((string) $archivo['name']), 255);
        $tipoArchivo = $mime;
    }

    /* Inserción */

    $pdo->beginTransaction();

    try {
        $st = $pdo->prepare(
            'INSERT INTO facturas
                (numero_factura, proveedor, rut_proveedor, fecha_emision,
                 subtotal, iva, total, tipo_gasto, id_obra,
                 archivo, nombre_archivo, tipo_archivo, texto_ocr, estado, id_usuario)
             VALUES
                (:numero, :proveedor, :rut, :fecha,
                 :subtotal, :iva, :total, :tipo, :id_obra,
                 :archivo, :nombre_archivo, :tipo_archivo, :texto_ocr, :estado, :id_usuario)'
        );

        $st->bindValue(':numero', $numero !== '' ? $numero : null, $numero !== '' ? PDO::PARAM_STR : PDO::PARAM_NULL);
        $st->bindValue(':proveedor', $proveedor, PDO::PARAM_STR);
        $st->bindValue(':rut', $rut !== '' ? $rut : null, $rut !== '' ? PDO::PARAM_STR : PDO::PARAM_NULL);
        $st->bindValue(':fecha', $fecha, PDO::PARAM_STR);
        $st->bindValue(':subtotal', number_format($subtotal, 2, '.', ''), PDO::PARAM_STR);
        $st->bindValue(':iva', number_format($iva, 2, '.', ''), PDO::PARAM_STR);
        $st->bindValue(':total', number_format($total, 2, '.', ''), PDO::PARAM_STR);
        $st->bindValue(':tipo', $tipo, PDO::PARAM_STR);
        $st->bindValue(':id_obra', $idObra, $idObra !== null ? PDO::PARAM_INT : PDO::PARAM_NULL);
        $st->bindValue(':archivo', $contenido, $contenido !== null ? PDO::PARAM_LOB : PDO::PARAM_NULL);
        $st->bindValue(':nombre_archivo', $nombreArchivo, $nombreArchivo !== null ? PDO::PARAM_STR : PDO::PARAM_NULL);
        $st->bindValue(':tipo_archivo', $tipoArchivo, $tipoArchivo !== null ? PDO::PARAM_STR : PDO::PARAM_NULL);
        $st->bindValue(':texto_ocr', $textoOcr !== '' ? $textoOcr : null, $textoOcr !== '' ? PDO::PARAM_STR : PDO::PARAM_NULL);
        $st->bindValue(':estado', $estado, PDO::PARAM_STR);
        $st->bindValue(':id_usuario', $u['id'], PDO::PARAM_INT);
        $st->execute();

        $idFactura = (int) $pdo->lastInsertId();

        $stDetalle = $pdo->prepare(
            'INSERT INTO factura_detalle
                (id_factura, descripcion, cantidad, precio_unitario, subtotal, id_obra)
             VALUES (?, ?, ?, ?, ?, ?)'
        );

        foreach ($items as $item) {
            $stDetalle->execute([
                $idFactura,
                $item['descripcion'],
                number_format($item['cantidad'], 2, '.', ''),
                number_format($item['precio_unitario'], 2, '.', ''),
                number_format($item['subtotal'], 2, '.', ''),
                $idObra,
            ]);
        }

        $pdo->commit();
    } catch (Throwable $e) {
        if ($pdo->inTransaction()) {
            $pdo->rollBack();
        }

        throw $e;
    }

    registrarAuditoria($pdo, 'crear', 'facturas', $idFactura, [
        'proveedor' => $proveedor,
        'numero_factura' => $numero,
        'tipo_gasto' => $tipo,
        'id_obra' => $idObra,
        'total' => $total,
    ]);

    responder([
        'success' => true,
        'message' => 'Factura guardada correctamente.',
        'id_factura' => $idFactura,
    ], 201);
}

/* ------------------------------------------------------------------ */
/* ESTADO Y ANULACIÓN                                                  */
/* ------------------------------------------------------------------ */

function estadoActual(PDO $pdo, int $id): string
{
    $st = $pdo->prepare('SELECT estado FROM facturas WHERE id_factura = ?');
    $st->execute([$id]);

    $estado = $st->fetchColumn();

    if ($estado === false) {
        fallar('La factura no existe.', 404);
    }

    return (string) $estado;
}

function accionEstado(PDO $pdo): void
{
    exigirMetodo('POST');

    $entrada = leerJson();
    $id = (int) ($entrada['id_factura'] ?? 0);
    $nuevo = (string) ($entrada['estado'] ?? '');

    if ($id <= 0 || !in_array($nuevo, ['Pendiente', 'Verificada'], true)) {
        fallar('Datos inválidos para cambiar el estado.');
    }

    $actual = estadoActual($pdo, $id);

    if (!in_array($actual, ['Pendiente', 'Verificada'], true)) {
        fallar("No se puede cambiar el estado de una factura {$actual}.", 409);
    }

    $st = $pdo->prepare('UPDATE facturas SET estado = ? WHERE id_factura = ?');
    $st->execute([$nuevo, $id]);

    registrarAuditoria($pdo, 'estado', 'facturas', $id, ['de' => $actual, 'a' => $nuevo]);

    responder(['success' => true, 'message' => 'Estado actualizado.', 'estado' => $nuevo]);
}

function accionAnular(PDO $pdo): void
{
    exigirMetodo('POST');

    $entrada = leerJson();
    $id = (int) ($entrada['id_factura'] ?? 0);

    if ($id <= 0) {
        fallar('Datos inválidos para anular la factura.');
    }

    $actual = estadoActual($pdo, $id);

    if ($actual === 'Anulada') {
        fallar('La factura ya está anulada.', 409);
    }

    $st = $pdo->prepare("UPDATE facturas SET estado = 'Anulada' WHERE id_factura = ?");
    $st->execute([$id]);

    registrarAuditoria($pdo, 'anular', 'facturas', $id, ['estado_anterior' => $actual]);

    responder(['success' => true, 'message' => 'Factura anulada.', 'estado' => 'Anulada']);
}

/* ------------------------------------------------------------------ */
/* PORCENTAJE FIJO POR OBRA                                            */
/* ------------------------------------------------------------------ */

function accionPorcentajes(PDO $pdo): void
{
    exigirMetodo('GET');

    $obras = $pdo->query(
        'SELECT id_obra, nombre, porcentaje_gastos_generales AS porcentaje
           FROM obras
          WHERE activo = 1
          ORDER BY nombre'
    )->fetchAll();

    foreach ($obras as &$obra) {
        $obra['id_obra'] = (int) $obra['id_obra'];
        $obra['porcentaje'] = (float) $obra['porcentaje'];
    }
    unset($obra);

    responder(['success' => true, 'obras' => $obras]);
}

function accionGuardarPorcentajes(PDO $pdo): void
{
    exigirMetodo('POST');

    $entrada = leerJson();
    $lista = $entrada['porcentajes'] ?? null;

    if (!is_array($lista) || count($lista) === 0) {
        fallar('No se recibieron porcentajes.');
    }

    $activas = array_map(
        'intval',
        $pdo->query('SELECT id_obra FROM obras WHERE activo = 1')->fetchAll(PDO::FETCH_COLUMN)
    );

    $valores = [];
    $suma = 0.0;

    foreach ($lista as $fila) {
        if (!is_array($fila)) {
            fallar('Hay porcentajes u obras inválidos.');
        }

        $id = (int) ($fila['id_obra'] ?? 0);
        $pct = $fila['porcentaje'] ?? null;

        if (
            !in_array($id, $activas, true)
            || !numeroValido($pct)
            || (float) $pct < 0
            || (float) $pct > 100
        ) {
            fallar('Hay porcentajes u obras inválidos.');
        }

        $valores[$id] = round((float) $pct, 2);
    }

    if (count($valores) !== count($activas)) {
        fallar('Indicá el porcentaje de todas las obras activas.');
    }

    $suma = round(array_sum($valores), 2);

    if (abs($suma - 100) > 0.01) {
        fallar('Los porcentajes deben sumar 100 (ahora suman ' . $suma . ').');
    }

    $pdo->beginTransaction();

    try {
        $st = $pdo->prepare(
            'UPDATE obras SET porcentaje_gastos_generales = ? WHERE id_obra = ?'
        );

        foreach ($valores as $id => $pct) {
            $st->execute([number_format($pct, 2, '.', ''), $id]);
        }

        $pdo->commit();
    } catch (Throwable $e) {
        if ($pdo->inTransaction()) {
            $pdo->rollBack();
        }

        throw $e;
    }

    registrarAuditoria($pdo, 'porcentajes', 'obras', 0, $valores);

    responder(['success' => true, 'message' => 'Porcentajes guardados.']);
}

/* ------------------------------------------------------------------ */
/* COBERTURA DE GASTOS                                                 */
/* ------------------------------------------------------------------ */

/*
 * Cada obra debe cubrir:
 *   - sus gastos directos: facturas de tipo Obra asociadas a ella, y
 *   - su parte de los gastos generales del período (facturas generales +
 *     costos manuales), repartida según el criterio elegido.
 *
 * Se cuentan todas las facturas del período excepto las anuladas.
 */
function accionDistribuir(PDO $pdo): void
{
    exigirMetodo('POST');

    $entrada = leerJson();
    $periodo = (string) ($entrada['periodo'] ?? '');
    $criterio = (string) ($entrada['criterio'] ?? '');

    if (!preg_match('/^\d{4}-(0[1-9]|1[0-2])$/', $periodo)) {
        fallar('El período no es válido.');
    }

    if (!in_array($criterio, ['Por_Horas', 'Por_Obreros', 'Por_Porcentaje'], true)) {
        fallar('El criterio de distribución no es válido.');
    }

    $desde = $periodo . '-01';
    $hasta = date('Y-m-t', strtotime($desde));

    /* Gastos generales del período */

    $st = $pdo->prepare(
        "SELECT COALESCE(SUM(total), 0) FROM facturas
          WHERE tipo_gasto = 'General' AND estado <> 'Anulada'
            AND fecha_emision BETWEEN ? AND ?"
    );
    $st->execute([$desde, $hasta]);
    $totalFacturasGenerales = round((float) $st->fetchColumn(), 2);

    $st = $pdo->prepare(
        "SELECT COALESCE(SUM(monto), 0) FROM costos_generales
          WHERE origen = 'Manual' AND periodo BETWEEN ? AND ?"
    );
    $st->execute([$desde, $hasta]);
    $totalManuales = round((float) $st->fetchColumn(), 2);

    $totalGeneral = round($totalFacturasGenerales + $totalManuales, 2);

    /* Gastos directos por obra */

    $st = $pdo->prepare(
        "SELECT id_obra, COALESCE(SUM(total), 0) AS monto FROM facturas
          WHERE tipo_gasto = 'Obra' AND id_obra IS NOT NULL AND estado <> 'Anulada'
            AND fecha_emision BETWEEN ? AND ?
          GROUP BY id_obra"
    );
    $st->execute([$desde, $hasta]);

    $directos = [];

    foreach ($st->fetchAll() as $fila) {
        $directos[(int) $fila['id_obra']] = round((float) $fila['monto'], 2);
    }

    /* Base de reparto según el criterio */

    $bases = [];
    $avisoPorcentaje = '';

    if ($criterio === 'Por_Horas') {
        $st = $pdo->prepare(
            'SELECT id_obra,
                    SUM(COALESCE(horas_trabajadas,
                        TIME_TO_SEC(TIMEDIFF(hora_salida, hora_entrada)) / 3600)) AS base
               FROM registros
              WHERE fecha BETWEEN ? AND ?
              GROUP BY id_obra'
        );
        $st->execute([$desde, $hasta]);

        foreach ($st->fetchAll() as $fila) {
            $bases[(int) $fila['id_obra']] = round((float) $fila['base'], 2);
        }
    } elseif ($criterio === 'Por_Obreros') {
        $st = $pdo->prepare(
            'SELECT id_obra, COUNT(DISTINCT id_obrero) AS base
               FROM registros
              WHERE fecha BETWEEN ? AND ?
              GROUP BY id_obra'
        );
        $st->execute([$desde, $hasta]);

        foreach ($st->fetchAll() as $fila) {
            $bases[(int) $fila['id_obra']] = (float) $fila['base'];
        }
    } else {
        /* Porcentaje fijo: el porcentaje guardado en cada obra activa del período */
        $st = $pdo->prepare(
            'SELECT id_obra, porcentaje_gastos_generales AS porcentaje FROM obras
              WHERE activo = 1
                AND (fecha_inicio IS NULL OR fecha_inicio <= ?)
                AND (fecha_fin IS NULL OR fecha_fin >= ?)'
        );
        $st->execute([$hasta, $desde]);

        $activas = $st->fetchAll();

        foreach ($activas as $fila) {
            if ((float) $fila['porcentaje'] > 0) {
                $bases[(int) $fila['id_obra']] = (float) $fila['porcentaje'];
            }
        }

        /* Sin porcentajes definidos: partes iguales entre las obras activas */
        if (count($bases) === 0 && count($activas) > 0) {
            $parte = 100 / count($activas);

            foreach ($activas as $fila) {
                $bases[(int) $fila['id_obra']] = $parte;
            }

            $avisoPorcentaje = 'No hay porcentajes definidos: se repartió en partes iguales '
                . 'entre las obras activas. Cargalos en el panel de porcentajes.';
        }
    }

    $baseTotal = array_sum($bases);

    /* Obras involucradas: las que tienen base o gasto directo */

    $ids = array_values(array_unique(array_merge(array_keys($bases), array_keys($directos))));

    $nombres = [];

    if (count($ids) > 0) {
        $marcadores = implode(',', array_fill(0, count($ids), '?'));
        $st = $pdo->prepare("SELECT id_obra, nombre FROM obras WHERE id_obra IN ($marcadores)");
        $st->execute($ids);

        foreach ($st->fetchAll() as $fila) {
            $nombres[(int) $fila['id_obra']] = (string) $fila['nombre'];
        }
    }

    $tasa = $baseTotal > 0 ? $totalGeneral / $baseTotal : 0.0;

    $filas = [];

    foreach ($ids as $id) {
        $base = $bases[$id] ?? 0.0;

        $filas[] = [
            'id_obra' => $id,
            'obra' => $nombres[$id] ?? ('Obra ' . $id),
            'base' => $base,
            'porcentaje' => $baseTotal > 0 ? ($base / $baseTotal) * 100 : 0.0,
            'tasa' => round($tasa, 4),
            'gasto_directo' => $directos[$id] ?? 0.0,
            'monto_asignado' => $baseTotal > 0 ? round($base * $tasa, 2) : 0.0,
        ];
    }

    /* Ajuste de centavos para que lo asignado sume exactamente el total general */

    if ($baseTotal > 0 && count($filas) > 0) {
        $asignado = 0.0;
        $indiceMayor = 0;

        foreach ($filas as $i => $fila) {
            $asignado += $fila['monto_asignado'];

            if ($fila['base'] > $filas[$indiceMayor]['base']) {
                $indiceMayor = $i;
            }
        }

        $filas[$indiceMayor]['monto_asignado'] = round(
            $filas[$indiceMayor]['monto_asignado'] + ($totalGeneral - $asignado),
            2
        );
    }

    $totalDirecto = 0.0;

    foreach ($filas as $i => $fila) {
        $filas[$i]['total_cubrir'] = round($fila['gasto_directo'] + $fila['monto_asignado'], 2);
        $totalDirecto += $fila['gasto_directo'];
    }

    usort($filas, function (array $a, array $b) {
        return strcmp($a['obra'], $b['obra']);
    });

    $totalDirecto = round($totalDirecto, 2);

    $advertencia = '';

    if ($baseTotal <= 0 && $totalGeneral > 0) {
        $advertencia = 'No hay datos para repartir los gastos generales con este criterio '
            . 'en el período (sin horas, obreros u obras activas). '
            . 'Solo se muestran los gastos directos de cada obra.';
    } elseif ($avisoPorcentaje !== '') {
        $advertencia = $avisoPorcentaje;
    }

    responder([
        'success' => true,
        'periodo' => $periodo,
        'criterio' => $criterio,
        'total_facturas_generales' => $totalFacturasGenerales,
        'total_costos_manuales' => $totalManuales,
        'total_general' => $totalGeneral,
        'total_directo' => $totalDirecto,
        'total_operacion' => round($totalGeneral + $totalDirecto, 2),
        'base_total' => round((float) $baseTotal, 2),
        'tasa' => round($tasa, 4),
        'advertencia' => $advertencia,
        'distribucion' => $filas,
    ]);
}

/* ------------------------------------------------------------------ */
/* ENRUTADOR                                                           */
/* ------------------------------------------------------------------ */

try {
    $pdo = conectar();

    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        validarCsrf();

        if (function_exists('verificarLimitePost')) {
            verificarLimitePost();
        }
    }

    $accion = (string) ($_GET['accion'] ?? '');

    switch ($accion) {
        case 'listar':
            accionListar($pdo);
            break;

        case 'obras':
            accionObras($pdo);
            break;

        case 'archivo':
            accionArchivo($pdo);
            break;

        case 'guardar':
            accionGuardar($pdo, $usuario);
            break;

        case 'estado':
            accionEstado($pdo);
            break;

        case 'anular':
            accionAnular($pdo);
            break;

        case 'porcentajes':
            accionPorcentajes($pdo);
            break;

        case 'guardar_porcentajes':
            accionGuardarPorcentajes($pdo);
            break;

        case 'distribuir':
            accionDistribuir($pdo);
            break;

        default:
            fallar('Acción no válida.', 404);
    }
} catch (Throwable $e) {
    error_log('facturas.php error: ' . $e->getMessage() . ' en ' . $e->getFile() . ':' . $e->getLine());
    fallar(DEBUG ? $e->getMessage() . ' (' . basename($e->getFile()) . ':' . $e->getLine() . ')' : 'Error interno del servidor.', 500);
}