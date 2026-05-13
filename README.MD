# Aplicación Desktop ➔ Portico.

## Tecnologias
- **Frontend:** HTML, CSS, JS
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
### Pasos antes de compilar
1. Renombrar el archivo `.env.example` a `.env`
2. Colocar las credenciales de la MySQL (No hace falta comillas)
3. Compilar el sistema

### Requisitos
.NET 10.0 

Para compilar la aplicación `.exe`:

```bash
dotnet build .\desktop-csharp\PorticoDesktop.csproj -c Release
```

El ejecutable quedará en `desktop-csharp/bin/Release/`.

---

## Flujo basico con Git

### 1. Clonar el repositorio

```bash
git clone https://github.com/usuario/portico.git
cd portico
```

Clonar el repositorio facilita el inicio porque ya genera la carpeta `.git` con toda la configuración e historial necesarios para poder usar `pull`, `commit`, `push` y trabajar con ramas.

### 2. Traer los cambios mas recientes de `main`

Antes de empezar a trabajar, actualiza tu rama local con los cambios remotos:

```bash
git pull origin main
```

Si quieres dejar tu copia local exactamente igual a GitHub y descartar cambios locales, usa este comando con cuidado:

```bash
git reset --hard origin/main
```

### 3. Revisar tus cambios

Antes de subir cambios, revisa el estado de tu repositorio:

```bash
git status
```

### 4. Guardar cambios en Git

```bash
git add .
git commit -m "Describe aqui tu cambio"
```

### 5. Subir cambios al repositorio remoto

Si estas trabajando en tu propia rama:

```bash
git push origin nombre-de-tu-rama
```

Si necesitas crear una rama nueva antes de subir cambios:

```bash
git checkout -b nombre-de-tu-rama
git push -u origin nombre-de-tu-rama
```

### 6. Crear un Pull Request (PR)

1. Entra al repositorio en GitHub.
2. Busca el aviso para abrir un Pull Request de tu rama.
3. Verifica que el destino sea `main`.
4. Escribe un titulo y descripcion claros.
5. Crea el PR y, si aplica, solicita revision.

### Flujo recomendado

```bash
git clone <URL_DEL_REPOSITORIO>
cd portico
git pull origin main
git checkout -b nombre-de-tu-rama
# hacer cambios
git add .
git commit -m "Describe aqui tu cambio"
git push -u origin nombre-de-tu-rama
```

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

ToDo: 
- Protección de sesiones en todas las paginas.
- Sistema de logs visible únicamente para el Admin. 