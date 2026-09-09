<?php

function conectar(): PDO
{
    static $pdo = null;

    if ($pdo !== null) {
        return $pdo;
    }

    $envPath = __DIR__ . '/../../.env';
    if (file_exists($envPath)) {
        foreach (file($envPath, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) as $line) {
            $line = trim($line);
            if ($line === '' || str_starts_with($line, '#')) {
                continue;
            }
            $pos = strpos($line, '=');
            if ($pos === false) {
                continue;
            }
            $key   = trim(substr($line, 0, $pos));
            $value = trim(substr($line, $pos + 1));
            // Eliminar comentarios inline
            $value = preg_replace('/\s+#.*$/', '', $value);
            if (!array_key_exists($key, $_ENV)) {
                $_ENV[$key] = $value;
            }
        }
    }

    $host   = $_ENV['DB_HOST']     ?? 'localhost';
    $port   = $_ENV['DB_PORT']     ?? '3306';
    $dbname = $_ENV['DB_NAME']     ?? 'portico';
    $user   = $_ENV['DB_USER']     ?? '';
    $pass   = $_ENV['DB_PASSWORD'] ?? '';

    if ($user === '') {
        throw new RuntimeException('Credenciales de base de datos no configuradas.');
    }

    $dsn = "mysql:host={$host};port={$port};dbname={$dbname};charset=utf8mb4";

    try {
        $pdo = new PDO($dsn, $user, $pass, [
            PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES   => false,
            PDO::ATTR_TIMEOUT            => 5,
        ]);
    } catch (PDOException $e) {
        error_log('DB connection error: ' . $e->getMessage());
        throw new RuntimeException('No se pudo conectar a la base de datos.');
    }

    return $pdo;
}
