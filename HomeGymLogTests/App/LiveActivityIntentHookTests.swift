import AppIntents
import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

/// m5-live-activity AC-12: the two intents deliver their action through the installed hook exactly once, and do nothing
/// when no hook is installed. The only suite that assigns `LiveActivityIntentHooks.handler`; serialized, and every test
/// saves and restores the handler and `inFlight` because the hosted test host ran `App.init`, which installed the live
/// handler (NB8).
@MainActor
@Suite(.serialized) struct LiveActivityIntentHookTests {
    @MainActor final class ActionLog {
        var actions: [RestActivityAction] = []
    }

    @Test("AddRestTimeIntent delivers .addRest once; with no handler it returns and records nothing")
    func addRest() async throws {
        let savedHandler = LiveActivityIntentHooks.handler, savedFlight = LiveActivityIntentHooks.inFlight
        defer { LiveActivityIntentHooks.handler = savedHandler; LiveActivityIntentHooks.inFlight = savedFlight }
        let log = ActionLog()
        LiveActivityIntentHooks.handler = { action in log.actions.append(action) }
        _ = try await AddRestTimeIntent().perform()
        #expect(log.actions == [.addRest])
        LiveActivityIntentHooks.handler = nil
        _ = try await AddRestTimeIntent().perform()
        #expect(log.actions == [.addRest])
    }

    @Test("SkipRestIntent delivers .skipRest once; with no handler it returns and records nothing")
    func skipRest() async throws {
        let savedHandler = LiveActivityIntentHooks.handler, savedFlight = LiveActivityIntentHooks.inFlight
        defer { LiveActivityIntentHooks.handler = savedHandler; LiveActivityIntentHooks.inFlight = savedFlight }
        let log = ActionLog()
        LiveActivityIntentHooks.handler = { action in log.actions.append(action) }
        _ = try await SkipRestIntent().perform()
        #expect(log.actions == [.skipRest])
        LiveActivityIntentHooks.handler = nil
        _ = try await SkipRestIntent().perform()
        #expect(log.actions == [.skipRest])
    }

    @Test("neither intent is discoverable or opens the app")
    func flags() {
        #expect(AddRestTimeIntent.isDiscoverable == false)
        #expect(SkipRestIntent.isDiscoverable == false)
        #expect(AddRestTimeIntent.openAppWhenRun == false)
        #expect(SkipRestIntent.openAppWhenRun == false)
    }

    @Test("the intent titles are the card's accessibility labels (typed as literals for the metadata extractor)")
    func titles() {
        #expect(String(localized: AddRestTimeIntent.title) == "Add 30 seconds")
        #expect(String(localized: SkipRestIntent.title) == "Skip rest")
        #expect(String(localized: AddRestTimeIntent.title) == RestActivityText.addAccessibility)
        #expect(String(localized: SkipRestIntent.title) == RestActivityText.skipAccessibility)
    }

    #if DEBUG
    /// AC-10 B1 through the installed hook: two "+30s" presses fired before either is awaited run one after the other, so
    /// the second re-syncs from the row the first wrote. The recorder yields inside every async call, so an unserialized
    /// chain interleaves and this fails (checked once by replacing the chain with a direct `perform`).
    @Test("two rapid +30s presses: update 12:01:32, schedule 12:01:32, update 12:02:02, schedule 12:02:02")
    func serializedPresses() async throws {
        let savedHandler = LiveActivityIntentHooks.handler, savedFlight = LiveActivityIntentHooks.inFlight
        defer { LiveActivityIntentHooks.handler = savedHandler; LiveActivityIntentHooks.inFlight = savedFlight }
        let cal = TestCalendar.calendar
        let noon = TestCalendar.day(2026, 9, 15).addingTimeInterval(12 * 3600)
        let container = try DebugSeed.woRest.makeContainer(calendar: cal)
        defer { withExtendedLifetime(container) {} }
        let log = try #require(try container.mainContext.fetch(FetchDescriptor(predicate: WorkoutSnapshotBuilder.inProgressPredicate)).first)
        let start = noon.addingTimeInterval(-13), next = "Next: set 2 of 3"
        let recorder = RestActivityCenterRecorder(shown: [ShownRestActivity(
            id: "a", logID: log.id.uuidString, content: RestActivityContent(startedAt: start, endsAt: noon.addingTimeInterval(62), nextText: next))])
        let suiteName = "live-activity-hook-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        LiveActivityIntentHooks.inFlight = nil
        LiveActivityIntentHooks.handler = RestActivityHandler.makeHook(container: container, clock: .frozen(at: noon, calendar: cal),
                                                                       defaults: defaults, notifier: recorder.notifier, center: recorder.center)
        let first = Task { _ = try await AddRestTimeIntent().perform() }
        let second = Task { _ = try await AddRestTimeIntent().perform() }
        try await first.value
        try await second.value
        let once = noon.addingTimeInterval(92), twice = noon.addingTimeInterval(122)
        #expect(recorder.events == [
            .update(id: "a", RestActivityContent(startedAt: start, endsAt: once, nextText: next)), .schedule(once, withSound: true),
            .update(id: "a", RestActivityContent(startedAt: start, endsAt: twice, nextText: next)), .schedule(twice, withSound: true),
        ])
    }
    #endif
}
