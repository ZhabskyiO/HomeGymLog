import Foundation

// The rest card's strings, typed once here because the app's card and the widget extension's Live Activity both draw
// them (spec m5-live-activity §4.3). This file is compiled into both targets, so it is `nonisolated` (the extension has
// no default actor) and imports nothing from the app. React analogy: a constants module shared by two packages.
nonisolated enum RestActivityText {
    static let title = "Rest"
    static let addLabel = "+30s"
    static let skipLabel = "Skip"
    static let addAccessibility = "Add 30 seconds"
    static let skipAccessibility = "Skip rest"
    static let restOver = "Rest over"
    static let nextPrefix = "Next: "
}
