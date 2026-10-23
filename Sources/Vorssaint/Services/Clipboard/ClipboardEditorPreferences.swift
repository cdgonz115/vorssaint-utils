//
//  ClipboardEditorPreferences.swift
//  Vorssaint
//
//  Created by Christian Gonzalez on 10/1/26.
//
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Which view the clipboard shows when it opens.
enum ClipboardOpenView: String, CaseIterable {
    case history
    case editor

    /// The view to open, given what is stored and whether the editor is on.
    ///
    /// Anything that is not a known value (a backup from another version, a
    /// hand-edited file), or the editor chosen while it is switched off, opens
    /// the history, which is what the clipboard did before the editor existed.
    static func resolve(stored: String?, editorEnabled: Bool) -> ClipboardOpenView {
        guard editorEnabled, let stored, let view = ClipboardOpenView(rawValue: stored) else {
            return .history
        }
        return view
    }

    /// The setting as it stands right now.
    static var current: ClipboardOpenView {
        let defaults = UserDefaults.standard
        return resolve(stored: defaults.string(forKey: DefaultsKey.clipboardEditorDefaultView),
                       editorEnabled: defaults.bool(forKey: DefaultsKey.clipboardEditorEnabled))
    }

    /// The view the "Copied" notice opens when it is clicked, which is set
    /// apart from the one the clipboard opens on by hand.
    static var forCopyNotice: ClipboardOpenView {
        let defaults = UserDefaults.standard
        return resolve(stored: defaults.string(forKey: DefaultsKey.clipboardEditorNoticeView),
                       editorEnabled: defaults.bool(forKey: DefaultsKey.clipboardEditorEnabled))
    }

    /// Whether the editor is switched on, for the buttons that lead to it.
    static var isEditorEnabled: Bool {
        UserDefaults.standard.bool(forKey: DefaultsKey.clipboardEditorEnabled)
    }
}

/// Which formats the editor's Formatted tab colors. Each one is its own
/// switch, so a format that is not wanted costs nothing, and a new format
/// is one more case and one more key.
enum ClipboardEditorColors {
    static func key(for format: TextToolsSupport.Format) -> String {
        switch format {
        case .json: return DefaultsKey.clipboardEditorColorJSON
        case .xml: return DefaultsKey.clipboardEditorColorXML
        }
    }

    static func isEnabled(_ format: TextToolsSupport.Format, defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: key(for: format))
    }
}
