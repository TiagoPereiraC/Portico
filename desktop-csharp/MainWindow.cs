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
			_webView.ZoomFactor = 1.1d;
			_webView.CoreWebView2.Settings.AreDevToolsEnabled = false;
			_webView.CoreWebView2.Settings.AreDefaultContextMenusEnabled = false;

			_webView.CoreWebView2.WebMessageReceived += OnWebMessageReceived;

			_webView.CoreWebView2.AddWebResourceRequestedFilter(
				"https://portico.desktop/*",
				CoreWebView2WebResourceContext.All);
			_webView.CoreWebView2.WebResourceRequested += OnWebResourceRequested;

			if (GetType().Assembly.GetManifestResourceStream("webui.Login.html") is null)
			{
				ShowError("No se encontró el recurso embebido webui.Login.html.");
				return;
			}

			_webView.Source = new Uri("https://portico.desktop/Login.html");
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
		string responseType = "desktop_response";
		string requestId = string.Empty;

		try
		{
			var json = args.TryGetWebMessageAsString();
			using var doc  = JsonDocument.Parse(json);
			var root = doc.RootElement;

			if (!root.TryGetProperty("type", out var typeProp)) return;
			var messageType = typeProp.GetString() ?? string.Empty;
			requestId = root.TryGetProperty("requestId", out var requestIdProp)
				? requestIdProp.GetString() ?? string.Empty
				: string.Empty;
			responseType = string.IsNullOrWhiteSpace(messageType) ? responseType : $"{messageType}_response";

			switch (messageType)
			{
				case "login":
					await HandleLoginAsync(root);
					break;
				case "logout":
					HandleLogout();
					break;
				case "users_list":
					await HandleUsersListAsync(root);
					break;
				case "user_get":
					await HandleUserGetAsync(root);
					break;
				case "user_create":
					await HandleUserCreateAsync(root);
					break;
				case "user_update":
					await HandleUserUpdateAsync(root);
					break;
				case "user_delete":
					await HandleUserDeleteAsync(root);
					break;
				case "obras_listar":
					await HandleObrasListarAsync(root);
					break;
				case "obras_guardar":
					await HandleGuardarObraAsync(root);
					break;
				case "obras_eliminar":
					await HandleEliminarObraAsync(root);
					break;
			case "obras_descargar_contrato":
				await HandleDescargarContratoAsync(root);
				break;
			case "obreros_listar":
				await HandleObrerosListarAsync(root);
				break;
			case "obreros_guardar":
				await HandleGuardarObreroAsync(root);
				break;
			case "obreros_eliminar":
				await HandleEliminarObreroAsync(root);
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
			PostToJs(new { type = responseType, requestId, success = false, error = "Error interno del servidor." });
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
				_webView.Source = new Uri($"https://portico.desktop/{destino}");
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

	private void HandleLogout()
	{
		_currentUserId = null;
		_currentNombre = string.Empty;
		_currentRol = string.Empty;

		PostToJs(new { type = "logout_response", success = true });

		Invoke(() =>
		{
			_webView.Source = new Uri("https://portico.desktop/Login.html");
		});
	}

	private async Task HandleAsistenciaCatalogosAsync(JsonElement root)
	{
		var requestId = root.TryGetProperty("requestId", out var requestIdProp)
			? requestIdProp.GetString() ?? string.Empty
			: string.Empty;

		if (!EnsureCapatazOAdmin(requestId, "asistencia_catalogos_response"))
			return;

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

	private async Task HandleUsersListAsync(JsonElement root)
	{
		var requestId = ReadRequestId(root);
		const string responseType = "users_list_response";

		if (!EnsureAdministrador(requestId, responseType))
			return;

		try
		{
			await using var conn = new MySqlConnection(BuildConnectionString());
			await conn.OpenAsync();

			var users = new List<object>();
			await using var cmd = conn.CreateCommand();
			cmd.CommandText = "SELECT id_usuario, nombre, usuario, rol, activo FROM usuarios ORDER BY id_usuario ASC";

			await using var reader = await cmd.ExecuteReaderAsync();
			while (await reader.ReadAsync())
			{
				users.Add(new
				{
					id_usuario = reader.GetInt32("id_usuario"),
					nombre = reader.GetString("nombre"),
					usuario = reader.GetString("usuario"),
					rol = reader.GetString("rol"),
					activo = Convert.ToInt32(reader["activo"])
				});
			}

			PostToJs(new { type = responseType, requestId, success = true, users });
		}
		catch (Exception ex)
		{
			System.Diagnostics.Debug.WriteLine($"[Users list error] {ex}");
			PostToJs(new { type = responseType, requestId, success = false, error = "No se pudieron cargar los usuarios." });
		}
	}

	private async Task HandleUserGetAsync(JsonElement root)
	{
		var requestId = ReadRequestId(root);
		const string responseType = "user_get_response";

		if (!EnsureAdministrador(requestId, responseType))
			return;

		try
		{
			var idUsuario = ReadPositiveInt(root, "id_usuario");

			await using var conn = new MySqlConnection(BuildConnectionString());
			await conn.OpenAsync();

			await using var cmd = conn.CreateCommand();
			cmd.CommandText = "SELECT id_usuario, nombre, usuario, rol, activo FROM usuarios WHERE id_usuario = @idUsuario LIMIT 1";
			cmd.Parameters.AddWithValue("@idUsuario", idUsuario);

			await using var reader = await cmd.ExecuteReaderAsync();
			if (!await reader.ReadAsync())
			{
				PostToJs(new { type = responseType, requestId, success = false, error = "Usuario no encontrado." });
				return;
			}

			PostToJs(new
			{
				type = responseType,
				requestId,
				success = true,
				user = new
				{
					id_usuario = reader.GetInt32("id_usuario"),
					nombre = reader.GetString("nombre"),
					usuario = reader.GetString("usuario"),
					rol = reader.GetString("rol"),
					activo = Convert.ToInt32(reader["activo"])
				}
			});
		}
		catch (InvalidOperationException ex)
		{
			PostToJs(new { type = responseType, requestId, success = false, error = ex.Message });
		}
		catch (Exception ex)
		{
			System.Diagnostics.Debug.WriteLine($"[User get error] {ex}");
			PostToJs(new { type = responseType, requestId, success = false, error = "No se pudo cargar el usuario." });
		}
	}

	private async Task HandleUserCreateAsync(JsonElement root)
	{
		var requestId = ReadRequestId(root);
		const string responseType = "user_create_response";

		if (!EnsureAdministrador(requestId, responseType))
			return;

		try
		{
			var nombre = ReadRequiredString(root, "nombre");
			var usuario = ReadRequiredString(root, "usuario");
			var password = ReadPasswordString(root, "password", required: true);
			var rol = ReadRequiredString(root, "rol");

			ValidateUserFields(nombre, usuario, password, rol, validatePassword: true);

			await using var conn = new MySqlConnection(BuildConnectionString());
			await conn.OpenAsync();

			await using (var checkCmd = conn.CreateCommand())
			{
				checkCmd.CommandText = "SELECT id_usuario FROM usuarios WHERE usuario = @usuario LIMIT 1";
				checkCmd.Parameters.AddWithValue("@usuario", usuario);
				var existing = await checkCmd.ExecuteScalarAsync();
				if (existing is not null)
				{
					PostToJs(new { type = responseType, requestId, success = false, error = "El nombre de usuario ya está registrado." });
					return;
				}
			}

			await using var cmd = conn.CreateCommand();
			cmd.CommandText =
				"INSERT INTO usuarios (nombre, usuario, password_hash, rol, activo) VALUES (@nombre, @usuario, @passwordHash, @rol, 1); " +
				"SELECT LAST_INSERT_ID();";
			cmd.Parameters.AddWithValue("@nombre", nombre);
			cmd.Parameters.AddWithValue("@usuario", usuario);
			cmd.Parameters.AddWithValue("@passwordHash", BCrypt.Net.BCrypt.HashPassword(password));
			cmd.Parameters.AddWithValue("@rol", rol);

			var insertedId = Convert.ToInt32(await cmd.ExecuteScalarAsync());
			PostToJs(new
			{
				type = responseType,
				requestId,
				success = true,
				message = $"Usuario '{usuario}' creado correctamente.",
				user_id = insertedId
			});
		}
		catch (InvalidOperationException ex)
		{
			PostToJs(new { type = responseType, requestId, success = false, error = ex.Message });
		}
		catch (Exception ex)
		{
			System.Diagnostics.Debug.WriteLine($"[User create error] {ex}");
			PostToJs(new { type = responseType, requestId, success = false, error = "No se pudo crear el usuario." });
		}
	}

	private async Task HandleUserUpdateAsync(JsonElement root)
	{
		var requestId = ReadRequestId(root);
		const string responseType = "user_update_response";

		if (!EnsureAdministrador(requestId, responseType))
			return;

		try
		{
			var idUsuario = ReadPositiveInt(root, "id_usuario");
			var nombre = ReadRequiredString(root, "nombre");
			var usuario = ReadRequiredString(root, "usuario");
			var rol = ReadRequiredString(root, "rol");
			var nuevaPassword = ReadPasswordString(root, "nueva_password", required: false);

			ValidateUserFields(nombre, usuario, nuevaPassword, rol, validatePassword: nuevaPassword.Length > 0);

			await using var conn = new MySqlConnection(BuildConnectionString());
			await conn.OpenAsync();

			await using (var existsCmd = conn.CreateCommand())
			{
				existsCmd.CommandText = "SELECT id_usuario FROM usuarios WHERE id_usuario = @idUsuario LIMIT 1";
				existsCmd.Parameters.AddWithValue("@idUsuario", idUsuario);
				var exists = await existsCmd.ExecuteScalarAsync();
				if (exists is null)
				{
					PostToJs(new { type = responseType, requestId, success = false, error = "Usuario no encontrado." });
					return;
				}
			}

			await using (var checkCmd = conn.CreateCommand())
			{
				checkCmd.CommandText = "SELECT id_usuario FROM usuarios WHERE usuario = @usuario AND id_usuario <> @idUsuario LIMIT 1";
				checkCmd.Parameters.AddWithValue("@usuario", usuario);
				checkCmd.Parameters.AddWithValue("@idUsuario", idUsuario);
				var existing = await checkCmd.ExecuteScalarAsync();
				if (existing is not null)
				{
					PostToJs(new { type = responseType, requestId, success = false, error = "El nombre de usuario ya está en uso por otra cuenta." });
					return;
				}
			}

			await using var cmd = conn.CreateCommand();
			if (nuevaPassword.Length > 0)
			{
				cmd.CommandText =
					"UPDATE usuarios SET nombre = @nombre, usuario = @usuario, rol = @rol, password_hash = @passwordHash WHERE id_usuario = @idUsuario";
				cmd.Parameters.AddWithValue("@passwordHash", BCrypt.Net.BCrypt.HashPassword(nuevaPassword));
			}
			else
			{
				cmd.CommandText = "UPDATE usuarios SET nombre = @nombre, usuario = @usuario, rol = @rol WHERE id_usuario = @idUsuario";
			}

			cmd.Parameters.AddWithValue("@nombre", nombre);
			cmd.Parameters.AddWithValue("@usuario", usuario);
			cmd.Parameters.AddWithValue("@rol", rol);
			cmd.Parameters.AddWithValue("@idUsuario", idUsuario);
			await cmd.ExecuteNonQueryAsync();

			PostToJs(new { type = responseType, requestId, success = true, message = "Usuario actualizado correctamente." });
		}
		catch (InvalidOperationException ex)
		{
			PostToJs(new { type = responseType, requestId, success = false, error = ex.Message });
		}
		catch (Exception ex)
		{
			System.Diagnostics.Debug.WriteLine($"[User update error] {ex}");
			PostToJs(new { type = responseType, requestId, success = false, error = "No se pudo actualizar el usuario." });
		}
	}

	private async Task HandleUserDeleteAsync(JsonElement root)
	{
		var requestId = ReadRequestId(root);
		const string responseType = "user_delete_response";

		if (!EnsureAdministrador(requestId, responseType))
			return;

		try
		{
			var idUsuario = ReadPositiveInt(root, "id_usuario");

			await using var conn = new MySqlConnection(BuildConnectionString());
			await conn.OpenAsync();

			string? usuario;
			await using (var selectCmd = conn.CreateCommand())
			{
				selectCmd.CommandText = "SELECT usuario FROM usuarios WHERE id_usuario = @idUsuario LIMIT 1";
				selectCmd.Parameters.AddWithValue("@idUsuario", idUsuario);

				var result = await selectCmd.ExecuteScalarAsync();
				if (result is null)
				{
					PostToJs(new { type = responseType, requestId, success = false, error = "Usuario no encontrado." });
					return;
				}

				usuario = Convert.ToString(result);
			}

			await using var deleteCmd = conn.CreateCommand();
			deleteCmd.CommandText = "DELETE FROM usuarios WHERE id_usuario = @idUsuario";
			deleteCmd.Parameters.AddWithValue("@idUsuario", idUsuario);
			await deleteCmd.ExecuteNonQueryAsync();

			PostToJs(new
			{
				type = responseType,
				requestId,
				success = true,
				message = $"Usuario '{usuario}' eliminado correctamente."
			});
		}
		catch (InvalidOperationException ex)
		{
			PostToJs(new { type = responseType, requestId, success = false, error = ex.Message });
		}
		catch (Exception ex)
		{
			System.Diagnostics.Debug.WriteLine($"[User delete error] {ex}");
			PostToJs(new { type = responseType, requestId, success = false, error = "No se pudo eliminar el usuario." });
		}
	}

	private async Task HandleObrasListarAsync(JsonElement root)
	{
		var requestId = root.TryGetProperty("requestId", out var requestIdProp)
			? requestIdProp.GetString() ?? string.Empty
			: string.Empty;

		if (!EnsureAutenticado(requestId, "obras_listar_response"))
			return;

		try
		{
			var page = 1;
			if (root.TryGetProperty("page", out var pageProp))
			{
				if (pageProp.ValueKind == JsonValueKind.Number && pageProp.TryGetInt32(out var pageNumber) && pageNumber > 0)
					page = pageNumber;
				else if (pageProp.ValueKind == JsonValueKind.String && int.TryParse(pageProp.GetString(), out pageNumber) && pageNumber > 0)
					page = pageNumber;
			}

			var limit = 10;
			if (root.TryGetProperty("limit", out var limitProp))
			{
				if (limitProp.ValueKind == JsonValueKind.Number && limitProp.TryGetInt32(out var limitNumber) && limitNumber > 0)
					limit = limitNumber;
				else if (limitProp.ValueKind == JsonValueKind.String && int.TryParse(limitProp.GetString(), out limitNumber) && limitNumber > 0)
					limit = limitNumber;
			}
			limit = Math.Clamp(limit, 1, 100);

			var search = root.TryGetProperty("search", out var searchProp) && searchProp.ValueKind == JsonValueKind.String
				? searchProp.GetString()?.Trim() ?? string.Empty
				: string.Empty;
			var status = root.TryGetProperty("status", out var statusProp) && statusProp.ValueKind == JsonValueKind.String
				? (statusProp.GetString()?.Trim().ToLowerInvariant() ?? "all")
				: "all";

			if (status is not ("all" or "active" or "inactive"))
				throw new InvalidOperationException("Filtro de estado inválido.");

			await using var conn = new MySqlConnection(BuildConnectionString());
			await conn.OpenAsync();

			var where = new List<string>();
			var countParams = new List<MySqlParameter>();

			if (!string.IsNullOrWhiteSpace(search))
			{
				where.Add("(o.numero_contrata LIKE @search OR o.nombre LIKE @search OR o.direccion LIKE @search OR o.descripcion LIKE @search OR o.nombre_cliente LIKE @search OR o.telefono_cliente LIKE @search)");
				countParams.Add(new MySqlParameter("@search", $"%{search}%"));
			}

			if (status == "active")
				where.Add("o.activo = 1");
			else if (status == "inactive")
				where.Add("o.activo = 0");

			var whereSql = where.Count > 0 ? " WHERE " + string.Join(" AND ", where) : string.Empty;

			var total = 0;
			await using (var countCmd = conn.CreateCommand())
			{
				countCmd.CommandText = "SELECT COUNT(*) FROM obras o" + whereSql;
				foreach (var param in countParams)
					countCmd.Parameters.AddWithValue(param.ParameterName, param.Value);

				total = Convert.ToInt32(await countCmd.ExecuteScalarAsync());
			}

			var totalPages = Math.Max(1, (int)Math.Ceiling(total / (double)limit));
			page = Math.Min(page, totalPages);
			var offset = (page - 1) * limit;

			var obras = new List<object>();
			await using var cmd = conn.CreateCommand();
			cmd.CommandText =
				"SELECT o.id_obra, o.numero_contrata, o.nombre, o.direccion, o.descripcion, o.fecha_inicio, o.fecha_fin, o.nombre_cliente, o.telefono_cliente, o.activo, " +
				"c.nombre_archivo AS contrato_nombre_archivo " +
				"FROM obras o " +
				"LEFT JOIN (" +
				"SELECT c1.id_obra, c1.nombre_archivo FROM contratos c1 " +
				"INNER JOIN (SELECT id_obra, MAX(id_contrato) AS max_id_contrato FROM contratos GROUP BY id_obra) ult " +
				"ON ult.id_obra = c1.id_obra AND ult.max_id_contrato = c1.id_contrato" +
				") c ON c.id_obra = o.id_obra " +
				whereSql +
				" ORDER BY o.fecha_inicio DESC, o.nombre ASC LIMIT @limit OFFSET @offset";
			foreach (var param in countParams)
				cmd.Parameters.AddWithValue(param.ParameterName, param.Value);
			cmd.Parameters.AddWithValue("@limit", limit);
			cmd.Parameters.AddWithValue("@offset", offset);

			await using var reader = await cmd.ExecuteReaderAsync();
			while (await reader.ReadAsync())
			{
				obras.Add(MapObra(reader));
			}

			PostToJs(new
			{
				type = "obras_listar_response",
				requestId,
				success = true,
				obras,
				total,
				page,
				per_page = limit,
				total_pages = totalPages
			});
		}
		catch (Exception ex)
		{
			System.Diagnostics.Debug.WriteLine($"[Obras listar error] {ex}");
			PostToJs(new { type = "obras_listar_response", requestId, success = false, error = "No se pudieron cargar las obras." });
		}
	}

	private async Task HandleGuardarObraAsync(JsonElement root)
	{
		var requestId = root.TryGetProperty("requestId", out var requestIdProp)
			? requestIdProp.GetString() ?? string.Empty
			: string.Empty;

		if (!EnsureAdministrador(requestId, "obras_guardar_response"))
			return;

		try
		{
			var payload = ValidateObraPayload(root);
			var contrato = ReadContrato(root);
			var idObra = TryReadPositiveInt(root, "id_obra");

			await using var conn = new MySqlConnection(BuildConnectionString());
			await conn.OpenAsync();
			await using var tx = await conn.BeginTransactionAsync();

			if (idObra.HasValue)
			{
				if (!await ObraExistsAsync(conn, idObra.Value))
					throw new InvalidOperationException("La obra indicada no existe.");

				await using var updateCmd = conn.CreateCommand();
				updateCmd.Transaction = tx;
				updateCmd.CommandText =
					"UPDATE obras SET numero_contrata = @numeroContrata, nombre = @nombre, direccion = @direccion, descripcion = @descripcion, " +
					"fecha_inicio = @fechaInicio, fecha_fin = @fechaFin, nombre_cliente = @nombreCliente, telefono_cliente = @telefonoCliente " +
					"WHERE id_obra = @idObra";
				AddObraParameters(updateCmd, payload, idObra.Value);
				await updateCmd.ExecuteNonQueryAsync();

				if (contrato is not null)
					await GuardarContratoAsync(conn, tx, idObra.Value, contrato.Value.NombreArchivo, contrato.Value.Archivo);

				await tx.CommitAsync();

				var obra = await GetObraByIdAsync(conn, idObra.Value);
				PostToJs(new
				{
					type = "obras_guardar_response",
					requestId,
					success = true,
					message = "Obra actualizada correctamente.",
					obra
				});
				return;
			}

			var nuevaId = 0;
			await using (var insertCmd = conn.CreateCommand())
			{
				insertCmd.Transaction = tx;
				insertCmd.CommandText =
					"INSERT INTO obras (numero_contrata, nombre, direccion, descripcion, fecha_inicio, fecha_fin, nombre_cliente, telefono_cliente) " +
					"VALUES (@numeroContrata, @nombre, @direccion, @descripcion, @fechaInicio, @fechaFin, @nombreCliente, @telefonoCliente)";
				AddObraParameters(insertCmd, payload, null);
				await insertCmd.ExecuteNonQueryAsync();
				nuevaId = Convert.ToInt32(insertCmd.LastInsertedId);
			}

			if (contrato is not null)
				await GuardarContratoAsync(conn, tx, nuevaId, contrato.Value.NombreArchivo, contrato.Value.Archivo);

			await tx.CommitAsync();

			var nuevaObra = await GetObraByIdAsync(conn, nuevaId);
			PostToJs(new
			{
				type = "obras_guardar_response",
				requestId,
				success = true,
				message = "Obra guardada correctamente.",
				obra = nuevaObra
			});
		}
		catch (InvalidOperationException ex)
		{
			PostToJs(new { type = "obras_guardar_response", requestId, success = false, error = ex.Message });
		}
		catch (MySqlException ex) when (ex.Number == 1062)
		{
			PostToJs(new { type = "obras_guardar_response", requestId, success = false, error = "El número de contrata ya existe." });
		}
		catch (Exception ex)
		{
			System.Diagnostics.Debug.WriteLine($"[Obras guardar error] {ex}");
			PostToJs(new { type = "obras_guardar_response", requestId, success = false, error = "No se pudo guardar la obra." });
		}
	}

	private async Task HandleEliminarObraAsync(JsonElement root)
	{
		var requestId = root.TryGetProperty("requestId", out var requestIdProp)
			? requestIdProp.GetString() ?? string.Empty
			: string.Empty;

		if (!EnsureAdministrador(requestId, "obras_eliminar_response"))
			return;

		try
		{
			var idObra = ReadPositiveInt(root, "id_obra");

			await using var conn = new MySqlConnection(BuildConnectionString());
			await conn.OpenAsync();

			await using var cmd = conn.CreateCommand();
			cmd.CommandText = "DELETE FROM obras WHERE id_obra = @idObra";
			cmd.Parameters.AddWithValue("@idObra", idObra);
			var affected = await cmd.ExecuteNonQueryAsync();

			if (affected == 0)
				throw new InvalidOperationException("La obra indicada no existe.");

			PostToJs(new
			{
				type = "obras_eliminar_response",
				requestId,
				success = true,
				message = "Obra eliminada correctamente."
			});
		}
		catch (InvalidOperationException ex)
		{
			PostToJs(new { type = "obras_eliminar_response", requestId, success = false, error = ex.Message });
		}
		catch (MySqlException ex) when (ex.Number == 1451)
		{
			PostToJs(new { type = "obras_eliminar_response", requestId, success = false, error = "No se puede eliminar la obra porque tiene registros asociados." });
		}
		catch (Exception ex)
		{
			System.Diagnostics.Debug.WriteLine($"[Obras eliminar error] {ex}");
			PostToJs(new { type = "obras_eliminar_response", requestId, success = false, error = "No se pudo eliminar la obra." });
		}
	}

	private async Task HandleDescargarContratoAsync(JsonElement root)
	{
		var requestId = root.TryGetProperty("requestId", out var requestIdProp)
			? requestIdProp.GetString() ?? string.Empty
			: string.Empty;

		if (!EnsureAdministrador(requestId, "obras_descargar_contrato_response"))
			return;

		try
		{
			var idObra = ReadPositiveInt(root, "id_obra");

			await using var conn = new MySqlConnection(BuildConnectionString());
			await conn.OpenAsync();

			await using var cmd = conn.CreateCommand();
			cmd.CommandText =
				"SELECT nombre_archivo, archivo FROM contratos WHERE id_obra = @idObra ORDER BY id_contrato DESC LIMIT 1";
			cmd.Parameters.AddWithValue("@idObra", idObra);

			await using var reader = await cmd.ExecuteReaderAsync(System.Data.CommandBehavior.SequentialAccess);
			if (!await reader.ReadAsync())
				throw new InvalidOperationException("La obra no tiene contrato cargado.");

			var nombreArchivo = ReadNullableString(reader, "nombre_archivo") ?? $"contrato-{idObra}";
			var archivoOrdinal = reader.GetOrdinal("archivo");
			var archivo = (byte[])reader.GetValue(archivoOrdinal);

			PostToJs(new
			{
				type = "obras_descargar_contrato_response",
				requestId,
				success = true,
				nombre_archivo = nombreArchivo,
				tipo_contenido = GuessMimeType(nombreArchivo),
				contenido_base64 = Convert.ToBase64String(archivo)
			});
		}
		catch (InvalidOperationException ex)
		{
			PostToJs(new { type = "obras_descargar_contrato_response", requestId, success = false, error = ex.Message });
		}
		catch (Exception ex)
		{
			System.Diagnostics.Debug.WriteLine($"[Obras descargar contrato error] {ex}");
			PostToJs(new { type = "obras_descargar_contrato_response", requestId, success = false, error = "No se pudo descargar el contrato." });
		}
	}

	private async Task HandleObrerosListarAsync(JsonElement root)
	{
		var requestId = root.TryGetProperty("requestId", out var requestIdProp)
			? requestIdProp.GetString() ?? string.Empty
			: string.Empty;

		if (!EnsureAutenticado(requestId, "obreros_listar_response"))
			return;

		try
		{
			var page = 1;
			if (root.TryGetProperty("page", out var pageProp))
			{
				if (pageProp.ValueKind == JsonValueKind.Number && pageProp.TryGetInt32(out var pageNumber) && pageNumber > 0)
					page = pageNumber;
				else if (pageProp.ValueKind == JsonValueKind.String && int.TryParse(pageProp.GetString(), out pageNumber) && pageNumber > 0)
					page = pageNumber;
			}

			var limit = 10;
			if (root.TryGetProperty("limit", out var limitProp))
			{
				if (limitProp.ValueKind == JsonValueKind.Number && limitProp.TryGetInt32(out var limitNumber) && limitNumber > 0)
					limit = limitNumber;
				else if (limitProp.ValueKind == JsonValueKind.String && int.TryParse(limitProp.GetString(), out limitNumber) && limitNumber > 0)
					limit = limitNumber;
			}
			limit = Math.Clamp(limit, 1, 100);

			var search = root.TryGetProperty("search", out var searchProp) && searchProp.ValueKind == JsonValueKind.String
				? (searchProp.GetString()?.Trim() ?? string.Empty)
				: string.Empty;

			await using var conn = new MySqlConnection(BuildConnectionString());
			await conn.OpenAsync();

			var where = new List<string> { "activo = 1" };
			var countParams = new List<MySqlParameter>();

			if (!string.IsNullOrWhiteSpace(search))
			{
				where.Add("(nombre LIKE @search OR apellido LIKE @search OR documento LIKE @search OR telefono LIKE @search)");
				countParams.Add(new MySqlParameter("@search", $"%{search}%"));
			}

			var whereSql = " WHERE " + string.Join(" AND ", where);

			var total = 0;
			await using (var countCmd = conn.CreateCommand())
			{
				countCmd.CommandText = "SELECT COUNT(*) FROM obreros" + whereSql;
				foreach (var param in countParams)
					countCmd.Parameters.AddWithValue(param.ParameterName, param.Value);
				total = Convert.ToInt32(await countCmd.ExecuteScalarAsync());
			}

			var totalPages = Math.Max(1, (int)Math.Ceiling(total / (double)limit));
			page = Math.Min(page, totalPages);
			var offset = (page - 1) * limit;

			await using var cmd = conn.CreateCommand();
			cmd.CommandText =
				"SELECT id_obrero, nombre, apellido, documento, telefono, fecha_contratacion FROM obreros"
				+ whereSql
				+ " ORDER BY id_obrero DESC LIMIT @limit OFFSET @offset";

			foreach (var param in countParams)
				cmd.Parameters.AddWithValue(param.ParameterName, param.Value);
			cmd.Parameters.AddWithValue("@limit", limit);
			cmd.Parameters.AddWithValue("@offset", offset);

			var obreros = new List<object>();
			await using var reader = await cmd.ExecuteReaderAsync();
			while (await reader.ReadAsync())
			{
				obreros.Add(new
				{
					id_obrero = reader.GetInt32("id_obrero"),
					nombre = reader.GetString("nombre"),
					apellido = ReadNullableString(reader, "apellido"),
					documento = reader.GetString("documento"),
					telefono = ReadNullableString(reader, "telefono"),
					fecha_contratacion = ReadNullableDate(reader, "fecha_contratacion")
				});
			}

			PostToJs(new
			{
				type = "obreros_listar_response",
				requestId,
				success = true,
				obreros,
				total,
				page,
				per_page = limit,
				total_pages = totalPages
			});
		}
		catch (Exception ex)
		{
			System.Diagnostics.Debug.WriteLine($"[Obreros listar error] {ex}");
			PostToJs(new { type = "obreros_listar_response", requestId, success = false, error = "No se pudieron cargar los obreros." });
		}
	}

	private async Task HandleGuardarObreroAsync(JsonElement root)
	{
		var requestId = root.TryGetProperty("requestId", out var requestIdProp)
			? requestIdProp.GetString() ?? string.Empty
			: string.Empty;

		if (!EnsureAdministrador(requestId, "obreros_guardar_response"))
			return;

		try
		{
			var nombre = ReadRequiredString(root, "nombre");
			var apellido = root.TryGetProperty("apellido", out var apellidoProp) && apellidoProp.ValueKind == JsonValueKind.String
				? (apellidoProp.GetString()?.Trim() ?? string.Empty)
				: string.Empty;
			var documento = ReadRequiredString(root, "documento");
			var telefono = root.TryGetProperty("telefono", out var telefonoProp) && telefonoProp.ValueKind == JsonValueKind.String
				? (telefonoProp.GetString()?.Trim() ?? string.Empty)
				: string.Empty;
			var fechaContratacion = root.TryGetProperty("fecha_contratacion", out var fechaProp) && fechaProp.ValueKind == JsonValueKind.String
				? (fechaProp.GetString()?.Trim() ?? string.Empty)
				: string.Empty;
			var idObrero = TryReadPositiveInt(root, "id_obrero");

			if (nombre.Length > 150)
				throw new InvalidOperationException("El nombre es demasiado largo.");
			if (apellido.Length > 100)
				throw new InvalidOperationException("El apellido es demasiado largo.");
			if (documento.Length > 30)
				throw new InvalidOperationException("El documento es demasiado largo.");
			if (telefono.Length > 30)
				throw new InvalidOperationException("El teléfono es demasiado largo.");

			string? fechaDb = null;
			if (!string.IsNullOrWhiteSpace(fechaContratacion))
			{
				if (!DateTime.TryParseExact(fechaContratacion, "yyyy-MM-dd", System.Globalization.CultureInfo.InvariantCulture, System.Globalization.DateTimeStyles.None, out _))
					throw new InvalidOperationException("Formato de fecha inválido.");
				fechaDb = fechaContratacion;
			}

			await using var conn = new MySqlConnection(BuildConnectionString());
			await conn.OpenAsync();
			await using var tx = await conn.BeginTransactionAsync();

			if (idObrero.HasValue)
			{
				await using (var existsCmd = conn.CreateCommand())
				{
					existsCmd.Transaction = tx;
					existsCmd.CommandText = "SELECT id_obrero FROM obreros WHERE id_obrero = @idObrero LIMIT 1";
					existsCmd.Parameters.AddWithValue("@idObrero", idObrero.Value);
					var exists = await existsCmd.ExecuteScalarAsync();
					if (exists is null)
						throw new InvalidOperationException("El obrero indicado no existe.");
				}

				await using (var dupCmd = conn.CreateCommand())
				{
					dupCmd.Transaction = tx;
					dupCmd.CommandText = "SELECT id_obrero FROM obreros WHERE documento = @documento AND id_obrero <> @idObrero LIMIT 1";
					dupCmd.Parameters.AddWithValue("@documento", documento);
					dupCmd.Parameters.AddWithValue("@idObrero", idObrero.Value);
					var dup = await dupCmd.ExecuteScalarAsync();
					if (dup is not null)
						throw new InvalidOperationException("Ya existe otro obrero con ese documento.");
				}

				await using var updateCmd = conn.CreateCommand();
				updateCmd.Transaction = tx;
				updateCmd.CommandText =
					"UPDATE obreros SET nombre = @nombre, apellido = @apellido, documento = @documento, telefono = @telefono, fecha_contratacion = @fecha WHERE id_obrero = @idObrero";
				updateCmd.Parameters.AddWithValue("@nombre", nombre);
				updateCmd.Parameters.AddWithValue("@apellido", string.IsNullOrWhiteSpace(apellido) ? DBNull.Value : apellido);
				updateCmd.Parameters.AddWithValue("@documento", documento);
				updateCmd.Parameters.AddWithValue("@telefono", string.IsNullOrWhiteSpace(telefono) ? DBNull.Value : telefono);
				updateCmd.Parameters.AddWithValue("@fecha", fechaDb is null ? DBNull.Value : fechaDb);
				updateCmd.Parameters.AddWithValue("@idObrero", idObrero.Value);
				await updateCmd.ExecuteNonQueryAsync();

				await tx.CommitAsync();

				PostToJs(new
				{
					type = "obreros_guardar_response",
					requestId,
					success = true,
					message = "Obrero actualizado correctamente."
				});
				return;
			}

			await using (var dupCmd = conn.CreateCommand())
			{
				dupCmd.Transaction = tx;
				dupCmd.CommandText = "SELECT id_obrero FROM obreros WHERE documento = @documento LIMIT 1";
				dupCmd.Parameters.AddWithValue("@documento", documento);
				var dup = await dupCmd.ExecuteScalarAsync();
				if (dup is not null)
					throw new InvalidOperationException("Ya existe un obrero con ese documento.");
			}

			await using var insertCmd = conn.CreateCommand();
			insertCmd.Transaction = tx;
			insertCmd.CommandText =
				"INSERT INTO obreros (nombre, apellido, documento, telefono, fecha_contratacion, activo) VALUES (@nombre, @apellido, @documento, @telefono, @fecha, 1)";
			insertCmd.Parameters.AddWithValue("@nombre", nombre);
			insertCmd.Parameters.AddWithValue("@apellido", string.IsNullOrWhiteSpace(apellido) ? DBNull.Value : apellido);
			insertCmd.Parameters.AddWithValue("@documento", documento);
			insertCmd.Parameters.AddWithValue("@telefono", string.IsNullOrWhiteSpace(telefono) ? DBNull.Value : telefono);
			insertCmd.Parameters.AddWithValue("@fecha", fechaDb is null ? DBNull.Value : fechaDb);
			await insertCmd.ExecuteNonQueryAsync();

			await tx.CommitAsync();

			PostToJs(new
			{
				type = "obreros_guardar_response",
				requestId,
				success = true,
				message = "Obrero registrado correctamente."
			});
		}
		catch (InvalidOperationException ex)
		{
			PostToJs(new { type = "obreros_guardar_response", requestId, success = false, error = ex.Message });
		}
		catch (MySqlException ex) when (ex.Number == 1062)
		{
			PostToJs(new { type = "obreros_guardar_response", requestId, success = false, error = "Ya existe un obrero con ese documento." });
		}
		catch (Exception ex)
		{
			System.Diagnostics.Debug.WriteLine($"[Obreros guardar error] {ex}");
			PostToJs(new { type = "obreros_guardar_response", requestId, success = false, error = "No se pudo guardar el obrero." });
		}
	}

	private async Task HandleEliminarObreroAsync(JsonElement root)
	{
		var requestId = root.TryGetProperty("requestId", out var requestIdProp)
			? requestIdProp.GetString() ?? string.Empty
			: string.Empty;

		if (!EnsureAdministrador(requestId, "obreros_eliminar_response"))
			return;

		try
		{
			var idObrero = ReadPositiveInt(root, "id_obrero");

			await using var conn = new MySqlConnection(BuildConnectionString());
			await conn.OpenAsync();

			await using var cmd = conn.CreateCommand();
			cmd.CommandText = "UPDATE obreros SET activo = 0 WHERE id_obrero = @idObrero";
			cmd.Parameters.AddWithValue("@idObrero", idObrero);
			var affected = await cmd.ExecuteNonQueryAsync();

			if (affected == 0)
				throw new InvalidOperationException("El obrero indicado no existe.");

			PostToJs(new
			{
				type = "obreros_eliminar_response",
				requestId,
				success = true,
				message = "Obrero eliminado correctamente."
			});
		}
		catch (InvalidOperationException ex)
		{
			PostToJs(new { type = "obreros_eliminar_response", requestId, success = false, error = ex.Message });
		}
		catch (Exception ex)
		{
			System.Diagnostics.Debug.WriteLine($"[Obreros eliminar error] {ex}");
			PostToJs(new { type = "obreros_eliminar_response", requestId, success = false, error = "No se pudo eliminar el obrero." });
		}
	}

	private async Task HandleGuardarAsistenciaAsync(JsonElement root)
	{
		var requestId = root.TryGetProperty("requestId", out var requestIdProp)
			? requestIdProp.GetString() ?? string.Empty
			: string.Empty;

		if (!EnsureCapatazOAdmin(requestId, "asistencia_guardar_response"))
			return;

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

	private static string ReadRequestId(JsonElement root)
	{
		return root.TryGetProperty("requestId", out var requestIdProp)
			? requestIdProp.GetString() ?? string.Empty
			: string.Empty;
	}

	private bool EnsureAdministrador(string requestId, string responseType)
	{
		if (_currentUserId is null)
		{
			PostToJs(new { type = responseType, requestId, success = false, error = "Sesión no válida. Iniciá sesión nuevamente." });
			return false;
		}

		if (!string.Equals(_currentRol, "Administrador", StringComparison.Ordinal))
		{
			PostToJs(new { type = responseType, requestId, success = false, error = "No tenés permisos para gestionar usuarios." });
			return false;
		}

		return true;
	}

	private bool EnsureAutenticado(string requestId, string responseType)
	{
		if (_currentUserId is null)
		{
			PostToJs(new { type = responseType, requestId, success = false, error = "Sesión no válida. Iniciá sesión nuevamente." });
			return false;
		}
		return true;
	}

	private bool EnsureCapatazOAdmin(string requestId, string responseType)
	{
		if (_currentUserId is null)
		{
			PostToJs(new { type = responseType, requestId, success = false, error = "Sesión no válida. Iniciá sesión nuevamente." });
			return false;
		}

		if (!string.Equals(_currentRol, "Administrador", StringComparison.Ordinal) &&
		    !string.Equals(_currentRol, "Capataz", StringComparison.Ordinal))
		{
			PostToJs(new { type = responseType, requestId, success = false, error = "No tenés permisos para esta acción." });
			return false;
		}

		return true;
	}

	private static int? TryReadPositiveInt(JsonElement root, string propertyName)
	{
		if (!root.TryGetProperty(propertyName, out var prop))
			return null;

		if (prop.ValueKind == JsonValueKind.Null)
			return null;

		if (prop.ValueKind == JsonValueKind.Number && prop.TryGetInt32(out var number) && number > 0)
			return number;

		if (prop.ValueKind == JsonValueKind.String)
		{
			var text = prop.GetString()?.Trim();
			if (string.IsNullOrWhiteSpace(text))
				return null;

			if (int.TryParse(text, out number) && number > 0)
				return number;
		}

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

	private static string ReadPasswordString(JsonElement root, string propertyName, bool required)
	{
		if (!root.TryGetProperty(propertyName, out var prop) || prop.ValueKind != JsonValueKind.String)
		{
			if (required)
				throw new InvalidOperationException($"Falta el campo {propertyName}.");

			return string.Empty;
		}

		var value = prop.GetString() ?? string.Empty;
		if (required && value.Length == 0)
			throw new InvalidOperationException($"El campo {propertyName} es obligatorio.");

		return value;
	}

	private static void ValidateUserFields(string nombre, string usuario, string password, string rol, bool validatePassword)
	{
		if (nombre.Length == 0)
			throw new InvalidOperationException("El nombre completo es obligatorio.");

		if (nombre.Length > 100)
			throw new InvalidOperationException("El nombre completo es demasiado largo.");

		if (usuario.Length == 0)
			throw new InvalidOperationException("El nombre de usuario es obligatorio.");

		if (usuario.Length > 50)
			throw new InvalidOperationException("El nombre de usuario es demasiado largo.");

		if (validatePassword)
		{
			if (password.Length < 6)
				throw new InvalidOperationException("La contraseña debe tener al menos 6 caracteres.");

			if (password.Length > 255)
				throw new InvalidOperationException("La contraseña es demasiado larga.");
		}

		if (!string.Equals(rol, "Administrador", StringComparison.Ordinal) &&
		    !string.Equals(rol, "Capataz", StringComparison.Ordinal))
		{
			throw new InvalidOperationException("Seleccione un rol válido.");
		}
	}

	private static Dictionary<string, object?> ValidateObraPayload(JsonElement root)
	{
		var numeroContrata = SanitizeText(root, "numero_contrata", 50, true);
		var nombre = SanitizeText(root, "nombre", 150, true);
		var direccion = SanitizeText(root, "direccion", 200, false);
		var descripcion = SanitizeText(root, "descripcion", 65535, false);
		var fechaInicio = NormalizeDate(root, "fecha_inicio");
		var fechaFin = NormalizeDate(root, "fecha_fin");
		var nombreCliente = SanitizeText(root, "nombre_cliente", 150, true);
		var telefonoCliente = SanitizeText(root, "telefono_cliente", 30, false);

		if (fechaInicio is not null && fechaFin is not null && string.CompareOrdinal(fechaFin, fechaInicio) < 0)
			throw new InvalidOperationException("La fecha de fin no puede ser menor a la de inicio.");

		return new Dictionary<string, object?>
		{
			["numero_contrata"] = numeroContrata,
			["nombre"] = nombre,
			["direccion"] = direccion,
			["descripcion"] = descripcion,
			["fecha_inicio"] = fechaInicio,
			["fecha_fin"] = fechaFin,
			["nombre_cliente"] = nombreCliente,
			["telefono_cliente"] = telefonoCliente
		};
	}

	private static (string NombreArchivo, byte[] Archivo)? ReadContrato(JsonElement root)
	{
		if (!root.TryGetProperty("contrato", out var contratoProp) || contratoProp.ValueKind != JsonValueKind.Object)
			return null;

		var nombreArchivo = SanitizeText(contratoProp, "nombre_archivo", 255, true);
		var contenidoBase64 = ReadRequiredString(contratoProp, "contenido_base64");

		byte[] archivo;
		try
		{
			archivo = Convert.FromBase64String(contenidoBase64);
		}
		catch (FormatException)
		{
			throw new InvalidOperationException("El contrato seleccionado es inválido.");
		}

		if (archivo.Length > 10 * 1024 * 1024)
			throw new InvalidOperationException("El contrato no puede superar los 10 MB.");

		return (nombreArchivo, archivo);
	}

	private static string SanitizeText(JsonElement root, string propertyName, int maxLength, bool required)
	{
		var value = root.TryGetProperty(propertyName, out var prop) && prop.ValueKind == JsonValueKind.String
			? prop.GetString()?.Trim() ?? string.Empty
			: string.Empty;

		if (value.Length == 0)
		{
			if (required)
				throw new InvalidOperationException("Número de contrata, nombre de la obra y cliente son obligatorios.");

			return string.Empty;
		}

		if (value.Length > maxLength)
			throw new InvalidOperationException("Uno de los campos supera la longitud permitida.");

		return value;
	}

	private static string? NormalizeDate(JsonElement root, string propertyName)
	{
		if (!root.TryGetProperty(propertyName, out var prop) || prop.ValueKind != JsonValueKind.String)
			return null;

		var value = prop.GetString()?.Trim() ?? string.Empty;
		if (value.Length == 0)
			return null;

		if (!DateTime.TryParseExact(value, "yyyy-MM-dd", System.Globalization.CultureInfo.InvariantCulture, System.Globalization.DateTimeStyles.None, out var date))
			throw new InvalidOperationException("Formato de fecha inválido.");

		return date.ToString("yyyy-MM-dd", System.Globalization.CultureInfo.InvariantCulture);
	}

	private static string CalcularHorasTrabajadas(string horaEntrada, string horaSalida)
	{
		var entrada = TimeSpan.Parse(horaEntrada);
		var salida = TimeSpan.Parse(horaSalida);
		if (salida <= entrada)
			throw new InvalidOperationException("La hora de salida debe ser mayor a la de entrada.");

		return ((decimal)(salida - entrada).TotalHours).ToString("0.00", System.Globalization.CultureInfo.InvariantCulture);
	}

	private static void AddObraParameters(MySqlCommand cmd, Dictionary<string, object?> payload, int? idObra)
	{
		cmd.Parameters.AddWithValue("@numeroContrata", payload["numero_contrata"]);
		cmd.Parameters.AddWithValue("@nombre", payload["nombre"]);
		cmd.Parameters.AddWithValue("@direccion", ToDbValue(payload["direccion"]));
		cmd.Parameters.AddWithValue("@descripcion", ToDbValue(payload["descripcion"]));
		cmd.Parameters.AddWithValue("@fechaInicio", ToDbValue(payload["fecha_inicio"]));
		cmd.Parameters.AddWithValue("@fechaFin", ToDbValue(payload["fecha_fin"]));
		cmd.Parameters.AddWithValue("@nombreCliente", payload["nombre_cliente"]);
		cmd.Parameters.AddWithValue("@telefonoCliente", ToDbValue(payload["telefono_cliente"]));

		if (idObra.HasValue)
			cmd.Parameters.AddWithValue("@idObra", idObra.Value);
	}

	private static object ToDbValue(object? value)
	{
		if (value is null)
			return DBNull.Value;

		if (value is string text && string.IsNullOrWhiteSpace(text))
			return DBNull.Value;

		return value;
	}

	private static object MapObra(MySqlDataReader reader)
	{
		return new
		{
			id_obra = reader.GetInt32("id_obra"),
			numero_contrata = reader.GetString("numero_contrata"),
			nombre = reader.GetString("nombre"),
			direccion = ReadNullableString(reader, "direccion"),
			descripcion = ReadNullableString(reader, "descripcion"),
			fecha_inicio = ReadNullableDate(reader, "fecha_inicio"),
			fecha_fin = ReadNullableDate(reader, "fecha_fin"),
			nombre_cliente = reader.GetString("nombre_cliente"),
			telefono_cliente = ReadNullableString(reader, "telefono_cliente"),
			activo = Convert.ToInt32(reader["activo"]),
			contrato_nombre_archivo = ReadNullableString(reader, "contrato_nombre_archivo")
		};
	}

	private static string? ReadNullableString(MySqlDataReader reader, string columnName)
	{
		var ordinal = reader.GetOrdinal(columnName);
		return reader.IsDBNull(ordinal) ? null : reader.GetString(ordinal);
	}

	private static string? ReadNullableDate(MySqlDataReader reader, string columnName)
	{
		var ordinal = reader.GetOrdinal(columnName);
		if (reader.IsDBNull(ordinal))
			return null;

		return reader.GetDateTime(ordinal).ToString("yyyy-MM-dd", System.Globalization.CultureInfo.InvariantCulture);
	}

	private static async Task<bool> ObraExistsAsync(MySqlConnection conn, int idObra)
	{
		await using var cmd = conn.CreateCommand();
		cmd.CommandText = "SELECT 1 FROM obras WHERE id_obra = @idObra LIMIT 1";
		cmd.Parameters.AddWithValue("@idObra", idObra);
		var result = await cmd.ExecuteScalarAsync();
		return result is not null;
	}

	private static async Task<object> GetObraByIdAsync(MySqlConnection conn, int idObra)
	{
		await using var cmd = conn.CreateCommand();
		cmd.CommandText =
			"SELECT o.id_obra, o.numero_contrata, o.nombre, o.direccion, o.descripcion, o.fecha_inicio, o.fecha_fin, o.nombre_cliente, o.telefono_cliente, o.activo, " +
			"c.nombre_archivo AS contrato_nombre_archivo " +
			"FROM obras o " +
			"LEFT JOIN (" +
			"SELECT c1.id_obra, c1.nombre_archivo FROM contratos c1 " +
			"INNER JOIN (SELECT id_obra, MAX(id_contrato) AS max_id_contrato FROM contratos GROUP BY id_obra) ult " +
			"ON ult.id_obra = c1.id_obra AND ult.max_id_contrato = c1.id_contrato" +
			") c ON c.id_obra = o.id_obra " +
			"WHERE o.id_obra = @idObra LIMIT 1";
		cmd.Parameters.AddWithValue("@idObra", idObra);

		await using var reader = await cmd.ExecuteReaderAsync();
		if (!await reader.ReadAsync())
			throw new InvalidOperationException("La obra indicada no existe.");

		return MapObra(reader);
	}

	private static async Task GuardarContratoAsync(MySqlConnection conn, MySqlTransaction tx, int idObra, string nombreArchivo, byte[] archivo)
	{
		await using (var deleteCmd = conn.CreateCommand())
		{
			deleteCmd.Transaction = tx;
			deleteCmd.CommandText = "DELETE FROM contratos WHERE id_obra = @idObra";
			deleteCmd.Parameters.AddWithValue("@idObra", idObra);
			await deleteCmd.ExecuteNonQueryAsync();
		}

		await using var insertCmd = conn.CreateCommand();
		insertCmd.Transaction = tx;
		insertCmd.CommandText =
			"INSERT INTO contratos (id_obra, archivo, nombre_archivo, fecha_subida) VALUES (@idObra, @archivo, @nombreArchivo, CURDATE())";
		insertCmd.Parameters.AddWithValue("@idObra", idObra);
		insertCmd.Parameters.Add("@archivo", MySqlDbType.LongBlob).Value = archivo;
		insertCmd.Parameters.AddWithValue("@nombreArchivo", nombreArchivo);
		await insertCmd.ExecuteNonQueryAsync();
	}

	private static string GuessMimeType(string nombreArchivo)
	{
		var extension = Path.GetExtension(nombreArchivo)?.ToLowerInvariant();
		return extension switch
		{
			".pdf" => "application/pdf",
			".doc" => "application/msword",
			".docx" => "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
			_ => "application/octet-stream"
		};
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

	private void OnWebResourceRequested(object? sender, CoreWebView2WebResourceRequestedEventArgs args)
	{
		var uri = new Uri(args.Request.Uri);
		if (!uri.Host.Equals("portico.desktop", StringComparison.OrdinalIgnoreCase))
			return;

		var path = uri.AbsolutePath.TrimStart('/');
		if (string.IsNullOrEmpty(path))
			path = "Login.html";

		var resourceName = MapPathToResourceName(path);
		var stream = GetType().Assembly.GetManifestResourceStream(resourceName);
		if (stream is null)
		{
			args.Response = _webView.CoreWebView2.Environment.CreateWebResourceResponse(
				new MemoryStream(0), 404, "Not Found", "Content-Type: text/plain");
			return;
		}

		var mime = GetMimeTypeForWebAsset(path);
		args.Response = _webView.CoreWebView2.Environment.CreateWebResourceResponse(
			stream, 200, "OK", $"Content-Type: {mime}");
	}

	private static string MapPathToResourceName(string path)
	{
		return "webui." + path.Replace('/', '.').Replace('\\', '.');
	}

	private static string GetMimeTypeForWebAsset(string path)
	{
		var extension = Path.GetExtension(path).ToLowerInvariant();
		return extension switch
		{
			".html" => "text/html",
			".css" => "text/css",
			".js" => "application/javascript",
			".json" => "application/json",
			".png" => "image/png",
			".jpg" => "image/jpeg",
			".jpeg" => "image/jpeg",
			".gif" => "image/gif",
			".svg" => "image/svg+xml",
			".ico" => "image/x-icon",
			".woff2" => "font/woff2",
			".woff" => "font/woff",
			".ttf" => "font/ttf",
			_ => "application/octet-stream"
		};
	}

	private void ShowError(string message)
	{
		var safe = message.Replace("<", "&lt;").Replace(">", "&gt;");
		_webView.NavigateToString($"<html><body style='font-family:Segoe UI;padding:20px;'><h2>Portico Desktop</h2><p>{safe}</p></body></html>");
	}
}
