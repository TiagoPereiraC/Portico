<?php

function registrarAuditoria(
    PDO $pdo,
    string $accion,
    string $entidad,
    ?int $entidadId = null,
    array $detalle = [],
    ?array $contextoUsuario = null
): void {
    try {
        $usuarioActual = $contextoUsuario ?? [
            'id_usuario' => isset($_SESSION['user_id']) ? (int) $_SESSION['user_id'] : null,
            'usuario' => isset($_SESSION['usuario']) ? (string) $_SESSION['usuario'] : null,
            'rol' => isset($_SESSION['rol']) ? (string) $_SESSION['rol'] : null,
        ];

        $ip = filter_var($_SERVER['REMOTE_ADDR'] ?? null, FILTER_VALIDATE_IP) ?: null;
        $detalleJson = $detalle === [] ? null : json_encode($detalle, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);

        if ($detalleJson === false) {
            $detalleJson = null;
        }

        $stmt = $pdo->prepare(
            'INSERT INTO auditoria_logs (id_usuario, usuario, rol, accion, entidad, entidad_id, detalle_json, ip_address, created_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, NOW())'
        );

        $stmt->execute([
            $usuarioActual['id_usuario'] ?? null,
            $usuarioActual['usuario'] ?? null,
            $usuarioActual['rol'] ?? null,
            $accion,
            $entidad,
            $entidadId,
            $detalleJson,
            $ip,
        ]);
    } catch (Throwable $e) {
        error_log('Audit log error: ' . $e->getMessage());
    }
}