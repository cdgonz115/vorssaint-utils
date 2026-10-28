//
//  TextEditorSettings.swift
//  Vorssaint
//
//  Created by Christian Gonzalez on 10/23/26.
//
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// Settings for the text editor that Vorssaint's windows share: which formats
/// it reads, and the color of each kind of text in each. Where the editor
/// appears (the clipboard today) is set on that feature's own page; nothing
/// here is specific to one of them.
struct TextEditorSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.textEditorFormatJSON) private var formatJSON = true
    @AppStorage(DefaultsKey.textEditorFormatXML) private var formatXML = true
    @AppStorage(DefaultsKey.textEditorColorsJSON) private var colorsJSON = ""
    @AppStorage(DefaultsKey.textEditorColorsXML) private var colorsXML = ""
    /// The formats whose colors are showing. They start folded away: most
    /// people never change them.
    @State private var expanded: Set<TextToolsSupport.Format> = []
    private var text: TextEditorStrings { FeatureStrings.textEditor(l10n.language) }

    var body: some View {
        Form {
            Section {
                Text(text.caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ForEach(TextEditorPreferences.formats, id: \.self) { format in
                formatSection(format)
            }
        }
        .formStyle(.grouped)
    }

    private func formatSection(_ format: TextToolsSupport.Format) -> some View {
        let enabled = enabledBinding(format)
        let stored = colorsBinding(format)
        return Section {
            Toggle(name(of: format), isOn: enabled)
                // A format that is off has no colors to show, so it folds up.
                .onChange(of: enabled.wrappedValue) { _, isOn in
                    if !isOn { expanded.remove(format) }
                }
            DisclosureGroup(text.colors, isExpanded: expandedBinding(format)) {
                ForEach(TextEditorPreferences.kinds(for: format), id: \.self) { kind in
                    ColorPicker(text.label(for: kind, in: format),
                                selection: colorBinding(kind, stored: stored),
                                supportsOpacity: false)
                }
                Button(text.reset) { stored.wrappedValue = "" }
                    .disabled(stored.wrappedValue.isEmpty)
            }
            .disabled(!enabled.wrappedValue)
        } header: {
            Text(name(of: format))
        }
    }

    // MARK: - Bindings

    private func expandedBinding(_ format: TextToolsSupport.Format) -> Binding<Bool> {
        Binding(get: { expanded.contains(format) },
                set: { if $0 { expanded.insert(format) } else { expanded.remove(format) } })
    }

    private func name(of format: TextToolsSupport.Format) -> String {
        switch format {
        case .json: return "JSON"
        case .xml: return "XML"
        }
    }

    private func enabledBinding(_ format: TextToolsSupport.Format) -> Binding<Bool> {
        switch format {
        case .json: return $formatJSON
        case .xml: return $formatXML
        }
    }

    private func colorsBinding(_ format: TextToolsSupport.Format) -> Binding<String> {
        switch format {
        case .json: return $colorsJSON
        case .xml: return $colorsXML
        }
    }

    /// One kind's color as the picker sees it. Writing stores only a color
    /// that differs from the built-in one, so picking the original back
    /// clears the change.
    private func colorBinding(_ kind: SyntaxHighlightSupport.Kind, stored: Binding<String>) -> Binding<Color> {
        Binding(
            get: {
                let changed = TextEditorPreferences.overrides(from: stored.wrappedValue)
                let hex = changed[kind] ?? TextEditorPreferences.defaultHex(for: kind)
                guard let value = ColorValue(text: hex) else { return .white }
                return Color(.sRGB, red: value.red, green: value.green, blue: value.blue, opacity: 1)
            },
            set: { color in
                guard let rgb = NSColor(color).usingColorSpace(.sRGB) else { return }
                let hex = TextEditorPreferences.hexString(red: Double(rgb.redComponent),
                                                          green: Double(rgb.greenComponent),
                                                          blue: Double(rgb.blueComponent))
                stored.wrappedValue = TextEditorPreferences.storing(hex, for: kind, in: stored.wrappedValue)
            })
    }
}
