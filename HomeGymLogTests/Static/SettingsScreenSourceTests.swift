import Foundation
import Testing

/// `SettingsContent` and `SettingsRows` are view code with no seam a unit test can drive, so what is reachable is scanned
/// over their source: the row order of spec 2.1–2.4 (which is also AC-15's VoiceOver order), every visible string coming
/// from `SettingsText`, the Haptics and Sound switches bound to their preferences, the accessibility shape of the two row kinds, and
/// the screen's one write going through `RestartAction`. `//` comments are stripped first.
@Suite struct SettingsScreenSourceTests {
    /// `<repo>/HomeGymLog`, derived from `<repo>/HomeGymLogTests/Static/…`.
    private static var appSourceRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("HomeGymLog", isDirectory: true)
    }

    private static func codeLines(_ relativePath: String) throws -> [String] {
        let file = appSourceRoot.appendingPathComponent(relativePath)
        return try String(contentsOf: file, encoding: .utf8).components(separatedBy: .newlines).map { line in
            if let comment = line.range(of: "//") { return String(line[..<comment.lowerBound]) }
            return line
        }
    }

    private static func settingsFiles() throws -> [(path: String, lines: [String])] {
        let folder = appSourceRoot.appendingPathComponent("Features/Settings", isDirectory: true)
        let files = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        return try files.map { ($0.lastPathComponent, try codeLines("Features/Settings/\($0.lastPathComponent)")) }
    }

    /// Every `SettingsText.<member>` in the file, in source order.
    private static func textMembers(in lines: [String]) -> [String] {
        var members: [String] = []
        for line in lines {
            var rest = Substring(line)
            while let hit = rest.range(of: "SettingsText.") {
                let tail = rest[hit.upperBound...]
                let name = tail.prefix { $0.isLetter || $0.isNumber || $0 == "_" }
                if !name.isEmpty { members.append(String(name)) }
                rest = tail
            }
        }
        return members
    }

    @Test("the ten Settings files are scanned")
    func filesScanned() throws {
        let files = try Self.settingsFiles()
        #expect(files.map(\.path) == ["AboutRows.swift", "BackupFile.swift", "BackupImportAction.swift", "BackupRows.swift", "LiveActivityRows.swift",
                                      "ReminderRows.swift", "RestartAction.swift", "SettingsContent.swift", "SettingsRows.swift",
                                      "SettingsView.swift"])
    }

    @Test("the preferences card lists Appearance, Units, the Daily reminder rows, Haptics, Sound, Lock Screen timer in that order")
    func preferencesRowOrder() throws {
        let lines = try Self.codeLines("Features/Settings/SettingsContent.swift")
        let tokens = ["SettingsText.appearance", "SettingsText.units", "ReminderRows(", "SettingsText.haptics", "SettingsText.sound,",
                      "LiveActivityRows("]
        let indexes = try tokens.map { token in try #require(lines.firstIndex { $0.contains(token) }, "\(token)") }
        #expect(indexes == indexes.sorted())
        #expect(Set(indexes).count == tokens.count)
    }

    @Test("the reminder rows read no stored value, store or clock, and draw toggle, divider, then the second row")
    func reminderRowsShape() throws {
        let lines = try Self.codeLines("Features/Settings/ReminderRows.swift")
        let code = lines.joined(separator: "\n")
        for forbidden in ["@AppStorage", "modelContext", "appClock"] {
            #expect(code.contains(forbidden) == false, "\(forbidden)")
        }
        for required in ["SettingsText.reminder", "ReminderText.timeLabel", "ReminderText.openSettings", "ReminderText.allow",
                         ".hourAndMinute", ".labelsHidden()"] {
            #expect(code.contains(required), "\(required)")
        }
        #expect(lines.filter { $0.contains("SettingsDivider()") }.count == 1)
        let toggle = try #require(lines.firstIndex { $0.contains("Toggle(") })
        let divider = try #require(lines.firstIndex { $0.contains("SettingsDivider()") })
        let secondRow = try #require(lines.firstIndex { line in
            ["ReminderText.timeLabel", "ReminderText.openSettings", "ReminderText.allow"].contains { line.contains($0) }
        })
        #expect(toggle < divider)
        #expect(divider < secondRow)
    }

    @Test("the program card lists Current, Missed a day, Build a new program… in that order")
    func programRowOrder() throws {
        let members = Self.textMembers(in: try Self.codeLines("Features/Settings/SettingsContent.swift"))
        let group = ["current", "currentProgram", "missedDay", "restart"]
        #expect(members.filter { group.contains($0) } == group)
    }

    @Test("the equipment card lists Dumbbells, Bench, Marcy home gym with their derived values")
    func equipmentRowOrder() throws {
        let members = Self.textMembers(in: try Self.codeLines("Features/Settings/SettingsContent.swift"))
        let group = ["dumbbells", "dumbbellRange", "bench", "benchDetail", "marcy", "marcyDetail"]
        #expect(members.filter { group.contains($0) } == group)
    }

    @Test("the four section headers in order: PROGRAM, EQUIPMENT (SettingsText), BACKUP (BackupText), then ABOUT (SettingsText)")
    func sectionHeaders() throws {
        let lines = try Self.codeLines("Features/Settings/SettingsContent.swift")
        let members = Self.textMembers(in: lines)
        #expect(members.filter { $0.hasSuffix("Section") } == ["programSection", "equipmentSection", "aboutSection"])
        #expect(members.first == "title", "the screen title is drawn first")
        let headers = try ["SettingsText.programSection", "SettingsText.equipmentSection", "BackupText.section",
                       "SettingsText.aboutSection"].map { token in
            try #require(lines.firstIndex { $0.contains("SettingsSectionHeader(title: \(token))") }, "\(token)")
        }
        #expect(headers == headers.sorted())
        #expect(Set(headers).count == 4)
    }

    @Test("each card's rows are separated by a hairline, and there is one fewer divider than rows")
    func dividerCount() throws {
        let lines = try Self.codeLines("Features/Settings/SettingsContent.swift")
        let dividers = lines.filter { $0.contains("SettingsDivider()") }.count
        #expect(dividers == 12, "6 preference + 3 program + 3 equipment + 2 backup + 3 about rows = 12 gaps (the reminder's and the Lock Screen timer's own dividers are in their rows files)")
    }

    @Test("no Settings file types a user-visible string: every one comes from SettingsText or an enum label")
    func noLiteralCopy() throws {
        for file in try Self.settingsFiles() {
            let literals = file.lines.filter { $0.contains("Text(\"") || $0.contains("Button(\"") || $0.contains("Label(\"") }
            #expect(literals.isEmpty, "\(file.path): \(literals)")
        }
    }

    @Test("rows 4–5 are two live toggle rows, Haptics then Sound, each with its subtitle, never disabled")
    func feedbackToggleRows() throws {
        let content = try Self.codeLines("Features/Settings/SettingsContent.swift")
        let rows = content.filter { $0.contains("SettingsToggleRow(") }
        #expect(rows.count == 2)
        #expect(rows.first?.contains("SettingsText.haptics,") == true)
        #expect(rows.first?.contains("SettingsText.hapticsSubtitle") == true)
        #expect(rows.last?.contains("SettingsText.sound,") == true)
        #expect(rows.last?.contains("SettingsText.soundSubtitle") == true)
        let lines = try Self.codeLines("Features/Settings/SettingsRows.swift")
        let code = lines.joined(separator: "\n")
        #expect(code.contains("struct SettingsToggleRow"))
        #expect(code.contains("Toggle(isOn: $isOn)"))
        #expect(code.contains(".disabled(") == false)
        #expect(lines.contains { $0.contains("@AppStorage") } == false, "the screen owns the stored preferences")
    }

    @Test("a read-only row is one element with a label and a value; a row holding a control is never combined")
    func rowAccessibilityShape() throws {
        let lines = try Self.codeLines("Features/Settings/SettingsRows.swift")
        guard let valueRow = lines.firstIndex(where: { $0.contains("struct SettingsValueRow") }),
              let controlRow = lines.firstIndex(where: { $0.contains("struct SettingsControlRow") }),
              let toggleRow = lines.firstIndex(where: { $0.contains("struct SettingsToggleRow") }) else {
            Issue.record("the three row types are declared in SettingsRows.swift")
            return
        }
        let valueRowBody = lines[valueRow..<controlRow]
        #expect(valueRowBody.contains { $0.contains(".accessibilityElement(children: .combine)") })
        #expect(valueRowBody.contains { $0.contains(".accessibilityLabel(label)") })
        #expect(valueRowBody.contains { $0.contains(".accessibilityValue(value)") })

        let controlRowBody = lines[controlRow..<toggleRow]
        #expect(controlRowBody.contains { $0.contains(".accessibilityElement(") } == false,
                "combining would fold the control into the row and break AC-15's order")

        let toggleRowEnd = lines.indices.first { $0 > toggleRow && lines[$0].hasPrefix("struct ") } ?? lines.endIndex
        #expect(lines[toggleRow..<toggleRowEnd].contains { $0.contains(".accessibilityElement(") } == false,
                "a labelled Toggle is already one switch")
    }

    @Test("the policy control speaks the row's label and the chosen policy as its value")
    func policyControlAccessibility() throws {
        let code = try Self.codeLines("Features/Settings/SettingsRows.swift").joined(separator: "\n")
        #expect(code.contains("struct MissedDayPolicyPicker"))
        #expect(code.contains(".accessibilityLabel(SettingsText.missedDay)"))
        #expect(code.contains(".accessibilityValue(SettingsText.policy(policy))"))
        #expect(code.contains("MissedDayPolicy.allCases"), "all three choices are offered")
    }

    @Test("both segmented controls use the settings style, and the appearance one offers all three modes")
    func segmentedControls() throws {
        let lines = try Self.codeLines("Features/Settings/SettingsContent.swift")
        let styled = lines.filter { $0.contains("style: .settings") }
        #expect(styled.count == 2, "Appearance and Units")
        let code = lines.joined(separator: "\n")
        #expect(code.contains("AppearanceMode.allCases"))
        #expect(code.contains("WeightUnit.allCases"))
    }

    @Test("the screen's only write goes through RestartAction, and a success resets the tab to Home")
    func restartPath() throws {
        let view = try Self.codeLines("Features/Settings/SettingsView.swift")
        let code = view.joined(separator: "\n")
        #expect(code.contains("RestartAction.run("))
        #expect(code.contains("selectedTab = .home"))
        #expect(view.contains { $0.contains("ProgramStore.archive(") } == false, "archiving goes through RestartAction only")
        #expect(view.filter { $0.contains(".confirmationDialog(") }.count == 1)
        #expect(view.filter { $0.contains(".alert(") }.count == 1)
        #expect(code.contains("SettingsText.restartConfirm"))
        #expect(code.contains("role: .destructive"))
        #expect(code.contains("SettingsText.archiveFailedTitle"))
        #expect(code.contains("SettingsText.ok"))
    }

    @Test("the appearance applier maps all three modes and runs on appear and on every change")
    func appearanceApplier() throws {
        let lines = try Self.codeLines("App/RootView.swift")
        let code = lines.joined(separator: "\n")
        #expect(code.contains("case .system: return .unspecified"))
        #expect(code.contains("case .dark: return .dark"))
        #expect(code.contains("case .light: return .light"))
        #expect(lines.filter { $0.contains("applyAppearance(") }.count == 3, "the function plus its two call sites")
        #expect(code.contains(".onChange(of: appearanceRaw)"))
        #expect(code.contains("window.overrideUserInterfaceStyle = style"))
    }

    @Test("the restart prefill picks the newest archived program in Swift, never with a sort descriptor")
    func prefillPick() throws {
        let lines = try Self.codeLines("App/RootView.swift")
        let code = lines.joined(separator: "\n")
        #expect(code.contains("archivedPrograms.max(by:"))
        #expect(code.contains("RestartPrefill.answers("))
        let query = try #require(lines.first { $0.contains("@Query") && $0.contains("archivedProgramPredicate") })
        #expect(query.contains("sort:") == false, "no sort descriptor on the optional archivedAt")
        #expect(lines.contains { $0.contains(".id(") && $0.contains("OnboardingView") } == false,
                "an id on the onboarding branch would wipe the typed answers")
    }

    @Test("RestartAction carries no assert: the failed-save test drives it on a read-only store in Debug")
    func restartActionHasNoAssert() throws {
        let lines = try Self.codeLines("Features/Settings/RestartAction.swift")
        #expect(lines.contains { $0.contains("assertionFailure") } == false)
        #expect(try Self.codeLines("Features/Settings/SettingsView.swift").contains { $0.contains("assertionFailure") },
                "the screen asserts when it handles .failed")
    }
}
