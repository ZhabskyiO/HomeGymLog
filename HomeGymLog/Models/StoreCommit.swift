import Foundation
import SwiftData

/// The model layer's two failed-save helpers, shared by every store (INSIGHTS "Failed-save policy": insert writers
/// rehearse, field writers restore). ≈ a tiny transaction module every repository imports.
enum StoreCommit {
    /// Field writers' save. If the save throws: `rollback()` first, then `revert` puts back every field the action changed,
    /// then the error is rethrown. ≈ aborting the transaction, then re-dispatching the previous state into the store, so no
    /// later read sees the optimistic value. The order is measured (researcher addendum P4, Xcode 27, iOS 17.5 and 26.5):
    /// restoring before the rollback left the unsaved values in the context on 26.5, and the first fetch of the row (a
    /// screen's `@Query` refresh) returned them. Rollback alone is not enough either: it leaves edited values on the objects.
    /// Leaves `hasChanges == true` (the restored originals), which the next save rewrites harmlessly. Only for actions with no
    /// insert or delete pending (every field writer); an action that inserted uses `commitInsert`.
    static func commit(_ context: ModelContext, revert: () -> Void) throws {
        do {
            try context.save()
        } catch {
            context.rollback()
            revert()
            throw error
        }
    }

    /// Insert writers' last resort, reached only when the save fails right after a successful rehearsal: `removeInserts`
    /// deletes (and unlinks) what the action inserted, then `rollback()`, then the error is rethrown. Never roll back first:
    /// on iOS 17.5 `rollback()` crashes the process while an inserted graph is pending (gotchas SwiftData 2026-09-13).
    static func commitInsert(_ context: ModelContext, removeInserts: () -> Void) throws {
        do {
            try context.save()
        } catch {
            removeInserts()
            context.rollback()
            throw error
        }
    }

    /// Proves an insert against the store before the writing context is touched: `insert` adds rows to a scratch context
    /// on the same container and returns how to remove them; the helper saves, removes, and saves again (≈ a dry run on a
    /// second DB connection inside its own transaction). A store that refuses the write throws here, so the caller's
    /// context never holds an unsaved insert, which cannot be undone in place (26.5 keeps it in fetches; 17.5 crashes on
    /// `rollback()`). `insert` returning nil means there is nothing to rehearse, and nothing is saved.
    static func rehearseInsert(in container: ModelContainer, _ insert: (ModelContext) throws -> (() -> Void)?) throws {
        let scratch = ModelContext(container)
        guard let remove = try insert(scratch) else { return }
        try scratch.save()
        remove()
        try scratch.save()
    }
}
