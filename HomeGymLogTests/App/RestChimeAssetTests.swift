import AVFAudio
import Foundation
import Testing

/// m5-haptics AC-16 (asset half): `rest-over.caf` is bundled in the app (the unit tests are hosted, so `Bundle.main` is
/// the app) and is a sub-second mono tone (spec 5.6: 0.2 s; IMA4 pads to 64-frame packets). Reads the file only; never
/// touches the audio session.
@Suite struct RestChimeAssetTests {
    @Test("the chime is in the app bundle, mono, about 0.2 s and under 1 s")
    func assetIsBundled() throws {
        let url = try #require(Bundle.main.url(forResource: "rest-over", withExtension: "caf"))
        let file = try AVAudioFile(forReading: url)
        #expect(file.processingFormat.channelCount == 1)
        let duration = Double(file.length) / file.processingFormat.sampleRate
        #expect(duration >= 0.19 && duration <= 0.21)
        #expect(duration < 1)
    }
}
