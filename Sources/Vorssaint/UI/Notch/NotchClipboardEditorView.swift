//
//  NotchClipboardEditorView.swift
//  Vorssaint
//
//  Created by Christian Gonzalez on 10/5/26.
//
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// The clipboard editor inside the island: the copied text in a monospaced
/// editor, with a button back to the history and two tabs.
///
/// Raw is the text exactly as it is, and the only place it is typed in.
/// Formatted reads the same text as a chosen type (text, JSON or XML) and lays
/// it out, indented or compact, without touching the text itself.
///
/// There is no Save button. What the open tab shows goes back to the clipboard
/// when the editor closes, which is any of: the list button, the island
/// collapsing, or another app coming to the front (the island stays open when
/// it is pinned, so that case is handled here and not left to the island
/// closing). Undo is the way to cancel; undoing every edit commits nothing.
struct NotchClipboardEditorView: View {
    @ObservedObject var model: ClipboardEditorModel
    /// Returns the page to the history. The edit has already been committed.
    let onShowHistory: () -> Void
    @ObservedObject private var history = ClipboardHistoryService.shared
    @ObservedObject private var l10n = L10n.shared
    @State private var rawEditor = EditorHandle()
    @State private var formattedEditor = EditorHandle()
    @State private var showFind = false
    /// The replace row stays out of the way until it is asked for, as in a
    /// code editor: most searches are only searches.
    @State private var showReplace = false
    // Read here so turning colors on or off in settings shows up at once.
    @AppStorage(DefaultsKey.clipboardEditorColorJSON) private var colorJSON = true
    @AppStorage(DefaultsKey.clipboardEditorColorXML) private var colorXML = true
    private var text: ClipboardEditorStrings { FeatureStrings.clipboardEditor(l10n.language) }
    private var toolsText: TextToolsStrings { FeatureStrings.textTools(l10n.language) }

    private static let fontSize: CGFloat = 12
    private static let editorInset = NSSize(width: 6, height: 6)

    /// Holds an editor's text view so a close can flush composing text and the
    /// find bar can select in it. Weak, since the view belongs to the editor.
    private final class EditorHandle {
        weak var view: NSTextView?
    }

    /// The text view of whichever tab is showing.
    private var activeView: NSTextView? {
        model.tab == .raw ? rawEditor.view : formattedEditor.view
    }

    var body: some View {
        VStack(spacing: NotchLayout.rowSpacing) {
            toolbar

            if showFind {
                NotchFindReplaceBar(textView: { activeView }, text: model.outputText,
                                    showReplace: $showReplace, onClose: closeFind)
            }

            ZStack {
                // Kept alive under Formatted so its undo history and caret are
                // still there when the person comes back to it.
                rawTextView
                    .opacity(model.tab == .raw ? 1 : 0)
                    .allowsHitTesting(model.tab == .raw)
                    .accessibilityHidden(model.tab != .raw)
                if model.tab == .formatted {
                    formattedTextView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .modifier(NotchControlSurface(cornerRadius: 12, interactive: false))

            if model.tab == .formatted {
                formatFooter
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // Command-F and Command-R are buttons of their own, since a button
        // holds a single shortcut and the toolbar's only opens or closes.
        .background {
            Group {
                Button(action: toggleFind) { EmptyView() }
                    .keyboardShortcut("f", modifiers: .command)
                Button(action: toggleFindAndReplace) { EmptyView() }
                    .keyboardShortcut("r", modifiers: .command)
            }
            .opacity(0)
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
        }
        // The island collapsing, or the page changing, ends the editor. The
        // outcome is not reported here: a failed commit keeps the draft, but
        // nothing is left on screen to show it on.
        .onDisappear {
            flushComposition()
            model.commit(to: history) { _ in }
        }
        // Another app coming forward ends the editor even when the island is
        // pinned and stays open. The on-screen keyboard is not "another app".
        .onReceive(NSWorkspace.shared.notificationCenter
            .publisher(for: NSWorkspace.didActivateApplicationNotification)) { note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.bundleIdentifier != Bundle.main.bundleIdentifier,
                  app.bundleIdentifier != AssistiveKeyboard.bundleID else { return }
            commitAndLeave()
        }
    }

    // MARK: - Toolbar

    /// Three separate pieces: the way back to the history, the find bar's
    /// opener in the middle, and the tabs on the right.
    private var toolbar: some View {
        HStack(spacing: NotchLayout.rowSpacing) {
            NotchIconButton(symbol: "list.bullet", title: text.defaultViewHistory) { commitAndLeave() }
                .frame(width: NotchLayout.clipboardSearchHeight, height: NotchLayout.clipboardSearchHeight)
                .modifier(NotchControlSurface(cornerRadius: NotchLayout.clipboardSearchHeight / 2))

            Button {
                if showFind { closeFind() } else { showFind = true }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                    Text(toolsText.find)
                    Spacer(minLength: 0)
                }
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(showFind ? 0.9 : 0.55))
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity)
                .frame(height: NotchLayout.clipboardSearchHeight)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .modifier(NotchControlSurface(cornerRadius: 14))
            .accessibilityLabel(toolsText.findToggle)
            .accessibilityAddTraits(showFind ? .isSelected : [])

            HStack(spacing: 2) {
                pill(text.raw, selected: model.tab == .raw) { select(.raw) }
                pill(text.formatted, selected: model.tab == .formatted) { select(.formatted) }
            }
            .padding(.horizontal, 8)
            .frame(height: NotchLayout.clipboardSearchHeight)
            .modifier(NotchControlSurface(cornerRadius: 14))
        }
    }

    /// Under the text on Formatted, as two separate pieces: a settings menu on
    /// the left (Minify for now, with room for more) and the type the text is
    /// read as on the right. Choosing a type lays the text out again, indented.
    private var formatFooter: some View {
        HStack(spacing: NotchLayout.rowSpacing) {
            footerMenu(cornerRadius: NotchLayout.clipboardSearchHeight / 2, title: text.formatted) {
                Toggle(text.minify, isOn: $model.minified)
                    .disabled(model.dataType == .text)
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: NotchLayout.clipboardSearchHeight,
                           height: NotchLayout.clipboardSearchHeight)
            }

            if !model.formattedText().isValid {
                Text(invalidMessage)
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color.orange)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)

            footerMenu(cornerRadius: 14, title: typeName(model.dataType)) {
                ForEach(ClipboardEditorModel.DataType.allCases, id: \.self) { type in
                    Button {
                        model.dataType = type
                        model.minified = false
                    } label: {
                        if model.dataType == type {
                            Label(typeName(type), systemImage: "checkmark")
                        } else {
                            Text(typeName(type))
                        }
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Text(typeName(model.dataType))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 8, weight: .semibold))
                }
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 12)
                .frame(height: NotchLayout.clipboardSearchHeight)
            }
        }
    }

    /// A menu drawn the way the toolbar's buttons are. The system menu styles
    /// draw their own label and drop a background put on it, so the look is
    /// drawn here and an invisible menu sits over it to take the click.
    private func footerMenu<Items: View, Label: View>(
        cornerRadius: CGFloat, title: String,
        @ViewBuilder items: () -> Items,
        @ViewBuilder label: () -> Label
    ) -> some View {
        label()
            .modifier(NotchControlSurface(cornerRadius: cornerRadius))
            .overlay {
                Menu {
                    items()
                } label: {
                    Color.clear
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                }
                // The button style hands the whole frame to the label, so the
                // click area is as big as the background. The borderless style
                // only answers over the middle of a small control.
                .menuStyle(.button)
                .buttonStyle(.plain)
                .menuIndicator(.hidden)
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(title)
    }

    /// A small selectable label in the island's style.
    private func pill(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(selected ? .white : .white.opacity(0.55))
                .padding(.horizontal, 11)
                .frame(height: 24)
                .background(.white.opacity(selected ? 0.12 : 0), in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(NotchButtonStyle(cornerRadius: 12))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func typeName(_ type: ClipboardEditorModel.DataType) -> String {
        switch type {
        case .text: return text.typeText
        case .json: return "JSON"
        case .xml: return "XML"
        }
    }

    private var invalidMessage: String {
        model.dataType == .xml ? text.invalidXML : text.invalidJSON
    }

    // MARK: - Text views

    /// Raw: the text as it is.
    private var rawTextView: some View {
        textEditor(text: $model.draft, handle: rawEditor)
    }

    /// The same text read as the chosen type, edited like Raw. The layout is
    /// worked out again, and what was typed here dropped, when the text on
    /// Raw, the type or Minify changes.
    private var formattedTextView: some View {
        textEditor(text: Binding(get: { model.formattedText().text },
                                 set: { model.formattedEdit = $0 }),
                   handle: formattedEditor, highlighting: formattedHighlighting)
    }

    /// Colors for the type the text is read as, when that type has them on and
    /// the text is that type. Text that is not (it is shown as it is) stays
    /// plain, so the colors never claim more than is true.
    private var formattedHighlighting: PlainTextEditor.Highlighting? {
        guard let format = model.dataType.structured, model.formattedText().isValid else { return nil }
        switch format {
        case .json: guard colorJSON else { return nil }
        case .xml: guard colorXML else { return nil }
        }
        return PlainTextEditor.Highlighting(id: "\(format)") { text in
            SyntaxHighlightSupport.tokens(in: text, format: format).map {
                ($0.range, Self.color(for: $0.kind))
            }
        }
    }

    /// Chosen to read on the island's dark background.
    private static func color(for kind: SyntaxHighlightSupport.Kind) -> NSColor {
        func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> NSColor {
            NSColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: 1)
        }
        switch kind {
        case .key, .tag: return rgb(125, 190, 255)
        case .string, .value: return rgb(240, 170, 120)
        case .number: return rgb(150, 215, 140)
        case .literal: return rgb(205, 150, 235)
        case .attribute: return rgb(230, 215, 130)
        case .punctuation: return NSColor.white.withAlphaComponent(0.5)
        case .comment: return NSColor.white.withAlphaComponent(0.4)
        }
    }

    /// The one editor both tabs are built from, so they look and behave the
    /// same: anything set up here is set up for each.
    private func textEditor(text: Binding<String>, handle: EditorHandle,
                            highlighting: PlainTextEditor.Highlighting? = nil) -> some View {
        PlainTextEditor(text: text,
                        fontSize: Self.fontSize,
                        textColor: .white,
                        textContainerInset: Self.editorInset,
                        usesFindBar: false,
                        ownsUndoManager: true,
                        highlighting: highlighting) { view in
            // Same point size as the editor's own font, so it does not put
            // the proportional font back when the view updates.
            view.font = .monospacedSystemFont(ofSize: Self.fontSize, weight: .regular)
            view.insertionPointColor = .white
            handle.view = view
            DispatchQueue.main.async { focusEditor() }
        }
    }

    // MARK: - Actions

    private func select(_ tab: ClipboardEditorModel.Tab) {
        guard model.tab != tab else { return }
        flushComposition()
        model.tab = tab
        // Opening Formatted starts from the indented layout.
        if tab == .formatted { model.minified = false }
        DispatchQueue.main.async { focusEditor() }
    }

    /// Command-F: the find row, then back out one step at a time. With the
    /// replace row showing it only puts that away; the next press closes the bar.
    private func toggleFind() {
        if !showFind {
            showFind = true
        } else if showReplace {
            showReplace = false
        } else {
            closeFind()
        }
    }

    /// Command-R: everything out, or everything away.
    private func toggleFindAndReplace() {
        if showFind && showReplace {
            closeFind()
        } else {
            showFind = true
            showReplace = true
        }
    }

    /// Puts the find bar away and gives the keyboard back to the text.
    private func closeFind() {
        showFind = false
        showReplace = false
        DispatchQueue.main.async { focusEditor() }
    }

    private func commitAndLeave() {
        flushComposition()
        model.commit(to: history) { outcome in
            if outcome == .failed { NSSound.beep() }
        }
        onShowHistory()
    }

    /// Text an input method is still composing is not in the draft yet.
    private func flushComposition() {
        for view in [rawEditor.view, formattedEditor.view] {
            if let view, view.hasMarkedText() { view.unmarkText() }
        }
    }

    /// The caret starts at the top, where the beginning of the data is.
    private func focusEditor() {
        guard let view = activeView, let window = view.window, window.isKeyWindow else { return }
        window.makeFirstResponder(view)
    }
}
