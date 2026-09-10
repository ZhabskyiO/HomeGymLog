import Foundation

/// One training day of a split: its name and full ordered exercise list (always six keys).
nonisolated struct SplitDay: Hashable, Sendable {
    let name: String
    let exerciseKeys: [String]
}

/// Display name and one-line description of a split.
nonisolated struct SplitInfo: Hashable, Sendable {
    let name: String
    let description: String
}

/// Static split definitions keyed by training frequency (3, 4 or 5 days per week).
nonisolated enum SplitPlans {
    private static let plans: [Int: [SplitDay]] = [
        3: [
            SplitDay(name: "Full Body A", exerciseKeys: ["dbBench", "latPull", "goblet", "shoulderPress", "curl", "pushdown"]),
            SplitDay(name: "Full Body B", exerciseKeys: ["chestPress", "dbRow", "rdl", "latRaise", "legExt", "skull"]),
            SplitDay(name: "Full Body C", exerciseKeys: ["inclineDb", "lowRow", "split", "pecDeck", "legCurl", "curl"]),
        ],
        4: [
            SplitDay(name: "Upper A", exerciseKeys: ["dbBench", "latPull", "shoulderPress", "lowRow", "curl", "pushdown"]),
            SplitDay(name: "Lower A", exerciseKeys: ["goblet", "rdl", "legExt", "legCurl", "lunge", "split"]),
            SplitDay(name: "Upper B", exerciseKeys: ["inclineDb", "dbRow", "pecDeck", "latRaise", "skull", "curl"]),
            SplitDay(name: "Lower B", exerciseKeys: ["split", "rdl", "legExt", "legCurl", "goblet", "lunge"]),
        ],
        5: [
            SplitDay(name: "Push", exerciseKeys: ["dbBench", "inclineDb", "shoulderPress", "pecDeck", "latRaise", "pushdown"]),
            SplitDay(name: "Pull", exerciseKeys: ["latPull", "lowRow", "dbRow", "rdl", "curl", "latRaise"]),
            SplitDay(name: "Legs", exerciseKeys: ["goblet", "rdl", "legExt", "legCurl", "split", "lunge"]),
            SplitDay(name: "Upper", exerciseKeys: ["chestPress", "dbRow", "shoulderPress", "pecDeck", "skull", "curl"]),
            SplitDay(name: "Lower", exerciseKeys: ["split", "legExt", "legCurl", "lunge", "goblet", "rdl"]),
        ],
    ]

    private static let infos: [Int: SplitInfo] = [
        3: SplitInfo(name: "Full body A / B / C", description: "Every session hits chest, back, legs, shoulders and arms."),
        4: SplitInfo(name: "Upper / Lower", description: "Two upper and two lower days; each muscle twice a week."),
        5: SplitInfo(name: "Push / Pull / Legs + Upper / Lower", description: "Five days, every muscle hit twice with a different emphasis."),
    ]

    /// Default training weekdays, 0 = Monday.
    private static let defaultDays: [Int: [Int]] = [
        3: [0, 2, 4],
        4: [0, 1, 3, 4],
        5: [0, 1, 2, 3, 4],
    ]

    /// The split's days in cycle order; nil unless frequency is 3, 4 or 5.
    static func days(frequency: Int) -> [SplitDay]? {
        plans[frequency]
    }

    /// Name and description of the split; nil unless frequency is 3, 4 or 5.
    static func info(frequency: Int) -> SplitInfo? {
        infos[frequency]
    }

    /// Default training weekdays (0 = Monday); nil unless frequency is 3, 4 or 5.
    static func defaultWeekdays(frequency: Int) -> [Int]? {
        defaultDays[frequency]
    }

    /// Exercises per session by session length: 20 → 3, 30 → 4, 45 → 5, 60 → 6; nil otherwise.
    static func exerciseCount(sessionLengthMinutes: Int) -> Int? {
        switch sessionLengthMinutes {
        case 20: return 3
        case 30: return 4
        case 45: return 5
        case 60: return 6
        default: return nil
        }
    }
}
