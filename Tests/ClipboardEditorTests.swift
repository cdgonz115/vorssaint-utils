//
//  ClipboardEditorTests.swift
//  Vorssaint
//
//  Created by Christian Gonzalez on 9/30/26.
//
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Stands in for ClipboardHistoryService: records what the model asked for and
/// lets a test make either step refuse.
private final class FakeHistory: ClipboardEditorHistory {
    var entries: [ClipboardHistoryEntry]
    var updateAllowed = true
    var copyResult = true
    private(set) var updates: [(id: UUID, text: String)] = []
    private(set) var copied: [ClipboardHistoryEntry] = []

    init(_ entries: [ClipboardHistoryEntry]) {
        self.entries = entries
    }

    func updateText(_ entry: ClipboardHistoryEntry, to draft: String) -> Bool {
        updates.append((entry.id, draft))
        guard updateAllowed, let index = entries.firstIndex(where: { $0.id == entry.id }) else { return false }
        entries[index].text = draft
        return true
    }

    func copy(_ entry: ClipboardHistoryEntry, completion: @escaping (Bool) -> Void) {
        copied.append(entry)
        completion(copyResult)
    }
}

enum ClipboardEditorTests {
    static func run(_ suite: TestSuite) {
        suite.run("clipboard editor skips") { skips(suite) }
        suite.run("clipboard editor history entry") { historyEntry(suite) }
        suite.run("clipboard editor live clipboard") { liveClipboard(suite) }
        suite.run("clipboard editor failures") { failures(suite) }
    }

    private static func commit(_ model: ClipboardEditorModel,
                               _ history: ClipboardEditorHistory) -> ClipboardEditorModel.Outcome? {
        var outcome: ClipboardEditorModel.Outcome?
        model.commit(to: history) { outcome = $0 }
        return outcome
    }

    private static func skips(_ suite: TestSuite) {
        let entry = ClipboardHistoryEntry(text: "hello")
        let history = FakeHistory([entry])
        let model = ClipboardEditorModel(original: "hello", source: .entry(entry.id))

        suite.expect(!model.hasChanges, "a fresh editor has no changes")
        suite.expect(commit(model, history) == .unchanged, "closing an untouched editor changes nothing")

        model.draft = "hello world"
        suite.expect(model.hasChanges, "typing is a change")
        model.draft = "hello"
        suite.expect(commit(model, history) == .unchanged, "undoing every edit is the same as cancelling")

        model.draft = "   \n"
        suite.expect(commit(model, history) == .notStorable, "a blank draft is never written")
        model.draft = String(repeating: "a", count: ClipboardHistoryEditing.maxCharacters + 1)
        suite.expect(commit(model, history) == .notStorable, "a draft over the size limit is never written")

        suite.expect(history.updates.isEmpty && history.copied.isEmpty,
                     "none of those touched history or the clipboard")
    }

    private static func historyEntry(_ suite: TestSuite) {
        var entry = ClipboardHistoryEntry(text: #"{"a":1}"#)
        entry.pinnedAt = Date()
        let other = ClipboardHistoryEntry(text: "other")
        let history = FakeHistory([other, entry])
        let model = ClipboardEditorModel(original: entry.text, source: .entry(entry.id))

        model.draft = "{\n  \"a\": 1\n}"
        suite.expect(commit(model, history) == .committed(updatedHistory: true), "an edited entry commits")
        suite.expect(history.updates.count == 1 && history.updates.first?.id == entry.id,
                     "the entry is updated in place")
        suite.expect(history.entries.count == 2, "no entry is added or removed")
        suite.expect(history.entries.first(where: { $0.id == entry.id })?.text == model.draft,
                     "the history now holds the edited text")
        suite.expect(history.copied.first?.text == model.draft, "the edited text, not the old text, is copied")
        suite.expect(history.copied.first?.id == entry.id, "the copied entry is the edited one")
        suite.expect(history.copied.first?.isPinned == true, "the pin survives the edit")

        suite.expect(commit(model, history) == .unchanged && history.copied.count == 1,
                     "a second close has nothing left to write")

        // The entry vanished while the editor was open (deleted, or expired).
        let gone = ClipboardHistoryEntry(text: "x")
        let emptyHistory = FakeHistory([])
        let orphan = ClipboardEditorModel(original: "x", source: .entry(gone.id))
        orphan.draft = "y"
        suite.expect(commit(orphan, emptyHistory) == .committed(updatedHistory: false),
                     "a vanished entry falls back to a clipboard-only write")
        suite.expect(emptyHistory.updates.isEmpty && emptyHistory.entries.isEmpty,
                     "and never invents a history entry")
    }

    private static func liveClipboard(_ suite: TestSuite) {
        let entry = ClipboardHistoryEntry(text: "raw")
        let history = FakeHistory([entry])
        let model = ClipboardEditorModel(original: "raw", source: .liveClipboard)
        model.draft = "edited"
        suite.expect(commit(model, history) == .committed(updatedHistory: true),
                     "live text that is in history replaces that entry")
        suite.expect(history.entries.first?.text == "edited", "the matching entry was edited in place")

        // Never recorded: history off, a password manager, an excluded app.
        let unrecorded = FakeHistory([ClipboardHistoryEntry(text: "something else")])
        let model2 = ClipboardEditorModel(original: "not in history", source: .liveClipboard)
        model2.draft = "changed"
        suite.expect(commit(model2, unrecorded) == .committed(updatedHistory: false),
                     "live text that is not in history only rewrites the clipboard")
        suite.expect(unrecorded.updates.isEmpty, "history is not touched")
        suite.expect(unrecorded.copied.map(\.text) == ["changed"], "the clipboard gets the edited text")
        suite.expect(unrecorded.entries.count == 1, "no history entry is added")
    }

    private static func failures(_ suite: TestSuite) {
        let entry = ClipboardHistoryEntry(text: "a")
        let history = FakeHistory([entry])
        let model = ClipboardEditorModel(original: "a", source: .entry(entry.id))
        model.draft = "b"

        history.updateAllowed = false
        suite.expect(commit(model, history) == .failed, "a refused history update fails the commit")
        suite.expect(history.copied.isEmpty, "a refused update never reaches the clipboard")
        suite.expect(model.hasChanges, "the draft is kept after a failure")

        history.updateAllowed = true
        history.copyResult = false
        suite.expect(commit(model, history) == .failed, "a refused copy fails the commit")
        suite.expect(model.hasChanges, "the draft is still kept, so the commit can be retried")

        history.copyResult = true
        suite.expect(commit(model, history) == .committed(updatedHistory: true), "a retry succeeds")
        suite.expect(!model.hasChanges, "after a commit the editor has nothing pending")
    }
}
