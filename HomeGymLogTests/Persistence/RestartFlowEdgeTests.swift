#if DEBUG
import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

/// AC-13 and AC-20 edges: a *second* restart (spec 6 "Two archived programs"), and the two failure shapes the alert path
/// can reach — an already-archived program on a store that refuses every save, and a refused archive retried after the
/// alert's OK. The newest-archived pick is written here the way `RootView` writes it, over rows the writers produced.
@MainActor
@Suite struct RestartFlowEdgeTests {
    private let cal = TestCalendar.calendar

    private func date(_ month: Int, _ day: Int, _ hour: Int) -> Date {
        cal.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    @Test("a second restart leaves two archived rows, and the newest archivedAt carries the second program's answers")
    func secondRestart() throws {
        let container = try AppSchema.makeContainer(inMemory: true)
        let context = container.mainContext
        let first = try MidProgramSeed.populate(in: context, calendar: cal)
        let firstID = first.id
        #expect(try ProgramStore.archive(first, at: date(9, 15, 11), in: context) == true)

        // The second program is deliberately unlike the first, so the prefill cannot pass by reading the wrong row.
        let inputs = ProgramInputs(months: 1, frequency: 3, trainingWeekdays: [0, 2, 4], sessionLengthMinutes: 30,
                                   startingWeightsLb: [:], generatedOn: date(9, 15, 12))
        let second = try #require(try ProgramStore.start(inputs, bodyWeightLb: 200, experience: "Beginner",
                                                         now: date(9, 15, 12), calendar: cal, in: context))
        let secondID = second.id
        #expect(try ProgramStore.archive(second, at: date(9, 20, 9), in: context) == true)

        let fresh = ModelContext(container)
        let archived = try fresh.fetch(FetchDescriptor<Program>(predicate: ProgressSnapshotBuilder.archivedProgramPredicate))
        #expect(archived.count == 2)
        #expect(try ProgramStore.current(in: fresh) == nil)
        // RootView's pick: newest `archivedAt` in Swift, never a sort descriptor on the optional.
        let newest = try #require(archived.max(by: { ($0.archivedAt ?? .distantPast) < ($1.archivedAt ?? .distantPast) }))
        #expect(newest.id == secondID)
        #expect(archived.map(\.id).contains(firstID))

        let answers = RestartPrefill.answers(months: newest.months, frequency: newest.frequency,
                                             trainingWeekdays: newest.trainingWeekdays,
                                             sessionLengthMinutes: newest.sessionLengthMinutes,
                                             bodyWeightLb: newest.bodyWeightLb, experience: newest.experience,
                                             startingWeightsLb: newest.startingWeightsLb)
        #expect(answers.months == 1)
        #expect(answers.frequency == 3)
        #expect(answers.trainingWeekdays == [0, 2, 4])
        #expect(answers.sessionLengthMinutes == 30)
        #expect(answers.bodyWeightLb == 200)
        #expect(answers.experience == .beginner)
        withExtendedLifetime(container) {}
    }

    @Test("an already archived program reports alreadyArchived even on a store that refuses every save")
    func alreadyArchivedOnAReadOnlyStore() throws {
        let archivedAt = date(9, 15, 11)
        try onDisk { context, writer, id in
            let program = try self.fetch(id, in: context)
            #expect(RestartAction.run(program: program, at: self.date(9, 20, 9), in: context) == .alreadyArchived,
                    "the guard returns before any save")
            let sameContext = try self.fetch(id, in: context).archivedAt
            #expect(sameContext == archivedAt, "writing context")
            #expect(context.hasChanges == false)
            let stored = try self.fetch(id, in: ModelContext(writer)).archivedAt
            #expect(stored == archivedAt, "store")
        } setUp: { context, program in
            let archived = try ProgramStore.archive(program, at: archivedAt, in: context)
            #expect(archived == true)
        }
    }

    @Test("a refused archive retried after the alert fails the same way and never leaves an archive date behind")
    func refusedArchiveRetried() throws {
        try onDisk { context, writer, id in
            let program = try self.fetch(id, in: context)
            #expect(RestartAction.run(program: program, at: self.date(9, 15, 11), in: context)
                    == .failed(SettingsText.archiveFailedMessage))
            // First read after the failure: a same-context fetch by id.
            let afterFirst = try self.fetch(id, in: context).archivedAt
            #expect(afterFirst == nil, "writing context after the first failure")

            #expect(RestartAction.run(program: program, at: self.date(9, 16, 11), in: context)
                    == .failed(SettingsText.archiveFailedMessage), "the retry is still refused, not a no-op")
            let afterRetry = try self.fetch(id, in: context).archivedAt
            #expect(afterRetry == nil, "writing context after the retry")
            let stored = try self.fetch(id, in: ModelContext(writer)).archivedAt
            #expect(stored == nil, "store")
        } setUp: { _, _ in }
    }

    /// A `midProgram` program on a temporary on-disk store, reopened `allowsSave: false` (the `ProgramArchiveRollbackTests`
    /// shape; its helper is private). `rollback()` runs before the file is removed, and both containers stay bound.
    private func onDisk(_ body: (ModelContext, ModelContainer, UUID) throws -> Void,
                        setUp: (ModelContext, Program) throws -> Void) throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("restart-edge-\(UUID().uuidString)",
                                                                                isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let result = Result { try run(storeAt: dir.appendingPathComponent("restart.store"), body, setUp: setUp) }
        try? FileManager.default.removeItem(at: dir)
        try result.get()
    }

    private func run(storeAt url: URL, _ body: (ModelContext, ModelContainer, UUID) throws -> Void,
                     setUp: (ModelContext, Program) throws -> Void) throws {
        let writer = try ModelContainer(for: AppSchema.schema,
                                        configurations: [ModelConfiguration(schema: AppSchema.schema, url: url)])
        let setupContext = ModelContext(writer)
        let program = try MidProgramSeed.populate(in: setupContext, calendar: cal)
        try setUp(setupContext, program)
        let id = program.id

        let readOnly = try ModelContainer(for: AppSchema.schema,
                                          configurations: [ModelConfiguration(schema: AppSchema.schema, url: url,
                                                                              allowsSave: false)])
        let context = ModelContext(readOnly)
        defer {
            context.rollback()
            withExtendedLifetime((writer, readOnly, setupContext)) {}
        }
        try body(context, writer, id)
    }

    private func fetch(_ id: UUID, in context: ModelContext) throws -> Program {
        try #require(try context.fetch(FetchDescriptor<Program>(predicate: #Predicate { $0.id == id })).first)
    }
}
#endif
