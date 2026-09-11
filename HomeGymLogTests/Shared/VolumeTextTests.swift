import Testing
@testable import HomeGymLog

@MainActor
@Suite struct VolumeTextTests {
    @Test("kfmt table", arguments: [(0, "0"), (999, "999"), (1000, "1.0k"), (7560, "7.6k"), (3429, "3.4k"), (49320, "49.3k"), (216000, "216.0k"), (1049, "1.0k"), (1050, "1.1k")])
    func kfmt(n: Int, expected: String) {
        #expect(VolumeText.kfmt(n) == expected)
    }

    @Test("week volume converts before formatting")
    func weekVolume() {
        #expect(VolumeText.weekVolume(lb: 7560, unit: .kg) == "3.4k")
        #expect(VolumeText.weekVolume(lb: 7560, unit: .lb) == "7.6k")
        #expect(VolumeText.weekVolume(lb: 0, unit: .kg) == "0")
        #expect(VolumeText.caption(unit: .lb) == "lb this week" && VolumeText.caption(unit: .kg) == "kg this week")
    }
}
