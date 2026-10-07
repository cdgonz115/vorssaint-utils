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

/// The clipboard editor inside the island: one piece of text in a monospaced
/// editor, with a button back to the history and the data tools beside it.
///
/// There is no Save button. The text goes back to the clipboard when the
/// editor closes, which is any of: the list button, the island collapsing, or
/// another app coming to the front (the island stays open when it is pinned,
/// so that case is handled here and not left to the island closing). Undo is
/// the way to cancel; undoing every edit commits nothing.
struct NotchClipboardEditorView: View {
    @ObservedObject var model: ClipboardEditorModel
    /// Returns the page to the history. The edit has already been committed.
    let onShowHistory: () -> Void
    @ObservedObject private var history = ClipboardHistoryService.shared
    @ObservedObject private var l10n = L10n.shared
    @State private var editor = EditorHandle()
    @State private var notice: String?
    @State private var showFind = false
    /// The replace row stays out of the way until it is asked for, as in a
    /// code editor: most searches are only searches.
    @State private var showReplace = false
    private var text: ClipboardEditorStrings { FeatureStrings.clipboardEditor(l10n.language) }
    private var toolsText: TextToolsStrings { FeatureStrings.textTools(l10n.language) }

    private static let fontSize: CGFloat = 12
    private static let editorInset = NSSize(width: 6, height: 6)

    /// Holds the editor's text view so a format can go through its undo and
    /// a close can flush composing text. Weak, since the view belongs to the
    /// editor.
    private final class EditorHandle {
        weak var view: NSTextView?
    }

    var body: some View {
        VStack(spacing: NotchLayout.rowSpacing) {
            HStack(spacing: 8) {
                NotchIconButton(symbol: "list.bullet", title: text.defaultViewHistory) { commitAndLeave() }
                Spacer(minLength: 0)
                if let notice {
                    Text(notice)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                }
                NotchIconButton(symbol: "magnifyingglass", title: toolsText.findToggle, selected: showFind) {
                    if showFind { closeFind() } else { showFind = true }
                }
                NotchIconButton(symbol: "curlybraces", title: text.format) { transform(minify: false) }
                NotchIconButton(symbol: "arrow.down.right.and.arrow.up.left", title: text.minify) {
                    transform(minify: true)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: NotchLayout.clipboardSearchHeight)
            .modifier(NotchControlSurface(cornerRadius: 14))

            if showFind {
                NotchFindReplaceBar(textView: { editor.view }, text: model.draft,
                                    showReplace: $showReplace, onClose: closeFind)
            }

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
                editor.view = view
                DispatchQueue.main.async { focusEditor() }
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
        .task(id: notice) {
            guard notice != nil else { return }
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            notice = nil
        }
    }

    /// Format and minify run on what is in the editor now and go through the
    /// text view, so Command-Z takes them back.
    private func transform(minify: Bool) {
        guard let view = editor.view else { return }
        let current = view.string
        guard let result = minify ? TextToolsSupport.minify(current) : TextToolsSupport.prettyPrint(current) else {
            notice = text.notStructured
            NSSound.beep()
            return
        }
        guard result != current else { return }
        view.replaceAllText(with: result)
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
        if let view = editor.view, view.hasMarkedText() { view.unmarkText() }
    }

    /// The caret starts at the top, where the beginning of the data is.
    private func focusEditor() {
        guard let view = editor.view, let window = view.window, window.isKeyWindow else { return }
        window.makeFirstResponder(view)
    }
}
