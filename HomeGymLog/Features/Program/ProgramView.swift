import SwiftUI
import SwiftData

/// The Program tab: every week of the program as chips, the selected week's days, and the selected day's
/// session (or a rest card). It writes to the store only through the shared start, when "Start workout" is tapped
/// on a today or missed card; the root then shows the workout.
/// Like Home, it owns its `@Query` (a view holding only the `Program` never re-renders on iOS 17) and keeps
/// one `now` written on appear and on scene-active. Analogy: `useQuery` for rows, a `visibilitychange` effect
/// for "today".
struct ProgramView: View {
    /// Immutable fields only: id, months, frequency.
    let program: Program
    @Binding var selectedTab: AppTab
    @Query private var sessions: [PlannedSession]
    @State private var selection: ProgramSelection = .followToday
    /// Written on appear and when the scene becomes active; a bare clock read in body never refreshes.
    @State private var now: Date?
    /// Bumped by every reset so the chip row re-scrolls even when the selected week is unchanged.
    @State private var scrollToken = 0
    @State private var infoExercise: Exercise?
    @Environment(\.appClock) private var clock
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @Environment(\.programTabPreselection) private var preselection
    @AppStorage("units") private var unitsRaw = WeightUnit.lb.rawValue

    init(program: Program, selectedTab: Binding<AppTab>) {
        self.program = program
        _selectedTab = selectedTab
        _sessions = Query(filter: HomeSnapshotBuilder.sessionPredicate(programID: program.id), sort: \PlannedSession.index)
    }

    private var unit: WeightUnit { WeightUnit(rawValue: unitsRaw) ?? .lb }

    var body: some View {
        let summaries = HomeSnapshotBuilder.sessionSummaries(from: sessions)   // scalar reads, safe while rendering
        ProgramContent(summaries: summaries, selection: selection, today: now ?? clock.now(), unit: unit,
                       calendar: clock.calendar, months: program.months, frequency: program.frequency,
                       scrollToken: scrollToken,
                       onSelectWeek: { selection = .week($0) },
                       onSelectDay: { week, day in selection = .day(week: week, day: day) },
                       onInfo: { infoExercise = $0 },
                       onStart: start(sessionIndex:),
                       onShift: shift(sessionIndex:),
                       onSkip: skip(sessionIndex:))
            .background(Theme.bg.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .onAppear { reset(summaries) }
            .onChange(of: selectedTab) { _, tab in
                if tab == .program { reset(summaries) }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { now = clock.now() }
            }
            .exerciseInfoSheet(item: $infoExercise)
    }

    /// Refreshes `now`, follows today (or the debug preselection, nil in Release), and re-scrolls the chip row.
    /// Idempotent, so both triggers above give the same state.
    private func reset(_ summaries: [SessionSummary]) {
        let today = clock.now()
        now = today
        selection = ProgramSelection.from(
            preselectedWeek: preselection?.week,
            preselectedDay: preselection?.day,
            initialWeek: ProgramTabStats.initialWeek(sessions: summaries, today: today, calendar: clock.calendar))
        scrollToken += 1
    }

    /// The shared start: nothing is written unless the row is still pending (a card can be stale; visibility follows
    /// the cached `now`, the write never does). `startedAt` is the clock read at the tap.
    private func start(sessionIndex: Int) {
        do {
            try WorkoutLogStore.start(sessionIndex: sessionIndex, rows: sessions, at: clock.now(), in: modelContext)
        } catch {
            assertionFailure("Start workout failed: \(error)")   // the store refused the write before this context changed; the shell stays
        }
    }

    /// A missed card's "Do it today · shift program". Follows today only when something moved (B3): it sets the selection
    /// directly, never through `reset`, which would re-apply the DEBUG preselection and re-select the emptied day. "Today" is
    /// the clock read at the tap, never the cached `now`.
    private func shift(sessionIndex: Int) {
        let today = clock.now()
        do {
            let moved = try ProgramStore.shift(missedIndex: sessionIndex, rows: sessions, trainingWeekdays: program.trainingWeekdays,
                                               today: today, calendar: clock.calendar, in: modelContext)
            guard !moved.isEmpty else { return }   // stale tap: nothing written, nothing refreshed
            selection = .followToday
            now = today
            scrollToken += 1
        } catch {
            assertionFailure("Shift failed: \(error)")   // rolled back and restored: the card stays "Missed" with its buttons
        }
    }

    /// A missed card's "Skip it · stay on schedule". The selection stays, so the same card re-renders as "Skipped"; a stale
    /// tap writes nothing.
    private func skip(sessionIndex: Int) {
        do {
            try ProgramStore.skipMissed(sessionIndex: sessionIndex, rows: sessions, today: clock.now(), calendar: clock.calendar,
                                        in: modelContext)
        } catch {
            assertionFailure("Skip failed: \(error)")   // rolled back and restored: the card stays "Missed" with its buttons
        }
    }
}

#if DEBUG
#Preview {
    let calendar = AppClock.live().calendar
    let container = try! DebugSeed.midProgram.makeContainer(calendar: calendar)
    return ProgramView(program: try! ProgramStore.current(in: container.mainContext)!, selectedTab: .constant(.program))
        .modelContainer(container)
        .environment(\.appClock, DebugSeed.midProgram.clock(calendar: calendar))
}
#endif
