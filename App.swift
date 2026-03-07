import AppKit
import SwiftUI
import AVFoundation

// MARK: - App Entry

@main
struct LiveWallpaperApp {
    static let wallpapersDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("projetos/live-wallpaper/wallpapers")

    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var wallpaperManager = WallpaperManager()
    var galleryWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "photo.tv", accessibilityDescription: "Live Wallpaper")
            button.action = #selector(showMenu)
            button.target = self
        }

        wallpaperManager.loadWallpapers()
        wallpaperManager.restoreSaved()
    }

    @objc func showMenu() {
        let menu = NSMenu()

        if let active = wallpaperManager.activeWallpaper {
            let activeItem = NSMenuItem(title: "Now: \(active)", action: nil, keyEquivalent: "")
            activeItem.isEnabled = false
            menu.addItem(activeItem)
            menu.addItem(NSMenuItem.separator())
        }

        let galleryItem = NSMenuItem(title: "Open Gallery", action: #selector(openGallery), keyEquivalent: "g")
        galleryItem.target = self
        menu.addItem(galleryItem)

        let folderItem = NSMenuItem(title: "Open Wallpapers Folder", action: #selector(openFolder), keyEquivalent: "f")
        folderItem.target = self
        menu.addItem(folderItem)

        menu.addItem(NSMenuItem.separator())

        if wallpaperManager.activeWallpaper != nil {
            let stopItem = NSMenuItem(title: "Stop Wallpaper", action: #selector(stopWallpaper), keyEquivalent: "s")
            stopItem.target = self
            menu.addItem(stopItem)
            menu.addItem(NSMenuItem.separator())
        }

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc func openGallery() {
        if let window = galleryWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        wallpaperManager.loadWallpapers()

        let hostingView = NSHostingController(
            rootView: GalleryView(manager: wallpaperManager)
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Live Wallpaper"
        window.contentViewController = hostingView
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        galleryWindow = window
    }

    @objc func openFolder() {
        NSWorkspace.shared.open(LiveWallpaperApp.wallpapersDir)
    }

    @objc func stopWallpaper() {
        wallpaperManager.stop()
    }

    @objc func quitApp() {
        wallpaperManager.stop()
        NSApp.terminate(nil)
    }
}

// MARK: - Wallpaper Manager

class WallpaperManager: ObservableObject {
    @Published var wallpapers: [WallpaperItem] = []
    @Published var activeWallpaper: String?
    @Published var lockScreenWallpaper: String?
    var windows: [NSWindow] = []
    var players: [AVPlayer] = []

    func loadWallpapers() {
        let dir = LiveWallpaperApp.wallpapersDir
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil
        ) else { return }

        wallpapers = files
            .filter { ["mov", "mp4", "m4v"].contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
            .map { WallpaperItem(url: $0) }

        lockScreenWallpaper = UserDefaults.standard.string(forKey: "lockScreenWallpaper")
    }

    func restoreSaved() {
        if let saved = UserDefaults.standard.string(forKey: "activeWallpaper") {
            activeWallpaper = saved
            if let item = wallpapers.first(where: { $0.url.lastPathComponent == saved }) {
                setDesktop(item: item)
            }
        }
    }

    func activate(filename: String) {
        guard let item = wallpapers.first(where: { $0.url.lastPathComponent == filename }) else { return }
        setDesktop(item: item)
    }

    func setAll(item: WallpaperItem) {
        setDesktop(item: item)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [self] in
            setLockScreen(item: item)
        }
    }

    func setDesktop(item: WallpaperItem) {
        stopDesktop()
        activeWallpaper = item.url.lastPathComponent
        UserDefaults.standard.set(activeWallpaper, forKey: "activeWallpaper")

        let asset = AVURLAsset(url: item.url)
        let playerItem = AVPlayerItem(asset: asset)
        playerItem.preferredForwardBufferDuration = 5
        let player = AVPlayer(playerItem: playerItem)
        player.isMuted = true
        player.actionAtItemEnd = .none

        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak player] _ in
            player?.seek(to: .zero)
            player?.play()
        }

        players.append(player)

        for screen in NSScreen.screens {
            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false
            )
            window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)))
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            window.isOpaque = true
            window.hasShadow = false
            window.ignoresMouseEvents = true
            window.backgroundColor = .black

            let playerLayer = AVPlayerLayer(player: player)
            playerLayer.frame = CGRect(origin: .zero, size: screen.frame.size)
            playerLayer.videoGravity = .resizeAspectFill

            let view = NSView(frame: CGRect(origin: .zero, size: screen.frame.size))
            view.wantsLayer = true
            view.layer?.addSublayer(playerLayer)
            window.contentView = view

            window.orderFront(nil)
            windows.append(window)
        }

        player.play()
    }

    func setLockScreen(item: WallpaperItem) {
        let filename = item.url.lastPathComponent
        let sourceURL = item.url

        DispatchQueue.global(qos: .utility).async {
            let saverDir = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Screen Savers/LoneKnightSaver.saver/Contents/Resources")
            let dest = saverDir.appendingPathComponent("wallpaper.mov")

            try? FileManager.default.removeItem(at: dest)
            try? FileManager.default.copyItem(at: sourceURL, to: dest)

            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
            task.arguments = ["legacyScreenSaver"]
            try? task.run()

            DispatchQueue.main.async { [self] in
                lockScreenWallpaper = filename
                UserDefaults.standard.set(filename, forKey: "lockScreenWallpaper")
            }
        }
    }

    func stopDesktop() {
        players.forEach { $0.pause() }
        windows.forEach { $0.close() }
        players.removeAll()
        windows.removeAll()
    }

    func stop() {
        stopDesktop()
        activeWallpaper = nil
        UserDefaults.standard.removeObject(forKey: "activeWallpaper")
    }
}

// MARK: - Model

struct WallpaperItem: Identifiable {
    let id = UUID()
    let url: URL

    var name: String {
        let filename = url.deletingPathExtension().lastPathComponent
        if filename.hasPrefix("wallux-preview-") {
            let short = String(filename.dropFirst("wallux-preview-".count).prefix(8))
            return "Preview \(short)"
        }
        return filename
    }

    var fileExtension: String {
        url.pathExtension.uppercased()
    }

    var size: String {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let bytes = attrs[.size] as? Int64 else { return "" }
        let mb = Double(bytes) / 1_000_000
        return String(format: "%.0f MB", mb)
    }
}

// MARK: - Gallery View

struct GalleryView: View {
    @ObservedObject var manager: WallpaperManager

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "photo.tv")
                    .font(.title2)
                Text("Live Wallpaper")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()

                Button(action: { manager.loadWallpapers() }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }

                Button(action: { NSWorkspace.shared.open(LiveWallpaperApp.wallpapersDir) }) {
                    Label("Open Folder", systemImage: "folder")
                }
            }
            .padding()

            Divider()

            // Grid
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 200, maximum: 280), spacing: 16)
                ], spacing: 16) {
                    ForEach(manager.wallpapers) { item in
                        WallpaperCard(
                            item: item,
                            isDesktopActive: manager.activeWallpaper == item.url.lastPathComponent,
                            isLockActive: manager.lockScreenWallpaper == item.url.lastPathComponent,
                            manager: manager
                        )
                    }
                }
                .padding()
            }

            // Status bar
            if manager.activeWallpaper != nil || manager.lockScreenWallpaper != nil {
                Divider()
                HStack(spacing: 16) {
                    if let desktop = manager.activeWallpaper {
                        Label(desktop, systemImage: "desktopcomputer")
                            .font(.caption)
                            .foregroundColor(.green)
                            .lineLimit(1)
                    }
                    if let lock = manager.lockScreenWallpaper {
                        Label(lock, systemImage: "lock.display")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .lineLimit(1)
                    }
                    Spacer()
                    Button("Stop Desktop") {
                        manager.stop()
                    }
                    .controlSize(.small)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
        }
        .frame(minWidth: 500, minHeight: 400)
    }
}

// MARK: - Wallpaper Card

struct WallpaperCard: View {
    let item: WallpaperItem
    let isDesktopActive: Bool
    let isLockActive: Bool
    @ObservedObject var manager: WallpaperManager
    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 0) {
            // Thumbnail
            ZStack(alignment: .topTrailing) {
                VideoThumbnailView(url: item.url)
                    .frame(height: 120)
                    .clipped()

                // Badges
                HStack(spacing: 4) {
                    if isDesktopActive {
                        BadgeView(icon: "desktopcomputer", color: .green)
                    }
                    if isLockActive {
                        BadgeView(icon: "lock.fill", color: .blue)
                    }
                }
                .padding(6)

                // Hover overlay with actions
                if isHovering {
                    Color.black.opacity(0.5)
                        .overlay(
                            HStack(spacing: 12) {
                                ActionButton(icon: "play.fill", label: "Both") {
                                    manager.setAll(item: item)
                                }
                                ActionButton(icon: "desktopcomputer", label: "Desktop") {
                                    manager.setDesktop(item: item)
                                }
                                ActionButton(icon: "lock.display", label: "Lock") {
                                    manager.setLockScreen(item: item)
                                }
                            }
                        )
                }
            }
            .frame(height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            // Info
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                    Text("\(item.size) · \(item.fileExtension)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 4)
            .padding(.top, 6)
        }
        .onHover { hovering in
            isHovering = hovering
        }
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isDesktopActive ? Color.green.opacity(0.5) : (isLockActive ? Color.blue.opacity(0.5) : Color.clear), lineWidth: 2)
        )
    }
}

struct BadgeView: View {
    let icon: String
    let color: Color

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(.white)
            .padding(4)
            .background(color.opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

struct ActionButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(label)
                    .font(.system(size: 10))
            }
            .foregroundColor(.white)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Video Thumbnail

struct VideoThumbnailView: View {
    let url: URL
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.15))
                    .overlay(
                        ProgressView()
                            .controlSize(.small)
                    )
            }
        }
        .onAppear { generateThumbnail() }
    }

    private static let thumbnailQueue = DispatchQueue(label: "thumbnails", qos: .background)
    private static let semaphore = DispatchSemaphore(value: 1)

    private func generateThumbnail() {
        Self.thumbnailQueue.async {
            Self.semaphore.wait()
            defer { Self.semaphore.signal() }

            let asset = AVURLAsset(url: url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 400, height: 200)

            let time = CMTime(seconds: 2, preferredTimescale: 600)
            if let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) {
                let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                DispatchQueue.main.async {
                    self.image = nsImage
                }
            }
        }
    }
}
