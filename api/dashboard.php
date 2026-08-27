<?php

require_once __DIR__ . '/config/db.php';
require_once __DIR__ . '/config/session.php';

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

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405);
    echo json_encode(['success' => false, 'error' => 'Método no permitido.']);
    exit;
}

iniciarSesion();

if (empty($_SESSION['user_id'])) {
    http_response_code(401);
    echo json_encode(['success' => false, 'error' => 'Sesión no válida. Iniciá sesión nuevamente.']);
    exit;
}

try {
    $pdo = conectar();
    $pdo->setAttribute(PDO::ATTR_DEFAULT_FETCH_MODE, PDO::FETCH_ASSOC);

    // 1. KPIs principales
    // Obras
    $stmtObras = $pdo->query('
        SELECT 
            COUNT(*) AS total_obras,
            SUM(CASE WHEN activo = 1 THEN 1 ELSE 0 END) AS obras_activas
        FROM obras
    ');
    $resObras = $stmtObras->fetch() ?: ['total_obras' => 0, 'obras_activas' => 0];

    // Obreros
    $stmtObreros = $pdo->query('
        SELECT 
            COUNT(*) AS total_obreros,
            SUM(CASE WHEN activo = 1 THEN 1 ELSE 0 END) AS obreros_activos
        FROM obreros
    ');
    $resObreros = $stmtObreros->fetch() ?: ['total_obreros' => 0, 'obreros_activos' => 0];

    // Maquinaria
    $stmtMaq = $pdo->query('
        SELECT 
            COUNT(*) AS total_maquinaria,
            (SELECT COUNT(DISTINCT id_maquinaria) FROM obra_maquinaria WHERE fecha_retiro IS NULL) AS maquinaria_asignada
        FROM maquinaria
    ');
    $resMaq = $stmtMaq->fetch() ?: ['total_maquinaria' => 0, 'maquinaria_asignada' => 0];

    // Horas y Asistencias
    $stmtHoras = $pdo->query('
        SELECT 
            COUNT(*) AS total_registros,
            COALESCE(SUM(horas_trabajadas), 0) AS total_horas
        FROM registros
    ');
    $resHoras = $stmtHoras->fetch() ?: ['total_registros' => 0, 'total_horas' => 0];

    // Alertas de certificados (vencidos o por vencer en 30 días)
    $stmtAlertasCert = $pdo->query('
        SELECT 
            COUNT(*) AS total_alertas_cert,
            SUM(CASE WHEN fecha_vencimiento < CURDATE() THEN 1 ELSE 0 END) AS cert_vencidos,
            SUM(CASE WHEN fecha_vencimiento >= CURDATE() AND fecha_vencimiento <= DATE_ADD(CURDATE(), INTERVAL 30 DAY) THEN 1 ELSE 0 END) AS cert_por_vencer
        FROM certificado
        WHERE fecha_vencimiento IS NOT NULL AND fecha_vencimiento <= DATE_ADD(CURDATE(), INTERVAL 30 DAY)
    ');
    $resAlertasCert = $stmtAlertasCert->fetch() ?: ['total_alertas_cert' => 0, 'cert_vencidos' => 0, 'cert_por_vencer' => 0];

    // Alertas de contratos de obreros
    $stmtAlertasContratos = $pdo->query('
        SELECT 
            COUNT(*) AS total_alertas_contratos,
            SUM(CASE WHEN fecha_vencimiento < CURDATE() THEN 1 ELSE 0 END) AS contratos_vencidos,
            SUM(CASE WHEN fecha_vencimiento >= CURDATE() AND fecha_vencimiento <= DATE_ADD(CURDATE(), INTERVAL 30 DAY) THEN 1 ELSE 0 END) AS contratos_por_vencer
        FROM contrato_obrero
        WHERE fecha_vencimiento IS NOT NULL AND fecha_vencimiento <= DATE_ADD(CURDATE(), INTERVAL 30 DAY)
    ');
    $resAlertasContratos = $stmtAlertasContratos->fetch() ?: ['total_alertas_contratos' => 0, 'contratos_vencidos' => 0, 'contratos_por_vencer' => 0];

    // 2. Gráfico: Distribución de obreros por cargo
    $stmtCargos = $pdo->query('
        SELECT cargo, COUNT(*) AS cantidad
        FROM obreros
        WHERE activo = 1
        GROUP BY cargo
        ORDER BY cantidad DESC
    ');
    $distribucionCargos = $stmtCargos->fetchAll();

    // 3. Gráfico: Top 5 Obras con más horas trabajadas
    $stmtHorasObras = $pdo->query('
        SELECT o.nombre, COALESCE(SUM(r.horas_trabajadas), 0) AS total_horas
        FROM obras o
        LEFT JOIN registros r ON o.id_obra = r.id_obra
        WHERE o.activo = 1
        GROUP BY o.id_obra, o.nombre
        ORDER BY total_horas DESC
        LIMIT 5
    ');
    $horasPorObra = $stmtHorasObras->fetchAll();

    // 4. Próximos vencimientos de certificados de maquinaria (Top 5)
    $stmtVencimientos = $pdo->query('
        SELECT c.id_certificado, c.nombre_archivo, c.fecha_vencimiento,
               m.nombre AS nombre_maquinaria, m.marca,
               DATEDIFF(c.fecha_vencimiento, CURDATE()) AS dias_restantes
        FROM certificado c
        JOIN maquinaria m ON c.id_maquinaria = m.id_maquinaria
        WHERE c.fecha_vencimiento IS NOT NULL
          AND c.fecha_vencimiento <= DATE_ADD(CURDATE(), INTERVAL 30 DAY)
        ORDER BY c.fecha_vencimiento ASC
        LIMIT 5
    ');
    $alertasRecientes = $stmtVencimientos->fetchAll();

    // 5. Últimos logs de auditoría (Top 5)
    $stmtLogs = $pdo->query('
        SELECT id_log, usuario, rol, accion, entidad, entidad_id, created_at
        FROM auditoria_logs
        ORDER BY created_at DESC
        LIMIT 5
    ');
    $ultimosLogs = $stmtLogs->fetchAll();

    echo json_encode([
        'success' => true,
        'data' => [
            'kpis' => [
                'obras' => [
                    'activas' => (int) $resObras['obras_activas'],
                    'total'   => (int) $resObras['total_obras'],
                ],
                'obreros' => [
                    'activos' => (int) $resObreros['obreros_activos'],
                    'total'   => (int) $resObreros['total_obreros'],
                ],
                'maquinaria' => [
                    'total'     => (int) $resMaq['total_maquinaria'],
                    'asignada'  => (int) $resMaq['maquinaria_asignada'],
                ],
                'horas' => [
                    'total_horas'     => (float) $resHoras['total_horas'],
                    'total_registros' => (int) $resHoras['total_registros'],
                ],
                'alertas' => [
                    'certificados' => (int) $resAlertasCert['total_alertas_cert'],
                    'cert_vencidos' => (int) $resAlertasCert['cert_vencidos'],
                    'cert_por_vencer' => (int) $resAlertasCert['cert_por_vencer'],
                    'contratos' => (int) $resAlertasContratos['total_alertas_contratos'],
                ]
            ], 
            'distribucion_cargos' => $distribucionCargos,
            'horas_por_obra' => $horasPorObra,
            'alertas_recientes' => $alertasRecientes,
            'ultimos_logs' => $ultimosLogs,
        ]
    ]);

} catch (Throwable $e) {
    error_log('api/dashboard.php error: ' . $e->getMessage());
    http_response_code(500);
    echo json_encode(['success' => false, 'error' => 'Error al recopilar métricas del panel.']);
}
