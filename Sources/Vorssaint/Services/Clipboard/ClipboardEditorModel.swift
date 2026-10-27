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

    /// What the text is treated as. Choosing JSON or XML lays the text out as
    /// that, and the editor does it as an edit that can be undone; Markdown
    /// turns on the writing tools and the preview; Text leaves it alone.
    enum DataType: String, CaseIterable {
        case text, json, xml, markdown

        /// The format the text tools parse, or nil for the types that are
        /// not laid out by parsing.
        var structured: TextToolsSupport.Format? {
            switch self {
            case .json: return .json
            case .xml: return .xml
            case .text, .markdown: return nil
            }
        }
    }

    /// `text` laid out as `type`, indented or compact, or nil when it is not
    /// that type. Text and Markdown are returned as they are.
    static func laidOut(_ text: String, as type: DataType, minified: Bool) -> String? {
        guard let format = type.structured else { return text }
        return TextToolsSupport.render(text, as: format, minified: minified)
    }

    let source: Source
    /// What the text was when the editor opened, or as of the last commit.
    private(set) var original: String
    /// The text being edited.
    @Published var draft: String
    @Published var dataType: DataType = .text
    /// Markdown shown as it reads, in place of the text.
    @Published var isPreviewing = false

    private var isCommitting = false

    init(original: String, source: Source) {
        self.original = original
        self.source = source
        self.draft = original
    }

    var hasChanges: Bool { draft != original }

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
        let text = draft
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
	
