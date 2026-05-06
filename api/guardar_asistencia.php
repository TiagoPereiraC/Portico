<?php
require_once __DIR__ . "/config/db.php";
require_once __DIR__ . "/config/session.php";

iniciarSesion();

header('Content-Type: application/json');

if ($_SERVER["REQUEST_METHOD"] === "POST") {

    try {

        $pdo = conectar();
        $pdo->beginTransaction();

        $id_obra = $_POST['id_obra'] ?? null;
        $fecha = $_POST['fecha'] ?? null;
        $id_usuario = $_SESSION['id_usuario'] ?? 1;

        if (!$id_obra || !$fecha) {
            throw new Exception("Datos incompletos");
        }

        // ===== ASISTENCIA =====
        if (!empty($_POST['obreros'])) {

            $stmt = $pdo->prepare("
                INSERT INTO registros 
                (fecha, hora_entrada, hora_salida, horas_trabajadas, id_obrero, id_obra, id_usuario)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            ");

            foreach ($_POST['obreros'] as $id_obrero) {

                $entrada = $_POST['hora_entrada'][$id_obrero];
                $salida = $_POST['hora_salida'][$id_obrero];

                $horas = (strtotime($salida) - strtotime($entrada)) / 3600;

                $stmt->execute([
                    $fecha,
                    $entrada,
                    $salida,
                    $horas,
                    $id_obrero,
                    $id_obra,
                    $id_usuario
                ]);
            }
        }

        // ===== MATERIALES =====
        if (!empty($_POST['material_nombre'])) {

            for ($i = 0; $i < count($_POST['material_nombre']); $i++) {

                $stmt = $pdo->prepare("
                    INSERT INTO recursos (id_obra, fecha, nombre, cantidad, precio_unitario, es_material)
                    VALUES (?, ?, ?, ?, ?, 1)
                ");

                $stmt->execute([
                    $id_obra,
                    $fecha,
                    $_POST['material_nombre'][$i],
                    $_POST['material_cantidad'][$i],
                    $_POST['material_costo'][$i]
                ]);
            }
        }

        // ===== HERRAMIENTAS =====
        if (!empty($_POST['herramienta_nombre'])) {

            for ($i = 0; $i < count($_POST['herramienta_nombre']); $i++) {

                $stmt = $pdo->prepare("
                    INSERT INTO recursos (id_obra, fecha, nombre, cantidad, es_material)
                    VALUES (?, ?, ?, ?, 0)
                ");

                $stmt->execute([
                    $id_obra,
                    $fecha,
                    $_POST['herramienta_nombre'][$i],
                    $_POST['herramienta_cantidad'][$i]
                ]);
            }
        }

        $pdo->commit();

        echo json_encode([
            "success" => true,
            "message" => "Asistencia guardada correctamente"
        ]);

    } catch (Exception $e) {

        if ($pdo->inTransaction()) {
            $pdo->rollBack();
        }

        http_response_code(500);
        echo json_encode([
            "success" => false,
            "error" => $e->getMessage()
        ]);
    }
}
?>