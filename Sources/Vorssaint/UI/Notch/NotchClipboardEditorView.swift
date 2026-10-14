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
    /// The type and layout controls under the tabs, which can be put away to
    /// give the text the room.
    @State private var showFormatOptions = true
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

            if model.tab == .formatted && showFormatOptions {
                formatOptions
            }

            if showFind {
                NotchFindReplaceBar(textView: { activeView }, text: model.outputText,
                                    showReplace: $showReplace, canReplace: model.tab == .raw,
                                    onClose: closeFind)
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

    private var toolbar: some View {
        HStack(spacing: 8) {
            NotchIconButton(symbol: "list.bullet", title: text.defaultViewHistory) { commitAndLeave() }
            HStack(spacing: 2) {
                pill(text.raw, selected: model.tab == .raw) { select(.raw) }
                pill(text.formatted, selected: model.tab == .formatted) { select(.formatted) }
            }
            Spacer(minLength: 0)
            if model.tab == .formatted {
                NotchIconButton(symbol: "slider.horizontal.3", title: text.formatted,
                                selected: showFormatOptions) {
                    showFormatOptions.toggle()
                }
            }
            NotchIconButton(symbol: "magnifyingglass", title: toolsText.findToggle, selected: showFind) {
                if showFind { closeFind() } else { showFind = true }
            }
        }
        .padding(.horizontal, 12)
        .frame(height: NotchLayout.clipboardSearchHeight)
        .modifier(NotchControlSurface(cornerRadius: 14))
    }

    /// The type the text is read as, and whether to indent it or make it compact.
    private var formatOptions: some View {
        HStack(spacing: 8) {
            Menu {
                ForEach(ClipboardEditorModel.DataType.allCases, id: \.self) { type in
                    Button {
                        model.dataType = type
                        if type == .text { model.minified = false }
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
                .padding(.horizontal, 10)
                .frame(height: 24)
                .background(.white.opacity(0.12), in: Capsule())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel(typeName(model.dataType))

            HStack(spacing: 2) {
                pill(text.format, selected: !model.minified) { model.minified = false }
                pill(text.minify, selected: model.minified) { model.minified = true }
            }
            .opacity(model.dataType == .text ? 0.35 : 1)
            .disabled(model.dataType == .text)
            Spacer(minLength: 0)
            if !model.formattedText().isValid {
                Text(invalidMessage)
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color.orange)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: NotchLayout.clipboardSearchHeight)
        .modifier(NotchControlSurface(cornerRadius: 14))
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

    private var rawTextView: some View {
        PlainTextEditor(text: $model.draft,
                        fontSize: Self.fontSize,
                        textColor: .white,
                        textContainerInset: Self.editorInset,
                        usesFindBar: false,
                        ownsUndoManager: true) { view in
            // Same point size as the editor's own font, so it does not put
            // the proportional font back when the view updates.
            view.font = .monospacedSystemFont(ofSize: Self.fontSize, weight: .regular)
            view.insertionPointColor = .white
            rawEditor.view = view
            DispatchQueue.main.async { focusEditor() }
        }
    }

    /// The same text read as the chosen type. It cannot be typed in: it is
    /// worked out from Raw, so a change here would be lost the next time
    /// anything on Raw or in the options changed.
    private var formattedTextView: some View {
        PlainTextEditor(text: .constant(model.formattedText().text),
                        fontSize: Self.fontSize,
                        textColor: .white,
                        textContainerInset: Self.editorInset,
                        usesFindBar: false,
                        ownsUndoManager: true,
                        isEditable: false) { view in
            view.font = .monospacedSystemFont(ofSize: Self.fontSize, weight: .regular)
            formattedEditor.view = view
            DispatchQueue.main.async { focusEditor() }
        }
    }

    // MARK: - Actions

    private func select(_ tab: ClipboardEditorModel.Tab) {
        guard model.tab != tab else { return }
        flushComposition()
        model.tab = tab
        // Formatted cannot be replaced into, so its replace row is put away.
        if tab == .formatted { showReplace = false }
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

    /// Command-R: everything out, or everything away. Formatted has nothing to
    /// replace into, so there it only opens or closes the find row.
    private func toggleFindAndReplace() {
        guard model.tab == .raw else {
            if showFind { closeFind() } else { showFind = true }
            return
        }
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
        if let view = rawEditor.view, view.hasMarkedText() { view.unmarkText() }
    }

    /// The caret starts at the top, where the beginning of the data is.
    private func focusEditor() {
        guard let view = activeView, let window = view.window, window.isKeyWindow else { return }
        window.makeFirstResponder(view)
    }
}
