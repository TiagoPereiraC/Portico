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

    // 1. Obras
    $stmtObras = $pdo->query('
        SELECT 
            COUNT(*) AS total_obras,
            SUM(CASE WHEN activo = 1 THEN 1 ELSE 0 END) AS obras_activas
        FROM obras
    ');
    $resObras = $stmtObras->fetch() ?: ['total_obras' => 0, 'obras_activas' => 0];

    // 2. Obreros
    $stmtObreros = $pdo->query('
        SELECT 
            COUNT(*) AS total_obreros,
            SUM(CASE WHEN activo = 1 THEN 1 ELSE 0 END) AS obreros_activos
        FROM obreros
    ');
    $resObreros = $stmtObreros->fetch() ?: ['total_obreros' => 0, 'obreros_activos' => 0];

    // 3. Maquinaria
    $stmtMaq = $pdo->query('
        SELECT 
            COUNT(*) AS total_maquinaria,
            (SELECT COUNT(DISTINCT id_maquinaria) FROM obra_maquinaria WHERE fecha_retiro IS NULL) AS maquinaria_asignada
        FROM maquinaria
    ');
    $resMaq = $stmtMaq->fetch() ?: ['total_maquinaria' => 0, 'maquinaria_asignada' => 0];

    // 4. Horas y Asistencias
    $stmtHoras = $pdo->query('
        SELECT 
            COUNT(*) AS total_registros,
            COALESCE(SUM(horas_trabajadas), 0) AS total_horas
        FROM registros
    ');
    $resHoras = $stmtHoras->fetch() ?: ['total_registros' => 0, 'total_horas' => 0];

    // 5. Combustible (Litros, Gasto, Distribución)
    $resCombustible = [
        'total_litros' => 0.0,
        'total_gasto' => 0.0,
        'diesel_litros' => 0.0,
        'nafta_litros' => 0.0,
        'por_tipo' => []
    ];
    try {
        $stmtComb = $pdo->query("
            SELECT 
                COALESCE(SUM(litros), 0) AS total_litros,
                COALESCE(SUM(precio_total), 0) AS total_gasto,
                COALESCE(SUM(CASE WHEN LOWER(nombre_combustible) LIKE '%diesel%' THEN litros ELSE 0 END), 0) AS diesel_litros,
                COALESCE(SUM(CASE WHEN LOWER(nombre_combustible) LIKE '%nafta%' THEN litros ELSE 0 END), 0) AS nafta_litros
            FROM combustible
        ");
        $rowComb = $stmtComb->fetch();
        if ($rowComb) {
            $resCombustible['total_litros'] = (float) $rowComb['total_litros'];
            $resCombustible['total_gasto'] = (float) $rowComb['total_gasto'];
            $resCombustible['diesel_litros'] = (float) $rowComb['diesel_litros'];
            $resCombustible['nafta_litros'] = (float) $rowComb['nafta_litros'];
        }

        $stmtCombTipo = $pdo->query("
            SELECT nombre_combustible AS tipo, SUM(litros) AS litros, SUM(precio_total) AS gasto
            FROM combustible
            GROUP BY nombre_combustible
        ");
        $resCombustible['por_tipo'] = $stmtCombTipo->fetchAll() ?: [];
    } catch (Throwable $e) {
        // La tabla se creará con el primer registro de asistencia
    }

    // 6. Actividades / Tareas del Contrato
    $resTareas = [
        'total_tareas' => 0,
        'tareas_completadas' => 0,
        'tareas_pendientes' => 0,
        'porcentaje_avance' => 0.0
    ];
    try {
        $stmtTareas = $pdo->query("
            SELECT 
                COUNT(*) AS total_tareas,
                SUM(CASE WHEN estado = 'Completada' THEN 1 ELSE 0 END) AS tareas_completadas,
                SUM(CASE WHEN estado = 'Pendiente' THEN 1 ELSE 0 END) AS tareas_pendientes
            FROM contrato_tareas
        ");
        $rowTareas = $stmtTareas->fetch();
        if ($rowTareas && (int)$rowTareas['total_tareas'] > 0) {
            $resTareas['total_tareas'] = (int) $rowTareas['total_tareas'];
            $resTareas['tareas_completadas'] = (int) $rowTareas['tareas_completadas'];
            $resTareas['tareas_pendientes'] = (int) $rowTareas['tareas_pendientes'];
            $resTareas['porcentaje_avance'] = round(($resTareas['tareas_completadas'] / $resTareas['total_tareas']) * 100, 1);
        }
    } catch (Throwable $e) {
    }

    // 7. Recursos (Materiales y Herramientas)
    $resRecursos = [
        'total_recursos' => 0,
        'total_materiales' => 0,
        'total_herramientas' => 0
    ];
    try {
        $stmtRecursos = $pdo->query("
            SELECT 
                COUNT(*) AS total_recursos,
                SUM(CASE WHEN es_material = 1 THEN 1 ELSE 0 END) AS total_materiales,
                SUM(CASE WHEN es_material = 0 THEN 1 ELSE 0 END) AS total_herramientas
            FROM recursos
        ");
        $rowRec = $stmtRecursos->fetch();
        if ($rowRec) {
            $resRecursos['total_recursos'] = (int) $rowRec['total_recursos'];
            $resRecursos['total_materiales'] = (int) $rowRec['total_materiales'];
            $resRecursos['total_herramientas'] = (int) $rowRec['total_herramientas'];
        }
    } catch (Throwable $e) {
    }

    // 8. Alertas de certificados técnicos de maquinaria
    $stmtAlertasCert = $pdo->query('
        SELECT 
            COUNT(*) AS total_alertas_cert,
            SUM(CASE WHEN fecha_vencimiento < CURDATE() THEN 1 ELSE 0 END) AS cert_vencidos,
            SUM(CASE WHEN fecha_vencimiento >= CURDATE() AND fecha_vencimiento <= DATE_ADD(CURDATE(), INTERVAL 30 DAY) THEN 1 ELSE 0 END) AS cert_por_vencer
        FROM certificado
        WHERE fecha_vencimiento IS NOT NULL AND fecha_vencimiento <= DATE_ADD(CURDATE(), INTERVAL 30 DAY)
    ');
    $resAlertasCert = $stmtAlertasCert->fetch() ?: ['total_alertas_cert' => 0, 'cert_vencidos' => 0, 'cert_por_vencer' => 0];

    // 9. Alertas de contratos de obreros
    $stmtAlertasContratos = $pdo->query('
        SELECT 
            COUNT(*) AS total_alertas_contratos,
            SUM(CASE WHEN fecha_vencimiento < CURDATE() THEN 1 ELSE 0 END) AS contratos_vencidos,
            SUM(CASE WHEN fecha_vencimiento >= CURDATE() AND fecha_vencimiento <= DATE_ADD(CURDATE(), INTERVAL 30 DAY) THEN 1 ELSE 0 END) AS contratos_por_vencer
        FROM contrato_obrero
        WHERE fecha_vencimiento IS NOT NULL AND fecha_vencimiento <= DATE_ADD(CURDATE(), INTERVAL 30 DAY)
    ');
    $resAlertasContratos = $stmtAlertasContratos->fetch() ?: ['total_alertas_contratos' => 0, 'contratos_vencidos' => 0, 'contratos_por_vencer' => 0];

    // 10. Gráfico: Distribución de obreros por cargo
    $stmtCargos = $pdo->query('
        SELECT cargo, COUNT(*) AS cantidad
        FROM obreros
        WHERE activo = 1
        GROUP BY cargo
        ORDER BY cantidad DESC
    ');
    $distribucionCargos = $stmtCargos->fetchAll();

    // 11. Gráfico: Top Obras con más horas trabajadas
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

    // 12. Próximos vencimientos de certificados de maquinaria (Top 5)
    $stmtVencimientos = $pdo->query('
        SELECT c.id_certificado, c.nombre_archivo, c.fecha_vencimiento,
               m.nombre AS nombre_maquinaria, m.marca,
               DATEDIFF(c.fecha_vencimiento, CURDATE()) AS dias_restantes,
               "maquinaria" AS tipo_alerta
        FROM certificado c
        JOIN maquinaria m ON c.id_maquinaria = m.id_maquinaria
        WHERE c.fecha_vencimiento IS NOT NULL
          AND c.fecha_vencimiento <= DATE_ADD(CURDATE(), INTERVAL 30 DAY)
        ORDER BY c.fecha_vencimiento ASC
        LIMIT 5
    ');
    $alertasRecientes = $stmtVencimientos->fetchAll();

    // 13. Próximos vencimientos de contratos de obreros (Top 5)
    $stmtContratosVenc = $pdo->query('
        SELECT co.id_contrato_obrero, co.fecha_vencimiento,
               CONCAT(o.nombre, " ", o.apellido) AS nombre_obrero, o.documento,
               DATEDIFF(co.fecha_vencimiento, CURDATE()) AS dias_restantes,
               "obrero" AS tipo_alerta
        FROM contrato_obrero co
        JOIN obreros o ON co.id_obrero = o.id_obrero
        WHERE co.fecha_vencimiento IS NOT NULL
          AND co.fecha_vencimiento <= DATE_ADD(CURDATE(), INTERVAL 30 DAY)
        ORDER BY co.fecha_vencimiento ASC
        LIMIT 5
    ');
    $alertasContratos = $stmtContratosVenc->fetchAll();

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
                'combustible' => $resCombustible,
                'actividades' => $resTareas,
                'recursos'    => $resRecursos,
                'alertas' => [
                    'certificados' => (int) $resAlertasCert['total_alertas_cert'],
                    'cert_vencidos' => (int) $resAlertasCert['cert_vencidos'],
                    'cert_por_vencer' => (int) $resAlertasCert['cert_por_vencer'],
                    'contratos' => (int) $resAlertasContratos['total_alertas_contratos'],
                    'contratos_vencidos' => (int) $resAlertasContratos['contratos_vencidos'],
                    'contratos_por_vencer' => (int) $resAlertasContratos['contratos_por_vencer'],
                    'total_general' => (int)$resAlertasCert['total_alertas_cert'] + (int)$resAlertasContratos['total_alertas_contratos'],
                ]
            ], 
            'distribucion_cargos' => $distribucionCargos,
            'horas_por_obra' => $horasPorObra,
            'alertas_recientes' => $alertasRecientes,
            'alertas_contratos' => $alertasContratos,
        ]
    ]);

} catch (Throwable $e) {
    error_log('api/dashboard.php error: ' . $e->getMessage());
    http_response_code(500);
    echo json_encode(['success' => false, 'error' => 'Error al recopilar métricas del panel.']);
}
