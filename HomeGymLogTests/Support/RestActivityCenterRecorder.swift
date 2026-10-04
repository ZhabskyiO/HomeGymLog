import Foundation
@testable import HomeGymLog

/// A fake Live Activity system for `RestActivityCenter` plus a fake rest notifier, appending to ONE event log so tests
/// can assert the order of activity and notification calls together (plan S8). It keeps its own `shown` list the way the
/// system keeps `Activity.activities`: a request appends `r1`, `r2`, …; an update or end acts only on an id still in the
/// list (a missing id records nothing, as the live seam skips it). Every async call first yields, so a non-serialized
/// caller can interleave and a test of the serialization can fail. `holdsEnd` holds each `end` call until released.
@MainActor
final class RestActivityCenterRecorder {
    enum Event: Equatable {
        case request(logID: String, RestActivityContent)
        case update(id: String, RestActivityContent)
        case end(id: String)
        case schedule(Date, withSound: Bool)
        case cancel
    }

    var shown: [ShownRestActivity] = []
    var activitiesEnabled = true
    /// When true, each `end` call waits until `releaseEnd(_:)` resumes it (before anything is ended).
    var holdsEnd = false
    private(set) var events: [Event] = []
    private var requests = 0
    private var held: [CheckedContinuation<Void, Never>?] = []

    init(shown: [ShownRestActivity] = []) {
        self.shown = shown
    }

    /// How many `end` calls have been held so far (released ones included).
    var waitingEnds: Int { held.count }

    func releaseEnd(_ index: Int) {
        guard held.indices.contains(index), let continuation = held[index] else { return }
        held[index] = nil
        continuation.resume()
    }

    var center: RestActivityCenter {
        RestActivityCenter(
            shown: { [unowned self] in self.shown },
            request: { [unowned self] logID, content in
                self.requests += 1
                self.events.append(.request(logID: logID, content))
                self.shown.append(ShownRestActivity(id: "r\(self.requests)", logID: logID, content: content))
            },
            update: { [unowned self] id, content in
                await Task.yield()
                guard let index = self.shown.firstIndex(where: { $0.id == id }) else { return }
                self.events.append(.update(id: id, content))
                self.shown[index] = ShownRestActivity(id: id, logID: self.shown[index].logID, content: content)
            },
            end: { [unowned self] ids in
                await Task.yield()
                if self.holdsEnd { await withCheckedContinuation { continuation in self.held.append(continuation) } }
                for id in ids where self.shown.contains(where: { $0.id == id }) {
                    self.events.append(.end(id: id))
                    self.shown.removeAll { $0.id == id }
                }
            },
            areActivitiesEnabled: { [unowned self] in self.activitiesEnabled })
    }

    var notifier: RestNotifier {
        RestNotifier(
            schedule: { [unowned self] endsAt, _, withSound in
                await Task.yield()
                self.events.append(.schedule(endsAt, withSound: withSound))
            },
            cancel: { [unowned self] in self.events.append(.cancel) },
            removeDelivered: {})
    }
}
