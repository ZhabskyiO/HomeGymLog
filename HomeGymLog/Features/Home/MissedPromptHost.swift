import SwiftUI
import SwiftData

/// The Home missed-session prompt: a black 0.55 scrim plus `MissedSessionCard`, over the whole shell including the tab bar
/// (`ShellView` applies it as an overlay after the bar's inset). Always mounted and derived on every render from the rows,
/// today, the selected tab and the dismissal silence, never from a one-shot "is open" flag (≈ rendering a modal from store
/// state instead of an `isOpen` `useState`): a shift or skip hides it when the query re-fetches, and a failed save leaves
/// it up. Owns its own `@Query` (≈ `useQuery`; a view holding only the `Program` never re-renders on iOS 17) and its own
/// `now`, refreshed on appear, on scene-active and when Home becomes the selected tab (≈ a `visibilitychange` effect).
struct MissedPromptHost: View {
    /// Immutable fields only: id (the query) and training weekdays (the shift).
    let program: Program
    let selected: AppTab
    @Query private var sessions: [PlannedSession]
    /// Written by the three handlers below, never in `body`; `now ?? clock.now()` covers the frame before `onAppear`.
    @State private var now: Date?
    /// Set by a scrim tap, a drag or VoiceOver escape; lives as long as the shell stays mounted.
    @State private var silence: MissedDay.PromptSilence?
    @Environment(\.appClock) private var clock
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    /// Nil (normal) outside DEBUG seeds; false keeps the prompt off for seeds that must match prototype snapshots.
    @Environment(\.missedPromptEnabled) private var enabled

    init(program: Program, selected: AppTab) {
        self.program = program
        self.selected = selected
        _sessions = Query(filter: HomeSnapshotBuilder.sessionPredicate(programID: program.id), sort: \PlannedSession.index)
    }

    var body: some View {
        let today = now ?? clock.now()
        let missed = MissedDay.firstMissed(sessions: HomeSnapshotBuilder.sessionSummaries(from: sessions), today: today,
                                           calendar: clock.calendar)
        let promptAllowed = enabled ?? true   // nil = normal; false only from a DEBUG seed outside the missed-day family
        let shows = promptAllowed && selected == .home
            && MissedDay.shouldPrompt(missed: missed, silence: silence, today: today, calendar: clock.calendar)
        // A concrete root, never a Group wrapping the `if` (that root skips onAppear while hidden): its handlers run while it
        // draws nothing, and empty it has zero size, so it intercepts no touch (researcher addendum P1).
        ZStack(alignment: .bottom) {
            if shows, let missed {
                ZStack(alignment: .bottom) {
                    Color.black.opacity(0.55)
                        .ignoresSafeArea()
                        .onTapGesture { dismiss(missed, today: today) }
                    MissedSessionCard(
                        title: MissedDayText.title(name: missed.name, scheduledDate: missed.scheduledDate, today: today,
                                                   calendar: clock.calendar),
                        onShift: { shift(missed.index) },
                        onSkip: { skip(missed.index) },
                        onDismiss: { dismiss(missed, today: today) })
                }
                .accessibilityElement(children: .contain)
                .accessibilityAddTraits(.isModal)   // ≈ aria-modal="true"; VoiceOver containment is a device check (AC-17)
                .accessibilityAction(.escape) { dismiss(missed, today: today) }   // two-finger Z ≈ an Escape-key handler
            }
        }
        .onAppear { now = clock.now() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { now = clock.now() }
        }
        .onChange(of: selected) { _, tab in
            if tab == .home { now = clock.now() }   // the app may have sat on another tab across midnight
        }
    }

    /// Silences this session for the day the card was rendered for (`today` = the host's `now`), not the clock at the tap:
    /// a card left up across midnight must still hide on its first tap.
    private func dismiss(_ missed: SessionSummary, today: Date) {
        silence = MissedDay.PromptSilence(sessionIndex: missed.index, day: CalendarRules.startOfDay(today, calendar: clock.calendar))
    }

    /// "Do it today · shift program": today is the clock read at the tap. `[:]` (no longer missed) is a silent no-op.
    private func shift(_ index: Int) {
        do {
            try ProgramStore.shift(missedIndex: index, rows: sessions, trainingWeekdays: program.trainingWeekdays, today: clock.now(),
                                   calendar: clock.calendar, in: modelContext)
        } catch {
            assertionFailure("Shift failed: \(error)")   // rolled back and restored: the rows are unchanged, so the prompt stays
        }
    }

    /// "Skip it · stay on schedule": false (no longer missed) is a silent no-op; a next missed session re-renders the card.
    private func skip(_ index: Int) {
        do {
            try ProgramStore.skipMissed(sessionIndex: index, rows: sessions, today: clock.now(), calendar: clock.calendar, in: modelContext)
        } catch {
            assertionFailure("Skip failed: \(error)")   // rolled back and restored: the rows are unchanged, so the prompt stays
        }
    }
}
