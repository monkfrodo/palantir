using System.Drawing;
using System.IO;
using System.Windows;
using System.Windows.Controls;
using Hardcodet.Wpf.TaskbarNotification;
using Palantir.Core;
using Palantir.Views;

namespace Palantir;

/// <summary>
/// Manages the system tray icon and its context menu.
/// </summary>
public class TrayIconManager : IDisposable
{
    private TaskbarIcon? _trayIcon;
    private GalleryWindow? _galleryWindow;

    public WallpaperManager WallpaperManager { get; } = new();

    private static TrayIconManager? _instance;

    public void Initialize()
    {
        _instance = this;

        _trayIcon = new TaskbarIcon
        {
            ToolTipText = "Palantir — Live Wallpaper",
            Icon = CreateDefaultIcon(),
            ContextMenu = BuildContextMenu(),
            DoubleClickCommand = new RelayCommand(_ => OpenGallery()),
        };

        // Rebuild menu when active wallpaper changes
        WallpaperManager.PropertyChanged += (s, e) =>
        {
            if (e.PropertyName == nameof(WallpaperManager.ActiveDesktopWallpaper))
            {
                System.Windows.Application.Current?.Dispatcher.Invoke(() =>
                {
                    _trayIcon.ContextMenu = BuildContextMenu();
                    _trayIcon.ToolTipText = WallpaperManager.ActiveDesktopWallpaper != null
                        ? $"Palantir — {WallpaperManager.ActiveDesktopWallpaper}"
                        : "Palantir — Live Wallpaper";
                });
            }
        };
    }

    private ContextMenu BuildContextMenu()
    {
        var menu = new ContextMenu();
        menu.Style = CreateDarkMenuStyle();

        if (WallpaperManager.ActiveDesktopWallpaper != null)
        {
            var nowPlaying = new MenuItem
            {
                Header = $"Now: {Path.GetFileNameWithoutExtension(WallpaperManager.ActiveDesktopWallpaper)}",
                IsEnabled = false,
                Foreground = System.Windows.Media.Brushes.LightGray,
            };
            menu.Items.Add(nowPlaying);
            menu.Items.Add(new Separator());
        }

        var galleryItem = new MenuItem { Header = "Open Gallery" };
        galleryItem.Click += (s, e) => OpenGallery();
        menu.Items.Add(galleryItem);

        var folderItem = new MenuItem { Header = "Open Wallpapers Folder" };
        folderItem.Click += (s, e) => OpenFolder();
        menu.Items.Add(folderItem);

        menu.Items.Add(new Separator());

        var autoStartItem = new MenuItem
        {
            Header = "Start with Windows",
            IsCheckable = true,
            IsChecked = WallpaperManager.IsAutoStartEnabled(),
        };
        autoStartItem.Click += (s, e) =>
        {
            WallpaperManager.SetAutoStart(autoStartItem.IsChecked);
        };
        menu.Items.Add(autoStartItem);

        if (WallpaperManager.ActiveDesktopWallpaper != null)
        {
            menu.Items.Add(new Separator());
            var stopItem = new MenuItem { Header = "Stop Wallpaper" };
            stopItem.Click += (s, e) => WallpaperManager.Stop();
            menu.Items.Add(stopItem);
        }

        menu.Items.Add(new Separator());

        var quitItem = new MenuItem { Header = "Quit" };
        quitItem.Click += (s, e) =>
        {
            WallpaperManager.Stop();
            System.Windows.Application.Current.Shutdown();
        };
        menu.Items.Add(quitItem);

        return menu;
    }

    public void OpenGalleryPublic() => OpenGallery();

    private void OpenGallery()
    {
        if (_galleryWindow != null && _galleryWindow.IsVisible)
        {
            _galleryWindow.Activate();
            _galleryWindow.Focus();
            return;
        }

        WallpaperManager.LoadWallpapers();

        _galleryWindow = new GalleryWindow(WallpaperManager);
        _galleryWindow.Closed += (s, e) => _galleryWindow = null;
        _galleryWindow.Show();
        _galleryWindow.Activate();
    }

    private void OpenFolder()
    {
        try
        {
            System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo
            {
                FileName = App.WallpapersDir,
                UseShellExecute = true,
            });
        }
        catch { }
    }

    /// <summary>
    /// Shows a balloon tip from the tray icon (fallback for toast notifications).
    /// </summary>
    public static void ShowBalloon(string title, string message)
    {
        _instance?._trayIcon?.ShowBalloonTip(title, message, BalloonIcon.Info);
    }

    private static Icon CreateDefaultIcon()
    {
        // Create a simple programmatic icon (white circle on transparent)
        var bitmap = new Bitmap(32, 32);
        using (var g = Graphics.FromImage(bitmap))
        {
            g.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.AntiAlias;
            g.Clear(Color.Transparent);

            // Draw a stylized eye/palantir shape
            using var brush = new SolidBrush(Color.FromArgb(255, 79, 195, 247));
            g.FillEllipse(brush, 4, 4, 24, 24);

            using var innerBrush = new SolidBrush(Color.FromArgb(255, 30, 30, 30));
            g.FillEllipse(innerBrush, 10, 10, 12, 12);

            using var dotBrush = new SolidBrush(Color.FromArgb(255, 79, 195, 247));
            g.FillEllipse(dotBrush, 13, 13, 6, 6);
        }

        return Icon.FromHandle(bitmap.GetHicon());
    }

    private Style CreateDarkMenuStyle()
    {
        var style = new Style(typeof(ContextMenu));
        style.Setters.Add(new Setter(System.Windows.Controls.Control.BackgroundProperty, System.Windows.Media.Brushes.Black));
        style.Setters.Add(new Setter(System.Windows.Controls.Control.ForegroundProperty, System.Windows.Media.Brushes.White));
        style.Setters.Add(new Setter(System.Windows.Controls.Control.BorderBrushProperty,
            new System.Windows.Media.SolidColorBrush(System.Windows.Media.Color.FromRgb(64, 64, 64))));
        return style;
    }

    public void Dispose()
    {
        _trayIcon?.Dispose();
        _galleryWindow?.Close();
    }
}

/// <summary>
/// Simple ICommand implementation for tray icon commands.
/// </summary>
public class RelayCommand : System.Windows.Input.ICommand
{
    private readonly Action<object?> _execute;
    private readonly Func<object?, bool>? _canExecute;

    public RelayCommand(Action<object?> execute, Func<object?, bool>? canExecute = null)
    {
        _execute = execute;
        _canExecute = canExecute;
    }

    public bool CanExecute(object? parameter) => _canExecute?.Invoke(parameter) ?? true;
    public void Execute(object? parameter) => _execute(parameter);

    public event EventHandler? CanExecuteChanged
    {
        add { System.Windows.Input.CommandManager.RequerySuggested += value; }
        remove { System.Windows.Input.CommandManager.RequerySuggested -= value; }
    }
}
