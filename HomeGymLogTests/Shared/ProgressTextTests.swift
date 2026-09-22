import Foundation
import Testing
@testable import HomeGymLog

/// AC-21 (text): every string and tone the Progress tab shows (spec 2.1–2.3, 4.3, 5.3, 5.7).
@MainActor
@Suite struct ProgressTextTests {
    private var cal: Calendar {
        var c = TestCalendar.calendar
        c.locale = Locale(identifier: "en_US")
        return c
    }

    @Test("delta: sign by the difference, U+2212 minus, converted as a difference in kg")
    func delta() {
        #expect(ProgressText.delta(lb: 5, unit: .lb) == "+5 lb")
        #expect(ProgressText.delta(lb: 0, unit: .lb) == "0 lb")
        #expect(ProgressText.delta(lb: -2.5, unit: .lb).unicodeScalars.map(\.value) == Array("\u{2212}2.5 lb".unicodeScalars.map(\.value)))
        #expect(ProgressText.delta(lb: -2.5, unit: .lb).unicodeScalars.first?.value == 0x2212)
        #expect(ProgressText.delta(lb: 5, unit: .kg) == "+2.3 kg")
        #expect(ProgressText.delta(lb: -2.5, unit: .kg) == "\u{2212}1.1 kg")
    }

    @Test("delta tone: success up, warning down, muted for 0 or no value")
    func tone() {
        #expect(ProgressText.deltaTone(lb: 5) == .success)
        #expect(ProgressText.deltaTone(lb: 0) == .muted)
        #expect(ProgressText.deltaTone(lb: -2.5) == .warning)
        #expect(ProgressText.deltaTone(lb: nil) == .muted)
    }

    @Test("weights in both units")
    func weights() {
        #expect(ProgressText.weight(lb: 42.5, unit: .lb) == "42.5")
        #expect(ProgressText.weight(lb: 42.5, unit: .kg) == "19.3")
        #expect(ProgressText.weight(lb: 40, unit: .kg) == "18.1")
    }

    @Test("month titles and completed counts")
    func month() {
        #expect(ProgressText.monthTitle(year: 2026, month: 9, calendar: cal) == "September 2026")
        #expect(ProgressText.monthTitle(year: 2026, month: 8, calendar: cal) == "August 2026")
        #expect(ProgressText.monthTitle(year: 2027, month: 2, calendar: cal) == "February 2027")
        #expect(ProgressText.completed(n: 9) == "9 completed")
        #expect(ProgressText.completed(n: 0) == "0 completed")
    }

    @Test("fixed strings verbatim, em dashes as U+2014")
    func constants() {
        #expect(ProgressText.title == "Progress")
        #expect(ProgressText.best == "Best")
        #expect(ProgressText.sinceStart == "Since start")
        #expect(ProgressText.none.unicodeScalars.map(\.value) == [0x2014])
        #expect(ProgressText.empty == "No sessions logged yet \u{2014} your first workout starts the line.")
        #expect(ProgressText.empty.unicodeScalars.filter { $0.value == 0x2014 }.count == 1)
    }

    @Test("cell values for all six states")
    func cellValues() {
        #expect(ProgressText.cellValue(state: .completed) == "Completed")
        #expect(ProgressText.cellValue(state: .today) == "Today")
        #expect(ProgressText.cellValue(state: .missed) == "Missed")
        #expect(ProgressText.cellValue(state: .skipped) == "Skipped")
        #expect(ProgressText.cellValue(state: .scheduled) == "Scheduled")
        #expect(ProgressText.cellValue(state: .rest) == nil)
    }

    @Test("chip labels are library names, unknown keys raw")
    func chips() {
        #expect(ProgressText.chipLabel(key: "dbBench") == "Dumbbell Bench Press")
        #expect(ProgressText.chipLabel(key: "goblet") == "Goblet Squat")
        #expect(ProgressText.chipLabel(key: "latPull") == "Lat Pulldown")
        #expect(ProgressText.chipLabel(key: "zzz") == "zzz")
    }

    @Test("chart summaries and point labels")
    func chart() {
        #expect(ProgressText.chartSummary(name: "Dumbbell Bench Press", count: 3, minLb: 37.5, maxLb: 42.5, unit: .lb)
                == "Dumbbell Bench Press, 3 sessions, 37.5 to 42.5 lb")
        #expect(ProgressText.chartSummary(name: "Dumbbell Bench Press", count: 1, minLb: 40, maxLb: 40, unit: .lb)
                == "Dumbbell Bench Press, 1 session, 40 to 40 lb")
        #expect(ProgressText.chartSummary(name: "Dumbbell Bench Press", count: 3, minLb: 37.5, maxLb: 42.5, unit: .kg)
                == "Dumbbell Bench Press, 3 sessions, 17 to 19.3 kg")
        #expect(ProgressText.chartEmptySummary(name: "Dumbbell Bench Press") == "Dumbbell Bench Press, no sessions logged")
        #expect(ProgressText.pointLabel(date: TestCalendar.day(2026, 8, 31), calendar: cal) == "Aug 31")
        #expect(ProgressText.pointValue(lb: 37.5, unit: .lb) == "37.5 lb")
    }
}
