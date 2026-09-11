import SwiftUI
import SwiftData

/// Routes between onboarding and the shell from a live query: onboarding while no program is current.
/// Nothing navigates explicitly; saving a program (or archiving it) flips the route. ≈ a live useQuery selector.
struct RootView: View {
    @Query(filter: ProgramStore.currentPredicate) private var currentPrograms: [Program]
    @AppStorage("units") private var unitsRaw = WeightUnit.lb.rawValue
    /// A DEBUG seed's prepared draft, or nil for a real launch.
    let seedDraft: OnboardingDraft?

    var body: some View {
        // if/else, not a ternary: a ternary needs one View type; @ViewBuilder wraps both branches.
        if currentPrograms.isEmpty {
            OnboardingView(initialDraft: seedDraft ?? OnboardingDraft(units: WeightUnit(rawValue: unitsRaw) ?? .lb))
        } else {
            ShellView()
        }
    }
}
