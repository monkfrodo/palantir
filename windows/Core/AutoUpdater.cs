using System.IO;
using System.Net.Http;
using System.Text.Json;
using System.Windows;

namespace Palantir.Core;

/// <summary>
/// Checks GitHub releases every 6 hours for new wallpapers and downloads them automatically.
/// </summary>
public class AutoUpdater
{
    private const string Repo = "monkfrodo/palantir";
    private const string ApiUrl = "https://api.github.com/repos/monkfrodo/palantir/releases/latest";
    private static readonly TimeSpan CheckInterval = TimeSpan.FromHours(6);
    private static readonly TimeSpan InitialDelay = TimeSpan.FromSeconds(30);
    private static readonly string[] SupportedExtensions = { ".mov", ".mp4", ".m4v" };

    private Timer? _timer;
    private readonly HttpClient _httpClient;
    private Action? _onNewWallpapers;

    public AutoUpdater()
    {
        _httpClient = new HttpClient();
        _httpClient.DefaultRequestHeaders.UserAgent.ParseAdd("Palantir/1.0");
    }

    public void StartChecking(Action onNewWallpapers)
    {
        _onNewWallpapers = onNewWallpapers;

        // Check once after initial delay, then every 6 hours
        _timer = new Timer(
            _ => _ = CheckForNewWallpapers(),
            null,
            InitialDelay,
            CheckInterval
        );
    }

    private async Task CheckForNewWallpapers()
    {
        try
        {
            var response = await _httpClient.GetStringAsync(ApiUrl);
            using var doc = JsonDocument.Parse(response);
            var root = doc.RootElement;

            if (!root.TryGetProperty("assets", out var assets))
                return;

            var existingFiles = Directory.Exists(App.WallpapersDir)
                ? Directory.GetFiles(App.WallpapersDir).Select(Path.GetFileName).ToHashSet(StringComparer.OrdinalIgnoreCase)
                : new HashSet<string>(StringComparer.OrdinalIgnoreCase);

            int downloaded = 0;

            foreach (var asset in assets.EnumerateArray())
            {
                var rawName = asset.GetProperty("name").GetString();
                var downloadUrl = asset.GetProperty("browser_download_url").GetString();

                if (string.IsNullOrEmpty(rawName) || string.IsNullOrEmpty(downloadUrl))
                    continue;

                var ext = Path.GetExtension(rawName).ToLowerInvariant();
                if (!SupportedExtensions.Contains(ext))
                    continue;

                // GitHub replaces spaces with dots in asset names — restore them
                var nameWithoutExt = Path.GetFileNameWithoutExtension(rawName).Replace('.', ' ');
                var cleanName = $"{nameWithoutExt}{ext}";

                if (existingFiles.Contains(cleanName))
                    continue;

                try
                {
                    var destPath = Path.Combine(App.WallpapersDir, cleanName);
                    using var stream = await _httpClient.GetStreamAsync(downloadUrl);
                    using var fileStream = new FileStream(destPath, FileMode.Create, FileAccess.Write, FileShare.None);
                    await stream.CopyToAsync(fileStream);
                    downloaded++;
                }
                catch
                {
                    // Download failure for individual file is non-fatal
                }
            }

            if (downloaded > 0)
            {
                Application.Current?.Dispatcher.Invoke(() =>
                {
                    _onNewWallpapers?.Invoke();
                });

                SendNotification(downloaded);
            }
        }
        catch
        {
            // Network failures are expected (offline, rate-limited, etc.)
        }
    }

    private void SendNotification(int count)
    {
        try
        {
            Application.Current?.Dispatcher.Invoke(() =>
            {
                var message = count == 1
                    ? "1 new wallpaper downloaded. Open the gallery to check it out!"
                    : $"{count} new wallpapers downloaded. Open the gallery to check them out!";

                TrayIconManager.ShowBalloon("Palantir", message);
            });
        }
        catch
        {
            // Notification failure is non-fatal
        }
    }
}
