import AppKit
import AVFoundation

class AppDelegate: NSObject, NSApplicationDelegate {
    var windows: [NSWindow] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        let videoPath = NSString(string: "~/Library/Application Support/Wallux/Wallpapers/Lone Knight at Sunset.mov").expandingTildeInPath
        let videoURL = URL(fileURLWithPath: videoPath)

        guard FileManager.default.fileExists(atPath: videoPath) else {
            print("Video not found: \(videoPath)")
            NSApp.terminate(nil)
            return
        }

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

            let playerItem = AVPlayerItem(url: videoURL)
            let player = AVPlayer(playerItem: playerItem)
            player.isMuted = true
            player.actionAtItemEnd = .none

            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: playerItem,
                queue: .main
            ) { _ in
                player.seek(to: .zero)
                player.play()
            }

            let playerLayer = AVPlayerLayer(player: player)
            playerLayer.frame = CGRect(origin: .zero, size: screen.frame.size)
            playerLayer.videoGravity = .resizeAspectFill

            let view = NSView(frame: CGRect(origin: .zero, size: screen.frame.size))
            view.wantsLayer = true
            view.layer?.addSublayer(playerLayer)
            window.contentView = view

            window.orderFront(nil)
            player.play()

            windows.append(window)
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
