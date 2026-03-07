import ScreenSaver
import AVFoundation
import AppKit

@objc(LoneKnightSaverView)
class LoneKnightSaverView: ScreenSaverView {
    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    private var hasSetup = false

    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        animationTimeInterval = 1.0 / 30.0
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        setupPlayer()
    }

    override func startAnimation() {
        super.startAnimation()
        if !hasSetup { setupPlayer() }
        player?.play()
    }

    private func resolveVideoURL() -> URL {
        let wallpapersDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("projetos/live-wallpaper/wallpapers")
        let configFile = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("projetos/live-wallpaper/.lock-wallpaper")

        // 1. Read from shared config file (written by main app)
        if let filename = try? String(contentsOf: configFile, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines) {
            let directURL = wallpapersDir.appendingPathComponent(filename)
            if FileManager.default.fileExists(atPath: directURL.path) {
                return directURL
            }
        }

        // 2. Fallback: bundled wallpaper.mov
        let bundle = Bundle(for: LoneKnightSaverView.self)
        if let bundleURL = bundle.url(forResource: "wallpaper", withExtension: "mov") {
            return bundleURL
        }

        // 3. Last resort
        return URL(fileURLWithPath: FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("projetos/live-wallpaper/Lone Knight at Sunset.mov").path)
    }

    private func setupPlayer() {
        guard !hasSetup, superview != nil else { return }
        hasSetup = true

        layer?.backgroundColor = NSColor.black.cgColor

        let url = resolveVideoURL()
        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        item.preferredForwardBufferDuration = 5
        player = AVPlayer(playerItem: item)
        player?.isMuted = true
        player?.actionAtItemEnd = .none

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(loopVideo),
            name: .AVPlayerItemDidPlayToEndTime,
            object: item
        )

        playerLayer = AVPlayerLayer(player: player)
        playerLayer?.frame = bounds
        playerLayer?.videoGravity = .resizeAspectFill
        playerLayer?.backgroundColor = NSColor.black.cgColor
        layer?.addSublayer(playerLayer!)

        player?.play()
    }

    @objc private func loopVideo() {
        player?.seek(to: .zero)
        player?.play()
    }

    override func animateOneFrame() {
        if !hasSetup { setupPlayer() }
        playerLayer?.frame = bounds
    }

    override func stopAnimation() {
        player?.pause()
        super.stopAnimation()
    }

    override func draw(_ rect: NSRect) {
        NSColor.black.setFill()
        rect.fill()
    }

    override var hasConfigureSheet: Bool { false }
    override var configureSheet: NSWindow? { nil }
}
