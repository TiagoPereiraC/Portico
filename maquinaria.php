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
            if (isset($_GET['id'])) {
                responderObtener($pdo);
                break;
            }
            responderListado($pdo);
            break;

        case 'POST':
            if (!$esAdmin) {
                http_response_code(403);
                echo json_encode(['error' => 'No tenés permisos para gestionar maquinaria.']);
                exit;
            }
            validarCsrf();
            $body = leerJson();
            responderGuardado($pdo, $body);
            break;

        case 'DELETE':
            if (!$esAdmin) {
                http_response_code(403);
                echo json_encode(['error' => 'No tenés permisos para gestionar maquinaria.']);
                exit;
            }
            validarCsrf();
            $body = leerJson();
            responderEliminacion($pdo, $body);
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
    if ((int) $e->getCode() === 23000) {
        http_response_code(409);
        echo json_encode(['error' => 'No se puede eliminar porque está asignada a una obra.']);
        exit;
    }

    error_log('maquinaria.php PDO error: ' . $e->getMessage());
    http_response_code(500);
    echo json_encode(['error' => 'Error interno del servidor.']);
} catch (Throwable $e) {
    error_log('maquinaria.php error: ' . $e->getMessage());
    http_response_code(500);
    echo json_encode(['error' => 'Error interno del servidor.']);
}

function responderListado(PDO $pdo): void
{
    $page = max(1, (int) ($_GET['page'] ?? 1));
    $limit = (int) ($_GET['limit'] ?? 10);
    $limit = max(1, min($limit, 100));

    $search = trim((string) ($_GET['search'] ?? ''));
    $estadoCert = trim((string) ($_GET['estado_cert'] ?? ''));

    $where = [];
    $params = [];

    if ($search !== '') {
        $where[] = '(
            m.nombre LIKE ?
            OR m.marca LIKE ?
            OR CONCAT(m.nombre, " ", COALESCE(m.marca, "")) LIKE ?
        )';

        $searchLike = '%' . $search . '%';

        $params[] = $searchLike;
        $params[] = $searchLike;
        $params[] = $searchLike;
    }

    if ($estadoCert === 'criticos') {
        $where[] = '(
            EXISTS (
                SELECT 1
                FROM certificado c
                WHERE c.id_maquinaria = m.id_maquinaria
                AND c.fecha_vencimiento IS NOT NULL
                AND c.fecha_vencimiento <= DATE_ADD(CURDATE(), INTERVAL 30 DAY)
            )
        )';
    }

    $whereSql = $where ? ' WHERE ' . implode(' AND ', $where) : '';

    $countStmt = $pdo->prepare(
        'SELECT COUNT(*) 
         FROM maquinaria m' . $whereSql
    );

    foreach ($params as $index => $value) {
        $countStmt->bindValue($index + 1, $value, PDO::PARAM_STR);
    }

    $countStmt->execute();
    $total = (int) $countStmt->fetchColumn();

    $totalPages = max(1, (int) ceil($total / $limit));
    $page = min($page, $totalPages);
    $offset = ($page - 1) * $limit;

    $stmt = $pdo->prepare(
        'SELECT
            m.id_maquinaria,
            m.nombre,
            m.marca,
            (
                SELECT MIN(c.fecha_vencimiento)
                FROM certificado c
                WHERE c.id_maquinaria = m.id_maquinaria
            ) AS vencimiento
        FROM maquinaria m'
        . $whereSql .
        ' ORDER BY m.nombre ASC
          LIMIT ? OFFSET ?'
    );

    $bindIndex = 1;

    foreach ($params as $value) {
        $stmt->bindValue($bindIndex++, $value, PDO::PARAM_STR);
    }

    $stmt->bindValue($bindIndex++, $limit, PDO::PARAM_INT);
    $stmt->bindValue($bindIndex, $offset, PDO::PARAM_INT);

    $stmt->execute();

    echo json_encode([
        'success' => true,
        'maquinaria' => $stmt->fetchAll(),
        'total' => $total,
        'page' => $page,
        'per_page' => $limit,
        'total_pages' => $totalPages,
    ]);
}

function responderObtener(PDO $pdo): void
{
    $id = isset($_GET['id']) ? (int) $_GET['id'] : 0;
    if ($id <= 0) {
        throw new InvalidArgumentException('ID inválido.');
    }

    $stmt = $pdo->prepare('SELECT id_maquinaria, nombre, marca FROM maquinaria WHERE id_maquinaria = ? LIMIT 1');
    $stmt->execute([$id]);
    $item = $stmt->fetch();

    if (!$item) {
        throw new RuntimeException('Maquinaria no encontrada.');
    }

    echo json_encode([
        'success' => true,
        'maquinaria' => $item,
    ]);
}

function responderGuardado(PDO $pdo, array $body): void
{
    $nombre = limpiarTexto($body['nombre'] ?? '', 150, true);
    $marca = limpiarTexto($body['marca'] ?? '', 100, false);
    $idMaquinaria = isset($body['id_maquinaria']) && $body['id_maquinaria'] !== '' ? (int) $body['id_maquinaria'] : null;

    if ($nombre === '') {
        throw new InvalidArgumentException('El nombre es obligatorio.');
    }

    if ($idMaquinaria !== null) {
        $stmt = $pdo->prepare('SELECT id_maquinaria FROM maquinaria WHERE id_maquinaria = ? LIMIT 1');
        $stmt->execute([$idMaquinaria]);

        if (!$stmt->fetchColumn()) {
            throw new RuntimeException('La maquinaria indicada no existe.');
        }

        $stmt = $pdo->prepare('UPDATE maquinaria SET nombre = ?, marca = ? WHERE id_maquinaria = ?');
        $stmt->execute([$nombre, $marca, $idMaquinaria]);

        http_response_code(200);
        echo json_encode([
            'success' => true,
            'message' => 'Maquinaria actualizada correctamente.',
            'maquinaria' => obtenerMaquinaria($pdo, $idMaquinaria),
        ]);
        return;
    }

    $stmt = $pdo->prepare('INSERT INTO maquinaria (nombre, marca) VALUES (?, ?)');
    $stmt->execute([$nombre, $marca]);

    $idMaquinaria = (int) $pdo->lastInsertId();

    http_response_code(201);
    echo json_encode([
        'success' => true,
        'message' => 'Maquinaria registrada correctamente.',
        'maquinaria' => obtenerMaquinaria($pdo, $idMaquinaria),
    ]);
}

function responderEliminacion(PDO $pdo, array $body): void
{
    $idMaquinaria = isset($body['id_maquinaria']) ? (int) $body['id_maquinaria'] : 0;
    if ($idMaquinaria <= 0) {
        throw new InvalidArgumentException('Debés indicar una maquinaria válida.');
    }

    $stmt = $pdo->prepare('DELETE FROM maquinaria WHERE id_maquinaria = ?');
    $stmt->execute([$idMaquinaria]);

    if ($stmt->rowCount() === 0) {
        throw new RuntimeException('La maquinaria indicada no existe.');
    }

    echo json_encode([
        'success' => true,
        'message' => 'Maquinaria eliminada correctamente.',
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

function limpiarTexto(mixed $value, int $maxLength, bool $required = true): ?string
{
    $text = trim((string) $value);
    if ($text === '') {
        return $required ? '' : null;
    }

    $length = function_exists('mb_strlen') ? mb_strlen($text) : strlen($text);
    if ($length > $maxLength) {
        throw new InvalidArgumentException('Uno de los campos supera la longitud permitida.');
    }

    return $text;
}

function obtenerMaquinaria(PDO $pdo, int $id): array
{
    $stmt = $pdo->prepare('SELECT id_maquinaria, nombre, marca FROM maquinaria WHERE id_maquinaria = ? LIMIT 1');
    $stmt->execute([$id]);
    $item = $stmt->fetch();
    if (!$item) {
        throw new RuntimeException('La maquinaria indicada no existe.');
    }
    return $item;
}