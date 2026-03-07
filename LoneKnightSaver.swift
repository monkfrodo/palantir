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

    private func setupPlayer() {
        guard !hasSetup, superview != nil else { return }
        hasSetup = true

        let bundle = Bundle(for: LoneKnightSaverView.self)
        let url = bundle.url(forResource: "wallpaper", withExtension: "mov")
            ?? URL(fileURLWithPath: "/Users/imacke/projetos/live-wallpaper/Lone Knight at Sunset.mov")

        let item = AVPlayerItem(url: url)
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
        super.stopAnimation()
        player?.pause()
    }

    override var hasConfigureSheet: Bool { false }
    override var configureSheet: NSWindow? { nil }
}
