<?php
require_once __DIR__ . '/config/db.php';
require_once __DIR__ . '/config/session.php';
require_once __DIR__ . '/config/auditoria.php';

$origin = (isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off' ? 'https' : 'http')
    . '://' . ($_SERVER['HTTP_HOST'] ?? 'localhost');

header("Access-Control-Allow-Origin: {$origin}");
header('Access-Control-Allow-Credentials: true');
header('Access-Control-Allow-Headers: Content-Type, X-CSRF-Token');
header('Access-Control-Allow-Methods: GET, POST, DELETE, OPTIONS');
header('Cache-Control: no-store, no-cache, must-revalidate');
header('Content-Type: application/json');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

iniciarSesion();

if (empty($_SESSION['user_id'])) {
    http_response_code(401);
    echo json_encode(['error' => 'Sesión no válida.']);
    exit;
}

$esAdmin = ($_SESSION['rol'] ?? '') === 'Administrador';

try {
    $pdo = conectar();

    switch ($_SERVER['REQUEST_METHOD']) {

        case 'GET':
            if (isset($_GET['descargar'])) {
                responderDescarga($pdo);
                break;
            }
            responderListado($pdo);
            break;

        case 'POST':
            if (!$esAdmin) {
                http_response_code(403);
                echo json_encode(['error' => 'Sin permisos.']);
                exit;
            }

            validarCsrf();

            verificarLimitePost();

            if (!empty($_FILES['certificado'])) {
                responderSubirMultipart($pdo);
                break;
            }

            $body = leerJson();

            switch ($body['accion'] ?? '') {

                case 'eliminar':
                    responderEliminacion($pdo, $body);
                    break;

                case 'editar_fecha':
                    responderEditarFecha($pdo, $body);
                    break;

                default:
                    responderSubirBase64($pdo, $body);
                    break;
            }
            break;

        default:
            http_response_code(405);
            echo json_encode(['error' => 'Método no permitido']);
    }

} catch (InvalidArgumentException $e) {
    http_response_code(400);
    echo json_encode(['error' => $e->getMessage()]);
} catch (RuntimeException $e) {
    http_response_code(404);
    echo json_encode(['error' => $e->getMessage()]);
} catch (PDOException $e) {
    error_log('cert_maq.php PDO error: ' . $e->getMessage());
    http_response_code(500);
    echo json_encode(['error' => 'Error interno del servidor.']);
} catch (Throwable $e) {
    error_log('cert_maq.php error: ' . $e->getMessage());
    http_response_code(500);
    echo json_encode(['error' => 'Error interno del servidor']);
}

function responderListado(PDO $pdo): void
{
    $id = (int) ($_GET['id_maquinaria'] ?? 0);
    if ($id <= 0) {
        throw new InvalidArgumentException('Maquinaria inválida');
    }

    $stmt = $pdo->prepare('SELECT id_certificado, nombre_archivo, fecha_vencimiento FROM certificado WHERE id_maquinaria = ? ORDER BY fecha_vencimiento ASC');
    $stmt->execute([$id]);

    echo json_encode([
        'success' => true,
        'certificados' => $stmt->fetchAll()
    ]);
}

function responderDescarga(PDO $pdo): void
{
    $idCertificado = isset($_GET['descargar']) ? (int) $_GET['descargar'] : 0;
    if ($idCertificado <= 0) {
        throw new InvalidArgumentException('Debés indicar un certificado válido.');
    }

    $stmt = $pdo->prepare('SELECT archivo, nombre_archivo FROM certificado WHERE id_certificado = ? LIMIT 1');
    $stmt->execute([$idCertificado]);
    $certificado = $stmt->fetch();

    if (!$certificado) {
        throw new RuntimeException('El certificado indicado no existe.');
    }

    $nombreArchivo = $certificado['nombre_archivo'] ?? "certificado-{$idCertificado}";
    $archivo = $certificado['archivo'];

    echo json_encode([
        'success' => true,
        'nombre_archivo' => $nombreArchivo,
        'tipo_contenido' => guessMimeType($nombreArchivo),
        'contenido_base64' => base64_encode($archivo),
    ]);
}

function responderSubirBase64(PDO $pdo, array $body): void
{
    $id = (int) ($body['id_maquinaria'] ?? 0);
    $nombre = trim($body['nombre_archivo'] ?? '');
    $fecha = normalizarFecha($body['fecha_vencimiento'] ?? null);
    $archivo = base64_decode($body['contenido_base64'] ?? '', true);

    if ($id <= 0 || !$archivo) {
        throw new InvalidArgumentException('Datos inválidos');
    }

    if (strlen($archivo) > 10 * 1024 * 1024) {
        throw new InvalidArgumentException('El certificado no puede superar los 10 MB.');
    }

    validarExtensionArchivo($nombre);

    insertarCertificado($pdo, $archivo, $nombre, $id, $fecha);

    registrarAuditoria($pdo, 'subir_certificado', 'certificados_maquinaria', $id, [
        'nombre_archivo' => $nombre,
        'id_maquinaria' => $id,
    ]);

    echo json_encode(['success' => true]);
}

function responderSubirMultipart(PDO $pdo): void
{
    $id = (int) ($_POST['id_maquinaria'] ?? 0);
    $fecha = normalizarFecha($_POST['fecha_vencimiento'] ?? null);

    if ($id <= 0) {
        throw new InvalidArgumentException('Maquinaria inválida.');
    }

    if (!isset($_FILES['certificado'])) {
        throw new InvalidArgumentException('No se seleccionó ningún archivo de certificado.');
    }

    $fileError = $_FILES['certificado']['error'];
    if ($fileError !== UPLOAD_ERR_OK) {
        if ($fileError === UPLOAD_ERR_INI_SIZE || $fileError === UPLOAD_ERR_FORM_SIZE) {
            throw new InvalidArgumentException('El archivo subido supera el tamaño máximo permitido por el servidor.');
        }
        if ($fileError === UPLOAD_ERR_NO_FILE) {
            throw new InvalidArgumentException('No se seleccionó ningún archivo de certificado.');
        }
        throw new InvalidArgumentException('Error al subir el archivo (código ' . $fileError . ').');
    }

    if (($_FILES['certificado']['size'] ?? 0) > 10 * 1024 * 1024) {
        throw new InvalidArgumentException('El certificado no puede superar los 10 MB.');
    }

    $nombre = $_FILES['certificado']['name'];
    validarExtensionArchivo($nombre);

    $archivo = file_get_contents($_FILES['certificado']['tmp_name']);
    if ($archivo === false || strlen($archivo) === 0) {
        throw new InvalidArgumentException('No se pudo leer el archivo del certificado.');
    }

    if (strlen($archivo) > 10 * 1024 * 1024) {
        throw new InvalidArgumentException('El certificado no puede superar los 10 MB.');
    }

    insertarCertificado($pdo, $archivo, $nombre, $id, $fecha);

    registrarAuditoria($pdo, 'subir_certificado', 'certificados_maquinaria', $id, [
        'nombre_archivo' => $nombre,
        'id_maquinaria' => $id,
    ]);

    echo json_encode(['success' => true]);
}

function insertarCertificado(PDO $pdo, string $archivo, string $nombre, int $id, ?string $fecha): void
{
    $stmt = $pdo->prepare('INSERT INTO certificado (archivo, nombre_archivo, id_maquinaria, fecha_vencimiento) VALUES (?, ?, ?, ?)');
    $stmt->bindValue(1, $archivo, PDO::PARAM_LOB);
    $stmt->bindValue(2, $nombre);
    $stmt->bindValue(3, $id, PDO::PARAM_INT);
    $stmt->bindValue(4, $fecha);
    $stmt->execute();
}

function responderEliminacion(PDO $pdo, array $body): void
{
    $id = (int) ($body['id_certificado'] ?? 0);

    $stmt = $pdo->prepare('SELECT id_certificado, id_maquinaria, nombre_archivo FROM certificado WHERE id_certificado = ? LIMIT 1');
    $stmt->execute([$id]);
    $cert = $stmt->fetch();
    if (!$cert) {
        throw new RuntimeException('El certificado indicado no existe.');
    }

    $pdo->prepare('DELETE FROM certificado WHERE id_certificado = ?')->execute([$id]);

    registrarAuditoria($pdo, 'eliminar_certificado', 'certificados_maquinaria', $cert['id_maquinaria'], [
        'nombre_archivo' => $cert['nombre_archivo'],
        'id_certificado' => $id,
    ]);

    echo json_encode(['success' => true]);
}

function responderEditarFecha(PDO $pdo, array $body): void
{
    $id = (int) ($body['id_certificado'] ?? 0);
    $fecha = normalizarFecha($body['fecha_vencimiento'] ?? null);

    if ($id <= 0) {
        throw new InvalidArgumentException('Debés indicar un certificado válido.');
    }

    $stmt = $pdo->prepare('SELECT id_certificado FROM certificado WHERE id_certificado = ? LIMIT 1');
    $stmt->execute([$id]);
    if (!$stmt->fetchColumn()) {
        throw new RuntimeException('El certificado indicado no existe.');
    }

    $stmt = $pdo->prepare('UPDATE certificado SET fecha_vencimiento = ? WHERE id_certificado = ?');
    $stmt->execute([$fecha, $id]);

    registrarAuditoria($pdo, 'editar_certificado', 'certificados_maquinaria', $id, [
        'fecha_vencimiento' => $fecha,
    ]);

    echo json_encode(['success' => true]);
}

function validarCsrf(): void
{
    $csrfRecibido = $_SERVER['HTTP_X_CSRF_TOKEN'] ?? '';
    $csrfGuardado = $_SESSION['csrf_token'] ?? '';

    if ($csrfGuardado === '' || !hash_equals($csrfGuardado, $csrfRecibido)) {
        http_response_code(403);
        echo json_encode(['error' => 'Token de seguridad inválido.']);
        exit;
    }
}

function leerJson(): array
{
    $body = json_decode(file_get_contents('php://input'), true);
    if (!is_array($body)) {
        throw new InvalidArgumentException('Cuerpo de solicitud inválido.');
    }
    return $body;
}

function normalizarFecha($v): ?string
{
    $v = trim((string) $v);
    return $v === '' ? null : substr($v, 0, 10);
}

function guessMimeType(string $nombreArchivo): string
{
    $extension = strtolower(pathinfo($nombreArchivo, PATHINFO_EXTENSION));
    return match ($extension) {
        'pdf' => 'application/pdf',
        'doc' => 'application/msword',
        'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'jpg', 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        default => 'application/octet-stream',
    };
}

function validarExtensionArchivo(string $nombreArchivo): void
{
    $extension = strtolower(pathinfo($nombreArchivo, PATHINFO_EXTENSION));
    $permitidas = ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'];
    if (!in_array($extension, $permitidas, true)) {
        throw new InvalidArgumentException('Formato de archivo no permitido. Solo se aceptan PDF, DOC, DOCX, JPG o PNG.');
    }
}

function verificarLimitePost(): void
{
    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        $contentLength = (int) ($_SERVER['CONTENT_LENGTH'] ?? 0);
        if ($contentLength > 0 && empty($_POST) && empty($_FILES)) {
            $rawInput = file_get_contents('php://input');
            if ($rawInput === false || strlen($rawInput) === 0) {
                $postMax = ini_get('post_max_size') ?: '8M';
                throw new InvalidArgumentException("El archivo o solicitud enviada supera el tamaño máximo permitido por el servidor (límite post_max_size: {$postMax}).");
            }
        }
    }
}