import Testing
@testable import HomeGymLog

@Suite struct ExerciseLibraryTests {
    private static let expected: [(key: String, name: String, muscle: MuscleGroup, equipment: String, lb: Double, kind: EquipmentKind)] = [
        ("dbBench", "Dumbbell Bench Press", .chest, "Dumbbells + bench", 40, .dumbbell),
        ("inclineDb", "Incline Dumbbell Press", .chest, "Dumbbells + bench (incline)", 35, .dumbbell),
        ("chestPress", "Seated Chest Press", .chest, "Marcy · press arms", 90, .marcy),
        ("pecDeck", "Pec Deck Fly", .chest, "Marcy · butterfly arms", 70, .marcy),
        ("latPull", "Lat Pulldown", .back, "Marcy · high pulley", 100, .marcy),
        ("lowRow", "Seated Low Row", .back, "Marcy · low pulley", 90, .marcy),
        ("dbRow", "One-arm Dumbbell Row", .back, "Dumbbell + bench", 45, .dumbbell),
        ("shoulderPress", "Seated Shoulder Press", .shoulders, "Dumbbells + bench (upright)", 30, .dumbbell),
        ("latRaise", "Dumbbell Lateral Raise", .shoulders, "Dumbbells", 15, .dumbbell),
        ("curl", "Dumbbell Curl", .arms, "Dumbbells", 25, .dumbbell),
        ("pushdown", "Triceps Pushdown", .arms, "Marcy · high pulley", 60, .marcy),
        ("skull", "Dumbbell Skullcrusher", .arms, "Dumbbells + bench", 25, .dumbbell),
        ("goblet", "Goblet Squat", .legs, "Dumbbell", 50, .dumbbell),
        ("rdl", "Dumbbell Romanian Deadlift", .legs, "Dumbbells", 50, .dumbbell),
        ("legExt", "Leg Extension", .legs, "Marcy · leg developer", 70, .marcy),
        ("legCurl", "Leg Curl", .legs, "Marcy · leg developer", 50, .marcy),
        ("split", "Bulgarian Split Squat", .legs, "Dumbbells + bench", 30, .dumbbell),
        ("lunge", "Dumbbell Walking Lunge", .legs, "Dumbbells", 30, .dumbbell),
    ]

    @Test("library has the 18 exercises with exact fields, in order")
    func entries() throws {
        #expect(ExerciseLibrary.all.count == 18)
        for (index, row) in Self.expected.enumerated() {
            let exercise = ExerciseLibrary.all[index]
            #expect(exercise.key == row.key)
            #expect(exercise.name == row.name)
            #expect(exercise.muscle == row.muscle)
            #expect(exercise.equipment == row.equipment)
            #expect(exercise.defaultWeightLb == row.lb)
            #expect(exercise.kind == row.kind)
            #expect(exercise.cues.count == 3, "\(row.key) needs three cues")
        }
        #expect(Set(ExerciseLibrary.all.map(\.key)).count == 18)
    }

    @Test("cue text is verbatim from the prototype")
    func cues() throws {
        let latPull = try #require(ExerciseLibrary.exercise(for: "latPull"))
        #expect(latPull.cues == ["Lean back 10–15°, chest up.", "Pull the bar to upper chest, elbows down.", "Let the lats stretch fully at the top."])
        let lunge = try #require(ExerciseLibrary.exercise(for: "lunge"))
        #expect(lunge.cues[2] == "Drive through front heel.")
        #expect(ExerciseLibrary.exercise(for: "nope") == nil)
    }

    @Test("muscle group counts are 4/3/2/3/6 and marcy has seven keys")
    func counts() {
        let byMuscle = Dictionary(grouping: ExerciseLibrary.all, by: \.muscle).mapValues(\.count)
        #expect(byMuscle[.chest] == 4)
        #expect(byMuscle[.back] == 3)
        #expect(byMuscle[.shoulders] == 2)
        #expect(byMuscle[.arms] == 3)
        #expect(byMuscle[.legs] == 6)
        let marcy = Set(ExerciseLibrary.all.filter { $0.kind == .marcy }.map(\.key))
        #expect(marcy == ["chestPress", "pecDeck", "latPull", "lowRow", "pushdown", "legExt", "legCurl"])
    }

    @Test("every default weight is loadable on its equipment")
    func defaultsLoadable() {
        for exercise in ExerciseLibrary.all {
            #expect(exercise.kind.isLoadable(lb: exercise.defaultWeightLb), "\(exercise.key) default \(exercise.defaultWeightLb)")
        }
    }

    @Test("split plans reference known keys, six distinct per day, in cycle order")
    func splitPlans() throws {
        let expectedNames: [Int: [String]] = [
            3: ["Full Body A", "Full Body B", "Full Body C"],
            4: ["Upper A", "Lower A", "Upper B", "Lower B"],
            5: ["Push", "Pull", "Legs", "Upper", "Lower"],
        ]
        for frequency in [3, 4, 5] {
            let days = try #require(SplitPlans.days(frequency: frequency))
            #expect(days.map(\.name) == expectedNames[frequency])
            for day in days {
                #expect(day.exerciseKeys.count == 6)
                #expect(Set(day.exerciseKeys).count == 6, "\(day.name) has duplicate keys")
                for key in day.exerciseKeys {
                    #expect(ExerciseLibrary.exercise(for: key) != nil, "unknown key \(key) in \(day.name)")
                }
            }
            #expect(SplitPlans.defaultWeekdays(frequency: frequency)?.count == frequency)
            #expect(SplitPlans.info(frequency: frequency) != nil)
        }
        #expect(SplitPlans.days(frequency: 3)?[0].exerciseKeys == ["dbBench", "latPull", "goblet", "shoulderPress", "curl", "pushdown"])
        #expect(SplitPlans.days(frequency: 5)?[4].exerciseKeys == ["split", "legExt", "legCurl", "lunge", "goblet", "rdl"])
        #expect(SplitPlans.defaultWeekdays(frequency: 4) == [0, 1, 3, 4])
        #expect(SplitPlans.info(frequency: 5)?.name == "Push / Pull / Legs + Upper / Lower")
        #expect(SplitPlans.days(frequency: 2) == nil)
        #expect(SplitPlans.defaultWeekdays(frequency: 6) == nil)
    }

    @Test("exercise count by session length", arguments: [(20, 3), (30, 4), (45, 5), (60, 6)])
    func exerciseCount(minutes: Int, expected: Int) {
        #expect(SplitPlans.exerciseCount(sessionLengthMinutes: minutes) == expected)
    }

    @Test("exercise count rejects other lengths")
    func exerciseCountInvalid() {
        #expect(SplitPlans.exerciseCount(sessionLengthMinutes: 40) == nil)
    }
}
