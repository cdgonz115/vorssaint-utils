//
//  TextViewEditing.swift
//  Vorssaint
//
//  Created by Christian Gonzalez on 10/5/26.
//
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit

extension NSTextView {
    /// Replaces the whole text through the text view's own editing path, so the
    /// change joins the undo stack and Command-Z takes it back. Assigning to
    /// `string`, or changing the binding behind the view, would skip the undo
    /// stack and leave the user with no way to cancel a format or a replace.
    func replaceAllText(with replacement: String) {
        // Text still being composed (an input method's underlined candidate)
        // has to be committed first, or the range below points at nothing.
        if hasMarkedText() { unmarkText() }
        let full = NSRange(location: 0, length: (string as NSString).length)
        guard shouldChangeText(in: full, replacementString: replacement) else { return }
        replaceCharacters(in: full, with: replacement)
        didChangeText()
        let start = NSRange(location: 0, length: 0)
        setSelectedRange(start)
        scrollRangeToVisible(start)
    }

    /// Replaces one range through the same editing path, so it is one step in
    /// the undo stack. The caret ends after the inserted text.
    func replaceText(in range: NSRange, with replacement: String) {
        if hasMarkedText() { unmarkText() }
        guard shouldChangeText(in: range, replacementString: replacement) else { return }
        replaceCharacters(in: range, with: replacement)
        didChangeText()
        setSelectedRange(NSRange(location: range.location + (replacement as NSString).length, length: 0))
    }

    /// Types the Markdown a writing-tools button stands for, through the text
    /// view so one Command-Z takes the whole mark back. Any editor can use it;
    /// it knows nothing about which one it is.
    func applyMark(_ mark: ScratchpadMark) {
        // A live input-method composition holds a marked range into the
        // storage; editing around it leaves that range pointing at nothing.
        if hasMarkedText() { unmarkText() }
        // Clicking a button takes first responder away from the editor, and a
        // selection set on a view that is not first responder does not show.
        window?.makeFirstResponder(self)
        let edit = ScratchpadSupport.edit(applying: mark, to: string, selection: selectedRange())
        guard (string as NSString).substring(with: edit.range) != edit.replacement else { return }
        guard shouldChangeText(in: edit.range, replacementString: edit.replacement) else { return }
        replaceCharacters(in: edit.range, with: edit.replacement)
        didChangeText()
        setSelectedRange(edit.selection)
        scrollRangeToVisible(edit.selection)
    }
}
