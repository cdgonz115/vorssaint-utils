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
        suite.run("clipboard editor preferences") { preferences(suite) }
        suite.run("clipboard editor tabs") { tabs(suite) }
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

    /// Every format on, so these do not depend on what the machine running them has set.
    private static let allFormats: (TextToolsSupport.Format) -> Bool = { _ in true }

    private static func tabs(_ suite: TestSuite) {
        let compact = #"{"a":1,"b":[1,2]}"#
        let pretty = TextToolsSupport.prettyPrintJSON(compact) ?? ""
        let entry = ClipboardHistoryEntry(text: compact)
        let history = FakeHistory([entry])
        let model = ClipboardEditorModel(original: compact, source: .entry(entry.id), isFormatEnabled: allFormats)

        suite.expect(model.tab == .raw && model.dataType == .json && !model.minified,
                     "the editor opens on Raw, set to the type the text parses as")
        suite.expect(model.outputText == compact && !model.hasChanges, "Raw writes the text as it is")

        model.tab = .formatted
        suite.expect(!pretty.isEmpty && model.formattedText() == .init(text: pretty, isValid: true)
                        && model.outputText == pretty,
                     "Formatted shows the text indented")
        suite.expect(model.draft == compact, "looking at Formatted never touches the text itself")
        model.minified = true
        suite.expect(model.outputText == compact, "Minified is the compact form")
        model.minified = false

        // What the open tab shows is what a close writes.
        suite.expect(commit(model, history) == .committed(updatedHistory: true), "closing on Formatted commits")
        suite.expect(history.entries.first?.text == pretty && history.copied.last?.text == pretty,
                     "the formatted text is what lands in history and on the clipboard")
        suite.expect(commit(model, history) == .unchanged, "a second close has nothing left to write")

        // Edits on Raw are re-read the next time Formatted is shown.
        let edited = ClipboardEditorModel(original: compact, source: .liveClipboard, isFormatEnabled: allFormats)
        edited.draft = #"{"z":2}"#
        edited.tab = .formatted
        suite.expect(edited.outputText == (TextToolsSupport.prettyPrintJSON(#"{"z":2}"#) ?? "?"),
                     "Formatted follows what was typed on Raw")

        // Formatted can be edited; the edit is what a close writes, and it is
        // dropped when the text is laid out again.
        let typed = ClipboardEditorModel(original: compact, source: .liveClipboard, isFormatEnabled: allFormats)
        typed.tab = .formatted
        typed.formattedEdit = "changed"
        suite.expect(typed.formattedText().text == "changed" && typed.outputText == "changed"
                        && typed.draft == compact,
                     "an edit on Formatted is what it shows and writes, and Raw is untouched")
        typed.tab = .raw
        typed.tab = .formatted
        suite.expect(typed.outputText == "changed", "the edit survives a trip to Raw and back")
        typed.minified = true
        suite.expect(typed.formattedEdit == nil && typed.outputText == compact,
                     "changing the layout lays the text out again")
        typed.formattedEdit = "again"
        typed.dataType = .text
        suite.expect(typed.formattedEdit == nil, "changing the type drops the edit")
        typed.formattedEdit = "again"
        typed.draft = #"{"q":1}"#
        suite.expect(typed.formattedEdit == nil, "changing Raw drops it too")

        // Text that is not the chosen type is shown as it is, and flagged.
        let broken = ClipboardEditorModel(original: "not { json", source: .liveClipboard, isFormatEnabled: allFormats)
        suite.expect(broken.dataType == .text, "text that parses as nothing starts on Text")
        broken.dataType = .json
        broken.tab = .formatted
        suite.expect(broken.formattedText() == .init(text: "not { json", isValid: false)
                        && broken.outputText == "not { json",
                     "the wrong type leaves the text alone and says so")
        suite.expect(commit(broken, FakeHistory([])) == .unchanged, "and writes nothing")
        broken.dataType = .text
        suite.expect(broken.formattedText().isValid && broken.outputText == "not { json",
                     "Text is always valid and unchanged, even minified")

        // Already-formatted text has nothing to change.
        let tidy = ClipboardEditorModel(original: pretty, source: .liveClipboard, isFormatEnabled: allFormats)
        tidy.tab = .formatted
        suite.expect(tidy.outputText == pretty && !tidy.hasChanges, "formatting formatted text changes nothing")

        // A format that is switched off is never picked, whatever the text is.
        let jsonOff = ClipboardEditorModel(original: compact, source: .liveClipboard,
                                           isFormatEnabled: { $0 != .json })
        suite.expect(jsonOff.dataType == .text, "JSON switched off: JSON text starts on Text")
        let xmlOnly = ClipboardEditorModel(original: "<a/>", source: .liveClipboard,
                                           isFormatEnabled: { $0 != .json })
        suite.expect(xmlOnly.dataType == .xml, "and XML is still found")

        let xml = ClipboardEditorModel(original: "<a><b>1</b></a>", source: .liveClipboard, isFormatEnabled: allFormats)
        suite.expect(xml.dataType == .xml, "XML is detected too")
        xml.tab = .formatted
        suite.expect(xml.formattedText().isValid && xml.outputText.contains("\n"), "and laid out on lines")
    }

    private static func preferences(_ suite: TestSuite) {
        suite.expect(ClipboardOpenView.resolve(stored: "editor", editorEnabled: true) == .editor,
                     "the editor can be chosen as the opening view")
        suite.expect(ClipboardOpenView.resolve(stored: "history", editorEnabled: true) == .history,
                     "the history can be chosen as the opening view")
        suite.expect(ClipboardOpenView.resolve(stored: "editor", editorEnabled: false) == .history,
                     "with the editor switched off, the history opens whatever was chosen")
        for unknown in [nil, "", "garbage", "Editor", "editor "] {
            suite.expect(ClipboardOpenView.resolve(stored: unknown, editorEnabled: true) == .history,
                         "an unknown stored value (\(unknown ?? "nil")) opens the history")
        }

        let registered = Defaults.registeredDefaults
        suite.expect(registered[DefaultsKey.clipboardEditorEnabled] as? Bool == true,
                     "the editor is on by default")
        suite.expect(registered[DefaultsKey.clipboardEditorDefaultView] as? String
                        == ClipboardOpenView.history.rawValue,
                     "the clipboard still opens on the history by default, as it always has")

        suite.expect(registered[DefaultsKey.clipboardEditorNoticeView] as? String
                        == ClipboardOpenView.editor.rawValue,
                     "clicking the Copied notice opens the editor by default")

        let exported = SettingsBackupSupport.exportKeys()
        suite.expect(exported.contains(DefaultsKey.clipboardEditorEnabled)
                        && exported.contains(DefaultsKey.clipboardEditorDefaultView)
                        && exported.contains(DefaultsKey.clipboardEditorNoticeView),
                     "all three editor settings travel in a backup")
        suite.expect(SettingsBackupSupport.valueLooksRight(DefaultsKey.clipboardEditorDefaultView, "editor")
                        && SettingsBackupSupport.valueLooksRight(DefaultsKey.clipboardEditorNoticeView, "history"),
                     "a restored opening view is accepted")
        suite.expect(!SettingsBackupSupport.valueLooksRight(DefaultsKey.clipboardEditorEnabled, "yes"),
                     "a restored switch of the wrong type is dropped")
    }
}
