//
//  TextEditorPreferences.swift
//  Vorssaint
//
//  Created by Christian Gonzalez on 10/23/26.
//
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// What the shared text editor is set to do with each format: whether the
/// format is on at all, and the color of each kind of text in it.
///
/// A format is a switch and a list of colorable kinds, so a new one is a case
/// here, a case in `TextToolsSupport.Format` and a tokenizer, and the settings
/// page picks it up. Colors are stored as the few the person changed
/// (`{"key":"#7DBEFF"}`), not as a full palette, so a color never changed
/// keeps following the built-in one when it is improved.
enum TextEditorPreferences {
    /// Every format, in the order settings lists them.
    static let formats: [TextToolsSupport.Format] = [.json, .xml]

    static func enabledKey(_ format: TextToolsSupport.Format) -> String {
        switch format {
        case .json: return DefaultsKey.textEditorFormatJSON
        case .xml: return DefaultsKey.textEditorFormatXML
        }
    }

    static func colorsKey(_ format: TextToolsSupport.Format) -> String {
        switch format {
        case .json: return DefaultsKey.textEditorColorsJSON
        case .xml: return DefaultsKey.textEditorColorsXML
        }
    }

    static func isEnabled(_ format: TextToolsSupport.Format, defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: enabledKey(format))
    }

    /// The kinds of text a format has colors for, in the order settings lists them.
    static func kinds(for format: TextToolsSupport.Format) -> [SyntaxHighlightSupport.Kind] {
        switch format {
        case .json: return [.key, .string, .number, .literal, .punctuation]
        case .xml: return [.tag, .attribute, .string, .value, .punctuation, .comment]
        }
    }

    /// The built-in color, chosen to read on the island's dark background.
    static func defaultHex(for kind: SyntaxHighlightSupport.Kind) -> String {
        switch kind {
        case .key, .tag: return "#7DBEFF"
        case .string, .value: return "#F0AA78"
        case .number: return "#96D78C"
        case .literal: return "#CD96EB"
        case .attribute: return "#E6D782"
        case .punctuation: return "#8C8C8C"
        case .comment: return "#6E6E6E"
        }
    }

    // MARK: - Stored overrides

    /// The colors someone changed, keyed by kind name. Anything that is not a
    /// known kind with a six-digit color (a hand-edited or restored value) is
    /// left out, so what is stored can only ever recolor, never break.
    static func overrides(from stored: String) -> [SyntaxHighlightSupport.Kind: String] {
        guard let data = stored.data(using: .utf8),
              let raw = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
        var result: [SyntaxHighlightSupport.Kind: String] = [:]
        for (name, hex) in raw {
            if let kind = SyntaxHighlightSupport.Kind(rawValue: name), let clean = normalizedHex(hex) {
                result[kind] = clean
            }
        }
        return result
    }

    /// The color to draw each kind of a format in: the changed one, or the built-in.
    static func palette(for format: TextToolsSupport.Format,
                        stored: String) -> [SyntaxHighlightSupport.Kind: String] {
        let changed = overrides(from: stored)
        return Dictionary(uniqueKeysWithValues: kinds(for: format).map { ($0, changed[$0] ?? defaultHex(for: $0)) })
    }

    /// `stored` with one kind's color set, or put back to the built-in color
    /// when `hex` is nil or the same as it. Empty when nothing is changed.
    static func storing(_ hex: String?, for kind: SyntaxHighlightSupport.Kind, in stored: String) -> String {
        var changed = overrides(from: stored)
        if let hex, let clean = normalizedHex(hex), clean != defaultHex(for: kind) {
            changed[kind] = clean
        } else {
            changed[kind] = nil
        }
        guard !changed.isEmpty else { return "" }
        let named = Dictionary(uniqueKeysWithValues: changed.map { ($0.key.rawValue, $0.value) })
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return (try? encoder.encode(named)).flatMap { String(data: $0, encoding: .utf8) } ?? ""
    }

    // MARK: - Hex

    /// `#RRGGBB`, upper case, from any single color value the app reads
    /// (`#abc`, `rgb(...)`), or nil. Transparency is not offered for text.
    static func normalizedHex(_ text: String) -> String? {
        ColorValue(text: text).map { hexString(red: $0.red, green: $0.green, blue: $0.blue) }
    }

    static func hexString(red: Double, green: Double, blue: Double) -> String {
        func byte(_ value: Double) -> Int { Int((min(max(value, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", byte(red), byte(green), byte(blue))
    }
}
