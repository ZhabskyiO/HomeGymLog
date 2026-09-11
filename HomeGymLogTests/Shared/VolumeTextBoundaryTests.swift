import Testing
@testable import HomeGymLog

/// `kfmt` at the 1 000 threshold and at each carry of the single decimal, plus the kg path around 1 000.
@MainActor
@Suite struct VolumeTextBoundaryTests {
    @Test("kfmt rounding boundaries", arguments: [
        (1, "1"), (950, "950"), (999, "999"), (1000, "1.0k"), (9949, "9.9k"), (9950, "10.0k"), (10000, "10.0k"),
        (99949, "99.9k"), (99950, "100.0k"), (999999, "1000.0k"),
    ])
    func kfmt(n: Int, expected: String) {
        #expect(VolumeText.kfmt(n) == expected)
    }

    @Test("kg conversion and whole-number rounding happen before the 1 000 threshold")
    func kgThreshold() {
        #expect(VolumeText.weekVolume(lb: 2203, unit: .kg) == "999", "999.26 kg")
        #expect(VolumeText.weekVolume(lb: 2204, unit: .kg) == "1.0k", "999.72 kg rounds to 1 000")
        #expect(VolumeText.weekVolume(lb: 999.5, unit: .lb) == "1.0k", "whole(lb:) rounds half away from zero")
    }
}
