import Testing
@testable import HomeGymLog

/// The static tables in spec 4.9, asserted verbatim row by row: every split day, every default-day
/// array, every split description, every cue triple. `@Test(arguments:)` runs the body once per row,
/// like `it.each(table)` in Jest.
@Suite struct StaticTableTests {
    @Test("split plan days list the spec's six keys in order", arguments: [
        (3, 0, "Full Body A", ["dbBench", "latPull", "goblet", "shoulderPress", "curl", "pushdown"]),
        (3, 1, "Full Body B", ["chestPress", "dbRow", "rdl", "latRaise", "legExt", "skull"]),
        (3, 2, "Full Body C", ["inclineDb", "lowRow", "split", "pecDeck", "legCurl", "curl"]),
        (4, 0, "Upper A", ["dbBench", "latPull", "shoulderPress", "lowRow", "curl", "pushdown"]),
        (4, 1, "Lower A", ["goblet", "rdl", "legExt", "legCurl", "lunge", "split"]),
        (4, 2, "Upper B", ["inclineDb", "dbRow", "pecDeck", "latRaise", "skull", "curl"]),
        (4, 3, "Lower B", ["split", "rdl", "legExt", "legCurl", "goblet", "lunge"]),
        (5, 0, "Push", ["dbBench", "inclineDb", "shoulderPress", "pecDeck", "latRaise", "pushdown"]),
        (5, 1, "Pull", ["latPull", "lowRow", "dbRow", "rdl", "curl", "latRaise"]),
        (5, 2, "Legs", ["goblet", "rdl", "legExt", "legCurl", "split", "lunge"]),
        (5, 3, "Upper", ["chestPress", "dbRow", "shoulderPress", "pecDeck", "skull", "curl"]),
        (5, 4, "Lower", ["split", "legExt", "legCurl", "lunge", "goblet", "rdl"]),
    ])
    func planDay(frequency: Int, dayIndex: Int, name: String, keys: [String]) throws {
        let days = try #require(SplitPlans.days(frequency: frequency))
        #expect(days.count == frequency)
        #expect(days[dayIndex].name == name)
        #expect(days[dayIndex].exerciseKeys == keys)
    }

    @Test("default training days are Mon/Wed/Fri, Mon/Tue/Thu/Fri, Mon–Fri", arguments: [
        (3, [0, 2, 4]), (4, [0, 1, 3, 4]), (5, [0, 1, 2, 3, 4]),
    ])
    func defaultDays(frequency: Int, expected: [Int]) {
        #expect(SplitPlans.defaultWeekdays(frequency: frequency) == expected)
    }

    @Test("split names and descriptions are verbatim", arguments: [
        (3, "Full body A / B / C", "Every session hits chest, back, legs, shoulders and arms."),
        (4, "Upper / Lower", "Two upper and two lower days; each muscle twice a week."),
        (5, "Push / Pull / Legs + Upper / Lower", "Five days, every muscle hit twice with a different emphasis."),
    ])
    func splitInfo(frequency: Int, name: String, description: String) throws {
        let info = try #require(SplitPlans.info(frequency: frequency))
        #expect(info.name == name)
        #expect(info.description == description)
    }

    @Test("every exercise's three cues are verbatim from the prototype", arguments: [
        ("dbBench", ["Feet planted, shoulder blades pinned to the bench.", "Lower to chest level, elbows ~45°.", "Press up and slightly in; don't clank the bells."]),
        ("inclineDb", ["Bench at 30°, ribs down.", "Lower to upper chest.", "Drive through and finish over the shoulders."]),
        ("chestPress", ["Handles at mid-chest height.", "Press straight forward, elbows soft at lockout.", "Control the return, stack never slams."]),
        ("pecDeck", ["Elbows level with shoulders.", "Squeeze pads together, pause 1s.", "Open only to a light stretch."]),
        ("latPull", ["Lean back 10–15°, chest up.", "Pull the bar to upper chest, elbows down.", "Let the lats stretch fully at the top."]),
        ("lowRow", ["Sit tall, knees slightly bent.", "Pull to the belly, elbows tight.", "Shoulders back — no shrugging."]),
        ("dbRow", ["Hand on bench, back flat.", "Row to the hip, not the chest.", "Full stretch at the bottom."]),
        ("shoulderPress", ["Bells at ear height to start.", "Press up and in; don't flare the ribs.", "Lower slowly to ear height."]),
        ("latRaise", ["Slight forward lean.", "Lead with elbows to shoulder height.", "Pause, then lower for 2 counts."]),
        ("curl", ["Elbows pinned at your sides.", "Curl and rotate pinky up.", "Lower under control — no swinging."]),
        ("pushdown", ["Elbows glued to ribs.", "Push to full lockout.", "Return only to 90°."]),
        ("skull", ["Arms vertical, bells over forehead.", "Bend only at the elbows.", "Extend to lockout, squeeze."]),
        ("goblet", ["Bell at chest, elbows down.", "Sit between the heels.", "Stand tall — knees track over toes."]),
        ("rdl", ["Soft knees, hips back.", "Bells slide down the thighs.", "Stop at hamstring stretch, drive hips forward."]),
        ("legExt", ["Pad above the ankles.", "Extend to full lockout, pause.", "Lower for 2 counts."]),
        ("legCurl", ["Hips stay down.", "Curl heels to glutes.", "Slow, controlled return."]),
        ("split", ["Rear foot on bench.", "Drop straight down, front knee over ankle.", "Push through the whole front foot."]),
        ("lunge", ["Long stride, torso upright.", "Back knee kisses the floor.", "Drive through front heel."]),
    ])
    func cues(key: String, expected: [String]) throws {
        let exercise = try #require(ExerciseLibrary.exercise(for: key))
        #expect(exercise.cues == expected)
    }
}
