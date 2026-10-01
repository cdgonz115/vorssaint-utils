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

    let source: Source
    /// What the text was when the editor opened, or as of the last commit.
    private(set) var original: String
    @Published var draft: String

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
        guard draft != original else { completion(.unchanged); return }
        guard ClipboardHistoryEditing.canSave(original: original, draft: draft) else {
            completion(.notStorable)
            return
        }

        let text = draft
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
	
