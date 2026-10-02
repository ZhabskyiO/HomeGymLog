import Foundation

// The backup file's shape (spec 4.3–4.4): one flat table of plain rows per stored model, linked by id, plus the eight
// preferences. Stored fields only, nothing derived; weights in pounds. `Codable` ≈ a TypeScript type whose
// `JSON.parse` / `JSON.stringify` are generated for you. Every `CodingKeys` below has no raw values on purpose: the JSON
// key is the case name, which equals the stored property (and, for preferences, the `UserDefaults` key), so no quoted key
// literal is ever typed twice (AC-19).

/// The whole backup: header, six tables, optional preferences.
nonisolated struct BackupDocument: Codable, Equatable, Sendable {
    static let currentFormatVersion = 1
    static let appName = "HomeGymLog"

    var app: String
    var formatVersion: Int
    var exportedAt: Date
    var programs: [BackupProgram]
    var sessions: [BackupSession]
    var workoutLogs: [BackupWorkoutLog]
    var loggedExercises: [BackupLoggedExercise]
    var loggedSets: [BackupLoggedSet]
    var exerciseNotes: [BackupExerciseNote]
    /// Absent when the file carries none (or a non-object): the restore then leaves this phone's preferences alone (5.7).
    var preferences: BackupPreferences?

    init(app: String = BackupDocument.appName, formatVersion: Int = BackupDocument.currentFormatVersion, exportedAt: Date,
         programs: [BackupProgram], sessions: [BackupSession], workoutLogs: [BackupWorkoutLog],
         loggedExercises: [BackupLoggedExercise], loggedSets: [BackupLoggedSet], exerciseNotes: [BackupExerciseNote],
         preferences: BackupPreferences?) {
        self.app = app
        self.formatVersion = formatVersion
        self.exportedAt = exportedAt
        self.programs = programs
        self.sessions = sessions
        self.workoutLogs = workoutLogs
        self.loggedExercises = loggedExercises
        self.loggedSets = loggedSets
        self.exerciseNotes = exerciseNotes
        self.preferences = preferences
    }

    enum CodingKeys: CodingKey {
        case app, formatVersion, exportedAt, programs, sessions, workoutLogs, loggedExercises, loggedSets, exerciseNotes
        case preferences
    }

    /// Hand-written only so `preferences` decodes leniently: a wrong-typed object reads as absent, never a failure.
    /// `encode(to:)` stays synthesized (it omits nil optionals).
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        app = try c.decode(String.self, forKey: .app)
        formatVersion = try c.decode(Int.self, forKey: .formatVersion)
        exportedAt = try c.decode(Date.self, forKey: .exportedAt)
        programs = try c.decode([BackupProgram].self, forKey: .programs)
        sessions = try c.decode([BackupSession].self, forKey: .sessions)
        workoutLogs = try c.decode([BackupWorkoutLog].self, forKey: .workoutLogs)
        loggedExercises = try c.decode([BackupLoggedExercise].self, forKey: .loggedExercises)
        loggedSets = try c.decode([BackupLoggedSet].self, forKey: .loggedSets)
        exerciseNotes = try c.decode([BackupExerciseNote].self, forKey: .exerciseNotes)
        preferences = (try? c.decodeIfPresent(BackupPreferences.self, forKey: .preferences)) ?? nil
    }

    /// The confirm message's counts (5.2): workouts are logs with `finishedAt` set.
    var counts: (programs: Int, workouts: Int, notes: Int) {
        (programs.count, workoutLogs.filter { $0.finishedAt != nil }.count, exerciseNotes.count)
    }
}

nonisolated struct BackupProgram: Codable, Equatable, Sendable {
    var id: UUID
    var createdAt: Date
    var archivedAt: Date?
    var startDate: Date
    var months: Int
    var frequency: Int
    var trainingWeekdays: [Int]
    var sessionLengthMinutes: Int
    var bodyWeightLb: Double
    var experience: String
    var startingWeightsLb: [String: Double]
}

nonisolated struct BackupSession: Codable, Equatable, Sendable {
    var id: UUID
    var programID: UUID?
    var index: Int
    var week: Int
    /// `Phase` raw value ("Foundation" …), checked by validation rule 9.
    var phase: String
    var name: String
    var scheduledDate: Date
    var sets: Int
    var reps: Int
    var restSeconds: Int
    var exercises: [PlannedExercise]
    /// `SessionStatus` raw value.
    var status: String
}

nonisolated struct BackupWorkoutLog: Codable, Equatable, Sendable {
    var id: UUID
    var sessionID: UUID?
    var startedAt: Date
    var finishedAt: Date?
    var restStartedAt: Date?
    var restEndsAt: Date?
}

nonisolated struct BackupLoggedExercise: Codable, Equatable, Sendable {
    var id: UUID
    var workoutID: UUID?
    var order: Int
    var exerciseKey: String
    var swappedFromKey: String?
    var targetWeightLb: Double
}

nonisolated struct BackupLoggedSet: Codable, Equatable, Sendable {
    var id: UUID
    var exerciseID: UUID?
    var order: Int
    var weightLb: Double
    var reps: Int
    /// `SetStatus` raw value.
    var status: String
    var rpe: Int?
    var rpeSkipped: Bool
    var loggedAt: Date?
}

nonisolated struct BackupExerciseNote: Codable, Equatable, Sendable {
    var id: UUID
    var exerciseKey: String
    var text: String
    var updatedAt: Date
}

/// The eight preferences as the app stores them (5.7), each optional and decoded leniently: a missing or wrong-typed
/// field is nil, never a reason to reject the file.
nonisolated struct BackupPreferences: Codable, Equatable, Sendable {
    var units: String?
    var bodyWeightUnits: String?
    var appearance: String?
    var missedDayPolicy: String?
    var reminderEnabled: Bool?
    var reminderMinutes: Int?
    var hapticsEnabled: Bool?
    var soundEnabled: Bool?

    init(units: String? = nil, bodyWeightUnits: String? = nil, appearance: String? = nil, missedDayPolicy: String? = nil,
         reminderEnabled: Bool? = nil, reminderMinutes: Int? = nil, hapticsEnabled: Bool? = nil, soundEnabled: Bool? = nil) {
        self.units = units
        self.bodyWeightUnits = bodyWeightUnits
        self.appearance = appearance
        self.missedDayPolicy = missedDayPolicy
        self.reminderEnabled = reminderEnabled
        self.reminderMinutes = reminderMinutes
        self.hapticsEnabled = hapticsEnabled
        self.soundEnabled = soundEnabled
    }

    enum CodingKeys: CodingKey {
        case units, bodyWeightUnits, appearance, missedDayPolicy, reminderEnabled, reminderMinutes, hapticsEnabled, soundEnabled
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        units = (try? c.decodeIfPresent(String.self, forKey: .units)) ?? nil
        bodyWeightUnits = (try? c.decodeIfPresent(String.self, forKey: .bodyWeightUnits)) ?? nil
        appearance = (try? c.decodeIfPresent(String.self, forKey: .appearance)) ?? nil
        missedDayPolicy = (try? c.decodeIfPresent(String.self, forKey: .missedDayPolicy)) ?? nil
        reminderEnabled = (try? c.decodeIfPresent(Bool.self, forKey: .reminderEnabled)) ?? nil
        reminderMinutes = (try? c.decodeIfPresent(Int.self, forKey: .reminderMinutes)) ?? nil
        hapticsEnabled = (try? c.decodeIfPresent(Bool.self, forKey: .hapticsEnabled)) ?? nil
        soundEnabled = (try? c.decodeIfPresent(Bool.self, forKey: .soundEnabled)) ?? nil
    }

    /// Every key resolved through its fallback (5.7), so the restore writes exactly what the file describes. Total.
    func resolved() -> ResolvedPreferences {
        ResolvedPreferences(
            units: units.flatMap(WeightUnit.init(rawValue:)) ?? .lb,
            bodyWeightUnits: bodyWeightUnits.flatMap(WeightUnit.init(rawValue:)) ?? .lb,
            appearance: AppearanceMode.from(raw: appearance ?? ""),
            missedDayPolicy: MissedDayPolicy.from(raw: missedDayPolicy ?? ""),
            reminderEnabled: reminderEnabled ?? false,
            reminderMinutes: reminderMinutes.flatMap { ReminderPlan.validMinutes($0) } ?? ReminderPlan.defaultMinutes,
            hapticsEnabled: hapticsEnabled ?? FeedbackCues.defaultEnabled,
            soundEnabled: soundEnabled ?? FeedbackCues.defaultEnabled)
    }
}

/// The preferences after the fallbacks: typed, every key present. What the root writes after a successful restore.
nonisolated struct ResolvedPreferences: Equatable, Sendable {
    var units: WeightUnit
    var bodyWeightUnits: WeightUnit
    var appearance: AppearanceMode
    var missedDayPolicy: MissedDayPolicy
    var reminderEnabled: Bool
    var reminderMinutes: Int
    var hapticsEnabled: Bool
    var soundEnabled: Bool

    /// 5.7's fallback column.
    static let defaults = ResolvedPreferences(units: .lb, bodyWeightUnits: .lb, appearance: .system, missedDayPolicy: .ask,
                                              reminderEnabled: false, reminderMinutes: ReminderPlan.defaultMinutes,
                                              hapticsEnabled: FeedbackCues.defaultEnabled,
                                              soundEnabled: FeedbackCues.defaultEnabled)
}
