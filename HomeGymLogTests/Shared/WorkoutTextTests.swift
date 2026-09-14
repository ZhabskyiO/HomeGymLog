import Foundation
import Testing
@testable import HomeGymLog

/// AC-32 (text half): the workout and summary strings, typed from spec 2.x, 5.4 and 5.5.
@MainActor
@Suite struct WorkoutTextTests {
    private var cal: Calendar {
        var c = TestCalendar.calendar
        c.locale = Locale(identifier: "en_US")
        return c
    }

    @Test("clock: minutes uncapped; a negative count (before the start) reads 00:00")
    func clock() {
        #expect([0, 59, 754, 2520, 3600, 4503].map(WorkoutText.clock(seconds:)) == ["00:00", "00:59", "12:34", "42:00", "60:00", "75:03"])
        #expect(WorkoutText.clock(seconds: -1) == "00:00")
        #expect(WorkoutText.clock(seconds: -754) == "00:00")
    }

    @Test("grouping and volume in both units")
    func volume() {
        #expect([0, 999, 1000, 9000, 12270, 1_234_567].map(WorkoutText.grouped) == ["0", "999", "1,000", "9,000", "12,270", "1,234,567"])
        #expect(WorkoutText.grouped(-1234) == "-1,234")
        #expect(WorkoutText.volume(lb: 12270, unit: .lb) == "12,270")
        #expect(WorkoutText.volume(lb: 12270, unit: .kg) == "5,566")
        #expect(WorkoutText.volume(lb: 9000, unit: .lb) == "9,000")
        #expect(WorkoutText.volume(lb: 9000, unit: .kg) == "4,082")
        #expect(WorkoutText.volume(lb: 0, unit: .lb) == "0")
        #expect(WorkoutText.volume(lb: 999, unit: .lb) == "999")
        #expect(WorkoutText.volumeCaption(unit: .lb) == "lb total volume" && WorkoutText.volumeCaption(unit: .kg) == "kg total volume")
        #expect(WorkoutText.weightCaption(unit: .lb) == "Weight · lb" && WorkoutText.weightCaption(unit: .kg) == "Weight · kg")
    }

    @Test("exercise name, line and equipment; an unknown key falls back")
    func exercise() {
        #expect(WorkoutText.exerciseName(key: "latPull") == "Lat Pulldown")
        #expect(WorkoutText.exerciseLine(number: 1, count: 5, key: "latPull") == "Exercise 1 of 5 · Back")
        #expect(WorkoutText.exerciseLine(number: 1, count: 5, key: "goblet") == "Exercise 1 of 5 · Legs")
        #expect(WorkoutText.equipment(key: "latPull") == "Marcy · high pulley")
        #expect(WorkoutText.exerciseName(key: "mystery") == "mystery")
        #expect(WorkoutText.exerciseLine(number: 2, count: 5, key: "mystery") == "Exercise 2 of 5")
        #expect(WorkoutText.equipment(key: "mystery") == "")
    }

    @Test("summary meta uses the start day with the stored week and phase, or the no-session fallback")
    func meta() {
        let noon = TestCalendar.day(2026, 9, 15).addingTimeInterval(12 * 3600)
        #expect(WorkoutText.meta(startedAt: noon, info: WorkoutSessionInfo(name: "Pull", week: 3, phase: .foundation), calendar: cal)
                == "Tue, Sep 15 · Week 3 · Foundation")
        #expect(WorkoutText.meta(startedAt: noon, info: WorkoutSessionInfo(name: "", week: 1, phase: .foundation), calendar: cal)
                == "Tue, Sep 15 · Week 1 · Foundation")
        #expect(WorkoutText.meta(startedAt: noon, info: WorkoutSessionInfo(name: "Legs", week: 2, phase: .foundation), calendar: cal)
                == "Tue, Sep 15 · Week 2 · Foundation")
    }

    @Test("row labels for all five kinds")
    func rowLabels() {
        #expect(WorkoutText.rowLabel(.done(rpe: 7)) == "RPE 7")
        #expect(WorkoutText.rowLabel(.done(rpe: nil)) == "logged")
        #expect(WorkoutText.rowLabel(.skipped) == "skipped")
        #expect(WorkoutText.rowLabel(.active) == "← →")
        #expect(WorkoutText.rowLabel(.waiting) == "")
    }

    @Test("RPE labels 6…10; outside the range is empty")
    func rpeLabels() {
        #expect((6...10).map(WorkoutText.rpeLabel) == ["easy", "solid", "hard", "grind", "max"])
        #expect(WorkoutText.rpeLabel(5) == "" && WorkoutText.rpeLabel(11) == "")
    }

    @Test("record rows in lb and kg, with a dash for no previous best")
    func records() {
        #expect(WorkoutText.recordPrevious(100, unit: .lb) == "100 lb")
        #expect(WorkoutText.recordNew(120, unit: .lb) == "120 lb")
        #expect(WorkoutText.recordPrevious(100, unit: .kg) == "45.4 kg")
        #expect(WorkoutText.recordNew(120, unit: .kg) == "54.4 kg")
        #expect(WorkoutText.recordNew(47.5, unit: .lb) == "47.5 lb")
        #expect(WorkoutText.recordPrevious(nil, unit: .lb) == "—")
        #expect(WorkoutText.recordPrevious(nil, unit: .kg) == "—")
    }

    @Test("active row accessibility label in lb and kg")
    func accessibility() {
        #expect(WorkoutText.setAccessibilityLabel(number: 1, weightLb: 110, reps: 12, unit: .lb) == "Set 1, 110 lb × 12 reps")
        #expect(WorkoutText.setAccessibilityLabel(number: 1, weightLb: 110, reps: 12, unit: .kg) == "Set 1, 49.9 kg × 12 reps")
    }
}
