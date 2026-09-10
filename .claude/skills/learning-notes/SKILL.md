---
name: learning-notes
description: Write a short Swift/SwiftUI/SwiftData study note for the slice just implemented, mapping every new concept to its React/TypeScript equivalent and pointing at the file where it is used. Usage: /learning-notes <slice>. For a developer new to Swift.
---

Produce `docs/learning/<slice>.md` for the slice named in the argument (a milestone or feature slug
matching `docs/specs/`). The reader is a senior React/TypeScript developer learning Swift through this
project; the note is what they read after the code lands to understand what they are looking at.

## Steps

1. `git diff --stat main...HEAD` (or the last milestone commit range) to find the Swift files the slice
   added or changed. Read them.
2. List every language or framework concept that appears for the first time in the project in this slice
   (not ones already covered in earlier notes under `docs/learning/`). Typical items: value vs reference
   types, optionals and `guard let`, enums with raw values and computed accessors, `@Model` and
   relationships, `@Query`, `@State`/`@Binding`/`@Environment`, `.task`, `safeAreaInset`, `Path`,
   `Result`, `throws`, `nonisolated`/`@MainActor`, Swift Testing macros.
3. For each concept write three to six lines: what it is in one sentence, the React/TypeScript analogy in
   one sentence, the exact `file:line` where it is used here, and one thing that commonly surprises
   JavaScript developers about it. Keep the code snippet to at most four lines, quoted from the project.
4. End with "What to read next": at most three links to Apple documentation pages for the concepts that
   will matter in the next slice.

## Rules

- Concepts only; no restating what the slice does (the spec covers that).
- Plain language. No Swift jargon without the analogy in the same paragraph.
- Under 150 lines. If the slice introduced more than ten new concepts, keep the ten most reused.

Return the file path and the list of concepts covered.
