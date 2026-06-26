# Propuesta simple: logs de auditoria

## Objetivo

Agregar una bitacora de auditoria para registrar acciones relevantes hechas por usuarios autenticados.

La idea no es guardar cada request del sistema, sino dejar evidencia util cuando alguien:

- inicia o cierra sesion
- crea, edita o elimina usuarios
- crea, edita o elimina obras
- crea, edita o elimina obreros
- crea, edita o elimina maquinaria
- carga asistencia
- sube o elimina contratos o certificados

Esto sirve para:

- saber quien hizo un cambio
- detectar errores operativos
- revisar acciones administrativas sensibles
- tener trazabilidad ante reclamos o incidentes

## Situacion actual

Hoy el sistema ya guarda algunas cosas, pero no hay una auditoria general:

- `intentos_login` registra intentos de acceso
- `registros` guarda asistencia de negocio

Eso no alcanza para responder preguntas como:

- quien elimino un usuario
- quien modifico una obra
- quien cargo cierta asistencia

## Cambio propuesto en base de datos

Agregar una tabla nueva dedicada a auditoria. No reutilizar `registros`, porque esa tabla representa asistencia y no eventos del sistema.

Ejemplo sugerido:

```sql
CREATE TABLE IF NOT EXISTS auditoria_logs (
    id_log INT AUTO_INCREMENT PRIMARY KEY,
    id_usuario INT NULL,
    usuario VARCHAR(50) NULL,
    rol VARCHAR(30) NULL,
    accion VARCHAR(50) NOT NULL,
    entidad VARCHAR(50) NOT NULL,
    entidad_id INT NULL,
    detalle_json JSON NULL,
    ip_address VARCHAR(45) NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario)
        ON UPDATE CASCADE ON DELETE SET NULL,

    INDEX idx_auditoria_fecha (created_at),
    INDEX idx_auditoria_usuario (id_usuario, created_at),
    INDEX idx_auditoria_entidad (entidad, entidad_id)
);
```

### Campos importantes

- `id_usuario`: usuario que ejecuto la accion
- `accion`: tipo de evento, por ejemplo `crear`, `editar`, `eliminar`, `login`, `logout`
- `entidad`: modulo afectado, por ejemplo `usuarios`, `obras`, `obreros`, `maquinaria`
- `entidad_id`: id del registro afectado
- `detalle_json`: datos complementarios para entender el cambio
- `ip_address`: IP desde donde se hizo la accion
- `created_at`: fecha y hora exacta

## Cambios esperados en backend

### 1. Crear una funcion reutilizable de auditoria

Crear un helper, por ejemplo en `api/config/auditoria.php`, con una funcion tipo:

```php
registrarAuditoria(PDO $pdo, string $accion, string $entidad, ?int $entidadId = null, array $detalle = []): void
```

Esa funcion deberia tomar los datos de sesion actuales y grabar el evento en `auditoria_logs`.

### 2. Llamar a esa funcion en endpoints sensibles

Los puntos mas importantes para cubrir primero son:

- `api/login.php`
- `api/logout.php`
- `api/usuarios.php`
- `api/Obras.php`
- `api/obreros.php`
- `api/maquinaria.php`
- `api/maquinaria_certificados.php`
- `api/guardar_asistencia.php`

### 3. Registrar solo eventos utiles

No conviene auditar lecturas comunes (`GET` de listados), porque agregan mucho ruido y poco valor.

Primera version recomendada:

- login exitoso
- logout
- altas
- ediciones
- bajas
- cambios de estado
- carga de asistencia
- altas o bajas de archivos adjuntos

## Cambios esperados en frontend

El sistema puede funcionar con logs sin mostrar nada en pantalla al principio.

Si despues se quiere consultar esa informacion desde la UI, se podria agregar:

- una pantalla nueva de "Logs" o "Auditoria"
- acceso solo para `Administrador`
- filtros por fecha, usuario, entidad y accion

Esto seria una segunda etapa, no algo obligatorio para arrancar.

## Impacto tecnico

Impacto bajo a medio.

- Base de datos: agregar una tabla nueva e indices
- Backend: agregar un helper y llamadas puntuales en endpoints existentes
- Frontend: opcional en primera etapa

No deberia romper funcionalidades actuales si se implementa como agregado y no como reemplazo de tablas existentes.

## Riesgos y cuidados

- no guardar contrasenas ni datos sensibles en texto plano dentro de `detalle_json`
- no registrar tokens de sesion o CSRF
- evitar loguear cuerpos completos si contienen archivos o datos privados
- mantener los detalles acotados a informacion util de auditoria

## Plan recomendado

### Etapa 1

- crear tabla `auditoria_logs`
- crear helper PHP reutilizable
- auditar login, logout, usuarios y obras

### Etapa 2

- auditar obreros, maquinaria, certificados y asistencia

### Etapa 3

- agregar pantalla de consulta para administradores

## Resumen corto para comunicar al equipo

Se propone agregar una bitacora de auditoria para registrar acciones importantes de los usuarios dentro del sistema. Esto no reemplaza los registros actuales de negocio, sino que suma trazabilidad tecnica y operativa. El cambio principal seria incorporar una nueva tabla en MySQL, una funcion reutilizable en PHP para guardar eventos y llamadas en los endpoints mas sensibles. La vista de logs para administradores puede dejarse como segunda etapa.