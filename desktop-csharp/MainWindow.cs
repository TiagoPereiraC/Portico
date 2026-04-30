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
			var nombre       = reader.GetString("nombre");
			var rol          = reader.GetString("rol");

			// BCrypt.Net-Next verifica hashes $2y$ de PHP y $2a$ de C#
			var hashValido = BCrypt.Net.BCrypt.Verify(password, passwordHash);

			if (activo == 0 || !hashValido)
			{
				PostToJs(new { type = "login_response", success = false, error = "Usuario o contraseña incorrectos." });
				return;
			}

			PostToJs(new { type = "login_response", success = true, nombre, rol });

			// Navegar al panel principal en el hilo de UI
			Invoke(() =>
			{
				var panelPath = ResolveHtmlPath("PanelInicio.html");
				if (panelPath is not null)
					_webView.Source = new Uri(panelPath);
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
