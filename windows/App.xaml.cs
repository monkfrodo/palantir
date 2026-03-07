using System.IO;
using System.Net.Http;
using System.Text.Json;
using System.Windows;
using Microsoft.Win32;

namespace Palantir;

public partial class App : Application
{
    public static string BaseDir { get; private set; } = string.Empty;
    public static string WallpapersDir { get; private set; } = string.Empty;
    public static string FramesDir { get; private set; } = string.Empty;
    public static string SettingsFile { get; private set; } = string.Empty;

    private TrayIconManager? _trayManager;

    protected override async void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        // Always use %USERPROFILE%\.palantir\ as base directory
        BaseDir = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
            ".palantir"
        );

        WallpapersDir = Path.Combine(BaseDir, "wallpapers");
        FramesDir = Path.Combine(BaseDir, ".frames");
        SettingsFile = Path.Combine(BaseDir, "settings.json");

        // Ensure directories exist
        Directory.CreateDirectory(WallpapersDir);
        Directory.CreateDirectory(FramesDir);

        // Copy exe to .palantir if running from elsewhere (e.g. Downloads)
        CopyExeToBaseDir();

        // First run: download wallpapers + set auto-start
        bool isFirstRun = !File.Exists(SettingsFile);
        if (isFirstRun)
        {
            SetAutoStart(true);
            await DownloadWallpapersFromRelease();
        }

        // Initialize tray icon and wallpaper manager
        _trayManager = new TrayIconManager();
        _trayManager.Initialize();

        // Restore saved wallpaper
        _trayManager.WallpaperManager.LoadWallpapers();
        _trayManager.WallpaperManager.RestoreSaved();

        // Start auto-updater
        var updater = new Core.AutoUpdater();
        updater.StartChecking(() =>
        {
            Current.Dispatcher.Invoke(() =>
            {
                _trayManager.WallpaperManager.LoadWallpapers();
            });
        });

        // Show gallery on first run so user sees it worked
        if (isFirstRun)
        {
            _trayManager.OpenGalleryPublic();
        }
    }

    private void CopyExeToBaseDir()
    {
        try
        {
            var currentExe = Environment.ProcessPath;
            if (string.IsNullOrEmpty(currentExe)) return;

            var destExe = Path.Combine(BaseDir, "Palantir.exe");

            // Don't copy if already running from BaseDir
            if (Path.GetDirectoryName(currentExe)?.Equals(BaseDir, StringComparison.OrdinalIgnoreCase) == true)
                return;

            File.Copy(currentExe, destExe, true);
        }
        catch { }
    }

    private static void SetAutoStart(bool enable)
    {
        try
        {
            using var key = Registry.CurrentUser.OpenSubKey(
                @"Software\Microsoft\Windows\CurrentVersion\Run", true);
            if (key == null) return;

            var exePath = Path.Combine(BaseDir, "Palantir.exe");
            if (enable)
                key.SetValue("Palantir", $"\"{exePath}\"", RegistryValueKind.String);
            else
                key.DeleteValue("Palantir", false);
        }
        catch { }
    }

    private static async Task DownloadWallpapersFromRelease()
    {
        try
        {
            using var http = new HttpClient();
            http.DefaultRequestHeaders.UserAgent.ParseAdd("Palantir/1.0");

            var json = await http.GetStringAsync(
                "https://api.github.com/repos/monkfrodo/palantir/releases/latest");
            using var doc = JsonDocument.Parse(json);

            if (!doc.RootElement.TryGetProperty("assets", out var assets))
                return;

            string[] supportedExts = { ".mov", ".mp4", ".m4v" };

            foreach (var asset in assets.EnumerateArray())
            {
                var rawName = asset.GetProperty("name").GetString();
                var downloadUrl = asset.GetProperty("browser_download_url").GetString();
                if (string.IsNullOrEmpty(rawName) || string.IsNullOrEmpty(downloadUrl))
                    continue;

                var ext = Path.GetExtension(rawName).ToLowerInvariant();
                if (!supportedExts.Contains(ext))
                    continue;

                // GitHub replaces spaces with dots — restore them
                var nameWithoutExt = Path.GetFileNameWithoutExtension(rawName).Replace('.', ' ');
                var cleanName = $"{nameWithoutExt}{ext}";
                var destPath = Path.Combine(WallpapersDir, cleanName);

                if (File.Exists(destPath)) continue;

                using var stream = await http.GetStreamAsync(downloadUrl);
                using var fs = new FileStream(destPath, FileMode.Create);
                await stream.CopyToAsync(fs);
            }
        }
        catch { }
    }

    protected override void OnExit(ExitEventArgs e)
    {
        _trayManager?.Dispose();
        base.OnExit(e);
    }
}
