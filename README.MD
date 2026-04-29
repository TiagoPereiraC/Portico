# Aplicación Desktop ➔ Portico.

## Tecnologias
- **Frontend:** HTML, CSS (?)
- **Backend:** PHP
- **Base de datos:** MySQL

---

## Pantallas y asignaciones
- **Irina:** Login y Consultas.
- **Natasha:** Registrar obrero
- **Angela:** Asistencia y Panel de inicio.
- **Santiago:** Registrar obra.

---

## Build

Para compilar la aplicación `.exe`:

```bash
dotnet build .\desktop-csharp\PorticoDesktop.csproj -c Release
```

El ejecutable quedará en `desktop-csharp/bin/Release/`.

---

## Paleta de colores

| Variable          | Valor     | Uso                        |
|-------------------|-----------|----------------------------|
| `--bg`            | `#954043` | Fondo general              |
| `--card-bg`       | `#e8e3df` | Fondo de tarjetas/forms    |
| `--input-bg`      | `#f5f5f5` | Fondo de inputs            |
| `--input-border`  | `#e0e0e0` | Borde de inputs            |
| `--text-dark`     | `#666`    | Texto principal            |
| `--text-muted`    | `#888`    | Texto secundario / Volver  |
| `--btn-bg`        | `#b54747` | Botón primario             |
| `--btn-hover`     | `#9e3c3c` | Hover botón primario       |
| `--accent`        | `#b54747` | Color de acento / focus    |

