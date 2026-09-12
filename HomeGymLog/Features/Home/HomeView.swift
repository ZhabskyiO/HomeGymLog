import SwiftUI
import SwiftData

/// The Home tab. Owns a live query on this program's sessions (a view holding only the `Program` never
/// re-renders on iOS 17; a `@Query` retains its rows and re-fetches on every save ≈ useQuery). Finished-log
/// values are rebuilt only when the rows' fingerprint changes ≈ useMemo keyed on a fingerprint.
struct HomeView: View {
    /// Immutable fields only: id, session length.
    let program: Program
    @Binding var selectedTab: AppTab
    @Query private var sessions: [PlannedSession]
    @State private var logs: [FinishedLogValue] = []
    /// Written when the scene becomes active; a bare clock read in body never refreshes on foreground.
    @State private var now: Date?
    @State private var infoExercise: Exercise?
    @Environment(\.appClock) private var clock
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("units") private var unitsRaw = WeightUnit.lb.rawValue

    init(program: Program, selectedTab: Binding<AppTab>) {
        self.program = program
        _selectedTab = selectedTab
        _sessions = Query(filter: HomeSnapshotBuilder.sessionPredicate(programID: program.id), sort: \PlannedSession.index)
    }

    private var unit: WeightUnit { WeightUnit(rawValue: unitsRaw) ?? .lb }

    /// Session values are mapped per render (scalar reads); logs come from state.
    private var input: HomeStatsInput {
        let summaries = HomeSnapshotBuilder.sessionSummaries(from: sessions)
        do {
            return try HomeStatsInput(sessions: summaries, logs: logs)
        } catch {
            // Only `logs` can be at fault; keep the header, tiles, strip and cards and drop PRs/volume for this frame.
            assertionFailure("Home stats input invalid: \(error)")
            return (try? HomeStatsInput(sessions: summaries, logs: [])) ?? .empty
        }
    }

    var body: some View {
        HomeContent(input: input, today: now ?? clock.now(), unit: unit, calendar: clock.calendar,
                    sessionLengthMinutes: program.sessionLengthMinutes,
                    onProgress: { selectedTab = .progress }, onInfo: { infoExercise = $0 })
            .background(Theme.bg.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .task(id: HomeSnapshotBuilder.fingerprint(of: sessions)) {
                logs = HomeSnapshotBuilder.finishedLogs(from: sessions)
            }
            .onAppear { now = clock.now() }   // ≈ useEffect(() => setNow(clock.now()), [])
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { now = clock.now() }
            }
            .exerciseInfoSheet(item: $infoExercise)
    }
}

#if DEBUG
#Preview {
    let calendar = AppClock.live().calendar
    let container = try! DebugSeed.midProgram.makeContainer(calendar: calendar)
    return HomeView(program: try! ProgramStore.current(in: container.mainContext)!, selectedTab: .constant(.home))
        .modelContainer(container)
        .environment(\.appClock, DebugSeed.midProgram.clock(calendar: calendar))
}
#endif
