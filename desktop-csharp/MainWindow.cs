using System;
using System.IO;
using System.Windows.Forms;
using Microsoft.Web.WebView2.Core;
using Microsoft.Web.WebView2.WinForms;

namespace PorticoDesktop;

public sealed class MainWindow : Form
{
	private readonly WebView2 _webView;

	public MainWindow()
	{
		Text = "Portico Desktop";
		StartPosition = FormStartPosition.CenterScreen;
		Width = 1920;
		Height = 1080;

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
			await _webView.EnsureCoreWebView2Async();
			_webView.CoreWebView2.Settings.AreDevToolsEnabled = false;
			_webView.CoreWebView2.Settings.AreDefaultContextMenusEnabled = false;

			var loginPath = ResolveLoginHtmlPath();
			if (loginPath is null)
			{
				ShowError("No se encontro web-ui/PanelInicio.html.");
				return;
			}

			_webView.Source = new Uri(loginPath);
		}
		catch (WebView2RuntimeNotFoundException)
		{
			ShowError("No se encontro WebView2 Runtime. Instala Microsoft Edge WebView2 Runtime para visualizar las pantallas correctamente.");
		}
		catch (Exception ex)
		{
			ShowError($"Error inicializando navegador: {ex.Message}");
		}
	}

	private static string? ResolveLoginHtmlPath()
	{
		var directPath = Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "web-ui", "PanelInicio.html"));
		if (File.Exists(directPath))
		{
			return directPath;
		}

		var dir = new DirectoryInfo(AppContext.BaseDirectory);
		while (dir is not null)
		{
			var candidate = Path.Combine(dir.FullName, "web-ui", "PanelInicio.html");
			if (File.Exists(candidate))
			{
				return candidate;
			}

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
