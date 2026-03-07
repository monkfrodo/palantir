using System.IO;
using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Imaging;

namespace Palantir.Core;

public class WallpaperItem
{
    public string FilePath { get; }
    public string Name { get; }
    public string FileExtension { get; }
    public string Size { get; }
    public string FileName { get; }

    private BitmapSource? _thumbnail;
    private bool _thumbnailGenerated;
    private static readonly object _thumbnailLock = new();

    public WallpaperItem(string filePath)
    {
        FilePath = filePath;
        FileName = Path.GetFileName(filePath);
        Name = Path.GetFileNameWithoutExtension(filePath);
        FileExtension = Path.GetExtension(filePath).TrimStart('.').ToUpperInvariant();

        var fileInfo = new FileInfo(filePath);
        if (fileInfo.Exists)
        {
            var mb = fileInfo.Length / 1_000_000.0;
            Size = $"{mb:F0} MB";
        }
        else
        {
            Size = "";
        }
    }

    public BitmapSource? GetThumbnail()
    {
        if (_thumbnailGenerated)
            return _thumbnail;

        lock (_thumbnailLock)
        {
            if (_thumbnailGenerated)
                return _thumbnail;

            _thumbnail = GenerateThumbnail();
            _thumbnailGenerated = true;
        }

        return _thumbnail;
    }

    public BitmapSource? GetThumbnailAsync(Action<BitmapSource?> callback)
    {
        if (_thumbnailGenerated)
            return _thumbnail;

        Task.Run(() =>
        {
            var thumb = GetThumbnail();
            if (thumb != null)
            {
                thumb.Freeze();
            }
            Application.Current?.Dispatcher.Invoke(() => callback(thumb));
        });

        return null;
    }

    private BitmapSource? GenerateThumbnail()
    {
        // Check cached frame first
        var cachedPath = Path.Combine(App.FramesDir, $"{Name}.png");
        if (File.Exists(cachedPath))
        {
            try
            {
                var bi = new BitmapImage();
                bi.BeginInit();
                bi.UriSource = new Uri(cachedPath, UriKind.Absolute);
                bi.CacheOption = BitmapCacheOption.OnLoad;
                bi.DecodePixelWidth = 400;
                bi.EndInit();
                bi.Freeze();
                return bi;
            }
            catch
            {
                // Fall through to generate
            }
        }

        // Generate thumbnail using MediaPlayer
        try
        {
            return ExtractFrameWithMediaPlayer(cachedPath);
        }
        catch
        {
            return null;
        }
    }

    private BitmapSource? ExtractFrameWithMediaPlayer(string cachePath)
    {
        BitmapSource? result = null;
        var resetEvent = new ManualResetEventSlim(false);

        // MediaPlayer must run on STA thread
        var thread = new Thread(() =>
        {
            try
            {
                var player = new MediaPlayer();
                player.Volume = 0;
                player.ScrubbingEnabled = true;

                bool opened = false;
                player.MediaOpened += (s, e) => opened = true;
                player.Open(new Uri(FilePath, UriKind.Absolute));

                // Wait for media to open
                var sw = System.Diagnostics.Stopwatch.StartNew();
                while (!opened && sw.ElapsedMilliseconds < 5000)
                {
                    System.Windows.Threading.Dispatcher.CurrentDispatcher.Invoke(
                        System.Windows.Threading.DispatcherPriority.Background,
                        new Action(() => { }));
                    Thread.Sleep(10);
                }

                if (!opened)
                {
                    resetEvent.Set();
                    return;
                }

                // Seek to 2 seconds
                player.Position = TimeSpan.FromSeconds(2);
                Thread.Sleep(500);

                // Pump messages to let seek complete
                for (int i = 0; i < 50; i++)
                {
                    System.Windows.Threading.Dispatcher.CurrentDispatcher.Invoke(
                        System.Windows.Threading.DispatcherPriority.Background,
                        new Action(() => { }));
                    Thread.Sleep(20);
                }

                // Render frame
                if (player.NaturalVideoWidth > 0 && player.NaturalVideoHeight > 0)
                {
                    int width = player.NaturalVideoWidth;
                    int height = player.NaturalVideoHeight;

                    // Cap for thumbnail
                    if (width > 800)
                    {
                        height = (int)(height * (800.0 / width));
                        width = 800;
                    }

                    var rtb = new RenderTargetBitmap(width, height, 96, 96, PixelFormats.Pbgra32);
                    var dv = new DrawingVisual();
                    using (var dc = dv.RenderOpen())
                    {
                        dc.DrawVideo(player, new Rect(0, 0, width, height));
                    }
                    rtb.Render(dv);
                    rtb.Freeze();

                    // Cache to disk
                    try
                    {
                        var encoder = new PngBitmapEncoder();
                        encoder.Frames.Add(BitmapFrame.Create(rtb));
                        using var fs = new FileStream(cachePath, FileMode.Create);
                        encoder.Save(fs);
                    }
                    catch
                    {
                        // Cache write failure is non-fatal
                    }

                    result = rtb;
                }

                player.Close();
            }
            catch
            {
                // Thumbnail generation failure is non-fatal
            }
            finally
            {
                resetEvent.Set();
            }
        });

        thread.SetApartmentState(ApartmentState.STA);
        thread.IsBackground = true;
        thread.Start();

        resetEvent.Wait(TimeSpan.FromSeconds(10));
        return result;
    }

    /// <summary>
    /// Extracts a high-quality frame for use as static wallpaper.
    /// Returns path to cached PNG, or null on failure.
    /// </summary>
    public string? ExtractHighQualityFrame()
    {
        var cachedPath = Path.Combine(App.FramesDir, $"{Name}_hq.png");
        if (File.Exists(cachedPath))
            return cachedPath;

        string? resultPath = null;
        var resetEvent = new ManualResetEventSlim(false);

        var thread = new Thread(() =>
        {
            try
            {
                var player = new MediaPlayer();
                player.Volume = 0;
                player.ScrubbingEnabled = true;

                bool opened = false;
                player.MediaOpened += (s, e) => opened = true;
                player.Open(new Uri(FilePath, UriKind.Absolute));

                var sw = System.Diagnostics.Stopwatch.StartNew();
                while (!opened && sw.ElapsedMilliseconds < 5000)
                {
                    System.Windows.Threading.Dispatcher.CurrentDispatcher.Invoke(
                        System.Windows.Threading.DispatcherPriority.Background,
                        new Action(() => { }));
                    Thread.Sleep(10);
                }

                if (!opened)
                {
                    resetEvent.Set();
                    return;
                }

                player.Position = TimeSpan.FromSeconds(2);
                Thread.Sleep(500);

                for (int i = 0; i < 50; i++)
                {
                    System.Windows.Threading.Dispatcher.CurrentDispatcher.Invoke(
                        System.Windows.Threading.DispatcherPriority.Background,
                        new Action(() => { }));
                    Thread.Sleep(20);
                }

                if (player.NaturalVideoWidth > 0 && player.NaturalVideoHeight > 0)
                {
                    int width = player.NaturalVideoWidth;
                    int height = player.NaturalVideoHeight;

                    var rtb = new RenderTargetBitmap(width, height, 96, 96, PixelFormats.Pbgra32);
                    var dv = new DrawingVisual();
                    using (var dc = dv.RenderOpen())
                    {
                        dc.DrawVideo(player, new Rect(0, 0, width, height));
                    }
                    rtb.Render(dv);

                    var encoder = new PngBitmapEncoder();
                    encoder.Frames.Add(BitmapFrame.Create(rtb));
                    using var fs = new FileStream(cachedPath, FileMode.Create);
                    encoder.Save(fs);
                    resultPath = cachedPath;
                }

                player.Close();
            }
            catch
            {
                // Extraction failure is non-fatal
            }
            finally
            {
                resetEvent.Set();
            }
        });

        thread.SetApartmentState(ApartmentState.STA);
        thread.IsBackground = true;
        thread.Start();

        resetEvent.Wait(TimeSpan.FromSeconds(15));
        return resultPath;
    }
}
