<?php

require_once __DIR__ . '/config/db.php';
require_once __DIR__ . '/config/session.php';
require_once __DIR__ . '/config/auditoria.php';


/*
|--------------------------------------------------------------------------
| CONFIGURACIÓN
|--------------------------------------------------------------------------
*/

const MAX_CONTRATO_BYTES = 10 * 1024 * 1024;

$origenesPermitidos = array_values(
    array_filter([
        'http://127.0.0.1:5500',
        'http://localhost:5500',

        // Permite agregar el origen mediante variable de entorno.
        getenv('PORTICO_FRONTEND_ORIGIN') ?: null
    ])
);


/*
|--------------------------------------------------------------------------
| CORS
|--------------------------------------------------------------------------
*/

$origin = $_SERVER['HTTP_ORIGIN'] ?? '';

if (
    $origin !== '' &&
    in_array($origin, $origenesPermitidos, true)
) {
    header("Access-Control-Allow-Origin: {$origin}");
    header('Access-Control-Allow-Credentials: true');
    header('Vary: Origin');
}

header('Access-Control-Allow-Headers: Content-Type, X-CSRF-Token');
header('Access-Control-Allow-Methods: GET, POST, DELETE, OPTIONS');
header('Content-Type: application/json; charset=utf-8');


/*
|--------------------------------------------------------------------------
| OPTIONS
|--------------------------------------------------------------------------
*/

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}


/*
|--------------------------------------------------------------------------
| SESIÓN
|--------------------------------------------------------------------------
*/

iniciarSesion();

if (empty($_SESSION['user_id'])) {

    http_response_code(401);

    echo json_encode([
        'success' => false,
        'error' => 'Sesión no válida. Iniciá sesión nuevamente.'
    ], JSON_UNESCAPED_UNICODE);

    exit;
}

$esAdmin = ($_SESSION['rol'] ?? '') === 'Administrador';


/*
|--------------------------------------------------------------------------
| ROUTER PRINCIPAL
|--------------------------------------------------------------------------
*/

try {

    $pdo = conectar();

    switch ($_SERVER['REQUEST_METHOD']) {

        /*
        |--------------------------------------------------------------------------
        | GET
        |--------------------------------------------------------------------------
        */

        case 'GET':

            if (isset($_GET['descargar_contrato'])) {
                responderDescargaContrato($pdo);
                break;
            }

            if (isset($_GET['detalle'])) {
                responderDetalle($pdo);
                break;
            }

            responderListado($pdo);
            break;


        /*
        |--------------------------------------------------------------------------
        | POST
        |--------------------------------------------------------------------------
        */

        case 'POST':

            validarCsrf();

            /*
            |--------------------------------------------------------------------------
            | Detectar límite de POST antes de procesar multipart
            |--------------------------------------------------------------------------
            */

            verificarLimitePost();

            $contentType = $_SERVER['CONTENT_TYPE'] ?? '';

            if (
                stripos(
                    $contentType,
                    'multipart/form-data'
                ) !== false
            ) {

                $body = $_POST;

                /*
                |--------------------------------------------------------------------------
                | TAREAS PENDIENTES
                |--------------------------------------------------------------------------
                */

                if (
                    isset($body['tareas_pendientes']) &&
                    is_string($body['tareas_pendientes'])
                ) {

                    $body['tareas_pendientes'] =
                        json_decode(
                            $body['tareas_pendientes'],
                            true
                        );

                    if (
                        !is_array(
                            $body['tareas_pendientes']
                        )
                    ) {
                        throw new InvalidArgumentException(
                            'Las actividades pendientes son inválidas.'
                        );
                    }
                }

                /*
                |--------------------------------------------------------------------------
                | NUEVAS TAREAS
                |--------------------------------------------------------------------------
                */

                if (
                    isset($body['nuevas_tareas']) &&
                    is_string($body['nuevas_tareas'])
                ) {

                    $body['nuevas_tareas'] =
                        json_decode(
                            $body['nuevas_tareas'],
                            true
                        );

                    if (
                        !is_array(
                            $body['nuevas_tareas']
                        )
                    ) {
                        throw new InvalidArgumentException(
                            'Las nuevas actividades son inválidas.'
                        );
                    }
                }

                /*
                |--------------------------------------------------------------------------
                | ARCHIVO DE NUEVO CONTRATO
                |--------------------------------------------------------------------------
                */

                if (
                    isset($_FILES['contrato_archivo']) &&
                    is_array($_FILES['contrato_archivo'])
                ) {

                    $archivo = $_FILES['contrato_archivo'];

                    if (
                        ($archivo['error'] ?? UPLOAD_ERR_NO_FILE)
                        !== UPLOAD_ERR_NO_FILE
                    ) {

                        if (
                            ($archivo['error'] ?? 0)
                            !== UPLOAD_ERR_OK
                        ) {
                            throw new InvalidArgumentException(
                                obtenerMensajeErrorUpload(
                                    (int) $archivo['error']
                                )
                            );
                        }

                        if (
                            !isset($archivo['tmp_name']) ||
                            !is_uploaded_file($archivo['tmp_name'])
                        ) {
                            throw new InvalidArgumentException(
                                'El archivo recibido no es válido.'
                            );
                        }

                        $tamano =
                            filesize(
                                $archivo['tmp_name']
                            );

                        if (
                            $tamano === false
                        ) {
                            throw new InvalidArgumentException(
                                'No se pudo determinar el tamaño del archivo.'
                            );
                        }

                        if (
                            $tamano > MAX_CONTRATO_BYTES
                        ) {
                            throw new InvalidArgumentException(
                                'El contrato no puede superar los 10 MB.'
                            );
                        }

                        $contenido =
                            file_get_contents(
                                $archivo['tmp_name']
                            );

                        if ($contenido === false) {
                            throw new InvalidArgumentException(
                                'No se pudo leer el archivo del nuevo contrato.'
                            );
                        }

                        $body['nuevo_contrato'] = [
                            'nombre_archivo' =>
                                $archivo['name'],

                            'contenido_base64' =>
                                base64_encode($contenido)
                        ];
                    }
                }

            } else {

                $body = leerJson();
            }


            $accion =
                trim(
                    (string) (
                        $body['accion'] ?? ''
                    )
                );


            /*
            |--------------------------------------------------------------------------
            | CAMBIAR ESTADO
            |--------------------------------------------------------------------------
            */

            if ($accion === 'cambiar_estado') {

                exigirAdministrador(
                    $esAdmin,
                    'No tenés permisos para gestionar obras.'
                );

                responderCambioEstado(
                    $pdo,
                    $body
                );

                break;
            }


            /*
            |--------------------------------------------------------------------------
            | CERRAR CONTRATO
            |--------------------------------------------------------------------------
            */

            if ($accion === 'cerrar_contrato') {

                exigirAdministrador(
                    $esAdmin,
                    'No tenés permisos para gestionar contratos.'
                );

                responderCerrarContrato(
                    $pdo,
                    $body
                );

                break;
            }


            /*
            |--------------------------------------------------------------------------
            | COMPLETAR TAREA
            |--------------------------------------------------------------------------
            */

            if ($accion === 'completar_tarea') {

                exigirAdministrador(
                    $esAdmin,
                    'No tenés permisos para completar actividades.'
                );

                responderCompletarTarea(
                    $pdo,
                    $body
                );

                break;
            }


            /*
            |--------------------------------------------------------------------------
            | GUARDAR / CREAR / EDITAR
            |--------------------------------------------------------------------------
            */

            if (
                $accion === '' ||
                $accion === 'guardar' ||
                $accion === 'crear' ||
                $accion === 'editar'
            ) {

                exigirAdministrador(
                    $esAdmin,
                    'No tenés permisos para gestionar obras.'
                );

                responderGuardado(
                    $pdo,
                    $body
                );

                break;
            }


            throw new InvalidArgumentException(
                'Acción no reconocida.'
            );


        /*
        |--------------------------------------------------------------------------
        | DELETE
        |--------------------------------------------------------------------------
        */

        case 'DELETE':

            exigirAdministrador(
                $esAdmin,
                'No tenés permisos para gestionar obras.'
            );

            validarCsrf();

            $body = leerJson();

            responderEliminacion(
                $pdo,
                $body
            );

            break;


        /*
        |--------------------------------------------------------------------------
        | MÉTODO NO PERMITIDO
        |--------------------------------------------------------------------------
        */

        default:

            http_response_code(405);

            echo json_encode([
                'success' => false,
                'error' => 'Método no permitido.'
            ], JSON_UNESCAPED_UNICODE);

            break;
    }


} catch (InvalidArgumentException $e) {

    http_response_code(400);

    echo json_encode([
        'success' => false,
        'error' => $e->getMessage()
    ], JSON_UNESCAPED_UNICODE);


} catch (RuntimeException $e) {

    http_response_code(404);

    echo json_encode([
        'success' => false,
        'error' => $e->getMessage()
    ], JSON_UNESCAPED_UNICODE);


} catch (PDOException $e) {

    error_log(
        'OBRAS.PHP PDO ERROR [' .
        $e->getCode() .
        ']: ' .
        $e->getMessage()
    );

    http_response_code(500);

    echo json_encode([
        'success' => false,
        'error' => 'Error de base de datos.'
    ], JSON_UNESCAPED_UNICODE);


} catch (Throwable $e) {

    error_log(
        'OBRAS.PHP ERROR: ' .
        $e->getMessage() .
        ' | FILE: ' .
        $e->getFile() .
        ' | LINE: ' .
        $e->getLine()
    );

    http_response_code(500);

    echo json_encode([
        'success' => false,
        'error' => 'Error interno del servidor.'
    ], JSON_UNESCAPED_UNICODE);
}


/*
|--------------------------------------------------------------------------
| EXIGIR ADMINISTRADOR
|--------------------------------------------------------------------------
*/

function exigirAdministrador(
    bool $esAdmin,
    string $mensaje
): void {

    if (!$esAdmin) {

        http_response_code(403);

        echo json_encode([
            'success' => false,
            'error' => $mensaje
        ], JSON_UNESCAPED_UNICODE);

        exit;
    }
}


/*
|--------------------------------------------------------------------------
| DETALLE
|--------------------------------------------------------------------------
*/

function responderDetalle(PDO $pdo): void
{

    $idObra =
        isset($_GET['id_obra'])
            ? (int) $_GET['id_obra']
            : 0;

    if ($idObra <= 0) {
        throw new InvalidArgumentException(
            'Debés indicar una obra válida.'
        );
    }


    $obra =
        obtenerObra(
            $pdo,
            $idObra
        );


    /*
    |--------------------------------------------------------------------------
    | MATERIALES
    |--------------------------------------------------------------------------
    */

    $stmt = $pdo->prepare(
        'SELECT
            nombre,
            SUM(cantidad) AS cantidad_total,
            SUM(
                cantidad * COALESCE(precio_unitario, 0)
            ) AS costo_total
         FROM recursos
         WHERE id_obra = ?
           AND es_material = 1
         GROUP BY nombre
         ORDER BY nombre'
    );

    $stmt->execute([
        $idObra
    ]);

    $materiales =
        $stmt->fetchAll(
            PDO::FETCH_ASSOC
        );


    /*
    |--------------------------------------------------------------------------
    | HERRAMIENTAS
    |--------------------------------------------------------------------------
    */

    $stmt = $pdo->prepare(
        'SELECT
            nombre,
            SUM(cantidad) AS cantidad_total
         FROM recursos
         WHERE id_obra = ?
           AND es_material = 0
         GROUP BY nombre
         ORDER BY nombre'
    );

    $stmt->execute([
        $idObra
    ]);

    $herramientas =
        $stmt->fetchAll(
            PDO::FETCH_ASSOC
        );


    /*
    |--------------------------------------------------------------------------
    | OBREROS
    |--------------------------------------------------------------------------
    */

    $stmt = $pdo->prepare(
        'SELECT
            obr.id_obrero,
            obr.nombre,
            obr.apellido,
            SUM(reg.horas_trabajadas) AS horas_totales
         FROM registros reg
         INNER JOIN obreros obr
             ON obr.id_obrero = reg.id_obrero
         WHERE reg.id_obra = ?
         GROUP BY
            obr.id_obrero,
            obr.nombre,
            obr.apellido
         ORDER BY
            obr.apellido,
            obr.nombre'
    );

    $stmt->execute([
        $idObra
    ]);

    $obreros =
        $stmt->fetchAll(
            PDO::FETCH_ASSOC
        );


    /*
    |--------------------------------------------------------------------------
    | MAQUINARIA
    |--------------------------------------------------------------------------
    */

    $stmt = $pdo->prepare(
        'SELECT
            m.nombre,
            m.marca,
            om.fecha_asignacion,
            om.fecha_retiro,
            am.fecha           AS fecha_devolucion,
            am.hora_salida     AS hora_salida,
            am.hora_devolucion AS hora_devolucion
         FROM obra_maquinaria om
         INNER JOIN maquinaria m
             ON m.id_maquinaria = om.id_maquinaria
         LEFT JOIN asistencia_maquinaria am
             ON am.id_obra       = om.id_obra
            AND am.id_maquinaria = om.id_maquinaria
            AND am.fecha = (
                SELECT MAX(am2.fecha)
                FROM asistencia_maquinaria am2
                WHERE am2.id_obra       = om.id_obra
                  AND am2.id_maquinaria = om.id_maquinaria
            )
         WHERE om.id_obra = ?
         ORDER BY
            om.fecha_asignacion DESC,
            m.nombre'
    );

    $stmt->execute([$idObra]);

    $maquinaria = $stmt->fetchAll(PDO::FETCH_ASSOC);



    /*
    |--------------------------------------------------------------------------
    | TAREAS DEL CONTRATO ACTIVO
    |--------------------------------------------------------------------------
    |
    | Una obra finalizada puede tener un contrato cerrado.
    | No se muestran sus tareas como tareas activas.
    |--------------------------------------------------------------------------
    */

    $stmt = $pdo->prepare(
        'SELECT
            ct.id_tarea,
            ct.id_contrato,
            ct.id_tarea_origen,
            ct.descripcion,
            ct.importe,
            ct.estado,
            ct.fecha_completada
         FROM contrato_tareas ct
         INNER JOIN contratos c
             ON c.id_contrato = ct.id_contrato
         WHERE c.id_obra = ?
           AND c.estado = ?
         ORDER BY ct.id_tarea ASC'
    );

    $stmt->execute([
        $idObra,
        'Activo'
    ]);

    $tareas =
        $stmt->fetchAll(
            PDO::FETCH_ASSOC
        );


    /*
    |--------------------------------------------------------------------------
    | COMBUSTIBLE
    |--------------------------------------------------------------------------
    */

    $stmt = $pdo->prepare(
        'SELECT
            c.id_combustible,
            c.fecha,
            c.nombre_combustible,
            c.litros,
            c.precio_unitario,
            c.precio_total,
            c.id_maquinaria,
            COALESCE(m.nombre, "Sin asignar") AS maquinaria_nombre,
            m.marca AS maquinaria_marca
         FROM combustible c
         LEFT JOIN maquinaria m
             ON m.id_maquinaria = c.id_maquinaria
         WHERE c.id_obra = ?
         ORDER BY c.fecha DESC, c.id_combustible DESC'
    );

    $stmt->execute([
        $idObra
    ]);

    $combustible =
        $stmt->fetchAll(
            PDO::FETCH_ASSOC
        );


    echo json_encode([
        'success' => true,
        'obra' => $obra,
        'materiales' => $materiales,
        'herramientas' => $herramientas,
        'obreros' => $obreros,
        'maquinaria' => $maquinaria,
        'combustible' => $combustible,
        'tareas' => $tareas
    ], JSON_UNESCAPED_UNICODE);
}


/*
|--------------------------------------------------------------------------
| LISTADO
|--------------------------------------------------------------------------
*/

function responderListado(PDO $pdo): void
{

    $page =
        max(
            1,
            (int) (
                $_GET['page'] ?? 1
            )
        );

    $limit =
        (int) (
            $_GET['limit'] ?? 10
        );

    $limit =
        max(
            1,
            min(
                $limit,
                100
            )
        );

    $search =
        trim(
            (string) (
                $_GET['search'] ?? ''
            )
        );

    $status =
        strtolower(
            trim(
                (string) (
                    $_GET['status'] ?? 'all'
                )
            )
        );


    if (
        !in_array(
            $status,
            [
                'all',
                'active',
                'inactive'
            ],
            true
        )
    ) {
        throw new InvalidArgumentException(
            'Filtro de estado inválido.'
        );
    }


    $where = [];
    $params = [];


    if ($search !== '') {

        $where[] = '(
            o.numero_contrata LIKE ?
            OR o.nombre LIKE ?
            OR o.direccion LIKE ?
            OR o.descripcion LIKE ?
            OR o.nombre_cliente LIKE ?
            OR o.telefono_cliente LIKE ?
        )';

        $searchLike =
            '%' . $search . '%';

        $params = [
            $searchLike,
            $searchLike,
            $searchLike,
            $searchLike,
            $searchLike,
            $searchLike
        ];
    }


    if ($status === 'active') {

        $where[] = 'o.activo = 1';

    } elseif ($status === 'inactive') {

        $where[] = 'o.activo = 0';
    }


    $whereSql =
        !empty($where)
            ? ' WHERE ' . implode(' AND ', $where)
            : '';


    /*
    |--------------------------------------------------------------------------
    | TOTAL
    |--------------------------------------------------------------------------
    */

    $countStmt =
        $pdo->prepare(
            'SELECT COUNT(*)
             FROM obras o'
            . $whereSql
        );


    foreach (
        $params
        as $index => $value
    ) {

        $countStmt->bindValue(
            $index + 1,
            $value,
            PDO::PARAM_STR
        );
    }

    $countStmt->execute();

    $total =
        (int)
        $countStmt->fetchColumn();


    $totalPages =
        max(
            1,
            (int) ceil(
                $total / $limit
            )
        );


    $page =
        min(
            $page,
            $totalPages
        );


    $offset =
        ($page - 1) * $limit;


    /*
    |--------------------------------------------------------------------------
    | LISTADO
    |--------------------------------------------------------------------------
    |
    | Se obtiene el ÚLTIMO contrato, independientemente de que esté
    | Activo o Cerrado.
    |--------------------------------------------------------------------------
    */

    $sql =
        'SELECT
            o.id_obra,
            o.numero_contrata,
            o.nombre,
            o.direccion,
            o.descripcion,
            o.fecha_inicio,
            o.fecha_fin,
            o.nombre_cliente,
            o.telefono_cliente,
            o.activo,

            c.id_contrato,

            c.nombre_archivo
                AS contrato_nombre_archivo,

            c.estado
                AS contrato_estado

         FROM obras o

         LEFT JOIN contratos c
             ON c.id_contrato = (
                 SELECT MAX(c2.id_contrato)
                 FROM contratos c2
                 WHERE c2.id_obra = o.id_obra
             )'
        . $whereSql .
        ' ORDER BY
            o.fecha_inicio DESC,
            o.nombre ASC
          LIMIT '
        . $limit .
        ' OFFSET '
        . $offset;


    $stmt =
        $pdo->prepare(
            $sql
        );


    foreach (
        $params
        as $index => $value
    ) {

        $stmt->bindValue(
            $index + 1,
            $value,
            PDO::PARAM_STR
        );
    }


    $stmt->execute();


    $obras =
        $stmt->fetchAll(
            PDO::FETCH_ASSOC
        );


    echo json_encode([

        'success' =>
            true,

        'obras' =>
            $obras,

        'total' =>
            $total,

        'page' =>
            $page,

        'per_page' =>
            $limit,

        'total_pages' =>
            $totalPages

    ], JSON_UNESCAPED_UNICODE);
}


/*
|--------------------------------------------------------------------------
| CAMBIAR ESTADO
|--------------------------------------------------------------------------
*/

function responderCambioEstado(
    PDO $pdo,
    array $body
): void {

    $idObra =
        isset($body['id_obra'])
            ? (int) $body['id_obra']
            : 0;

    $activo =
        normalizarBooleano(
            $body['activo'] ?? null,
            null
        );


    if ($idObra <= 0) {

        throw new InvalidArgumentException(
            'Debés indicar una obra válida.'
        );
    }


    if ($activo === null) {

        throw new InvalidArgumentException(
            'El estado de la obra es inválido.'
        );
    }


    $stmt =
        $pdo->prepare(
            'UPDATE obras
             SET activo = ?
             WHERE id_obra = ?'
        );


    $stmt->execute([
        $activo,
        $idObra
    ]);


    if (
        $stmt->rowCount() === 0
    ) {

        $check =
            $pdo->prepare(
                'SELECT id_obra
                 FROM obras
                 WHERE id_obra = ?
                 LIMIT 1'
            );

        $check->execute([
            $idObra
        ]);

        if (!$check->fetchColumn()) {

            throw new RuntimeException(
                'La obra indicada no existe.'
            );
        }
    }


    $obra =
        obtenerObra(
            $pdo,
            $idObra
        );


    registrarAuditoria(
        $pdo,
        'cambiar_estado',
        'obras',
        $idObra,
        [
            'nombre' =>
                $obra['nombre'],

            'activo' =>
                $activo
        ]
    );


    echo json_encode([
        'success' => true,
        'message' =>
            'Estado de la obra actualizado correctamente.'
    ], JSON_UNESCAPED_UNICODE);
}


/*
|--------------------------------------------------------------------------
| CERRAR CONTRATO
|--------------------------------------------------------------------------
*/

function responderCerrarContrato(
    PDO $pdo,
    array $body
): void {

    $idObra =
        isset($body['id_obra'])
            ? (int) $body['id_obra']
            : 0;

    $opcion =
        trim(
            (string) (
                $body['opcion'] ?? ''
            )
        );


    if ($idObra <= 0) {
        throw new InvalidArgumentException(
            'Debés indicar una obra válida.'
        );
    }


    if (
        !in_array(
            $opcion,
            [
                'nuevo_contrato',
                'finalizar_obra'
            ],
            true
        )
    ) {
        throw new InvalidArgumentException(
            'La opción de cierre es inválida.'
        );
    }


    /*
    |--------------------------------------------------------------------------
    | OBRA
    |--------------------------------------------------------------------------
    */

    $stmt = $pdo->prepare(
        'SELECT
            id_obra,
            nombre,
            activo
         FROM obras
         WHERE id_obra = ?
         LIMIT 1'
    );

    $stmt->execute([$idObra]);

    $obra = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$obra) {
        throw new RuntimeException(
            'La obra indicada no existe.'
        );
    }


    /*
    |--------------------------------------------------------------------------
    | CONTRATO ACTIVO (PERMISIVO SI ES NUEVO CONTRATO)
    |--------------------------------------------------------------------------
    */

    $stmt = $pdo->prepare(
        'SELECT
            id_contrato,
            id_obra,
            nombre_archivo
         FROM contratos
         WHERE id_obra = ?
           AND estado = ?
         ORDER BY id_contrato DESC
         LIMIT 1'
    );

    $stmt->execute([
        $idObra,
        'Activo'
    ]);

    $contrato = $stmt->fetch(PDO::FETCH_ASSOC);

    /*
    | Si se solicita finalizar obra, exige obligatoriamente un contrato activo.
    | Si se va a crear un nuevo contrato, permite continuar independientemente
    | de si existía uno activo o no.
    */
    if (!$contrato && $opcion === 'finalizar_obra') {
        throw new RuntimeException(
            'La obra no tiene un contrato activo para finalizar.'
        );
    }

    $idContrato = $contrato ? (int) $contrato['id_contrato'] : null;


    /*
    |--------------------------------------------------------------------------
    | TAREAS DEL CONTRATO ANTERIOR (SI EXISTE)
    |--------------------------------------------------------------------------
    */

    $tareasActuales = [];

    if ($idContrato !== null) {
        $stmt = $pdo->prepare(
            'SELECT
                id_tarea,
                descripcion,
                importe,
                estado,
                fecha_completada
             FROM contrato_tareas
             WHERE id_contrato = ?
             ORDER BY id_tarea ASC'
        );

        $stmt->execute([$idContrato]);

        $tareasActuales = $stmt->fetchAll(PDO::FETCH_ASSOC);
    }


    $tareasPendientes = [];
    $importeFinal = 0.00;
    $tareasCompletadas = 0;


    foreach ($tareasActuales as $tarea) {

        $estado = strtolower(trim((string) ($tarea['estado'] ?? '')));

        if ($estado === 'completada') {
            $importeFinal += (float) ($tarea['importe'] ?? 0);
            $tareasCompletadas++;
        } else {
            $tareasPendientes[] = $tarea;
        }
    }


    /*
    |--------------------------------------------------------------------------
    | NUEVO CONTRATO
    |--------------------------------------------------------------------------
    */

    $nuevoContrato = null;

    if ($opcion === 'nuevo_contrato') {

        if (
            !isset($body['nuevo_contrato']) ||
            !is_array($body['nuevo_contrato'])
        ) {
            throw new InvalidArgumentException(
                'Debés cargar el archivo del nuevo contrato.'
            );
        }

        $nuevoContrato = extraerContratoDesdeCampo(
            $body['nuevo_contrato'],
            'nuevo contrato'
        );
    }


    /*
    |--------------------------------------------------------------------------
    | NUEVAS TAREAS
    |--------------------------------------------------------------------------
    */

    $nuevasTareas = [];

    if ($opcion === 'nuevo_contrato') {

        $nuevasTareas = validarTareas(
            $body['nuevas_tareas'] ?? []
        );

        foreach ($nuevasTareas as &$tarea) {
            $tarea['id_tarea'] = null;
            $tarea['id_tarea_origen'] = null;
            $tarea['estado'] = 'Pendiente';
            $tarea['fecha_completada'] = null;
        }

        unset($tarea);
    }


    /*
    |--------------------------------------------------------------------------
    | TRANSACCIÓN
    |--------------------------------------------------------------------------
    */

    $pdo->beginTransaction();

    try {

        /*
        |--------------------------------------------------------------------------
        | CERRAR CONTRATO ACTUAL (SI EXISTE)
        |--------------------------------------------------------------------------
        */

        if ($idContrato !== null) {

            $stmt = $pdo->prepare(
                'UPDATE contratos
                 SET
                    estado = ?,
                    fecha_cierre = CURDATE(),
                    importe_final = ?,
                    motivo_cierre = ?
                 WHERE id_contrato = ?'
            );

            $stmt->execute([
                'Cerrado',
                $importeFinal,
                $opcion === 'nuevo_contrato'
                    ? 'Nuevo contrato'
                    : 'Finalizacion de obra',
                $idContrato
            ]);
        }


        /*
        |--------------------------------------------------------------------------
        | CREAR NUEVO CONTRATO
        |--------------------------------------------------------------------------
        */

        if ($opcion === 'nuevo_contrato') {

            $stmt = $pdo->prepare(
                'INSERT INTO contratos (
                    id_obra,
                    archivo,
                    nombre_archivo,
                    fecha_subida,
                    estado
                )
                VALUES (?, ?, ?, CURDATE(), ?)'
            );

            $stmt->execute([
                $idObra,
                $nuevoContrato['archivo'],
                $nuevoContrato['nombre_archivo'],
                'Activo'
            ]);

            $idNuevoContrato = (int) $pdo->lastInsertId();


            /*
            |--------------------------------------------------------------------------
            | COPIAR PENDIENTES DEL CONTRATO ANTERIOR
            |--------------------------------------------------------------------------
            */

            foreach ($tareasPendientes as $tarea) {

                $stmt = $pdo->prepare(
                    'INSERT INTO contrato_tareas (
                        id_contrato,
                        id_tarea_origen,
                        descripcion,
                        importe,
                        estado,
                        fecha_completada
                    )
                    VALUES (?, ?, ?, ?, ?, NULL)'
                );

                $stmt->execute([
                    $idNuevoContrato,
                    (int) $tarea['id_tarea'],
                    $tarea['descripcion'],
                    $tarea['importe'],
                    'Pendiente'
                ]);
            }


            /*
            |--------------------------------------------------------------------------
            | GUARDAR NUEVAS TAREAS
            |--------------------------------------------------------------------------
            */

            if (!empty($nuevasTareas)) {
                guardarTareas(
                    $pdo,
                    $idNuevoContrato,
                    $nuevasTareas
                );
            }


            /*
            |--------------------------------------------------------------------------
            | MANTENER / ACTIVAR LA OBRA
            |--------------------------------------------------------------------------
            */

            $stmt = $pdo->prepare(
                'UPDATE obras
                 SET
                    activo = 1,
                    fecha_fin = NULL
                 WHERE id_obra = ?'
            );

            $stmt->execute([$idObra]);

            $pdo->commit();


            registrarAuditoria(
                $pdo,
                'cerrar_contrato',
                'contratos',
                $idContrato ?? $idNuevoContrato,
                [
                    'id_obra' => $idObra,
                    'id_nuevo_contrato' => $idNuevoContrato,
                    'importe_final' => $importeFinal,
                    'tareas_pendientes_copiadas' => count($tareasPendientes),
                    'tareas_nuevas' => count($nuevasTareas),
                    'obra_continua_activa' => true
                ]
            );


            echo json_encode([
                'success' => true,
                'message' => 'Contrato cerrado y nuevo contrato creado correctamente.',
                'id_contrato_anterior' => $idContrato,
                'id_nuevo_contrato' => $idNuevoContrato,
                'importe_final' => $importeFinal,
                'tareas_pendientes_copiadas' => count($tareasPendientes),
                'tareas_nuevas' => count($nuevasTareas),
                'obra_activa' => true
            ], JSON_UNESCAPED_UNICODE);

            return;
        }


        /*
        |--------------------------------------------------------------------------
        | FINALIZAR OBRA
        |--------------------------------------------------------------------------
        */

        $stmt = $pdo->prepare(
            'UPDATE obras
             SET
                activo = 0,
                fecha_fin = CURDATE()
             WHERE id_obra = ?'
        );

        $stmt->execute([$idObra]);

        $pdo->commit();


        registrarAuditoria(
            $pdo,
            'finalizar_obra',
            'obras',
            $idObra,
            [
                'id_contrato' => $idContrato,
                'importe_final' => $importeFinal,
                'tareas_completadas' => $tareasCompletadas,
                'tareas_pendientes' => count($tareasPendientes),
                'obra_continua_activa' => false
            ]
        );


        echo json_encode([
            'success' => true,
            'message' => 'Contrato cerrado y obra finalizada correctamente.',
            'id_contrato' => $idContrato,
            'importe_final' => $importeFinal,
            'obra_activa' => false
        ], JSON_UNESCAPED_UNICODE);


    } catch (Throwable $e) {

        if ($pdo->inTransaction()) {
            $pdo->rollBack();
        }

        throw $e;
    }
}


/*
|--------------------------------------------------------------------------
| EXTRAER CONTRATO
|--------------------------------------------------------------------------
*/

function extraerContratoDesdeCampo(
    array $contrato,
    string $campo
): array {

    $nombreArchivo =
        limpiarTexto(
            $contrato['nombre_archivo'] ?? '',
            255
        );


    $contenidoBase64 =
        trim(
            (string) (
                $contrato['contenido_base64'] ?? ''
            )
        );


    if (
        $nombreArchivo === '' ||
        $contenidoBase64 === ''
    ) {

        throw new InvalidArgumentException(
            "El archivo de {$campo} es inválido."
        );
    }


    $archivo =
        base64_decode(
            $contenidoBase64,
            true
        );


    if ($archivo === false) {

        throw new InvalidArgumentException(
            "El archivo de {$campo} es inválido."
        );
    }


    if (
        strlen($archivo)
        > MAX_CONTRATO_BYTES
    ) {

        throw new InvalidArgumentException(
            'El contrato no puede superar los 10 MB.'
        );
    }


    /*
    |--------------------------------------------------------------------------
    | EXTENSION PERMITIDA
    |--------------------------------------------------------------------------
    */

    $extension =
        strtolower(
            pathinfo(
                $nombreArchivo,
                PATHINFO_EXTENSION
            )
        );


    if (
        !in_array(
            $extension,
            [
                'pdf',
                'doc',
                'docx'
            ],
            true
        )
    ) {

        throw new InvalidArgumentException(
            'El contrato debe estar en formato PDF, DOC o DOCX.'
        );
    }


    return [

        'nombre_archivo' =>
            $nombreArchivo,

        'archivo' =>
            $archivo
    ];
}


/*
|--------------------------------------------------------------------------
| COMPLETAR TAREA
|--------------------------------------------------------------------------
*/

function responderCompletarTarea(
    PDO $pdo,
    array $body
): void {

    $idTarea =
        isset($body['id_tarea'])
            ? (int) $body['id_tarea']
            : 0;


    if ($idTarea <= 0) {

        throw new InvalidArgumentException(
            'Debés indicar una actividad válida.'
        );
    }


    $stmt =
        $pdo->prepare(
            'SELECT
                ct.id_tarea,
                ct.id_contrato,
                ct.descripcion,
                ct.estado,
                c.id_obra
             FROM contrato_tareas ct
             INNER JOIN contratos c
                 ON c.id_contrato = ct.id_contrato
             WHERE ct.id_tarea = ?
             LIMIT 1'
        );


    $stmt->execute([
        $idTarea
    ]);


    $tarea =
        $stmt->fetch(
            PDO::FETCH_ASSOC
        );


    if (!$tarea) {

        throw new RuntimeException(
            'La actividad indicada no existe.'
        );
    }


    if (
        strtolower(
            (string)
            $tarea['estado']
        ) === 'completada'
    ) {

        echo json_encode([

            'success' =>
                true,

            'message' =>
                'La actividad ya estaba completada.'

        ], JSON_UNESCAPED_UNICODE);

        return;
    }


    $stmt =
        $pdo->prepare(
            'UPDATE contrato_tareas
             SET
                estado = ?,
                fecha_completada = CURDATE()
             WHERE id_tarea = ?'
        );


    $stmt->execute([
        'Completada',
        $idTarea
    ]);


    registrarAuditoria(
        $pdo,
        'completar_tarea',
        'contrato_tareas',
        $idTarea,
        [

            'id_obra' =>
                (int)
                $tarea['id_obra'],

            'descripcion' =>
                $tarea['descripcion'],

            'estado_anterior' =>
                $tarea['estado'],

            'estado_nuevo' =>
                'Completada'
        ]
    );


    echo json_encode([

        'success' =>
            true,

        'message' =>
            'Actividad marcada como completada correctamente.',

        'id_tarea' =>
            $idTarea,

        'estado' =>
            'Completada',

        'fecha_completada' =>
            date('Y-m-d')

    ], JSON_UNESCAPED_UNICODE);
}


/*
|--------------------------------------------------------------------------
| GUARDAR / EDITAR OBRA
|--------------------------------------------------------------------------
*/

function responderGuardado(
    PDO $pdo,
    array $body
): void {

    $payload =
        validarPayload(
            $body
        );


    $contrato =
        extraerContrato(
            $body
        );


    $tareas =
        validarTareas(
            $body['tareas'] ?? []
        );


    $idObra =
        isset($body['id_obra']) &&
        $body['id_obra'] !== ''
            ? (int)
                $body['id_obra']
            : null;


    $pdo->beginTransaction();


    try {

        /*
        |--------------------------------------------------------------------------
        | EDITAR OBRA
        |--------------------------------------------------------------------------
        */

        if ($idObra !== null) {

            $stmt =
                $pdo->prepare(
                    'SELECT
                        id_obra,
                        activo
                     FROM obras
                     WHERE id_obra = ?
                     LIMIT 1'
                );


            $stmt->execute([
                $idObra
            ]);


            $obraExistente =
                $stmt->fetch(
                    PDO::FETCH_ASSOC
                );


            if (!$obraExistente) {

                throw new RuntimeException(
                    'La obra indicada no existe.'
                );
            }


            $stmt =
                $pdo->prepare(
                    'UPDATE obras
                     SET
                        numero_contrata = ?,
                        nombre = ?,
                        direccion = ?,
                        descripcion = ?,
                        fecha_inicio = ?,
                        fecha_fin = ?,
                        nombre_cliente = ?,
                        telefono_cliente = ?,
                        activo = ?
                     WHERE id_obra = ?'
                );


            $stmt->execute([

                $payload['numero_contrata'],

                $payload['nombre'],

                $payload['direccion'],

                $payload['descripcion'],

                $payload['fecha_inicio'],

                $payload['fecha_fin'],

                $payload['nombre_cliente'],

                $payload['telefono_cliente'],

                $payload['activo'],

                $idObra
            ]);


            /*
            |--------------------------------------------------------------------------
            | CONTRATO
            |--------------------------------------------------------------------------
            |
            | Al editar:
            |
            | - Si existe contrato activo, se actualiza.
            | - Si solo existen contratos cerrados, NO se crea uno nuevo.
            | - Para crear una nueva versión se debe usar
            |   "cerrar contrato -> nuevo contrato".
            |--------------------------------------------------------------------------
            */

            if ($contrato !== null) {

                $idContrato =
                    guardarContrato(
                        $pdo,
                        $idObra,
                        $contrato,
                        false
                    );

            } else {

                $idContrato =
                    obtenerIdContrato(
                        $pdo,
                        $idObra
                    );
            }


            /*
            |--------------------------------------------------------------------------
            | TAREAS
            |--------------------------------------------------------------------------
            */

            if (
                !empty($tareas)
            ) {

                if (
                    $idContrato === null
                ) {

                    throw new InvalidArgumentException(
                        'Para registrar actividades debés tener un contrato activo.'
                    );
                }


                guardarTareas(
                    $pdo,
                    $idContrato,
                    $tareas,
                    true
                );
            }


            $pdo->commit();


            $obraRespuesta =
                obtenerObra(
                    $pdo,
                    $idObra
                );


            registrarAuditoria(
                $pdo,
                'editar',
                'obras',
                $idObra,
                [

                    'nombre' =>
                        $obraRespuesta['nombre'],

                    'contrato_actualizado' =>
                        $contrato !== null,

                    'tareas_actualizadas' =>
                        count($tareas)

                ]
            );


            echo json_encode([

                'success' =>
                    true,

                'message' =>
                    'Obra actualizada correctamente.',

                'obra' =>
                    $obraRespuesta

            ], JSON_UNESCAPED_UNICODE);


            return;
        }


        /*
        |--------------------------------------------------------------------------
        | CREAR OBRA
        |--------------------------------------------------------------------------
        */

        $stmt =
            $pdo->prepare(
                'INSERT INTO obras (
                    numero_contrata,
                    nombre,
                    direccion,
                    descripcion,
                    fecha_inicio,
                    fecha_fin,
                    nombre_cliente,
                    telefono_cliente,
                    activo
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)'
            );


        $stmt->execute([

            $payload['numero_contrata'],

            $payload['nombre'],

            $payload['direccion'],

            $payload['descripcion'],

            $payload['fecha_inicio'],

            $payload['fecha_fin'],

            $payload['nombre_cliente'],

            $payload['telefono_cliente'],

            $payload['activo']
        ]);


        $idObra =
            (int)
            $pdo->lastInsertId();


        if ($contrato !== null) {

            $idContrato =
                guardarContrato(
                    $pdo,
                    $idObra,
                    $contrato,
                    true
                );

        } else {

            $idContrato = null;
        }


        if (
            !empty($tareas)
        ) {

            if ($idContrato === null) {

                throw new InvalidArgumentException(
                    'Para registrar actividades debés cargar primero el contrato.'
                );
            }


            guardarTareas(
                $pdo,
                $idContrato,
                $tareas,
                false
            );
        }


        $pdo->commit();


        $obraRespuesta =
            obtenerObra(
                $pdo,
                $idObra
            );


        registrarAuditoria(
            $pdo,
            'crear',
            'obras',
            $idObra,
            [

                'nombre' =>
                    $obraRespuesta['nombre'],

                'numero_contrata' =>
                    $obraRespuesta['numero_contrata'],

                'tareas_creadas' =>
                    count($tareas)

            ]
        );


        http_response_code(201);


        echo json_encode([

            'success' =>
                true,

            'message' =>
                'Obra guardada correctamente.',

            'obra' =>
                $obraRespuesta

        ], JSON_UNESCAPED_UNICODE);


    } catch (Throwable $e) {

        if ($pdo->inTransaction()) {
            $pdo->rollBack();
        }

        throw $e;
    }
}


/*
|--------------------------------------------------------------------------
| ELIMINAR OBRA
|--------------------------------------------------------------------------
*/

function responderEliminacion(
    PDO $pdo,
    array $body
): void {

    $idObra =
        isset($body['id_obra'])
            ? (int) $body['id_obra']
            : 0;


    if ($idObra <= 0) {

        throw new InvalidArgumentException(
            'Debés indicar una obra válida.'
        );
    }


    $stmt =
        $pdo->prepare(
            'SELECT
                id_obra,
                nombre
             FROM obras
             WHERE id_obra = ?
             LIMIT 1'
        );


    $stmt->execute([
        $idObra
    ]);


    $obra =
        $stmt->fetch(
            PDO::FETCH_ASSOC
        );


    if (!$obra) {

        throw new RuntimeException(
            'La obra indicada no existe.'
        );
    }


    $pdo->beginTransaction();


    try {

        /*
        |--------------------------------------------------------------------------
        | TAREAS
        |--------------------------------------------------------------------------
        */

        $stmt =
            $pdo->prepare(
                'DELETE ct
                 FROM contrato_tareas ct
                 INNER JOIN contratos c
                     ON c.id_contrato = ct.id_contrato
                 WHERE c.id_obra = ?'
            );

        $stmt->execute([
            $idObra
        ]);


        /*
        |--------------------------------------------------------------------------
        | CONTRATOS
        |--------------------------------------------------------------------------
        */

        $pdo
            ->prepare(
                'DELETE FROM contratos
                 WHERE id_obra = ?'
            )
            ->execute([
                $idObra
            ]);


        /*
        |--------------------------------------------------------------------------
        | RECURSOS
        |--------------------------------------------------------------------------
        */

        $pdo
            ->prepare(
                'DELETE FROM recursos
                 WHERE id_obra = ?'
            )
            ->execute([
                $idObra
            ]);


        /*
        |--------------------------------------------------------------------------
        | REGISTROS
        |--------------------------------------------------------------------------
        */

        $pdo
            ->prepare(
                'DELETE FROM registros
                 WHERE id_obra = ?'
            )
            ->execute([
                $idObra
            ]);


        /*
        |--------------------------------------------------------------------------
        | MAQUINARIA
        |--------------------------------------------------------------------------
        */

        $pdo
            ->prepare(
                'DELETE FROM obra_maquinaria
                 WHERE id_obra = ?'
            )
            ->execute([
                $idObra
            ]);


        /*
        |--------------------------------------------------------------------------
        | OBRA
        |--------------------------------------------------------------------------
        */

        $pdo
            ->prepare(
                'DELETE FROM obras
                 WHERE id_obra = ?'
            )
            ->execute([
                $idObra
            ]);


        $pdo->commit();


        registrarAuditoria(
            $pdo,
            'eliminar',
            'obras',
            $idObra,
            [
                'nombre' =>
                    $obra['nombre']
            ]
        );


        echo json_encode([

            'success' =>
                true,

            'message' =>
                'Obra eliminada correctamente.'

        ], JSON_UNESCAPED_UNICODE);


    } catch (Throwable $e) {

        if ($pdo->inTransaction()) {
            $pdo->rollBack();
        }

        throw $e;
    }
}


/*
|--------------------------------------------------------------------------
| CSRF
|--------------------------------------------------------------------------
*/

function validarCsrf(): void
{

    $csrfRecibido =
        $_SERVER['HTTP_X_CSRF_TOKEN']
        ?? '';

    $csrfGuardado =
        $_SESSION['csrf_token']
        ?? '';


    if (
        $csrfGuardado === '' ||
        !hash_equals(
            $csrfGuardado,
            $csrfRecibido
        )
    ) {

        http_response_code(403);

        echo json_encode([

            'success' =>
                false,

            'error' =>
                'Token de seguridad inválido. Recargá la página.'

        ], JSON_UNESCAPED_UNICODE);

        exit;
    }
}


/*
|--------------------------------------------------------------------------
| LÍMITE POST
|--------------------------------------------------------------------------
*/

function verificarLimitePost(): void
{

    if (
        $_SERVER['REQUEST_METHOD']
        !== 'POST'
    ) {
        return;
    }


    $contentLength =
        (int) (
            $_SERVER['CONTENT_LENGTH']
            ?? 0
        );


    if ($contentLength <= 0) {
        return;
    }


    $postMax =
        ini_get('post_max_size');


    $postMaxBytes =
        convertirBytes(
            $postMax
        );


    if (
        $postMaxBytes > 0 &&
        $contentLength > $postMaxBytes
    ) {

        throw new InvalidArgumentException(
            "La solicitud supera el límite post_max_size del servidor ({$postMax}). Configurá PHP para permitir al menos 12M."
        );
    }


    /*
    |--------------------------------------------------------------------------
    | PHP puede vaciar $_POST / $_FILES cuando se supera post_max_size.
    |--------------------------------------------------------------------------
    */

    if (
        empty($_POST) &&
        empty($_FILES) &&
        $contentLength > 0
    ) {

        $raw =
            file_get_contents(
                'php://input'
            );


        if (
            $raw === false ||
            strlen($raw) === 0
        ) {

            throw new InvalidArgumentException(
                "La solicitud no pudo ser procesada. Verificá post_max_size y upload_max_filesize en PHP."
            );
        }
    }
}


/*
|--------------------------------------------------------------------------
| LEER JSON
|--------------------------------------------------------------------------
*/

function leerJson(): array
{

    $raw =
        file_get_contents(
            'php://input'
        );


    if (
        $raw === false ||
        trim($raw) === ''
    ) {

        throw new InvalidArgumentException(
            'Cuerpo de solicitud vacío.'
        );
    }


    $body =
        json_decode(
            $raw,
            true
        );


    if (
        !is_array($body)
    ) {

        throw new InvalidArgumentException(
            'Cuerpo de solicitud inválido.'
        );
    }


    return $body;
}


/*
|--------------------------------------------------------------------------
| VALIDAR PAYLOAD
|--------------------------------------------------------------------------
*/

function validarPayload(
    array $body
): array {

    $numeroContrata =
        limpiarTexto(
            $body['numero_contrata'] ?? '',
            50
        );


    $nombre =
        limpiarTexto(
            $body['nombre'] ?? '',
            150
        );


    $direccion =
        limpiarTexto(
            $body['direccion'] ?? '',
            200,
            false
        );


    $descripcion =
        limpiarTexto(
            $body['descripcion'] ?? '',
            65535,
            false
        );


    $fechaInicio =
        normalizarFecha(
            $body['fecha_inicio'] ?? null
        );


    $fechaFin =
        normalizarFecha(
            $body['fecha_fin'] ?? null
        );


    $nombreCliente =
        limpiarTexto(
            $body['nombre_cliente'] ?? '',
            150
        );


    $telefonoCliente =
        limpiarTexto(
            $body['telefono_cliente'] ?? '',
            30,
            false
        );


    $activo =
        normalizarBooleano(
            $body['activo'] ?? 1,
            true
        );


    if (
        $numeroContrata === '' ||
        $nombre === '' ||
        $nombreCliente === ''
    ) {

        throw new InvalidArgumentException(
            'Número de contrata, nombre de la obra y cliente son obligatorios.'
        );
    }


    if (
        $fechaInicio !== null &&
        $fechaFin !== null &&
        $fechaFin < $fechaInicio
    ) {

        throw new InvalidArgumentException(
            'La fecha de fin no puede ser menor a la de inicio.'
        );
    }


    return [

        'numero_contrata' =>
            $numeroContrata,

        'nombre' =>
            $nombre,

        'direccion' =>
            $direccion,

        'descripcion' =>
            $descripcion,

        'fecha_inicio' =>
            $fechaInicio,

        'fecha_fin' =>
            $fechaFin,

        'nombre_cliente' =>
            $nombreCliente,

        'telefono_cliente' =>
            $telefonoCliente,

        'activo' =>
            $activo
    ];
}


/*
|--------------------------------------------------------------------------
| BOOLEANO
|--------------------------------------------------------------------------
*/

function normalizarBooleano(
    mixed $value,
    ?bool $default
): ?int {

    if ($value === null || $value === '') {

        return $default === null
            ? null
            : ($default ? 1 : 0);
    }


    if (is_bool($value)) {
        return $value ? 1 : 0;
    }


    $valueString =
        strtolower(
            trim(
                (string) $value
            )
        );


    if (
        in_array(
            $valueString,
            [
                '1',
                'true',
                'on',
                'yes',
                'si',
                'sí'
            ],
            true
        )
    ) {
        return 1;
    }


    if (
        in_array(
            $valueString,
            [
                '0',
                'false',
                'off',
                'no'
            ],
            true
        )
    ) {
        return 0;
    }


    return null;
}


/*
|--------------------------------------------------------------------------
| LIMPIAR TEXTO
|--------------------------------------------------------------------------
*/

function limpiarTexto(
    mixed $value,
    int $maxLength,
    bool $required = true
): ?string {

    $text =
        trim(
            (string) $value
        );


    if ($text === '') {

        return $required
            ? ''
            : null;
    }


    $length =
        function_exists('mb_strlen')
            ? mb_strlen($text)
            : strlen($text);


    if ($length > $maxLength) {

        throw new InvalidArgumentException(
            'Uno de los campos supera la longitud permitida.'
        );
    }


    return $text;
}


/*
|--------------------------------------------------------------------------
| FECHA
|--------------------------------------------------------------------------
*/

function normalizarFecha(
    mixed $value
): ?string {

    $text =
        trim(
            (string) (
                $value ?? ''
            )
        );


    if ($text === '') {
        return null;
    }


    $date =
        DateTime::createFromFormat(
            'Y-m-d',
            $text
        );


    $errors =
        DateTime::getLastErrors();


    if (
        !$date ||
        (
            is_array($errors) &&
            (
                ($errors['warning_count'] ?? 0) > 0 ||
                ($errors['error_count'] ?? 0) > 0
            )
        )
    ) {

        throw new InvalidArgumentException(
            'Formato de fecha inválido.'
        );
    }


    return $date->format('Y-m-d');
}


/*
|--------------------------------------------------------------------------
| OBTENER OBRA
|--------------------------------------------------------------------------
*/

function obtenerObra(
    PDO $pdo,
    int $idObra
): array {

    /*
    |--------------------------------------------------------------------------
    | IMPORTANTE:
    |
    | Se obtiene el último contrato sin importar si está Activo o Cerrado.
    | Esto permite que una obra finalizada siga mostrando su contrato.
    |--------------------------------------------------------------------------
    */

    $stmt =
        $pdo->prepare(
            'SELECT
                o.id_obra,
                o.numero_contrata,
                o.nombre,
                o.direccion,
                o.descripcion,
                o.fecha_inicio,
                o.fecha_fin,
                o.nombre_cliente,
                o.telefono_cliente,
                o.activo,

                c.id_contrato,

                c.nombre_archivo
                    AS contrato_nombre_archivo,

                c.estado
                    AS contrato_estado,

                c.fecha_cierre
                    AS contrato_fecha_cierre,

                c.importe_final
                    AS contrato_importe_final

             FROM obras o

             LEFT JOIN contratos c
                 ON c.id_contrato = (
                     SELECT MAX(c2.id_contrato)
                     FROM contratos c2
                     WHERE c2.id_obra = o.id_obra
                 )

             WHERE o.id_obra = ?

             LIMIT 1'
        );


    $stmt->execute([
        $idObra
    ]);


    $obra =
        $stmt->fetch(
            PDO::FETCH_ASSOC
        );


    if (!$obra) {

        throw new RuntimeException(
            'La obra indicada no existe.'
        );
    }


    return $obra;
}


/*
|--------------------------------------------------------------------------
| DESCARGAR CONTRATO
|--------------------------------------------------------------------------
*/

function responderDescargaContrato(
    PDO $pdo
): void {

    $idObra =
        isset($_GET['id_obra'])
            ? (int) $_GET['id_obra']
            : 0;


    if ($idObra <= 0) {

        throw new InvalidArgumentException(
            'Debés indicar una obra válida.'
        );
    }


    $stmt =
        $pdo->prepare(
            'SELECT
                nombre_archivo,
                archivo
             FROM contratos
             WHERE id_obra = ?
             ORDER BY id_contrato DESC
             LIMIT 1'
        );


    $stmt->execute([
        $idObra
    ]);


    $contrato =
        $stmt->fetch(
            PDO::FETCH_ASSOC
        );


    if (!$contrato) {

        throw new RuntimeException(
            'La obra no tiene contrato cargado.'
        );
    }


    $nombreArchivo =
        $contrato['nombre_archivo']
        ?: "contrato-{$idObra}";


    $mime =
        detectarMimeContrato(
            $nombreArchivo
        );


    /*
    |--------------------------------------------------------------------------
    | LIMPIAR HEADERS JSON
    |--------------------------------------------------------------------------
    */

    header_remove('Content-Type');


    header(
        'Content-Type: ' . $mime
    );


    header(
        'Content-Length: ' .
        strlen(
            $contrato['archivo']
        )
    );


    /*
    |--------------------------------------------------------------------------
    | NOMBRE DE ARCHIVO UTF-8
    |--------------------------------------------------------------------------
    */

    $nombreFallback =
        preg_replace(
            '/[^A-Za-z0-9._-]/',
            '_',
            $nombreArchivo
        );


    if (
        !$nombreFallback
    ) {
        $nombreFallback =
            "contrato-{$idObra}";
    }


    header(
        'Content-Disposition: attachment; filename="' .
        $nombreFallback .
        '"; filename*=UTF-8\'\'' .
        rawurlencode(
            $nombreArchivo
        )
    );


    echo $contrato['archivo'];
}


/*
|--------------------------------------------------------------------------
| EXTRAER CONTRATO NORMAL
|--------------------------------------------------------------------------
*/

function extraerContrato(
    array $body
): ?array {

    if (
        !isset($body['contrato']) ||
        !is_array($body['contrato'])
    ) {
        return null;
    }


    return extraerContratoDesdeCampo(
        $body['contrato'],
        'contrato'
    );
}


/*
|--------------------------------------------------------------------------
| GUARDAR CONTRATO
|--------------------------------------------------------------------------
*/

function guardarContrato(
    PDO $pdo,
    int $idObra,
    array $contrato,
    bool $permitirCrearSiNoExiste = true
): int {

    /*
    |--------------------------------------------------------------------------
    | BUSCAR CONTRATO ACTIVO
    |--------------------------------------------------------------------------
    */

    $stmt =
        $pdo->prepare(
            'SELECT id_contrato
             FROM contratos
             WHERE id_obra = ?
               AND estado = ?
             ORDER BY id_contrato DESC
             LIMIT 1'
        );


    $stmt->execute([
        $idObra,
        'Activo'
    ]);


    $contratoExistente =
        $stmt->fetchColumn();


    /*
    |--------------------------------------------------------------------------
    | ACTUALIZAR CONTRATO ACTIVO
    |--------------------------------------------------------------------------
    */

    if (
        $contratoExistente !== false
    ) {

        $idContrato =
            (int)
            $contratoExistente;


        $stmt =
            $pdo->prepare(
                'UPDATE contratos
                 SET
                    archivo = ?,
                    nombre_archivo = ?,
                    fecha_subida = CURDATE()
                 WHERE id_contrato = ?'
            );


        $stmt->execute([

            $contrato['archivo'],

            $contrato['nombre_archivo'],

            $idContrato
        ]);


        return $idContrato;
    }


    /*
    |--------------------------------------------------------------------------
    | EDITANDO UNA OBRA FINALIZADA
    |--------------------------------------------------------------------------
    |
    | No creamos accidentalmente un nuevo contrato.
    | El nuevo contrato debe pasar por el flujo de cierre.
    |--------------------------------------------------------------------------
    */

    if (!$permitirCrearSiNoExiste) {

        throw new InvalidArgumentException(
            'La obra no tiene un contrato activo. Para crear un nuevo contrato utilizá la opción "Nuevo contrato".'
        );
    }


    /*
    |--------------------------------------------------------------------------
    | CREAR CONTRATO
    |--------------------------------------------------------------------------
    */

    $stmt =
        $pdo->prepare(
            'INSERT INTO contratos (
                id_obra,
                archivo,
                nombre_archivo,
                fecha_subida,
                estado
            )
            VALUES (?, ?, ?, CURDATE(), ?)'
        );


    $stmt->execute([

        $idObra,

        $contrato['archivo'],

        $contrato['nombre_archivo'],

        'Activo'
    ]);


    return (int)
        $pdo->lastInsertId();
}


/*
|--------------------------------------------------------------------------
| OBTENER CONTRATO ACTIVO
|--------------------------------------------------------------------------
*/

function obtenerIdContrato(
    PDO $pdo,
    int $idObra
): ?int {

    $stmt =
        $pdo->prepare(
            'SELECT id_contrato
             FROM contratos
             WHERE id_obra = ?
               AND estado = ?
             ORDER BY id_contrato DESC
             LIMIT 1'
        );


    $stmt->execute([
        $idObra,
        'Activo'
    ]);


    $idContrato =
        $stmt->fetchColumn();


    return $idContrato !== false
        ? (int) $idContrato
        : null;
}


/*
|--------------------------------------------------------------------------
| VALIDAR TAREAS
|--------------------------------------------------------------------------
*/

function validarTareas(
    mixed $tareas
): array {

    if (
        $tareas === null ||
        $tareas === ''
    ) {
        return [];
    }


    if (!is_array($tareas)) {

        throw new InvalidArgumentException(
            'Las actividades del contrato son inválidas.'
        );
    }


    $resultado = [];


    foreach (
        $tareas
        as $tarea
    ) {

        if (!is_array($tarea)) {

            throw new InvalidArgumentException(
                'Una de las actividades es inválida.'
            );
        }


        /*
        |--------------------------------------------------------------------------
        | ID
        |--------------------------------------------------------------------------
        */

        $idTarea = null;


        if (
            isset($tarea['id_tarea']) &&
            $tarea['id_tarea'] !== ''
        ) {

            $idTarea =
                (int)
                $tarea['id_tarea'];


            if ($idTarea <= 0) {
                $idTarea = null;
            }
        }


        /*
        |--------------------------------------------------------------------------
        | DESCRIPCIÓN
        |--------------------------------------------------------------------------
        */

        $descripcion =
            limpiarTexto(
                $tarea['descripcion'] ?? '',
                255
            );


        if ($descripcion === '') {

            throw new InvalidArgumentException(
                'La descripción de la actividad es obligatoria.'
            );
        }


        /*
        |--------------------------------------------------------------------------
        | IMPORTE
        |--------------------------------------------------------------------------
        */

        $importe =
            $tarea['importe'] ?? 0;


        if (
            !is_numeric($importe) ||
            (float) $importe < 0
        ) {

            throw new InvalidArgumentException(
                'El importe de una actividad es inválido.'
            );
        }


        /*
        |--------------------------------------------------------------------------
        | ESTADO
        |--------------------------------------------------------------------------
        */

        $estado =
            trim(
                (string) (
                    $tarea['estado']
                    ?? 'Pendiente'
                )
            );


        if (
            !in_array(
                $estado,
                [
                    'Pendiente',
                    'Completada'
                ],
                true
            )
        ) {

            throw new InvalidArgumentException(
                'El estado de una actividad es inválido.'
            );
        }


        /*
        |--------------------------------------------------------------------------
        | FECHA COMPLETADA
        |--------------------------------------------------------------------------
        */

        $fechaCompletada = null;


        if (
            $estado === 'Completada'
        ) {

            if (
                !empty(
                    $tarea['fecha_completada']
                )
            ) {

                $fechaCompletada =
                    normalizarFecha(
                        $tarea['fecha_completada']
                    );

            } else {

                /*
                |--------------------------------------------------------------------------
                | Si se marca como completada pero no llega fecha,
                | el servidor registra la fecha actual.
                |--------------------------------------------------------------------------
                */

                $fechaCompletada =
                    date('Y-m-d');
            }
        }


        /*
        |--------------------------------------------------------------------------
        | ID ORIGEN
        |--------------------------------------------------------------------------
        */

        $idTareaOrigen = null;


        if (
            isset(
                $tarea['id_tarea_origen']
            ) &&
            $tarea['id_tarea_origen'] !== ''
        ) {

            $idTareaOrigen =
                (int)
                $tarea['id_tarea_origen'];


            if ($idTareaOrigen <= 0) {
                $idTareaOrigen = null;
            }
        }


        /*
        |--------------------------------------------------------------------------
        | RESULTADO
        |--------------------------------------------------------------------------
        */

        $resultado[] = [

            'id_tarea' =>
                $idTarea,

            'id_tarea_origen' =>
                $idTareaOrigen,

            'descripcion' =>
                $descripcion,

            'importe' =>
                number_format(
                    (float) $importe,
                    2,
                    '.',
                    ''
                ),

            'estado' =>
                $estado,

            'fecha_completada' =>
                $fechaCompletada
        ];
    }


    return $resultado;
}

/*
|--------------------------------------------------------------------------
| GUARDAR TAREAS (CORREGIDA)
|--------------------------------------------------------------------------
|
| Al editar un contrato:
|
| - Las tareas pendientes que siguen presentes se actualizan.
| - Las tareas nuevas se insertan.
| - Las tareas pendientes que fueron eliminadas del formulario
|   se eliminan de la BD.
| - Las tareas completadas NUNCA se eliminan automáticamente.
| - Una tarea completada NO puede volver a pendiente.
|--------------------------------------------------------------------------
*/

function guardarTareas(
    PDO $pdo,
    int $idContrato,
    array $tareas,
    bool $sincronizarPendientes = false
): void {

    /*
    |--------------------------------------------------------------------------
    | IDS ENVIADOS
    |--------------------------------------------------------------------------
    */

    $idsEnviados = [];

    foreach ($tareas as $tarea) {
        if (
            isset($tarea['id_tarea']) &&
            (int) $tarea['id_tarea'] > 0
        ) {
            $idsEnviados[] = (int) $tarea['id_tarea'];
        }
    }

    /*
    |--------------------------------------------------------------------------
    | ELIMINAR TAREAS PENDIENTES OMITIDAS
    |--------------------------------------------------------------------------
    |
    | Solo se hace durante una edición normal.
    | Las completadas se conservan como historial.
    |--------------------------------------------------------------------------
    */

    if ($sincronizarPendientes) {

        if (!empty($idsEnviados)) {

            $placeholders = implode(',', array_fill(0, count($idsEnviados), '?'));

            /*
            |--------------------------------------------------------------------------
            | PARÁMETROS CORREGIDOS:
            | 1º parametro: id_contrato (?)
            | 2º parametro: estado (?)
            | 3º en adelante: lista de IDs en NOT IN (?, ?, ...)
            |--------------------------------------------------------------------------
            */
            $params = array_merge([$idContrato, 'Pendiente'], $idsEnviados);

            $sql = 'DELETE FROM contrato_tareas
                    WHERE id_contrato = ?
                      AND estado = ?
                      AND id_tarea NOT IN (' . $placeholders . ')';

            $stmt = $pdo->prepare($sql);
            $stmt->execute($params);

        } else {

            /*
            |--------------------------------------------------------------------------
            | No llegó ninguna tarea existente.
            | Se eliminan únicamente las pendientes del contrato.
            |--------------------------------------------------------------------------
            */

            $stmt = $pdo->prepare(
                'DELETE FROM contrato_tareas
                 WHERE id_contrato = ?
                   AND estado = ?'
            );

            $stmt->execute([
                $idContrato,
                'Pendiente'
            ]);
        }
    }

    /*
    |--------------------------------------------------------------------------
    | GUARDAR / ACTUALIZAR TAREAS RECIBIDAS
    |--------------------------------------------------------------------------
    */

    foreach ($tareas as $tarea) {

        $idTarea = isset($tarea['id_tarea']) ? (int) $tarea['id_tarea'] : 0;
        $descripcion = trim((string) ($tarea['descripcion'] ?? ''));
        $importe = isset($tarea['importe']) ? (float) $tarea['importe'] : 0;
        $estado = trim((string) ($tarea['estado'] ?? 'Pendiente'));
        $fechaCompletada = $tarea['fecha_completada'] ?? null;

        if ($descripcion === '') {
            continue;
        }

        /*
        |--------------------------------------------------------------------------
        | TAREA EXISTENTE
        |--------------------------------------------------------------------------
        */

        if ($idTarea > 0) {

            $stmt = $pdo->prepare(
                'SELECT
                    id_tarea,
                    estado,
                    fecha_completada
                 FROM contrato_tareas
                 WHERE id_tarea = ?
                   AND id_contrato = ?
                 LIMIT 1'
            );

            $stmt->execute([
                $idTarea,
                $idContrato
            ]);

            $tareaExistente = $stmt->fetch(PDO::FETCH_ASSOC);

            if ($tareaExistente) {

                /*
                |--------------------------------------------------------------------------
                | UNA TAREA COMPLETADA NO VUELVE A PENDIENTE
                |--------------------------------------------------------------------------
                */

                if (strtolower((string) $tareaExistente['estado']) === 'completada') {
                    $estado = 'Completada';
                    $fechaCompletada = $tareaExistente['fecha_completada'] ?: date('Y-m-d');
                }

                /*
                |--------------------------------------------------------------------------
                | Normalizar fechas según estado
                |--------------------------------------------------------------------------
                */

                if ($estado === 'Pendiente') {
                    $fechaCompletada = null;
                }

                if ($estado === 'Completada' && empty($fechaCompletada)) {
                    $fechaCompletada = date('Y-m-d');
                }

                $stmt = $pdo->prepare(
                    'UPDATE contrato_tareas
                     SET
                        descripcion = ?,
                        importe = ?,
                        estado = ?,
                        fecha_completada = ?
                     WHERE id_tarea = ?
                       AND id_contrato = ?'
                );

                $stmt->execute([
                    $descripcion,
                    $importe,
                    $estado,
                    $fechaCompletada,
                    $idTarea,
                    $idContrato
                ]);

                continue;
            }
        }

        /*
        |--------------------------------------------------------------------------
        | TAREA NUEVA
        |--------------------------------------------------------------------------
        */

        $idTareaOrigen = (isset($tarea['id_tarea_origen']) && $tarea['id_tarea_origen'] !== null)
            ? (int) $tarea['id_tarea_origen']
            : null;

        if ($estado === 'Pendiente') {
            $fechaCompletada = null;
        } elseif ($estado === 'Completada' && empty($fechaCompletada)) {
            $fechaCompletada = date('Y-m-d');
        }

        $stmt = $pdo->prepare(
            'INSERT INTO contrato_tareas (
                id_contrato,
                id_tarea_origen,
                descripcion,
                importe,
                estado,
                fecha_completada
            )
            VALUES (?, ?, ?, ?, ?, ?)'
        );

        $stmt->execute([
            $idContrato,
            $idTareaOrigen,
            $descripcion,
            $importe,
            $estado,
            $fechaCompletada
        ]);
    }
}

/*
|--------------------------------------------------------------------------
| MIME
|--------------------------------------------------------------------------
*/

function detectarMimeContrato(
    string $nombreArchivo
): string {

    $extension =
        strtolower(
            pathinfo(
                $nombreArchivo,
                PATHINFO_EXTENSION
            )
        );


    return match ($extension) {

        'pdf' =>
            'application/pdf',

        'doc' =>
            'application/msword',

        'docx' =>
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document',

        default =>
            'application/octet-stream'
    };
}


/*
|--------------------------------------------------------------------------
| ERROR DE UPLOAD
|--------------------------------------------------------------------------
*/

function obtenerMensajeErrorUpload(
    int $codigo
): string {

    return match ($codigo) {

        UPLOAD_ERR_INI_SIZE =>
            'El archivo supera upload_max_filesize configurado en PHP.',

        UPLOAD_ERR_FORM_SIZE =>
            'El archivo supera el tamaño máximo permitido por el formulario.',

        UPLOAD_ERR_PARTIAL =>
            'El archivo se subió parcialmente.',

        UPLOAD_ERR_NO_FILE =>
            'No se recibió ningún archivo.',

        UPLOAD_ERR_NO_TMP_DIR =>
            'Falta la carpeta temporal del servidor.',

        UPLOAD_ERR_CANT_WRITE =>
            'No se pudo guardar temporalmente el archivo.',

        UPLOAD_ERR_EXTENSION =>
            'Una extensión de PHP detuvo la carga del archivo.',

        default =>
            'No se pudo cargar el archivo.'
    };
}


/*
|--------------------------------------------------------------------------
| CONVERTIR TAMAÑO PHP A BYTES
|--------------------------------------------------------------------------
*/

function convertirBytes(
    string $valor
): int {

    $valor =
        trim(
            $valor
        );


    if ($valor === '') {
        return 0;
    }


    $ultimo =
        strtolower(
            substr(
                $valor,
                -1
            )
        );


    $numero =
        (float)
        $valor;


    return match ($ultimo) {

        'g' =>
            (int) (
                $numero *
                1024 *
                1024 *
                1024
            ),

        'm' =>
            (int) (
                $numero *
                1024 *
                1024
            ),

        'k' =>
            (int) (
                $numero *
                1024
            ),

        default =>
            (int) $numero
    };
}