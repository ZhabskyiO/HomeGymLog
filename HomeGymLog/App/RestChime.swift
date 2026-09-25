import Foundation
import AVFAudio

/// The foreground "rest finished" chime (m5-haptics 2.3): `rest-over.caf`, played through the app's own audio session in
/// the ambient category, so it mixes with the user's music, follows its route (speaker, AirPods) and obeys the silent
/// switch. A struct of closures like `RestNotifier` (≈ an injected service): `.live()` in the app, `.silent()` in seeds
/// and previews, a counting double in tests. The only file that touches `AVFAudio`.
struct RestChime {
    var play: () -> Void

    /// Holds no state of its own: an `@Entry` default is re-evaluated on every environment read (gotchas SwiftUI
    /// 2026-09-24), so the player lives in the process-wide box below and `.live()` touches nothing until `play`.
    static func live() -> RestChime {
        RestChime(play: { Self.box.play() })
    }

    /// Does nothing: seeds freeze the clock and previews must not play audio.
    static func silent() -> RestChime {
        RestChime(play: {})
    }

    /// One player for the process (≈ a module-level singleton, not a value re-made per render).
    private static let box = PlayerBox()

    /// Loads the player on the first `play` of the process and never retries: if the ambient category cannot be set the
    /// player stays nil, so the app never plays in the default `soloAmbient` category, which would stop the user's music
    /// (gotchas Audio 2026-09-24). A missing or unreadable asset likewise leaves it nil. Later plays rewind and replay.
    private final class PlayerBox {
        private var didLoad = false
        private var player: AVAudioPlayer?

        func play() {
            if !didLoad {
                didLoad = true
                player = Self.makePlayer()
            }
            guard let player else { return }
            player.currentTime = 0
            player.play()
        }

        private static func makePlayer() -> AVAudioPlayer? {
            do {
                try AVAudioSession.sharedInstance().setCategory(.ambient)
            } catch {
                return nil
            }
            guard let url = Bundle.main.url(forResource: "rest-over", withExtension: "caf"),
                  let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
            player.prepareToPlay()
            return player
        }
    }
}
