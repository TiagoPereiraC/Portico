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
    $archivo = file_get_contents($_FILES['certificado']['tmp_name']);
    $nombre = $_FILES['certificado']['name'];

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