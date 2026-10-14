//
//  ClipboardEditorModel.swift
//  Vorssaint
//
//  Created by Christian Gonzalez on 9/30/26.
//
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Combine
import Foundation

/// What the editor needs from clipboard history, and nothing more.
/// ClipboardHistoryService conforms (ClipboardHistoryService+Editor.swift);
/// tests pass a fake, so this file never touches a real pasteboard.
protocol ClipboardEditorHistory: AnyObject {
    var entries: [ClipboardHistoryEntry] { get }
    func updateText(_ entry: ClipboardHistoryEntry, to draft: String) -> Bool
    func copy(_ entry: ClipboardHistoryEntry, completion: @escaping (Bool) -> Void)
}

/// The state behind the clipboard editor: the text being edited, where it came
/// from, and what happens to it when the editor closes.
///
/// There is no Save button. Closing the editor commits, and undo is the way to
/// cancel: undoing every edit puts the draft back to the original, which
/// commits nothing. Call everything here on the main thread.
final class ClipboardEditorModel: ObservableObject {
    enum Source: Equatable {
        /// A specific entry picked from the history list.
        case entry(UUID)
        /// Whatever is on the clipboard right now.
        case liveClipboard
    }

    enum Outcome: Equatable {
        /// The draft matches the original. Nothing was touched.
        case unchanged
        /// The draft is blank or too long to store. Nothing was touched, so a
        /// cleared editor never empties the clipboard by accident.
        case notStorable
        /// The edited text is on the clipboard. `updatedHistory` says whether a
        /// history entry was replaced, or only the clipboard was written.
        case committed(updatedHistory: Bool)
        /// Something refused. The draft is kept so the commit can be retried.
        case failed
    }

    /// Which view is showing, and so which text a close writes back.
    enum Tab: Equatable {
        /// The text exactly as it is, and the only one that can be typed in.
        case raw
        /// The same text read as a chosen type and laid out to match.
        case formatted
    }

    /// What the Formatted tab reads the text as.
    enum DataType: String, CaseIterable {
        case text, json, xml

        /// The format the text tools parse, or nil for plain text, which is
        /// shown as it is.
        var structured: TextToolsSupport.Format? {
            switch self {
            case .text: return nil
            case .json: return .json
            case .xml: return .xml
            }
        }

        /// What the text parses as, so the type starts on the right choice.
        static func detect(_ text: String) -> DataType {
            switch TextToolsSupport.detectFormat(text) {
            case .json?: return .json
            case .xml?: return .xml
            case nil: return .text
            }
        }
    }

    /// What the Formatted tab shows. `isValid` is false when the text is not
    /// the chosen type; the text is then shown unchanged.
    struct FormattedText: Equatable {
        let text: String
        let isValid: Bool
    }

    let source: Source
    /// What the text was when the editor opened, or as of the last commit.
    private(set) var original: String
    /// The text being edited. Only the Raw tab changes it.
    @Published var draft: String
    @Published var tab: Tab = .raw
    @Published var dataType: DataType
    /// Compact instead of indented. Plain text has no compact form.
    @Published var minified = false

    private var isCommitting = false
    private var formattedCache: (key: FormatKey, value: FormattedText)?

    private struct FormatKey: Equatable {
        let draft: String
        let dataType: DataType
        let minified: Bool
    }

    init(original: String, source: Source) {
        self.original = original
        self.source = source
        self.draft = original
        self.dataType = DataType.detect(original)
    }

    /// The draft read as the chosen type. Worked out when it is asked for and
    /// remembered, since a large document is not cheap to lay out and the
    /// view asks again whenever anything on the page changes.
    func formattedText() -> FormattedText {
        let key = FormatKey(draft: draft, dataType: dataType, minified: minified)
        if let cached = formattedCache, cached.key == key { return cached.value }
        let value: FormattedText
        if let structured = dataType.structured {
            if let text = TextToolsSupport.render(draft, as: structured, minified: minified) {
                value = FormattedText(text: text, isValid: true)
            } else {
                value = FormattedText(text: draft, isValid: false)
            }
        } else {
            value = FormattedText(text: draft, isValid: true)
        }
        formattedCache = (key, value)
        return value
    }

    /// What closing the editor would write: what the open tab shows. Looking at
    /// Formatted and closing therefore keeps the formatted text, and Raw never
    /// changes anything but what was typed.
    var outputText: String {
        tab == .raw ? draft : formattedText().text
    }

    var hasChanges: Bool { outputText != original }

    /// Writes the draft back, unless there is nothing worth writing.
    ///
    /// When the text belongs to a history entry, that entry is replaced in
    /// place (so it keeps its pin and its position) and then copied, so the
    /// next paste is the edited text. When it does not (history is off, the
    /// text was never recorded, or the entry is gone), only the clipboard is
    /// written and history is left alone.
    func commit(to history: ClipboardEditorHistory, completion: @escaping (Outcome) -> Void) {
        // A commit already carrying this text is on its way.
        guard !isCommitting else { completion(.unchanged); return }
        let text = outputText
        guard text != original else { completion(.unchanged); return }
        guard ClipboardHistoryEditing.canSave(original: original, draft: text) else {
            completion(.notStorable)
            return
        }

        isCommitting = true
        let finish: (Outcome) -> Void = { [weak self] outcome in
            if let self {
                self.isCommitting = false
                // Compare against what was written, not the current draft:
                // typing may have continued while the copy was in flight.
                if case .committed = outcome { self.original = text }
            }
            completion(outcome)
        }

        if let entry = target(in: history) {
            // Look the entry up again afterwards: `entry` is a copy taken
            // before the update and still holds the old text.
            guard history.updateText(entry, to: text),
                  let updated = history.entries.first(where: { $0.id == entry.id })
            else {
                finish(.failed)
                return
            }
            history.copy(updated) { copied in
                finish(copied ? .committed(updatedHistory: true) : .failed)
            }
        } else {
            // A transient entry is never added to history: the service's copy
            // only touches entries it already has, and it records the
            // pasteboard change so the history watcher does not capture it.
            history.copy(ClipboardHistoryEntry(text: text)) { copied in
                finish(copied ? .committed(updatedHistory: false) : .failed)
            }
        }
    }

    private func target(in history: ClipboardEditorHistory) -> ClipboardHistoryEntry? {
        switch source {
        case .entry(let id):
            return history.entries.first { $0.id == id && $0.kind == .text }
        case .liveClipboard:
            return history.entries.first { $0.kind == .text && $0.text == original }
        }
    }
}
	
