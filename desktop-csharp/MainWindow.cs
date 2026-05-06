using System;
using System.Collections.Generic;
using System.IO;
using System.Text.Json;
using System.Threading.Tasks;
using System.Windows.Forms;
using BCrypt.Net;
using Microsoft.Web.WebView2.Core;
using Microsoft.Web.WebView2.WinForms;
using MySqlConnector;

namespace PorticoDesktop;

public sealed class MainWindow : Form
{
	private readonly WebView2 _webView;
	private Dictionary<string, string> _env = new();
	private int? _currentUserId;
	private string _currentNombre = string.Empty;
	private string _currentRol = string.Empty;

	public MainWindow()
	{
		Text = "Portico Desktop";
		StartPosition = FormStartPosition.CenterScreen;
		Width = 1920;
		Height = 1080;
		WindowState = FormWindowState.Maximized;

		var exePath = Application.ExecutablePath;
		if (File.Exists(exePath))
			Icon = Icon.ExtractAssociatedIcon(exePath);

		_webView = new WebView2
		{
			Dock = DockStyle.Fill
		};

		Controls.Add(_webView);
		Load += OnLoadAsync;
	}

	private async void OnLoadAsync(object? sender, EventArgs e)
	{
		try
		{
			_env = LoadEnv();

			await _webView.EnsureCoreWebView2Async();
			_webView.CoreWebView2.Settings.AreDevToolsEnabled = false;
			_webView.CoreWebView2.Settings.AreDefaultContextMenusEnabled = false;

			_webView.CoreWebView2.WebMessageReceived += OnWebMessageReceived;

			var loginPath = ResolveHtmlPath("Login.html");
			if (loginPath is null)
			{
				ShowError("No se encontró web-ui/Login.html.");
				return;
			}

			_webView.Source = new Uri(loginPath);
		}
		catch (WebView2RuntimeNotFoundException)
		{
			ShowError("No se encontró WebView2 Runtime. Instalá Microsoft Edge WebView2 Runtime.");
		}
		catch (Exception ex)
		{
			ShowError($"Error inicializando navegador: {ex.Message}");
		}
	}

	private async void OnWebMessageReceived(object? sender, CoreWebView2WebMessageReceivedEventArgs args)
	{
		try
		{
			var json = args.TryGetWebMessageAsString();
			using var doc  = JsonDocument.Parse(json);
			var root = doc.RootElement;

			if (!root.TryGetProperty("type", out var typeProp)) return;

			switch (typeProp.GetString())
			{
				case "login":
					await HandleLoginAsync(root);
					break;
				case "asistencia_catalogos":
					await HandleAsistenciaCatalogosAsync(root);
					break;
				case "asistencia_guardar":
					await HandleGuardarAsistenciaAsync(root);
					break;
			}
		}
		catch (Exception ex)
		{
			PostToJs(new { type = "login_response", success = false, error = "Error interno del servidor." });
			// Log real error internally, never exponer al cliente
			System.Diagnostics.Debug.WriteLine($"[WebMessage error] {ex}");
		}
	}

	private async Task HandleLoginAsync(JsonElement root)
	{
		if (!root.TryGetProperty("usuario", out var usuarioProp) ||
		    !root.TryGetProperty("password", out var passwordProp))
		{
			PostToJs(new { type = "login_response", success = false, error = "Campos requeridos." });
			return;
		}

		var usuario  = usuarioProp.GetString()?.Trim() ?? "";
		var password = passwordProp.GetString() ?? "";

		if (usuario.Length == 0 || password.Length == 0 || usuario.Length > 50 || password.Length > 255)
		{
			PostToJs(new { type = "login_response", success = false, error = "Datos inválidos." });
			return;
		}

		try
		{
			var connString = BuildConnectionString();
			await using var conn = new MySqlConnection(connString);
			await conn.OpenAsync();

			// Prepared statement: sin interpolación de strings → inmune a SQL Injection
			await using var cmd = conn.CreateCommand();
			cmd.CommandText =
				"SELECT id_usuario, nombre, usuario, password_hash, rol, activo " +
				"FROM usuarios WHERE usuario = @usuario LIMIT 1";
			cmd.Parameters.AddWithValue("@usuario", usuario);

			await using var reader = await cmd.ExecuteReaderAsync();

			if (!await reader.ReadAsync())
			{
				// Usuario no existe — mismo mensaje genérico para no filtrar info
				PostToJs(new { type = "login_response", success = false, error = "Usuario o contraseña incorrectos." });
				return;
			}

			var activo       = Convert.ToInt32(reader["activo"]);
			var passwordHash = reader.GetString("password_hash");
			var idUsuario    = reader.GetInt32("id_usuario");
			var nombre       = reader.GetString("nombre");
			var rol          = reader.GetString("rol");

			// BCrypt.Net-Next verifica hashes $2y$ de PHP y $2a$ de C#
			var hashValido = BCrypt.Net.BCrypt.Verify(password, passwordHash);

			if (activo == 0 || !hashValido)
			{
				PostToJs(new { type = "login_response", success = false, error = "Usuario o contraseña incorrectos." });
				return;
			}

			_currentUserId = idUsuario;
			_currentNombre = nombre;
			_currentRol = rol;

			PostToJs(new { type = "login_response", success = true, user_id = idUsuario, nombre, rol });

			// Navegar según rol en el hilo de UI
			Invoke(() =>
			{
				var destino = rol == "Capataz" ? "Asistencia.html" : "PanelInicio.html";
				var path = ResolveHtmlPath(destino);
				if (path is not null)
					_webView.Source = new Uri(path);
			});
		}
		catch (MySqlException ex)
		{
			System.Diagnostics.Debug.WriteLine($"[MySQL error] {ex}");
			PostToJs(new { type = "login_response", success = false, error = "No se pudo conectar a la base de datos." });
		}
		catch (Exception ex)
		{
			System.Diagnostics.Debug.WriteLine($"[Login error] {ex}");
			PostToJs(new { type = "login_response", success = false, error = "Error interno del servidor." });
		}
	}

	private async Task HandleAsistenciaCatalogosAsync(JsonElement root)
	{
		var requestId = root.TryGetProperty("requestId", out var requestIdProp)
			? requestIdProp.GetString() ?? string.Empty
			: string.Empty;

		try
		{
			await using var conn = new MySqlConnection(BuildConnectionString());
			await conn.OpenAsync();

			var obras = new List<object>();
			await using (var cmd = conn.CreateCommand())
			{
				cmd.CommandText = "SELECT id_obra, nombre, numero_contrata FROM obras ORDER BY nombre ASC";
				await using var reader = await cmd.ExecuteReaderAsync();
				while (await reader.ReadAsync())
				{
					obras.Add(new
					{
						id = reader.GetInt32("id_obra"),
						nombre = reader.GetString("nombre"),
						numero_contrata = reader.GetString("numero_contrata")
					});
				}
			}

			var obreros = new List<object>();
			await using (var cmd = conn.CreateCommand())
			{
				cmd.CommandText = "SELECT id_obrero, nombre, apellido, documento FROM obreros WHERE activo = 1 ORDER BY nombre ASC, apellido ASC";
				await using var reader = await cmd.ExecuteReaderAsync();
				while (await reader.ReadAsync())
				{
					var apellidoOrdinal = reader.GetOrdinal("apellido");
					var apellido = reader.IsDBNull(apellidoOrdinal) ? string.Empty : reader.GetString("apellido");
					obreros.Add(new
					{
						id = reader.GetInt32("id_obrero"),
						nombre = string.Join(" ", new[] { reader.GetString("nombre"), apellido }.Where(static value => !string.IsNullOrWhiteSpace(value))),
						documento = reader.GetString("documento")
					});
				}
			}

			var materiales = await LeerRecursosAsync(conn, true);
			var herramientas = await LeerRecursosAsync(conn, false);

			PostToJs(new
			{
				type = "asistencia_catalogos_response",
				requestId,
				success = true,
				obras,
				obreros,
				materiales,
				herramientas
			});
		}
		catch (Exception ex)
		{
			System.Diagnostics.Debug.WriteLine($"[Asistencia catalogos error] {ex}");
			PostToJs(new { type = "asistencia_catalogos_response", requestId, success = false, error = "No se pudieron cargar los datos de asistencia." });
		}
	}

	private async Task HandleGuardarAsistenciaAsync(JsonElement root)
	{
		var requestId = root.TryGetProperty("requestId", out var requestIdProp)
			? requestIdProp.GetString() ?? string.Empty
			: string.Empty;

		try
		{
			var idObra = ReadPositiveInt(root, "id_obra");
			var fecha = ReadRequiredString(root, "fecha");
			var finalizaObra = root.TryGetProperty("finaliza_obra", out var finalizaProp) && finalizaProp.ValueKind == JsonValueKind.True;
			var idUsuario = _currentUserId ?? ReadPositiveInt(root, "id_usuario");

			if (!root.TryGetProperty("obreros", out var obrerosElement) || obrerosElement.ValueKind != JsonValueKind.Array || obrerosElement.GetArrayLength() == 0)
				throw new InvalidOperationException("Seleccioná al menos un obrero.");

			var obreros = new List<(int IdObrero, string HoraEntrada, string HoraSalida)>();
			foreach (var item in obrerosElement.EnumerateArray())
			{
				var idObrero = ReadPositiveInt(item, "id_obrero");
				var horaEntrada = ReadRequiredString(item, "hora_entrada");
				var horaSalida = ReadRequiredString(item, "hora_salida");

				if (TimeSpan.Parse(horaSalida) <= TimeSpan.Parse(horaEntrada))
					throw new InvalidOperationException("La hora de salida debe ser mayor a la de entrada.");

				obreros.Add((idObrero, horaEntrada, horaSalida));
			}

			await using var conn = new MySqlConnection(BuildConnectionString());
			await conn.OpenAsync();
			await using var tx = await conn.BeginTransactionAsync();

			var registrosInsertados = 0;
			foreach (var obrero in obreros)
			{
				await using var insertRegistro = conn.CreateCommand();
				insertRegistro.Transaction = tx;
				insertRegistro.CommandText =
					"INSERT INTO registros (fecha, hora_entrada, hora_salida, horas_trabajadas, id_obrero, id_obra, id_usuario) " +
					"VALUES (@fecha, @entrada, @salida, @horas, @idObrero, @idObra, @idUsuario)";
				insertRegistro.Parameters.AddWithValue("@fecha", fecha);
				insertRegistro.Parameters.AddWithValue("@entrada", obrero.HoraEntrada);
				insertRegistro.Parameters.AddWithValue("@salida", obrero.HoraSalida);
				insertRegistro.Parameters.AddWithValue("@horas", decimal.Parse(CalcularHorasTrabajadas(obrero.HoraEntrada, obrero.HoraSalida)));
				insertRegistro.Parameters.AddWithValue("@idObrero", obrero.IdObrero);
				insertRegistro.Parameters.AddWithValue("@idObra", idObra);
				insertRegistro.Parameters.AddWithValue("@idUsuario", idUsuario);
				await insertRegistro.ExecuteNonQueryAsync();
				registrosInsertados++;
			}

			var recursosInsertados = 0;
			recursosInsertados += await InsertarRecursosAsync(conn, tx, root, "materiales", idObra, fecha, true);
			recursosInsertados += await InsertarRecursosAsync(conn, tx, root, "herramientas", idObra, fecha, false);

			if (finalizaObra)
			{
				await using var updateObra = conn.CreateCommand();
				updateObra.Transaction = tx;
				updateObra.CommandText = "UPDATE obras SET fecha_fin = @fecha WHERE id_obra = @idObra";
				updateObra.Parameters.AddWithValue("@fecha", fecha);
				updateObra.Parameters.AddWithValue("@idObra", idObra);
				await updateObra.ExecuteNonQueryAsync();
			}

			await tx.CommitAsync();

			PostToJs(new
			{
				type = "asistencia_guardar_response",
				requestId,
				success = true,
				registros_insertados = registrosInsertados,
				recursos_insertados = recursosInsertados
			});
		}
		catch (InvalidOperationException ex)
		{
			PostToJs(new { type = "asistencia_guardar_response", requestId, success = false, error = ex.Message });
		}
		catch (Exception ex)
		{
			System.Diagnostics.Debug.WriteLine($"[Asistencia guardar error] {ex}");
			PostToJs(new { type = "asistencia_guardar_response", requestId, success = false, error = "No se pudo guardar la asistencia." });
		}
	}

	private static int ReadPositiveInt(JsonElement root, string propertyName)
	{
		if (!root.TryGetProperty(propertyName, out var prop))
			throw new InvalidOperationException($"Falta el campo {propertyName}.");

		if (prop.ValueKind == JsonValueKind.Number && prop.TryGetInt32(out var number) && number > 0)
			return number;

		if (prop.ValueKind == JsonValueKind.String && int.TryParse(prop.GetString(), out number) && number > 0)
			return number;

		throw new InvalidOperationException($"El campo {propertyName} es inválido.");
	}

	private static string ReadRequiredString(JsonElement root, string propertyName)
	{
		if (!root.TryGetProperty(propertyName, out var prop) || prop.ValueKind != JsonValueKind.String)
			throw new InvalidOperationException($"Falta el campo {propertyName}.");

		var value = prop.GetString()?.Trim() ?? string.Empty;
		if (string.IsNullOrWhiteSpace(value))
			throw new InvalidOperationException($"El campo {propertyName} es obligatorio.");

		return value;
	}

	private static string CalcularHorasTrabajadas(string horaEntrada, string horaSalida)
	{
		var entrada = TimeSpan.Parse(horaEntrada);
		var salida = TimeSpan.Parse(horaSalida);
		if (salida <= entrada)
			throw new InvalidOperationException("La hora de salida debe ser mayor a la de entrada.");

		return ((decimal)(salida - entrada).TotalHours).ToString("0.00", System.Globalization.CultureInfo.InvariantCulture);
	}

	private static async Task<List<string>> LeerRecursosAsync(MySqlConnection conn, bool esMaterial)
	{
		var items = new List<string>();
		await using var cmd = conn.CreateCommand();
		cmd.CommandText = "SELECT DISTINCT nombre FROM recursos WHERE es_material = @esMaterial ORDER BY nombre ASC";
		cmd.Parameters.AddWithValue("@esMaterial", esMaterial);
		await using var reader = await cmd.ExecuteReaderAsync();
		while (await reader.ReadAsync())
		{
			items.Add(reader.GetString("nombre"));
		}
		return items;
	}

	private static async Task<int> InsertarRecursosAsync(MySqlConnection conn, MySqlTransaction tx, JsonElement root, string propertyName, int idObra, string fecha, bool esMaterial)
	{
		if (!root.TryGetProperty(propertyName, out var recursosElement) || recursosElement.ValueKind != JsonValueKind.Array)
			return 0;

		var count = 0;
		foreach (var item in recursosElement.EnumerateArray())
		{
			var nombre = ReadRequiredString(item, "nombre");
			var cantidad = ReadPositiveDecimal(item, "cantidad");
			var precio = esMaterial ? ReadNonNegativeDecimal(item, "precio_unitario") : (decimal?)null;

			await using var cmd = conn.CreateCommand();
			cmd.Transaction = tx;
			cmd.CommandText =
				"INSERT INTO recursos (id_obra, id_registro, fecha, nombre, cantidad, precio_unitario, es_material) " +
				"VALUES (@idObra, NULL, @fecha, @nombre, @cantidad, @precio, @esMaterial)";
			cmd.Parameters.AddWithValue("@idObra", idObra);
			cmd.Parameters.AddWithValue("@fecha", fecha);
			cmd.Parameters.AddWithValue("@nombre", nombre);
			cmd.Parameters.AddWithValue("@cantidad", cantidad);
			cmd.Parameters.AddWithValue("@precio", precio.HasValue ? precio.Value : DBNull.Value);
			cmd.Parameters.AddWithValue("@esMaterial", esMaterial);
			await cmd.ExecuteNonQueryAsync();
			count++;
		}

		return count;
	}

	private static decimal ReadPositiveDecimal(JsonElement root, string propertyName)
	{
		var value = ReadDecimal(root, propertyName);
		if (value <= 0)
			throw new InvalidOperationException($"El campo {propertyName} debe ser mayor a cero.");
		return value;
	}

	private static decimal ReadNonNegativeDecimal(JsonElement root, string propertyName)
	{
		var value = ReadDecimal(root, propertyName);
		if (value < 0)
			throw new InvalidOperationException($"El campo {propertyName} no puede ser negativo.");
		return value;
	}

	private static decimal ReadDecimal(JsonElement root, string propertyName)
	{
		if (!root.TryGetProperty(propertyName, out var prop))
			throw new InvalidOperationException($"Falta el campo {propertyName}.");

		if (prop.ValueKind == JsonValueKind.Number && prop.TryGetDecimal(out var number))
			return number;

		if (prop.ValueKind == JsonValueKind.String && decimal.TryParse(prop.GetString(), System.Globalization.NumberStyles.Number, System.Globalization.CultureInfo.InvariantCulture, out number))
			return number;

		throw new InvalidOperationException($"El campo {propertyName} es inválido.");
	}

	private void PostToJs(object payload)
	{
		var json = JsonSerializer.Serialize(payload);
		// Debe ejecutarse en el hilo de UI
		Invoke(() => _webView.CoreWebView2.PostWebMessageAsString(json));
	}

	private string BuildConnectionString()
	{
		var host = _env.GetValueOrDefault("DB_HOST", "localhost");
		var port = _env.GetValueOrDefault("DB_PORT", "3306");
		var name = _env.GetValueOrDefault("DB_NAME", "portico");
		var user = _env.GetValueOrDefault("DB_USER", "");
		var pass = _env.GetValueOrDefault("DB_PASSWORD", "");

		return $"Server={host};Port={port};Database={name};User ID={user};Password={pass};CharSet=utf8mb4;";
	}

	private static Dictionary<string, string> LoadEnv()
	{
		var result  = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
		var envPath = FindEnvFile();

		if (envPath is null) return result;

		foreach (var line in File.ReadAllLines(envPath))
		{
			var trimmed = line.Trim();
			if (trimmed.Length == 0 || trimmed.StartsWith('#')) continue;

			var pos = trimmed.IndexOf('=');
			if (pos < 1) continue;

			var key   = trimmed[..pos].Trim();
			var value = trimmed[(pos + 1)..].Trim();

			// Quitar comentarios inline: key=value # comentario
			var commentIdx = value.IndexOf(" #", StringComparison.Ordinal);
			if (commentIdx >= 0) value = value[..commentIdx].Trim();

			result[key] = value;
		}

		return result;
	}

	// Busca .env subiendo directorios desde el ejecutable
	private static string? FindEnvFile()
	{
		var dir = new DirectoryInfo(AppContext.BaseDirectory);
		while (dir is not null)
		{
			var candidate = Path.Combine(dir.FullName, ".env");
			if (File.Exists(candidate)) return candidate;
			dir = dir.Parent;
		}
		return null;
	}

	private static string? ResolveHtmlPath(string fileName)
	{
		var directPath = Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "web-ui", fileName));
		if (File.Exists(directPath)) return directPath;

		var dir = new DirectoryInfo(AppContext.BaseDirectory);
		while (dir is not null)
		{
			var candidate = Path.Combine(dir.FullName, "web-ui", fileName);
			if (File.Exists(candidate)) return candidate;
			dir = dir.Parent;
		}
		return null;
	}

	private void ShowError(string message)
	{
		var safe = message.Replace("<", "&lt;").Replace(">", "&gt;");
		_webView.NavigateToString($"<html><body style='font-family:Segoe UI;padding:20px;'><h2>Portico Desktop</h2><p>{safe}</p></body></html>");
	}
}
