import Foundation
import Testing
@testable import HomeGymLog

/// AC-16 (Settings half): every Settings string against a literal typed here from spec 4.3, plus the two derived rows.
/// The equipment rows are also rebuilt from `EquipmentKind` through `WeightDisplay`, so a change to the rack moves the
/// assertion and the screen together.
@MainActor
@Suite struct SettingsTextTests {
    @Test("currentProgram joins the program title and the frequency")
    func currentProgram() {
        #expect(SettingsText.currentProgram(months: 6, frequency: 5) == "6-month program · 5 days")
        #expect(SettingsText.currentProgram(months: 1, frequency: 4) == "1-month program · 4 days")
        #expect(SettingsText.currentProgram(months: 2, frequency: 3) == "2-month program · 3 days")
    }

    @Test("dumbbellRange reads 5–52.5 lb / 2.3–23.8 kg, derived from the dumbbell grid, joined with an en dash")
    func dumbbellRange() {
        let lb = SettingsText.dumbbellRange(unit: .lb)
        let kg = SettingsText.dumbbellRange(unit: .kg)
        #expect(lb == "5\u{2013}52.5 lb")
        #expect(kg == "2.3\u{2013}23.8 kg")
        let derivedLb = WeightDisplay.text(lb: EquipmentKind.dumbbell.minLb, unit: .lb) + "\u{2013}"
            + WeightDisplay.text(lb: EquipmentKind.dumbbell.maxLb, unit: .lb) + " lb"
        let derivedKg = WeightDisplay.text(lb: EquipmentKind.dumbbell.minLb, unit: .kg) + "\u{2013}"
            + WeightDisplay.text(lb: EquipmentKind.dumbbell.maxLb, unit: .kg) + " kg"
        #expect(lb == derivedLb)
        #expect(kg == derivedKg)
        #expect(lb.unicodeScalars.contains("\u{2013}"))
        #expect(!lb.contains("-"))
    }

    @Test("marcyDetail reads 150 lb stack / 68 kg stack")
    func marcyDetail() {
        #expect(SettingsText.marcyDetail(unit: .lb) == "150 lb stack")
        #expect(SettingsText.marcyDetail(unit: .kg) == "68 kg stack")
    }

    @Test("policy names all three choices")
    func policy() {
        #expect(SettingsText.policy(.ask) == "Ask me each time")
        #expect(SettingsText.policy(.shift) == "Always shift")
        #expect(SettingsText.policy(.skip) == "Always skip")
    }

    @Test("the fixed strings are the prototype's copy, and the restart label ends in a horizontal ellipsis")
    func fixedStrings() {
        #expect(SettingsText.title == "Settings")
        #expect(SettingsText.appearance == "Appearance")
        #expect(SettingsText.units == "Units")
        #expect(SettingsText.reminder == "Daily reminder")
        #expect(SettingsText.haptics == "Sound & haptics")
        #expect(SettingsText.comingSoon == "Coming soon")
        #expect(SettingsText.programSection == "PROGRAM")
        #expect(SettingsText.current == "Current")
        #expect(SettingsText.missedDay == "Missed a day")
        #expect(SettingsText.restart == "Build a new program\u{2026}")
        #expect(SettingsText.restart.unicodeScalars.last == "\u{2026}")
        #expect(SettingsText.restartTitle == "Build a new program?")
        #expect(SettingsText.restartMessage
                == "Your current program is archived and stays in Progress. You'll answer the setup questions again.")
        #expect(SettingsText.restartConfirm == "Archive and start over")
        #expect(SettingsText.cancel == "Cancel")
        #expect(SettingsText.archiveFailedTitle == "Couldn't archive your program")
        #expect(SettingsText.archiveFailedMessage == "Your program could not be archived. Please try again.")
        #expect(SettingsText.ok == "OK")
        #expect(SettingsText.equipmentSection == "EQUIPMENT")
        #expect(SettingsText.dumbbells == "Dumbbells")
        #expect(SettingsText.bench == "Bench")
        #expect(SettingsText.benchDetail == "Flat · incline")
        #expect(SettingsText.marcy == "Marcy home gym")
    }
}
