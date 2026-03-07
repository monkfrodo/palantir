import AppKit
import SwiftUI
import AVFoundation
import CoreMedia

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
    private var activeVideoURL: URL?
    private var workspaceObservers: [NSObjectProtocol] = []

    private static let framesDir: URL = {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("projetos/live-wallpaper/.frames")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    // Aerials injection paths (same approach as Wallux)
    private static let aerialsBase: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/com.apple.wallpaper/aerials")
    private static let manifestFile: URL = aerialsBase.appendingPathComponent("manifest/entries.json")
    private static let thumbnailsDir: URL = aerialsBase.appendingPathComponent("thumbnails")

    private static let categoryID = "LW000000-0000-4000-8000-000000000001"
    private static let subcategoryID = "LW000000-0000-4000-8000-000000000002"

    /// Generates a stable UUID for a wallpaper filename (deterministic so it persists across runs)
    private static func stableUUID(for filename: String) -> String {
        // Check cached mapping first
        let key = "uuid_\(filename)"
        if let cached = UserDefaults.standard.string(forKey: key) {
            return cached
        }
        let uuid = UUID().uuidString
        UserDefaults.standard.set(uuid, forKey: key)
        return uuid
    }

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

        // Sync all wallpapers to macOS aerials system (each gets its own tile in System Settings)
        syncAllToAerials()
    }

    func restoreSaved() {
        // Small delay to ensure desktop is ready after login
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [self] in
            if let saved = UserDefaults.standard.string(forKey: "activeWallpaper") {
                activeWallpaper = saved
                if let item = wallpapers.first(where: { $0.url.lastPathComponent == saved }) {
                    setDesktop(item: item)
                }
            }
        }
        startWorkspaceObservers()
    }

    private func startWorkspaceObservers() {
        stopWorkspaceObservers()

        // Re-show windows when active space changes
        let spaceObs = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.reassertWindows()
        }
        workspaceObservers.append(spaceObs)

        // Re-show windows when screen wakes up
        let wakeObs = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.screensDidWakeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self?.reassertWindows()
            }
        }
        workspaceObservers.append(wakeObs)

        // Re-show windows when screen unlocks (prevents black screen after ESC on lock)
        let unlockObs = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.screenIsUnlocked"),
            object: nil, queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self?.reassertWindows()
                // Resume playback in case it was paused
                self?.players.forEach { $0.play() }
            }
        }
        workspaceObservers.append(unlockObs)

        // Re-show windows when screens change configuration
        let screenObs = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.handleScreenChange()
        }
        workspaceObservers.append(screenObs)
    }

    private func stopWorkspaceObservers() {
        for obs in workspaceObservers {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
            NotificationCenter.default.removeObserver(obs)
        }
        workspaceObservers.removeAll()
    }

    private func reassertWindows() {
        for window in windows {
            window.orderFront(nil)
        }
        // Also re-set static wallpaper in case macOS changed it
        if let url = activeVideoURL {
            setStaticWallpaper(from: url)
        }
    }

    private func handleScreenChange() {
        guard let name = activeWallpaper,
              let item = wallpapers.first(where: { $0.url.lastPathComponent == name }) else { return }
        // Recreate windows for new screen layout
        setDesktop(item: item)
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
        activeVideoURL = item.url
        UserDefaults.standard.set(activeWallpaper, forKey: "activeWallpaper")

        // Set macOS static wallpaper to a frame from the video (fallback for lock, restart, etc.)
        setStaticWallpaper(from: item.url)

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

    /// Extracts a frame from the video and sets it as macOS static wallpaper for all screens
    private func setStaticWallpaper(from videoURL: URL) {
        DispatchQueue.global(qos: .utility).async {
            let frameURL = self.extractFrame(from: videoURL)
            guard let frameURL = frameURL else { return }

            DispatchQueue.main.async {
                for screen in NSScreen.screens {
                    try? NSWorkspace.shared.setDesktopImageURL(
                        frameURL, for: screen, options: [:]
                    )
                }
            }
        }
    }

    /// Extracts a frame from video and caches it as PNG
    private func extractFrame(from videoURL: URL) -> URL? {
        let name = videoURL.deletingPathExtension().lastPathComponent
        let frameURL = Self.framesDir.appendingPathComponent("\(name).png")

        // Use cached frame if available
        if FileManager.default.fileExists(atPath: frameURL.path) {
            return frameURL
        }

        let asset = AVURLAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        // High quality frame for wallpaper
        generator.maximumSize = CGSize(width: 3840, height: 2160)

        let time = CMTime(seconds: 2, preferredTimescale: 600)
        guard let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) else {
            return nil
        }

        let rep = NSBitmapImageRep(cgImage: cgImage)
        guard let pngData = rep.representation(using: .png, properties: [:]) else {
            return nil
        }

        try? pngData.write(to: frameURL)
        return frameURL
    }

    func setLockScreen(item: WallpaperItem) {
        let filename = item.url.lastPathComponent
        DispatchQueue.main.async { [self] in
            lockScreenWallpaper = filename
            UserDefaults.standard.set(filename, forKey: "lockScreenWallpaper")
        }
        // Aerials are already synced via loadWallpapers/syncAllToAerials
        // Just restart the extension to ensure latest state
        DispatchQueue.global(qos: .utility).async {
            let kill = Process()
            kill.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
            kill.arguments = ["WallpaperAerialsExtension"]
            try? kill.run()
        }
    }

    /// Syncs ALL wallpapers to macOS aerials system — each one gets its own tile in System Settings
    private func syncAllToAerials() {
        let items = wallpapers
        DispatchQueue.global(qos: .utility).async { [self] in
            // Create directories
            let manifestDir = Self.aerialsBase.appendingPathComponent("manifest")
            for dir in [manifestDir, Self.thumbnailsDir] {
                try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            }

            // Read existing manifest
            var manifest: [String: Any]
            if let data = try? Data(contentsOf: Self.manifestFile),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                manifest = json
            } else {
                let systemManifest = URL(fileURLWithPath:
                    "/System/Library/PrivateFrameworks/WallpaperAerialAssets.framework/Versions/A/Resources/entries.json")
                if let data = try? Data(contentsOf: systemManifest),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    manifest = json
                } else {
                    manifest = ["assets": [[String: Any]](), "categories": [[String: Any]]()]
                }
            }

            var assets = manifest["assets"] as? [[String: Any]] ?? []
            var categories = manifest["categories"] as? [[String: Any]] ?? []

            // Remove all our previous assets (any ID that has a cached uuid_ key)
            assets.removeAll { asset in
                guard let id = asset["id"] as? String else { return false }
                return (asset["categories"] as? [String])?.contains(Self.categoryID) == true
                    || id == "LW000000-0000-4000-8000-AAAAAAAAAAAA" // old fixed ID
            }

            // Remove old fixed-UUID video if it exists
            let oldVideo = Self.aerialsBase.appendingPathComponent("videos/LW000000-0000-4000-8000-AAAAAAAAAAAA.mov")
            try? FileManager.default.removeItem(at: oldVideo)

            // Add each wallpaper as a separate aerial asset
            var firstAssetID: String?
            for (i, item) in items.enumerated() {
                let filename = item.url.lastPathComponent
                let assetID = Self.stableUUID(for: filename)
                if i == 0 { firstAssetID = assetID }

                // Generate thumbnail if needed
                let thumbDest = Self.thumbnailsDir.appendingPathComponent("\(assetID).png")
                if !FileManager.default.fileExists(atPath: thumbDest.path) {
                    if let frameURL = extractFrame(from: item.url) {
                        try? FileManager.default.copyItem(at: frameURL, to: thumbDest)
                    }
                }

                // Symlink video into aerials/videos/ (no disk space used)
                let videosDir = Self.aerialsBase.appendingPathComponent("videos")
                try? FileManager.default.createDirectory(at: videosDir, withIntermediateDirectories: true)
                let linkDest = videosDir.appendingPathComponent("\(assetID).mov")
                if !FileManager.default.fileExists(atPath: linkDest.path) {
                    try? FileManager.default.createSymbolicLink(at: linkDest, withDestinationURL: item.url)
                }

                let asset: [String: Any] = [
                    "id": assetID,
                    "accessibilityLabel": item.name,
                    "localizedNameKey": item.name,
                    "categories": [Self.categoryID],
                    "subcategories": [Self.subcategoryID],
                    "url-4K-SDR-240FPS": "videos/\(assetID).mov",
                    "previewImage": "thumbnails/\(assetID).png",
                    "shotID": "LW_\(String(assetID.prefix(6)))",
                    "pointsOfInterest": ["0": "LW_0"],
                    "showInTopLevel": true,
                    "includeInShuffle": true,
                    "preferredOrder": i
                ]
                assets.insert(asset, at: i)
            }

            // Add/update our category
            let repID = firstAssetID ?? ""
            categories.removeAll { ($0["id"] as? String) == Self.categoryID }
            let category: [String: Any] = [
                "id": Self.categoryID,
                "localizedDescriptionKey": "Live Wallpaper",
                "localizedNameKey": "Live Wallpaper",
                "preferredOrder": 0,
                "previewImage": firstAssetID.map { "thumbnails/\($0).png" } ?? "",
                "representativeAssetID": repID,
                "subcategories": [[
                    "id": Self.subcategoryID,
                    "localizedDescriptionKey": "Live Wallpaper",
                    "localizedNameKey": "Live Wallpaper",
                    "preferredOrder": 0,
                    "previewImage": firstAssetID.map { "thumbnails/\($0).png" } ?? "",
                    "representativeAssetID": repID
                ] as [String: Any]]
            ]
            categories.insert(category, at: 0)

            manifest["assets"] = assets
            manifest["categories"] = categories

            if let data = try? JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys]) {
                try? data.write(to: Self.manifestFile)
            }

            // Restart WallpaperAerialsExtension to pick up changes
            let kill = Process()
            kill.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
            kill.arguments = ["WallpaperAerialsExtension"]
            try? kill.run()
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
        activeVideoURL = nil
        UserDefaults.standard.removeObject(forKey: "activeWallpaper")
        stopWorkspaceObservers()
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
