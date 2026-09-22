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
    /// The last automatic action's banner, shown while Home is the selected tab; dropped with the shell (spec 2.7).
    @State private var banner: MissedDayBanner?
    /// Bumped once per result, so the same text twice still re-announces and restarts the 3 s.
    @State private var bannerToken = 0
    @Environment(\.appClock) private var clock
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Nil outside a DEBUG launch with `-holdBanner`, which keeps the banner up for a screenshot.
    @Environment(\.missedBannerHold) private var bannerHold
    /// Nil (normal) outside DEBUG seeds; false keeps the prompt off for seeds that must match prototype snapshots.
    @Environment(\.missedPromptEnabled) private var enabled
    /// "Ask me each time" (the default), "Always shift" or "Always skip" (Settings, spec 2.6).
    @AppStorage(MissedDayPolicy.storageKey) private var policyRaw = MissedDayPolicy.ask.rawValue

    init(program: Program, selected: AppTab) {
        self.program = program
        self.selected = selected
        _sessions = Query(filter: HomeSnapshotBuilder.sessionPredicate(programID: program.id), sort: \PlannedSession.index)
    }

    var body: some View {
        let today = now ?? clock.now()
        let policy = MissedDayPolicy.from(raw: policyRaw)
        let promptAllowed = enabled ?? true   // nil = normal; false only from a DEBUG seed outside the missed-day family
        // One value per render for prompt and automatic action alike: `.none` / `.prompt` / `.shift` / `.skip` (spec 5.5).
        let resolution = promptAllowed
            ? MissedDay.resolution(policy: policy, sessions: HomeSnapshotBuilder.sessionSummaries(from: sessions),
                                   silence: silence, today: today, calendar: clock.calendar)
            : .none
        let missed = promptCard(resolution)
        let shows = selected == .home && missed != nil
        // A concrete root, never a Group wrapping the `if` (that root skips onAppear while hidden): its handlers run while it
        // draws nothing, and a transparent full-size frame intercepts no touch (researcher addendum P1).
        ZStack(alignment: .bottom) {
            if shows, let missed {
                ZStack(alignment: .bottom) {
                    Color.black.opacity(0.55)
                        .ignoresSafeArea()
                        .onTapGesture { dismiss(missed, today: today) }
                    MissedSessionCard(
                        title: MissedDayText.title(name: missed.name, scheduledDate: missed.scheduledDate, today: today,
                                                   calendar: clock.calendar),
                        onShift: { _ = shift(missed.index) },
                        onSkip: { _ = skip(missed.index) },
                        onDismiss: { dismiss(missed, today: today) })
                }
                .accessibilityElement(children: .contain)
                .accessibilityAddTraits(.isModal)   // ≈ aria-modal="true"; VoiceOver containment is a device check (AC-17)
                .accessibilityAction(.escape) { dismiss(missed, today: today) }   // two-finger Z ≈ an Escape-key handler
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .top) {
            if let banner, selected == .home {
                MissedActionBanner(text: banner.text, onTap: { self.banner = nil })
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: visibleToken)
        // ≈ useEffect(run, [policy, first missed index, day]): one run per distinct action, never on a plain re-render.
        .task(id: MissedDay.automaticActionKey(resolution: resolution, policy: policy, today: today, calendar: clock.calendar)) {
            runAutomatic(resolution)
        }
        // The announcement fires when the banner appears *on Home*, not when the action ran on another tab.
        .onChange(of: visibleToken) { _, token in
            if token != nil, let text = banner?.text {
                AccessibilityNotification.Announcement(text).post()
            }
        }
        // 3 s of *visible* time: leaving Home cancels this task and the `catch` returns without clearing, so the banner
        // survives and the 3 s restarts on the way back.
        .task(id: timerToken) {
            guard let timerToken else { return }
            do {
                try await Task.sleep(for: .seconds(3))
            } catch {
                return
            }
            if banner?.token == timerToken { banner = nil }
        }
        .onAppear { now = clock.now() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { now = clock.now() }
        }
        .onChange(of: selected) { _, tab in
            if tab == .home { now = clock.now() }   // the app may have sat on another tab across midnight
        }
        // A silence belongs to the prompt only, so switching policies acts at once (NB3).
        .onChange(of: policyRaw) { _, _ in silence = nil }
    }

    /// The banner's token while Home is the selected tab, nil otherwise: one derived value drives both the announcement and
    /// the timer (≈ a selector, never a `@State` written in `body`).
    private var visibleToken: Int? { selected == .home ? banner?.token : nil }

    /// The auto-dismiss key. Read here in `body`, never after an `await` (an environment value read after a suspension is
    /// stale; gotchas Swift 2026-09-22).
    private var timerToken: Int? { bannerHold == true ? nil : visibleToken }

    /// The session the card names, or nil under every other resolution. The card reads the associated value, so prompt and
    /// automatic action can never disagree about which session is first.
    private func promptCard(_ resolution: MissedDayResolution) -> SessionSummary? {
        if case .prompt(let missed) = resolution { return missed }
        return nil
    }

    /// The automatic pass (spec 2.6, B1). Deliberately synchronous with no `await`: the query must not re-fetch between the
    /// skip saves, or the task would be cancelled after the first one. The task also runs at mount with a nil id (on 26.5
    /// before `onAppear`), so the resolution's case is the guard. A failed write here is silent even in Debug (see `shift`).
    private func runAutomatic(_ resolution: MissedDayResolution) {
        switch resolution {
        case .none, .prompt:
            return
        case .shift(let missedIndex):
            guard let map = shift(missedIndex, assertOnFailure: false), let newDate = map[missedIndex],
                  let name = sessionName(missedIndex) else { return }
            let now = clock.now()
            show(MissedDayText.shiftedBanner(name: name,
                                             style: MissedDay.bannerDayStyle(newDate: newDate, today: now, calendar: clock.calendar),
                                             newDate: newDate, calendar: clock.calendar))
        case .skip(let indexes):
            var skipped: [String] = []
            for index in indexes {
                // A failed save stops the pass, keeping what landed; no assert, because no tap started this.
                guard let written = skip(index, assertOnFailure: false) else { break }
                if written, let name = sessionName(index) { skipped.append(name) }
            }
            if let text = MissedDayText.skippedBanner(names: skipped) { show(text) }
        }
    }

    private func sessionName(_ index: Int) -> String? {
        sessions.first { $0.index == index }?.name
    }

    /// One banner at a time; a newer result replaces the text and restarts the 3 s (spec 2.7).
    private func show(_ text: String) {
        bannerToken += 1
        banner = MissedDayBanner(text: text, token: bannerToken)
    }

    /// Silences this session for the day the card was rendered for (`today` = the host's `now`), not the clock at the tap:
    /// a card left up across midnight must still hide on its first tap.
    private func dismiss(_ missed: SessionSummary, today: Date) {
        silence = MissedDay.PromptSilence(sessionIndex: missed.index, day: CalendarRules.startOfDay(today, calendar: clock.calendar))
    }

    /// "Do it today · shift program": today is the clock read at the tap. Returns the applied map (`[:]` when the session is
    /// no longer missed, a silent no-op) or nil when the save failed, so the caller can name what moved. Callers that ignore
    /// the result discard it explicitly (`_ =`); there is no `@discardableResult` here.
    /// `assertOnFailure` is false on the automatic path only: that one runs with no tap, so a persistently failing store
    /// would otherwise trap every Debug launch. Release behaviour is identical either way (`assertionFailure` is a no-op).
    private func shift(_ index: Int, assertOnFailure: Bool = true) -> [Int: Date]? {
        do {
            return try ProgramStore.shift(missedIndex: index, rows: sessions, trainingWeekdays: program.trainingWeekdays,
                                          today: clock.now(), calendar: clock.calendar, in: modelContext)
        } catch {
            // Rolled back and restored: the rows are unchanged, so the prompt stays and the Program card keeps its buttons.
            if assertOnFailure { assertionFailure("Shift failed: \(error)") }
            return nil
        }
    }

    /// "Skip it · stay on schedule": true when the row was written, false when it was no longer missed (a silent no-op), nil
    /// when the save failed, so an automatic pass can stop and still name what landed. `assertOnFailure` as in `shift`.
    private func skip(_ index: Int, assertOnFailure: Bool = true) -> Bool? {
        do {
            return try ProgramStore.skipMissed(sessionIndex: index, rows: sessions, today: clock.now(),
                                               calendar: clock.calendar, in: modelContext)
        } catch {
            // Rolled back and restored: the rows are unchanged, so the prompt stays and the Program card keeps its buttons.
            if assertOnFailure { assertionFailure("Skip failed: \(error)") }
            return nil
        }
    }
}
