import SwiftUI
import SwiftData

/// The onboarding flow: one screen, one draft, the content switches on the step (decision: no NavigationStack,
/// no swipeable pager). The draft is a `@State`-owned store ≈ useReducer at the wizard container.
struct OnboardingView: View {
    @State private var draft: OnboardingDraft
    @Environment(\.appClock) private var clock
    @Environment(\.modelContext) private var modelContext
    @AppStorage("units") private var unitsRaw = WeightUnit.lb.rawValue
    /// Stays true after a successful start until the route flips, so a second tap cannot land.
    @State private var isStarting = false
    @State private var startError: String?

    init(initialDraft: OnboardingDraft) {
        _draft = State(initialValue: initialDraft)
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    OnboardingHeader(step: draft.step, onBack: { withAnimation(.easeInOut(duration: 0.25)) { draft.goBack() } })
                    stepContent
                        .id(draft.step)
                        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                                removal: .move(edge: .leading).combined(with: .opacity)))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(maxHeight: .infinity, alignment: draft.step == 0 ? .bottom : .top)
                }
                .padding(.horizontal, 22)
                .padding(.top, 6)
                .frame(minHeight: geometry.size.height, alignment: .top)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: draft.step)
        .background(Theme.bg.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            OnboardingFooter(label: draft.ctaLabel, isEnabled: draft.canContinue && !isStarting, action: primaryAction)
        }
        .ignoresSafeArea(edges: .bottom)
        .alert("Couldn't start your program", isPresented: Binding(get: { startError != nil }, set: { if !$0 { startError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(startError ?? "")
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch draft.step {
        case 0: WelcomeStep(draft: draft)
        case 1: LengthStep(draft: draft)
        case 2: FrequencyStep(draft: draft)
        case 3: AboutYouStep(draft: draft)
        case 4: StartingWeightsStep(draft: draft)
        default:
            if let preview = draft.preview {
                GeneratedProgramStep(summary: preview, calendar: clock.calendar)
            }
        }
    }

    private func primaryAction() {
        if draft.step < 5 {
            withAnimation(.easeInOut(duration: 0.25)) {
                draft.advance(now: clock.now(), calendar: clock.calendar)
            }
        } else {
            startProgram()
        }
    }

    /// "Start program": the model layer writes; the screen only records the unit preference. Routing flips by itself.
    private func startProgram() {
        guard !isStarting else { return }
        isStarting = true
        do {
            let now = clock.now()
            let program = try ProgramStore.start(draft.inputs(generatedOn: now), bodyWeightLb: draft.bodyWeightLb,
                                                 experience: draft.experience.rawValue, now: now, calendar: clock.calendar,
                                                 in: modelContext)
            if program != nil {
                unitsRaw = draft.units.rawValue   // the route flips on its own once the save lands
            } else {
                isStarting = false
            }
        } catch {
            isStarting = false
            assertionFailure("Start program failed: \(error)")
            startError = "Your program could not be saved. Please try again."
        }
    }
}
