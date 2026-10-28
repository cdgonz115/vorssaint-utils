//
//  TextEditorFormatSettings.swift
//  Vorssaint
//
//  Created by Christian Gonzalez on 10/26/26.
//
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// The text editor's format settings as a view reads them: which formats are
/// on, and the colors to draw each in. Declared as a property of a view, so
/// the view redraws when one changes in settings. Every editor that colors
/// text builds its highlighting here, so they cannot drift apart.
struct TextEditorFormatSettings: DynamicProperty {
    @AppStorage(DefaultsKey.textEditorFormatJSON) private var jsonOn = true
    @AppStorage(DefaultsKey.textEditorFormatXML) private var xmlOn = true
    @AppStorage(DefaultsKey.textEditorColorsJSON) private var jsonColors = ""
    @AppStorage(DefaultsKey.textEditorColorsXML) private var xmlColors = ""

    func isEnabled(_ format: TextToolsSupport.Format) -> Bool {
        switch format {
        case .json: return jsonOn
        case .xml: return xmlOn
        }
    }

    /// Colors for text read as `format`, or nil when there is none or the
    /// format is switched off.
    func highlighting(for format: TextToolsSupport.Format?) -> PlainTextEditor.Highlighting? {
        guard let format, isEnabled(format) else { return nil }
        let stored = format == .json ? jsonColors : xmlColors
        let palette = TextEditorPreferences.palette(for: format, stored: stored).mapValues(Self.color(hex:))
        // The stored colors are part of the identity, so changing one in
        // settings colors the text again.
        return PlainTextEditor.Highlighting(id: "\(format)\(stored)") { text in
            SyntaxHighlightSupport.tokens(in: text, format: format).compactMap { token in
                palette[token.kind].map { (token.range, $0) }
            }
        }
    }

    private static func color(hex: String) -> NSColor {
        guard let value = ColorValue(text: hex) else { return .white }
        return NSColor(srgbRed: value.red, green: value.green, blue: value.blue, alpha: 1)
    }
}
