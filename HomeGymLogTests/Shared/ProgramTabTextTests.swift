import Foundation
import Testing
@testable import HomeGymLog

/// AC-19: every string and colour role the Program tab shows (spec §2.1, §2.3, §5.6, §5.8).
@MainActor
@Suite struct ProgramTabTextTests {
    private var cal: Calendar {
        var c = TestCalendar.calendar
        c.locale = Locale(identifier: "en_US")
        return c
    }

    @Test("subtitle joins the program length and the split name")
    func subtitle() throws {
        let five = try #require(SplitPlans.info(frequency: 5)).name
        #expect(ProgramTabText.subtitle(months: 6, splitName: five) == "6-month program · Push / Pull / Legs + Upper / Lower")
        let four = try #require(SplitPlans.info(frequency: 4)).name
        #expect(ProgramTabText.subtitle(months: 1, splitName: four) == "1-month program · Upper / Lower")
    }

    @Test("the phase line reads name · scheme, with the Deload load note")
    func phaseLine() {
        #expect("\(Phase.foundation.rawValue) · \(ProgramTabText.phaseScheme(.foundation))" == "Foundation · 3 × 12")
        #expect("\(Phase.build.rawValue) · \(ProgramTabText.phaseScheme(.build))" == "Build · 4 × 10")
        #expect("\(Phase.peak.rawValue) · \(ProgramTabText.phaseScheme(.peak))" == "Peak · 4 × 8")
        #expect("\(Phase.deload.rawValue) · \(ProgramTabText.phaseScheme(.deload))" == "Deload · 2 × 12 · \u{2212}30% load")
        // The prototype uses a real minus sign, not a hyphen.
        #expect(ProgramTabText.phaseScheme(.deload).contains("\u{2212}"))
        #expect(!ProgramTabText.phaseScheme(.deload).contains("-"))
    }

    @Test("row scheme has no spaces")
    func rowScheme() {
        #expect(ProgramTabText.rowScheme(sets: 3, reps: 12) == "3×12")
        #expect(ProgramTabText.rowScheme(sets: 4, reps: 8) == "4×8")
        #expect(ProgramTabText.rowScheme(sets: 2, reps: 12) == "2×12")
    }

    @Test("status text and tone per session state")
    func status() {
        let date = TestCalendar.day(2026, 9, 16)
        #expect(ProgramTabText.status(.completed, date: date, calendar: cal) == "Completed")
        #expect(ProgramTabText.status(.skipped, date: date, calendar: cal) == "Skipped")
        #expect(ProgramTabText.status(.today, date: date, calendar: cal) == "Today")
        #expect(ProgramTabText.status(.missed, date: date, calendar: cal) == "Missed")
        #expect(ProgramTabText.status(.scheduled, date: date, calendar: cal) == "Sep 16")
        #expect(ProgramTabText.status(.rest, date: date, calendar: cal) == "")

        #expect(ProgramTabText.tone(for: .completed) == .success)
        #expect(ProgramTabText.tone(for: .skipped) == .muted)
        #expect(ProgramTabText.tone(for: .today) == .muted)
        #expect(ProgramTabText.tone(for: .missed) == .warning)
        #expect(ProgramTabText.tone(for: .scheduled) == .muted)
    }

    @Test("card weights in kg, one decimal")
    func kgWeights() {
        #expect(WeightDisplay.text(lb: 110, unit: .kg) == "49.9")
        #expect(WeightDisplay.text(lb: 100, unit: .kg) == "45.4")
        #expect(WeightDisplay.text(lb: 47.5, unit: .kg) == "21.5")
        #expect(WeightDisplay.text(lb: 52.5, unit: .kg) == "23.8")
        #expect(WeightDisplay.text(lb: 27.5, unit: .kg) == "12.5")
        #expect(WeightDisplay.text(lb: 40, unit: .kg) == "18.1")
    }

    @Test("fixed copy is verbatim")
    func fixedCopy() {
        #expect(ProgramTabText.restDay == "Rest day. Light walk, stretch, eat.")
        #expect(ProgramTabText.weekChipCaption == "WK")
    }
}
