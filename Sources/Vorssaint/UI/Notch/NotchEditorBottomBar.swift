//
//  NotchEditorBottomBar.swift
//  Vorssaint
//
//  Created by Christian Gonzalez on 10/27/26.
//
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// The row under the island's text editors, written once for the clipboard
/// editor and the scratchpad so they behave the same: Minify (JSON and XML), the preview (Markdown), and the type the
/// text is on the right.
///
/// Choosing JSON or XML indents the text in place, through the text view, so
/// one undo takes it back; Minify does the same the other way. Text that is
/// not that type is left alone and says so.
struct NotchEditorBottomBar: View {
    @Binding var dataType: ClipboardEditorModel.DataType
    let isPreviewing: Bool
    let isEmpty: Bool
    let textView: () -> NSTextView?
    let onTogglePreview: () -> Void

    @ObservedObject private var l10n = L10n.shared
    /// A format action that found the text is not that type.
    @State private var hasProblem = false
    // Read here so a change in the text editor's settings shows up at once.
    private let formatSettings = TextEditorFormatSettings()
    private var text: ClipboardEditorStrings { FeatureStrings.clipboardEditor(l10n.language) }
    private var padText: ScratchpadFeatureStrings { FeatureStrings.scratchpad(l10n.language) }
    private static let barHeight: CGFloat = 28

    init(dataType: Binding<ClipboardEditorModel.DataType>,
         isPreviewing: Bool, isEmpty: Bool,
         textView: @escaping () -> NSTextView?, onTogglePreview: @escaping () -> Void) {
        _dataType = dataType
        self.isPreviewing = isPreviewing
        self.isEmpty = isEmpty
        self.textView = textView
        self.onTogglePreview = onTogglePreview
    }

    private var isMarkdown: Bool { dataType == .markdown }

    var body: some View {
        HStack(spacing: 4) {
            // Only the tools that belong to the type: Text has none.
            if dataType.structured != nil {
                NotchIconButton(symbol: "arrow.down.right.and.arrow.up.left", title: text.minify) {
                    relayout(minified: true)
                }
            }
            if isMarkdown {
                NotchIconButton(symbol: isPreviewing ? "pencil" : "eye",
                                title: isPreviewing ? padText.editText : padText.previewFormatting,
                                selected: isPreviewing, action: onTogglePreview)
                    .disabled(isEmpty)
            }
            if hasProblem {
                Text(dataType == .xml ? text.invalidXML : text.invalidJSON)
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color.orange)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            typeMenu
        }
        .frame(height: Self.barHeight)
    }

    /// The type menu, drawn the way the island's buttons are. The system menu
    /// styles draw their own label and drop a background put on it, so the
    /// look is drawn here and an invisible menu sits over it to take the click.
    private var typeMenu: some View {
        HStack(spacing: 5) {
            Text(typeName(dataType))
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 8, weight: .semibold))
        }
        .font(.system(size: 11.5, weight: .medium))
        .foregroundStyle(.white.opacity(0.85))
        .padding(.horizontal, 12)
        .frame(height: Self.barHeight)
        .modifier(NotchControlSurface(cornerRadius: 14))
        .overlay {
            Menu {
                ForEach(availableTypes, id: \.self) { type in
                    Button { choose(type) } label: {
                        if dataType == type {
                            Label(typeName(type), systemImage: "checkmark")
                        } else {
                            Text(typeName(type))
                        }
                    }
                }
            } label: {
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
            }
            // The button style hands the whole frame to the label, so the
            // click area is as big as the background.
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(typeName(dataType))
    }

    /// Text, each format that is switched on in the text editor's settings, and
    /// Markdown.
    private var availableTypes: [ClipboardEditorModel.DataType] {
        ClipboardEditorModel.DataType.allCases.filter { type in
            type.structured.map(formatSettings.isEnabled) ?? true
        }
    }

    private func typeName(_ type: ClipboardEditorModel.DataType) -> String {
        switch type {
        case .text: return text.typeText
        case .json: return "JSON"
        case .xml: return "XML"
        case .markdown: return "Markdown"
        }
    }

    private func choose(_ type: ClipboardEditorModel.DataType) {
        guard type != dataType else { return }
        flushComposition()
        dataType = type
        hasProblem = false
        if type.structured != nil { relayout(minified: false) }
    }

    /// Rewrites the text as the current type, through the text view so the
    /// change is one step of its undo history. Invalid text is left alone.
    private func relayout(minified: Bool) {
        flushComposition()
        guard let view = textView() else { return }
        guard let laid = ClipboardEditorModel.laidOut(view.string, as: dataType, minified: minified) else {
            hasProblem = true
            NSSound.beep()
            return
        }
        hasProblem = false
        if laid != view.string { view.replaceAllText(with: laid) }
    }

    /// Text an input method is still composing is not in the text yet.
    private func flushComposition() {
        if let view = textView(), view.hasMarkedText() { view.unmarkText() }
    }
}
