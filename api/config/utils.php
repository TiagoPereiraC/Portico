<?php

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

function verificarLimitePost(): void
{
    if ($_SERVER['REQUEST_METHOD'] === 'POST' && empty($_POST) && empty($_FILES)) {
        $contentLength = (int) ($_SERVER['CONTENT_LENGTH'] ?? 0);
        if ($contentLength > 0) {
            $postMax = ini_get('post_max_size') ?: '8M';
            throw new InvalidArgumentException("El tamaño del archivo o solicitud enviada supera el límite configurado en el servidor (post_max_size: {$postMax}).");
        }
    }
}

function leerJson(): array
{
    verificarLimitePost();
    $rawInput = file_get_contents('php://input');
    $body = json_decode($rawInput, true);
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

function limpiarTextoRequerido(mixed $value, int $maxLength): string
{
    $text = trim((string) $value);
    if ($text === '') {
        throw new InvalidArgumentException('Uno de los campos obligatorios está vacío.');
    }

    $length = function_exists('mb_strlen') ? mb_strlen($text) : strlen($text);
    if ($length > $maxLength) {
        throw new InvalidArgumentException('Uno de los campos supera la longitud permitida.');
    }

    return $text;
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
