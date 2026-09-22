import SwiftUI
import SwiftData

/// The Progress tab: exercise chips, the selected exercise's top-weight chart with Best and Since start, and the month
/// calendar. Read-only: nothing is written, not even the selected chip. Named `ProgressTabView` because an app-module
/// `ProgressView` would shadow SwiftUI's across the target.
/// Current sessions come from a `@Query` (≈ `useQuery`), archived programs from a second one; their completed sessions and
/// the selected key's tops are fetched in one `.task(id:)` (≈ an effect keyed on its id) and held in `@State`
/// (≈ `useState`). `body` never reads a session's `program` (~330 µs per row on iOS 17.5).
struct ProgressTabView: View {
    /// Immutable fields only: id and createdAt.
    let program: Program
    /// By value: the screen only watches for its own tab becoming selected, it never writes the selection.
    let selectedTab: AppTab
    @Query private var sessions: [PlannedSession]
    @Query(filter: ProgressSnapshotBuilder.archivedProgramPredicate, sort: \Program.createdAt) private var archivedPrograms: [Program]
    /// Written on appear, on scene-active and when this tab becomes selected; a bare clock read in body never refreshes.
    @State private var now: Date?
    /// A tapped chip; nil until the first tap (then the DEBUG preselection or the first chip shows).
    @State private var selectedKey: String?
    /// The task's last result. Never cleared before a re-fetch, so a return to the tab keeps the line up.
    @State private var held: ProgressHeld?
    @Environment(\.appClock) private var clock
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @Environment(\.progressPreselection) private var preselection
    @AppStorage("units") private var unitsRaw = WeightUnit.lb.rawValue

    init(program: Program, selectedTab: AppTab) {
        self.program = program
        self.selectedTab = selectedTab
        _sessions = Query(filter: HomeSnapshotBuilder.sessionPredicate(programID: program.id),
                          sort: [SortDescriptor(\PlannedSession.scheduledDate), SortDescriptor(\PlannedSession.index)])
    }

    var body: some View {
        let all = ProgressSnapshotBuilder.sessions(from: sessions, programID: program.id, programCreatedAt: program.createdAt, isArchived: false)
            + (held?.archivedSessions ?? [])
        let keys = ProgressStats.exerciseKeys(sessions: all)
        // A stale or unknown selection falls back to the first chip here, with no write (≈ a derived value, not an effect).
        let key = ProgressStats.effectiveKey(selected: selectedKey ?? preselection, keys: keys)
        let fingerprint = ProgressSnapshotBuilder.fingerprint(currentRows: sessions, archivedPrograms: archivedPrograms)
        ProgressContent(sessions: all, keys: keys, selectedKey: key,
                        tops: ProgressStats.heldTops(heldKey: held?.key, tops: held?.tops ?? [], effectiveKey: key),
                        isLoading: held?.key != key,
                        today: now ?? clock.now(), unit: WeightUnit(rawValue: unitsRaw) ?? .lb, calendar: clock.calendar,
                        onSelect: { selectedKey = $0 })
            .background(Theme.bg.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .task(id: "\(key ?? "")|\(fingerprint)") { load(key: key) }
            .onAppear { now = clock.now() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { now = clock.now() }
            }
            .onChange(of: selectedTab) { _, tab in
                if tab == .progress { now = clock.now() }
            }
    }

    /// The archived programs' completed sessions and the key's tops, on `mainContext`. Each fetch falls back on its own, so a
    /// failed tops read still leaves the chips and calendar their archived days (and vice versa).
    private func load(key: String?) {
        var archived: [ProgressSession] = []
        do {
            archived = try ProgressSnapshotBuilder.archivedCompletedSessions(of: archivedPrograms, in: modelContext)
        } catch {
            assertionFailure("Progress archived sessions fetch failed: \(error)")   // current program only
        }
        var tops: [ProgressTop] = []
        if let key {
            do {
                tops = try ProgressSnapshotBuilder.tops(
                    key: key, programCreatedAt: ProgressSnapshotBuilder.createdAtByProgram(current: program, archived: archivedPrograms),
                    in: modelContext)
            } catch {
                assertionFailure("Progress tops fetch failed: \(error)")   // the card shows the empty state for this key
            }
        }
        guard !Task.isCancelled else { return }   // a superseded run never overwrites a newer result
        held = ProgressHeld(key: key, tops: tops, archivedSessions: archived)
    }
}

/// What the task last fetched, and for which key.
private struct ProgressHeld {
    let key: String?
    let tops: [ProgressTop]
    let archivedSessions: [ProgressSession]
}

#if DEBUG
#Preview {
    let calendar = AppClock.live().calendar
    let container = try! DebugSeed.progressHistory.makeContainer(calendar: calendar)
    return ProgressTabView(program: try! ProgramStore.current(in: container.mainContext)!, selectedTab: .progress)
        .modelContainer(container)
        .environment(\.appClock, DebugSeed.progressHistory.clock(calendar: calendar))
}
#endif
