using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using Palantir.Core;

namespace Palantir.Views;

public enum WallpaperActionType
{
    Desktop,
    LockScreen,
    Both
}

public class WallpaperActionEventArgs : EventArgs
{
    public WallpaperItem Item { get; }
    public WallpaperActionType Action { get; }

    public WallpaperActionEventArgs(WallpaperItem item, WallpaperActionType action)
    {
        Item = item;
        Action = action;
    }
}

public partial class WallpaperCard : UserControl
{
    public WallpaperItem WallpaperItem { get; }
    private readonly WallpaperManager _manager;
    private bool _isDesktopActive;
    private bool _isLockActive;

    public event EventHandler<WallpaperActionEventArgs>? WallpaperAction;

    public WallpaperCard(WallpaperItem item, WallpaperManager manager)
    {
        InitializeComponent();

        WallpaperItem = item;
        _manager = manager;

        NameText.Text = item.Name;
        InfoText.Text = $"{item.Size} \u00B7 {item.FileExtension}";

        // Load thumbnail asynchronously
        LoadThumbnail();

        // Wire up hover events
        MouseEnter += OnMouseEnter;
        MouseLeave += OnMouseLeave;
    }

    private void LoadThumbnail()
    {
        WallpaperItem.GetThumbnailAsync(thumb =>
        {
            if (thumb != null)
            {
                ThumbnailImage.Source = thumb;
                LoadingText.Visibility = Visibility.Collapsed;
            }
            else
            {
                LoadingText.Text = "No preview";
            }
        });
    }

    public void UpdateActiveState(bool isDesktop, bool isLock)
    {
        _isDesktopActive = isDesktop;
        _isLockActive = isLock;

        DesktopBadge.Visibility = isDesktop ? Visibility.Visible : Visibility.Collapsed;
        LockBadge.Visibility = isLock ? Visibility.Visible : Visibility.Collapsed;

        if (isDesktop)
        {
            RootBorder.BorderBrush = new SolidColorBrush(Color.FromArgb(128, 76, 175, 80));
        }
        else if (isLock)
        {
            RootBorder.BorderBrush = new SolidColorBrush(Color.FromArgb(128, 66, 165, 245));
        }
        else
        {
            RootBorder.BorderBrush = Brushes.Transparent;
        }
    }

    private void OnMouseEnter(object sender, MouseEventArgs e)
    {
        HoverOverlay.Visibility = Visibility.Visible;
    }

    private void OnMouseLeave(object sender, MouseEventArgs e)
    {
        HoverOverlay.Visibility = Visibility.Collapsed;
    }

    private void BothButton_Click(object sender, RoutedEventArgs e)
    {
        WallpaperAction?.Invoke(this, new WallpaperActionEventArgs(WallpaperItem, WallpaperActionType.Both));
    }

    private void DesktopButton_Click(object sender, RoutedEventArgs e)
    {
        WallpaperAction?.Invoke(this, new WallpaperActionEventArgs(WallpaperItem, WallpaperActionType.Desktop));
    }

    private void LockButton_Click(object sender, RoutedEventArgs e)
    {
        WallpaperAction?.Invoke(this, new WallpaperActionEventArgs(WallpaperItem, WallpaperActionType.LockScreen));
    }
}
