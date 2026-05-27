<?php
require_once __DIR__ . '/config/db.php';
require_once __DIR__ . '/config/session.php';

$origin = (isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off' ? 'https' : 'http')
    . '://' . ($_SERVER['HTTP_HOST'] ?? 'localhost');

header("Access-Control-Allow-Origin: {$origin}");
header('Access-Control-Allow-Credentials: true');
header('Access-Control-Allow-Headers: Content-Type, X-CSRF-Token');
header('Access-Control-Allow-Methods: GET, POST, DELETE, OPTIONS');
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
                echo json_encode(['error' => 'No tenés permisos para gestionar certificados.']);
                exit;
            }
            validarCsrf();

            // Multipart: archivo real desde el frontend web
            if (!empty($_FILES['certificado']) && $_FILES['certificado']['error'] === UPLOAD_ERR_OK) {
                responderSubirMultipart($pdo);
                break;
            }

            // JSON: eliminar o subir con base64 (desktop)
            $body = leerJson();
            if (($body['accion'] ?? '') === 'eliminar') {
                responderEliminacion($pdo, $body);
                break;
            }
            responderSubirBase64($pdo, $body);
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
    echo json_encode(['error' => 'Error interno del servidor.']);
}

function responderListado(PDO $pdo): void
{
    $idMaquinaria = isset($_GET['id_maquinaria']) ? (int) $_GET['id_maquinaria'] : 0;
    if ($idMaquinaria <= 0) {
        throw new InvalidArgumentException('Debés indicar una maquinaria válida.');
    }

    $stmt = $pdo->prepare(
        'SELECT id_certificado, nombre_archivo, fecha_vencimiento FROM certificado WHERE id_maquinaria = ? ORDER BY fecha_vencimiento ASC'
    );
    $stmt->execute([$idMaquinaria]);
    $certificados = $stmt->fetchAll();

    echo json_encode([
        'success' => true,
        'certificados' => $certificados,
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
        'tipo_contenido' => GuessMimeType($nombreArchivo),
        'contenido_base64' => base64_encode($archivo),
    ]);
}

function responderSubirMultipart(PDO $pdo): void
{
    $idMaquinaria = isset($_POST['id_maquinaria']) ? (int) $_POST['id_maquinaria'] : 0;
    $fechaVencimiento = normalizarFecha($_POST['fecha_vencimiento'] ?? null);

    if ($idMaquinaria <= 0) {
        throw new InvalidArgumentException('Debés indicar una maquinaria válida.');
    }

    $archivoContenido = file_get_contents($_FILES['certificado']['tmp_name']);
    $nombreOriginal = $_FILES['certificado']['name'];

    if (strlen($archivoContenido) > 10 * 1024 * 1024) {
        throw new InvalidArgumentException('El certificado no puede superar los 10 MB.');
    }

    $stmt = $pdo->prepare('INSERT INTO certificado (archivo, nombre_archivo, id_maquinaria, fecha_vencimiento) VALUES (?, ?, ?, ?)');
    $stmt->bindValue(1, $archivoContenido, PDO::PARAM_LOB);
    $stmt->bindValue(2, $nombreOriginal);
    $stmt->bindValue(3, $idMaquinaria, PDO::PARAM_INT);
    $stmt->bindValue(4, $fechaVencimiento);
    $stmt->execute();

    echo json_encode([
        'success' => true,
        'message' => 'Certificado subido correctamente.',
    ]);
}

function responderSubirBase64(PDO $pdo, array $body): void
{
    $idMaquinaria = isset($body['id_maquinaria']) ? (int) $body['id_maquinaria'] : 0;
    $fechaVencimiento = normalizarFecha($body['fecha_vencimiento'] ?? null);
    $nombreArchivo = limpiarTexto($body['nombre_archivo'] ?? '', 255, true);
    $contenidoBase64 = $body['contenido_base64'] ?? '';

    if ($idMaquinaria <= 0) {
        throw new InvalidArgumentException('Debés indicar una maquinaria válida.');
    }
    if ($contenidoBase64 === '') {
        throw new InvalidArgumentException('El archivo seleccionado es inválido.');
    }

    $archivo = base64_decode($contenidoBase64, true);
    if ($archivo === false) {
        throw new InvalidArgumentException('El archivo seleccionado es inválido.');
    }

    if (strlen($archivo) > 10 * 1024 * 1024) {
        throw new InvalidArgumentException('El certificado no puede superar los 10 MB.');
    }

    $stmt = $pdo->prepare('INSERT INTO certificado (archivo, nombre_archivo, id_maquinaria, fecha_vencimiento) VALUES (?, ?, ?, ?)');
    $stmt->bindValue(1, $archivo, PDO::PARAM_LOB);
    $stmt->bindValue(2, $nombreArchivo);
    $stmt->bindValue(3, $idMaquinaria, PDO::PARAM_INT);
    $stmt->bindValue(4, $fechaVencimiento);
    $stmt->execute();

    echo json_encode([
        'success' => true,
        'message' => 'Certificado subido correctamente.',
    ]);
}

function responderEliminacion(PDO $pdo, array $body): void
{
    $idCertificado = isset($body['id_certificado']) ? (int) $body['id_certificado'] : 0;
    if ($idCertificado <= 0) {
        throw new InvalidArgumentException('Debés indicar un certificado válido.');
    }

    $stmt = $pdo->prepare('DELETE FROM certificado WHERE id_certificado = ?');
    $stmt->execute([$idCertificado]);

    if ($stmt->rowCount() === 0) {
        throw new RuntimeException('El certificado indicado no existe.');
    }

    echo json_encode([
        'success' => true,
        'message' => 'Certificado eliminado correctamente.',
    ]);
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

function leerJson(): array
{
    $body = json_decode(file_get_contents('php://input'), true);
    if (!is_array($body)) {
        throw new InvalidArgumentException('Cuerpo de solicitud inválido.');
    }
    return $body;
}

function normalizarFecha(mixed $value): ?string
{
    $text = trim((string) ($value ?? ''));
    if ($text === '') {
        return null;
    }

    $date = DateTime::createFromFormat('Y-m-d', $text);
    $errors = DateTime::getLastErrors();

    if (!$date || ($errors['warning_count'] ?? 0) > 0 || ($errors['error_count'] ?? 0) > 0) {
        throw new InvalidArgumentException('Formato de fecha inválido.');
    }

    return $date->format('Y-m-d');
}

function limpiarTexto(mixed $value, int $maxLength, bool $required = true): string
{
    $text = trim((string) $value);
    if ($text === '') {
        if ($required) {
            throw new InvalidArgumentException('Uno de los campos obligatorios está vacío.');
        }
        return '';
    }

    $length = function_exists('mb_strlen') ? mb_strlen($text) : strlen($text);
    if ($length > $maxLength) {
        throw new InvalidArgumentException('Uno de los campos supera la longitud permitida.');
    }

    return $text;
}

function GuessMimeType(string $nombreArchivo): string
{
    $extension = pathinfo($nombreArchivo, PATHINFO_EXTENSION);
    $extension = strtolower($extension);

    return match ($extension) {
        'pdf' => 'application/pdf',
        'doc' => 'application/msword',
        'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'jpg', 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        default => 'application/octet-stream',
    };
}
