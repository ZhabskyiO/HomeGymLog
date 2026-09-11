import Foundation
import Observation

/// Every onboarding answer plus the current step, owned by the flow root. `@Observable` ≈ a small store the
/// views read and mutate; no step view keeps its own state (the step transition would reset it).
@Observable
final class OnboardingDraft {
    /// 0 = welcome … 5 = generated program.
    var step = 0
    /// App-wide display unit chosen on the welcome step. Body weight follows it until chosen separately.
    var units: WeightUnit {
        didSet { if !bodyWeightUnitChosen { bodyWeightUnit = units } }
    }
    /// Unit for the body-weight stepper only; may differ from `units`. Storage stays in pounds.
    var bodyWeightUnit: WeightUnit {
        didSet { bodyWeightUnitChosen = true }
    }
    private var bodyWeightUnitChosen = false
    var months = 1
    private(set) var frequency = 4
    /// Sorted training weekdays, 0 = Monday.
    private(set) var days: [Int]
    var bodyWeightLb = 180.0
    var experience = Experience.intermediate
    var sessionLengthMinutes = 45
    /// User-set starting weights in pounds; keys not present use the library default.
    private(set) var startingWeightsLb: [String: Double] = [:]
    /// Computed once when entering step 5; nil elsewhere.
    private(set) var preview: ProgramSummary?

    static let ctaLabels = ["Set up my program", "Continue", "Continue", "Continue", "Generate program", "Start program"]
    static let bodyWeightRangeLb = 50.0...500.0

    init(units: WeightUnit = .lb, months: Int = 1, frequency: Int = 4) {
        self.units = units
        self.bodyWeightUnit = units
        self.months = months
        self.frequency = frequency
        self.days = SplitPlans.defaultWeekdays(frequency: frequency) ?? [0, 1, 3, 4]
    }

    var ctaLabel: String { Self.ctaLabels[min(max(step, 0), Self.ctaLabels.count - 1)] }

    /// Only the frequency step can block: exactly `frequency` days must be picked.
    var canContinue: Bool { step != 2 || days.count == frequency }

    var exerciseCount: Int { SplitPlans.exerciseCount(sessionLengthMinutes: sessionLengthMinutes) ?? 0 }

    var startingWeightRows: [StartingWeightRow] {
        StartingWeights.rows(frequency: frequency, sessionLengthMinutes: sessionLengthMinutes, overrides: startingWeightsLb)
    }

    func selectFrequency(_ frequency: Int) {
        guard let defaults = SplitPlans.defaultWeekdays(frequency: frequency) else { return }
        self.frequency = frequency
        days = defaults
    }

    /// Deselect always. Select when fewer than `frequency` days are picked; when the week is already full,
    /// the new day replaces the earliest selected day (week starts Monday). Keeps `days` sorted.
    func toggleDay(_ day: Int) {
        guard (0...6).contains(day) else { return }
        if let index = days.firstIndex(of: day) {
            days.remove(at: index)
            return
        }
        if days.count >= frequency, let earliest = days.min(), let index = days.firstIndex(of: earliest) {
            days.remove(at: index)
        }
        days.append(day)
        days.sort()
    }

    /// One unit per tap in the body-weight display unit (1 lb, or 1 kg = 2.20462 lb), clamped to 50…500 lb.
    /// Storage stays in pounds; a kg user's value is therefore a non-integer number of pounds.
    func adjustBodyWeight(steps: Int) {
        let stepLb = bodyWeightUnit == .lb ? 1.0 : 1.0 / WeightDisplay.kgPerLb
        let result = bodyWeightLb + Double(steps) * stepLb
        bodyWeightLb = min(max(result, Self.bodyWeightRangeLb.lowerBound), Self.bodyWeightRangeLb.upperBound)
    }

    /// Moves one row by equipment steps; no-op at the equipment bound.
    func adjustStartingWeight(key: String, steps: Int) {
        guard let row = startingWeightRows.first(where: { $0.key == key }),
              let next = row.kind.stepped(lb: row.weightLb, by: steps) else { return }
        startingWeightsLb[key] = next
    }

    func inputs(generatedOn: Date) -> ProgramInputs {
        ProgramInputs(months: months, frequency: frequency, trainingWeekdays: days, sessionLengthMinutes: sessionLengthMinutes,
                      startingWeightsLb: startingWeightsLb, generatedOn: generatedOn)
    }

    /// Next step; entering the summary computes the preview once.
    func advance(now: Date, calendar: Calendar) {
        guard step < 5, canContinue else { return }
        if step == 4 {
            do {
                preview = ProgramSummary(generated: try ProgramGenerator.generate(inputs(generatedOn: now), calendar: calendar))
            } catch {
                assertionFailure("onboarding produced invalid inputs: \(error)")
                return
            }
        }
        step += 1
    }

    /// Previous step; leaving the summary clears the preview.
    func goBack() {
        guard step > 0 else { return }
        if step == 5 { preview = nil }
        step -= 1
    }
}
