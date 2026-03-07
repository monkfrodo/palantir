using System.IO;
using System.Windows;

namespace Palantir;

public partial class App : Application
{
    public static string BaseDir { get; private set; } = string.Empty;
    public static string WallpapersDir { get; private set; } = string.Empty;
    public static string FramesDir { get; private set; } = string.Empty;
    public static string SettingsFile { get; private set; } = string.Empty;

    private TrayIconManager? _trayManager;

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        // Resolve base directory: %USERPROFILE%\.palantir\ or exe directory
        var homePalantir = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
            ".palantir"
        );

        if (Directory.Exists(homePalantir))
        {
            BaseDir = homePalantir;
        }
        else
        {
            var exeDir = AppContext.BaseDirectory;
            BaseDir = exeDir;
        }

        WallpapersDir = Path.Combine(BaseDir, "wallpapers");
        FramesDir = Path.Combine(BaseDir, ".frames");
        SettingsFile = Path.Combine(BaseDir, "settings.json");

        // Ensure directories exist
        Directory.CreateDirectory(WallpapersDir);
        Directory.CreateDirectory(FramesDir);

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
    }

    protected override void OnExit(ExitEventArgs e)
    {
        _trayManager?.Dispose();
        base.OnExit(e);
    }
}
