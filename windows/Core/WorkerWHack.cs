using System.Runtime.InteropServices;

namespace Palantir.Core;

/// <summary>
/// Implements the WorkerW desktop wallpaper injection hack for Windows.
/// This finds the WorkerW window behind the desktop icons and allows
/// embedding a child window (our video player) as the desktop wallpaper.
/// </summary>
public static class WorkerWHack
{
    #region P/Invoke

    [DllImport("user32.dll", SetLastError = true)]
    private static extern IntPtr FindWindow(string? lpClassName, string? lpWindowName);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern IntPtr FindWindowEx(IntPtr hwndParent, IntPtr hwndChildAfter, string? lpszClass, string? lpszWindow);

    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    private static extern IntPtr SendMessageTimeout(
        IntPtr hWnd, uint msg, UIntPtr wParam, IntPtr lParam,
        uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);

    private delegate bool EnumWindowsProc(IntPtr hwnd, IntPtr lParam);

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern IntPtr SetParent(IntPtr hWndChild, IntPtr hWndNewParent);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern int SetWindowLong(IntPtr hWnd, int nIndex, int dwNewLong);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern int GetWindowLong(IntPtr hWnd, int nIndex);

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int x, int y, int cx, int cy, uint uFlags);

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool IsWindow(IntPtr hWnd);

    private const int GWL_STYLE = -16;
    private const int GWL_EXSTYLE = -20;
    private const int WS_CHILD = 0x40000000;
    private const int WS_VISIBLE = 0x10000000;
    private const uint SMTO_NORMAL = 0x0000;
    private const uint SWP_NOACTIVATE = 0x0010;
    private const uint SWP_SHOWWINDOW = 0x0040;
    private const int SW_SHOW = 5;

    #endregion

    private static IntPtr _workerW = IntPtr.Zero;

    /// <summary>
    /// Finds the WorkerW window that sits behind the desktop icons.
    /// Sends the 0x052C message to Progman to spawn the WorkerW hierarchy,
    /// then enumerates top-level windows to find the correct one.
    /// </summary>
    public static IntPtr GetWorkerW()
    {
        // Find Progman (Program Manager)
        IntPtr progman = FindWindow("Progman", null);
        if (progman == IntPtr.Zero)
            return IntPtr.Zero;

        // Send 0x052C to Progman to spawn a WorkerW window behind the desktop icons
        SendMessageTimeout(
            progman,
            0x052C,
            UIntPtr.Zero,
            IntPtr.Zero,
            SMTO_NORMAL,
            1000,
            out _
        );

        IntPtr workerW = IntPtr.Zero;

        // Enumerate all top-level windows to find the WorkerW that contains SHELLDLL_DefView
        EnumWindows((hwnd, lParam) =>
        {
            IntPtr shellDefView = FindWindowEx(hwnd, IntPtr.Zero, "SHELLDLL_DefView", null);
            if (shellDefView != IntPtr.Zero)
            {
                // Found the window that contains SHELLDLL_DefView
                // The WorkerW we want is the NEXT one after this
                workerW = FindWindowEx(IntPtr.Zero, hwnd, "WorkerW", null);
            }
            return true; // Continue enumeration
        }, IntPtr.Zero);

        _workerW = workerW;
        return workerW;
    }

    /// <summary>
    /// Embeds the given WPF window handle as a child of the WorkerW desktop window.
    /// </summary>
    public static bool EmbedWindow(IntPtr childHwnd, IntPtr workerW, int x, int y, int width, int height)
    {
        if (workerW == IntPtr.Zero || childHwnd == IntPtr.Zero)
            return false;

        // Set as child of WorkerW
        SetParent(childHwnd, workerW);

        // Modify window style to be a child window
        int style = GetWindowLong(childHwnd, GWL_STYLE);
        style = (style | WS_CHILD | WS_VISIBLE) & ~0x00C00000 & ~0x00040000; // Remove WS_CAPTION, WS_THICKFRAME
        SetWindowLong(childHwnd, GWL_STYLE, style);

        // Remove extended styles that interfere
        int exStyle = GetWindowLong(childHwnd, GWL_EXSTYLE);
        exStyle &= ~0x00000100; // Remove WS_EX_TOOLWINDOW
        exStyle &= ~0x00040000; // Remove WS_EX_APPWINDOW
        SetWindowLong(childHwnd, GWL_EXSTYLE, exStyle);

        // Position and size the window to fill the monitor area
        SetWindowPos(childHwnd, IntPtr.Zero, x, y, width, height, SWP_NOACTIVATE | SWP_SHOWWINDOW);
        ShowWindow(childHwnd, SW_SHOW);

        return true;
    }

    /// <summary>
    /// Detaches a child window from WorkerW and restores it.
    /// </summary>
    public static void DetachWindow(IntPtr childHwnd)
    {
        if (childHwnd == IntPtr.Zero || !IsWindow(childHwnd))
            return;

        // Set parent back to desktop (null parent = top-level)
        SetParent(childHwnd, IntPtr.Zero);
    }

    /// <summary>
    /// Refreshes the desktop to restore normal wallpaper after stopping.
    /// </summary>
    public static void RestoreDesktop()
    {
        // Send a refresh to Progman to restore normal wallpaper rendering
        IntPtr progman = FindWindow("Progman", null);
        if (progman != IntPtr.Zero)
        {
            SendMessageTimeout(
                progman,
                0x052C,
                UIntPtr.Zero,
                IntPtr.Zero,
                SMTO_NORMAL,
                1000,
                out _
            );
        }
    }
}
