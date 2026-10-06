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
}
