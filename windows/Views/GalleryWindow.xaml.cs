using System.IO;
using System.Windows;
using Palantir.Core;

namespace Palantir.Views;

public partial class GalleryWindow : Window
{
    private readonly WallpaperManager _manager;

    public GalleryWindow(WallpaperManager manager)
    {
        InitializeComponent();
        _manager = manager;

        _manager.PropertyChanged += Manager_PropertyChanged;

        PopulateGrid();
        UpdateStatusBar();
    }

    private void PopulateGrid()
    {
        WallpaperGrid.Items.Clear();

        foreach (var item in _manager.Wallpapers)
        {
            var card = new WallpaperCard(item, _manager);
            card.WallpaperAction += OnWallpaperAction;
            WallpaperGrid.Items.Add(card);
        }

        UpdateCardStates();
    }

    private void OnWallpaperAction(object? sender, WallpaperActionEventArgs e)
    {
        switch (e.Action)
        {
            case WallpaperActionType.Desktop:
                _manager.SetDesktop(e.Item);
                break;
            case WallpaperActionType.LockScreen:
                _manager.SetLockScreen(e.Item);
                break;
            case WallpaperActionType.Both:
                _manager.SetAll(e.Item);
                break;
        }

        UpdateCardStates();
        UpdateStatusBar();
    }

    private void Manager_PropertyChanged(object? sender, System.ComponentModel.PropertyChangedEventArgs e)
    {
        Dispatcher.Invoke(() =>
        {
            UpdateCardStates();
            UpdateStatusBar();
        });
    }

    private void UpdateCardStates()
    {
        foreach (var item in WallpaperGrid.Items)
        {
            if (item is WallpaperCard card)
            {
                card.UpdateActiveState(
                    _manager.ActiveDesktopWallpaper == card.WallpaperItem.FileName,
                    _manager.ActiveLockScreenWallpaper == card.WallpaperItem.FileName
                );
            }
        }
    }

    private void UpdateStatusBar()
    {
        bool hasActive = _manager.ActiveDesktopWallpaper != null || _manager.ActiveLockScreenWallpaper != null;
        StatusBar.Visibility = hasActive ? Visibility.Visible : Visibility.Collapsed;

        if (_manager.ActiveDesktopWallpaper != null)
        {
            DesktopStatusText.Text = $"\u25CF Desktop: {Path.GetFileNameWithoutExtension(_manager.ActiveDesktopWallpaper)}";
            DesktopStatusText.Visibility = Visibility.Visible;
        }
        else
        {
            DesktopStatusText.Visibility = Visibility.Collapsed;
        }

        if (_manager.ActiveLockScreenWallpaper != null)
        {
            LockStatusText.Text = $"\u25CF Lock: {Path.GetFileNameWithoutExtension(_manager.ActiveLockScreenWallpaper)}";
            LockStatusText.Visibility = Visibility.Visible;
        }
        else
        {
            LockStatusText.Visibility = Visibility.Collapsed;
        }
    }

    private void RefreshButton_Click(object sender, RoutedEventArgs e)
    {
        _manager.LoadWallpapers();
        PopulateGrid();
        UpdateStatusBar();
    }

    private void OpenFolderButton_Click(object sender, RoutedEventArgs e)
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

    private void StopButton_Click(object sender, RoutedEventArgs e)
    {
        _manager.Stop();
        UpdateCardStates();
        UpdateStatusBar();
    }

    protected override void OnClosed(EventArgs e)
    {
        _manager.PropertyChanged -= Manager_PropertyChanged;
        base.OnClosed(e);
    }
}
