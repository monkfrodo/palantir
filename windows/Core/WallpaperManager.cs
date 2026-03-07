using System.ComponentModel;
using System.IO;
using System.Runtime.CompilerServices;
using System.Text.Json;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Interop;
using System.Windows.Media;
using Microsoft.Win32;
using WinFormsScreen = System.Windows.Forms.Screen;

namespace Palantir.Core;

/// <summary>
/// Manages live wallpaper playback across all monitors using the WorkerW injection hack.
/// </summary>
public class WallpaperManager : INotifyPropertyChanged
{
    private readonly List<WallpaperItem> _wallpapers = new();
    private readonly List<Window> _wallpaperWindows = new();
    private readonly List<MediaElement> _mediaElements = new();

    private string? _activeDesktopWallpaper;
    private string? _activeLockScreenWallpaper;

    public IReadOnlyList<WallpaperItem> Wallpapers => _wallpapers;

    public string? ActiveDesktopWallpaper
    {
        get => _activeDesktopWallpaper;
        private set { _activeDesktopWallpaper = value; OnPropertyChanged(); }
    }

    public string? ActiveLockScreenWallpaper
    {
        get => _activeLockScreenWallpaper;
        private set { _activeLockScreenWallpaper = value; OnPropertyChanged(); }
    }

    public event PropertyChangedEventHandler? PropertyChanged;

    private void OnPropertyChanged([CallerMemberName] string? name = null)
    {
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
    }

    private static readonly string[] SupportedExtensions = { ".mov", ".mp4", ".m4v", ".wmv", ".avi" };

    public void LoadWallpapers()
    {
        _wallpapers.Clear();

        if (!Directory.Exists(App.WallpapersDir))
            return;

        var files = Directory.GetFiles(App.WallpapersDir)
            .Where(f => SupportedExtensions.Contains(Path.GetExtension(f).ToLowerInvariant()))
            .OrderBy(f => Path.GetFileName(f), StringComparer.OrdinalIgnoreCase)
            .ToList();

        foreach (var file in files)
        {
            _wallpapers.Add(new WallpaperItem(file));
        }

        // Load lock screen from settings
        var settings = LoadSettings();
        _activeLockScreenWallpaper = settings.LockScreenWallpaper;

        OnPropertyChanged(nameof(Wallpapers));
    }

    public void SetDesktop(WallpaperItem item)
    {
        StopDesktop();

        ActiveDesktopWallpaper = item.FileName;
        SaveSettings();

        IntPtr workerW = WorkerWHack.GetWorkerW();
        if (workerW == IntPtr.Zero)
        {
            System.Windows.MessageBox.Show(
                "Could not find the desktop WorkerW window.\nThis may happen if your Windows shell is not standard.",
                "Palantir",
                MessageBoxButton.OK,
                MessageBoxImage.Warning);
            return;
        }

        // Create one borderless window per monitor
        foreach (var screen in WinFormsScreen.AllScreens)
        {
            var window = new Window
            {
                WindowStyle = WindowStyle.None,
                ResizeMode = ResizeMode.NoResize,
                ShowInTaskbar = false,
                ShowActivated = false,
                AllowsTransparency = false,
                Background = System.Windows.Media.Brushes.Black,
                Left = screen.Bounds.Left,
                Top = screen.Bounds.Top,
                Width = screen.Bounds.Width,
                Height = screen.Bounds.Height,
            };

            var mediaElement = new MediaElement
            {
                Source = new Uri(item.FilePath, UriKind.Absolute),
                LoadedBehavior = MediaState.Manual,
                UnloadedBehavior = MediaState.Manual,
                Stretch = Stretch.UniformToFill,
                IsMuted = true,
                IsHitTestVisible = false,
            };

            // Loop video
            mediaElement.MediaEnded += (s, e) =>
            {
                mediaElement.Position = TimeSpan.Zero;
                mediaElement.Play();
            };

            window.Content = mediaElement;
            window.Show();

            // Get the HWND after showing the window
            var helper = new WindowInteropHelper(window);
            IntPtr hwnd = helper.Handle;

            // Embed into WorkerW
            WorkerWHack.EmbedWindow(
                hwnd,
                workerW,
                screen.Bounds.Left,
                screen.Bounds.Top,
                screen.Bounds.Width,
                screen.Bounds.Height
            );

            mediaElement.Play();

            _wallpaperWindows.Add(window);
            _mediaElements.Add(mediaElement);
        }
    }

    public void SetLockScreen(WallpaperItem item)
    {
        ActiveLockScreenWallpaper = item.FileName;
        SaveSettings();

        // Extract a high-quality frame and set as lock screen image
        Task.Run(() =>
        {
            var framePath = item.ExtractHighQualityFrame();
            if (framePath == null)
                return;

            try
            {
                // Method 1: PersonalizationCSP (works on Windows 10/11 Pro)
                using var key = Registry.LocalMachine.OpenSubKey(
                    @"SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP", true);

                if (key != null)
                {
                    key.SetValue("LockScreenImagePath", framePath, RegistryValueKind.String);
                    key.SetValue("LockScreenImageStatus", 1, RegistryValueKind.DWord);
                    return;
                }
            }
            catch
            {
                // May need admin, try alternative
            }

            try
            {
                // Method 2: Copy to the lock screen cache location
                var lockScreenDir = Path.Combine(
                    Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData),
                    @"Microsoft\Windows\SystemData"
                );

                // Alternative: set via user personalization
                using var userKey = Registry.CurrentUser.OpenSubKey(
                    @"SOFTWARE\Microsoft\Windows\CurrentVersion\Lock Screen", true);

                if (userKey != null)
                {
                    // Copy frame to a permanent location
                    var destPath = Path.Combine(App.BaseDir, "lock-screen.png");
                    File.Copy(framePath, destPath, true);

                    userKey.SetValue("LockScreenImage", destPath, RegistryValueKind.String);
                }
            }
            catch
            {
                // Lock screen setting requires elevated permissions on some editions
                System.Windows.Application.Current?.Dispatcher.Invoke(() =>
                {
                    System.Windows.MessageBox.Show(
                        "Could not set lock screen image. This may require administrator privileges.",
                        "Palantir",
                        MessageBoxButton.OK,
                        MessageBoxImage.Information);
                });
            }
        });
    }

    public void SetAll(WallpaperItem item)
    {
        SetDesktop(item);
        SetLockScreen(item);
    }

    public void StopDesktop()
    {
        foreach (var media in _mediaElements)
        {
            try { media.Stop(); media.Close(); } catch { }
        }

        foreach (var window in _wallpaperWindows)
        {
            try
            {
                var helper = new WindowInteropHelper(window);
                WorkerWHack.DetachWindow(helper.Handle);
                window.Close();
            }
            catch { }
        }

        _mediaElements.Clear();
        _wallpaperWindows.Clear();
    }

    public void Stop()
    {
        StopDesktop();
        ActiveDesktopWallpaper = null;
        SaveSettings();
        WorkerWHack.RestoreDesktop();
    }

    public void RestoreSaved()
    {
        var settings = LoadSettings();

        if (!string.IsNullOrEmpty(settings.DesktopWallpaper))
        {
            var item = _wallpapers.FirstOrDefault(w => w.FileName == settings.DesktopWallpaper);
            if (item != null)
            {
                ActiveDesktopWallpaper = settings.DesktopWallpaper;
                // Delay to ensure desktop is ready
                Task.Run(async () =>
                {
                    await Task.Delay(2000);
                    System.Windows.Application.Current?.Dispatcher.Invoke(() =>
                    {
                        SetDesktop(item);
                    });
                });
            }
        }

        ActiveLockScreenWallpaper = settings.LockScreenWallpaper;
    }

    #region Settings Persistence

    private class PalantirSettings
    {
        public string? DesktopWallpaper { get; set; }
        public string? LockScreenWallpaper { get; set; }
        public bool AutoStart { get; set; } = true;
    }

    private void SaveSettings()
    {
        try
        {
            var settings = new PalantirSettings
            {
                DesktopWallpaper = ActiveDesktopWallpaper,
                LockScreenWallpaper = ActiveLockScreenWallpaper,
                AutoStart = IsAutoStartEnabled()
            };

            var json = JsonSerializer.Serialize(settings, new JsonSerializerOptions { WriteIndented = true });
            File.WriteAllText(App.SettingsFile, json);
        }
        catch
        {
            // Settings save failure is non-fatal
        }
    }

    private PalantirSettings LoadSettings()
    {
        try
        {
            if (File.Exists(App.SettingsFile))
            {
                var json = File.ReadAllText(App.SettingsFile);
                return JsonSerializer.Deserialize<PalantirSettings>(json) ?? new PalantirSettings();
            }
        }
        catch { }

        return new PalantirSettings();
    }

    #endregion

    #region Auto-Start

    private const string AutoStartKeyPath = @"Software\Microsoft\Windows\CurrentVersion\Run";
    private const string AutoStartValueName = "Palantir";

    public bool IsAutoStartEnabled()
    {
        try
        {
            using var key = Registry.CurrentUser.OpenSubKey(AutoStartKeyPath, false);
            return key?.GetValue(AutoStartValueName) != null;
        }
        catch
        {
            return false;
        }
    }

    public void SetAutoStart(bool enable)
    {
        try
        {
            using var key = Registry.CurrentUser.OpenSubKey(AutoStartKeyPath, true);
            if (key == null) return;

            if (enable)
            {
                var exePath = Environment.ProcessPath ?? AppContext.BaseDirectory + "Palantir.exe";
                key.SetValue(AutoStartValueName, $"\"{exePath}\"", RegistryValueKind.String);
            }
            else
            {
                key.DeleteValue(AutoStartValueName, false);
            }
        }
        catch
        {
            // Registry access failure
        }
    }

    #endregion
}
