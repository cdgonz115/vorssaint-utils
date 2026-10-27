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

/// The clipboard editor inside the island, built like the scratchpad: a
/// condensed top bar with the way back to the history, a strip of the pinned
/// clipboards to switch between, and the find opener; the text in a monospaced
/// editor; and a bottom bar with the writing tools, Minify, and the type the
/// text is.
///
/// The type is how the text gets laid out. Text is left alone. JSON and XML
/// are indented in place when chosen, as one edit that undo takes back, and
/// Minify compacts them the same way. Markdown keeps the text as it is and
/// offers the scratchpad's writing tools and a rendered preview.
///
/// There is no Save button. What the editor shows goes back to the clipboard
/// when it closes, which is any of: the list button, the island collapsing,
/// switching to another pinned clipboard, or another app coming to the front
/// (the island stays open when it is pinned, so that case is handled here and
/// not left to the island closing). Undo is the way to cancel; undoing every
/// edit commits nothing.
struct NotchClipboardEditorView: View {
    @ObservedObject var model: ClipboardEditorModel
    /// Returns the page to the history. The edit has already been committed.
    let onShowHistory: () -> Void
    /// Opens a pinned clipboard in the editor. The edit has already been committed.
    let onSwitch: (ClipboardHistoryEntry) -> Void
    @ObservedObject private var history = ClipboardHistoryService.shared
    @ObservedObject private var l10n = L10n.shared
    @State private var editor = EditorHandle()
    @State private var showFind = false
    /// The replace row stays out of the way until it is asked for, as in a
    /// code editor: most searches are only searches.
    @State private var showReplace = false
    @State private var showTools = false
    // Read here so a change in the text editor's settings shows up at once.
    private var formatSettings = TextEditorFormatSettings()
    private var text: ClipboardEditorStrings { FeatureStrings.clipboardEditor(l10n.language) }

    init(model: ClipboardEditorModel, onShowHistory: @escaping () -> Void,
         onSwitch: @escaping (ClipboardHistoryEntry) -> Void) {
        self.model = model
        self.onShowHistory = onShowHistory
        self.onSwitch = onSwitch
    }

    private static let fontSize: CGFloat = 12
    private static let editorInset = NSSize(width: 6, height: 6)
    private static let barHeight: CGFloat = 28

    /// Holds the editor's text view so a close can flush composing text and the
    /// find bar can select in it. Weak, since the view belongs to the editor.
    private final class EditorHandle {
        weak var view: NSTextView?
    }

    private var isMarkdown: Bool { model.dataType == .markdown }

    var body: some View {
        VStack(spacing: 6) {
            topBar
                .frame(height: 24)

            if showTools && isMarkdown && !model.isPreviewing {
                ScratchpadFormatBar(style: .island, editor: editor.view,
                                    onApply: { editor.view?.applyMark($0) })
                    .frame(height: Self.barHeight)
            }

            if showFind {
                NotchFindReplaceBar(textView: { editor.view }, text: model.draft,
                                    showReplace: $showReplace, onClose: closeFind)
            }

            editorSurface

            NotchEditorBottomBar(dataType: $model.dataType, showTools: $showTools,
                                 isPreviewing: model.isPreviewing, isEmpty: model.draft.isEmpty,
                                 textView: { editor.view }, onTogglePreview: togglePreview)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // A pinned clipboard opens as the type it was left on.
        .onAppear {
            guard let id = selectedPinnedID,
                  let raw = TextEditorTypeStore.rawType(for: id, in: TextEditorTypeStore.load()),
                  let type = ClipboardEditorModel.DataType(rawValue: raw) else { return }
            model.dataType = type
            // Markdown opens as its preview, the way it reads best.
            if type == .markdown && !model.draft.isEmpty { model.isPreviewing = true }
        }
        // Leaving Markdown puts its tools and preview away.
        .onChange(of: model.dataType) { _, type in
            rememberType(type)
            guard type != .markdown else { return }
            model.isPreviewing = false
            showTools = false
            DispatchQueue.main.async { focusEditor() }
        }
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

    // MARK: - Bars

    /// Condensed and without a background, like the scratchpad's: the way back
    /// to the history and the pinned clipboards to switch between. Find is
    /// the keyboard's: Command-F and Command-R.
    private var topBar: some View {
        HStack(spacing: 4) {
            NotchIconButton(symbol: "list.bullet", title: text.defaultViewHistory) { commitAndLeave() }
            NotchChipStrip(items: pinned, selectedID: selectedPinnedID) { chip($0) }
                .frame(maxWidth: .infinity)
        }
    }

    private var pinned: [ClipboardHistoryEntry] {
        history.pinnedEntries.filter { $0.kind == .text }
    }

    private var selectedPinnedID: UUID? {
        if case .entry(let id) = model.source { return id }
        return nil
    }

    private func chip(_ entry: ClipboardHistoryEntry) -> some View {
        let selected = entry.id == selectedPinnedID
        return Button { switchTo(entry) } label: {
            HStack(spacing: 4) {
                Image(systemName: "pin.fill")
                    .font(.system(size: 8, weight: .semibold))
                Text(number(of: entry))
                    .font(.system(size: 11, weight: .medium))
            }
                .lineLimit(1)
                .foregroundStyle(selected ? .white : .white.opacity(0.6))
                .padding(.horizontal, 10)
                .frame(height: 22)
                .background(.white.opacity(selected ? 0.14 : 0.05), in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(NotchButtonStyle(cornerRadius: 11, lifts: false))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    /// Pinned clipboards are numbered by their place among the pins.
    private func number(of entry: ClipboardHistoryEntry) -> String {
        "\((pinned.firstIndex { $0.id == entry.id } ?? 0) + 1)"
    }

    // MARK: - Text

    private var editorSurface: some View {
        ZStack {
            PlainTextEditor(text: $model.draft,
                            fontSize: Self.fontSize,
                            textColor: .white,
                            textContainerInset: Self.editorInset,
                            usesFindBar: false,
                            ownsUndoManager: true,
                            highlighting: formatSettings.highlighting(for: model.dataType.structured)) { view in
                // Same point size as the editor's own font, so it does not put
                // the proportional font back when the view updates.
                view.font = .monospacedSystemFont(ofSize: Self.fontSize, weight: .regular)
                view.insertionPointColor = .white
                editor.view = view
                DispatchQueue.main.async { focusEditor() }
            }
            .opacity(model.isPreviewing ? 0 : 1)
            .allowsHitTesting(!model.isPreviewing)
            .accessibilityHidden(model.isPreviewing)
            if model.isPreviewing {
                MarkdownPreview(blocks: ScratchpadSupport.markdownPreview(model.draft),
                                baseSize: Self.fontSize)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .modifier(NotchControlSurface(cornerRadius: 12, interactive: false))
    }

    // MARK: - Actions

    private func togglePreview() {
        flushComposition()
        closeFindQuietly()
        withAnimation(.easeOut(duration: 0.15)) { model.isPreviewing.toggle() }
        if !model.isPreviewing { DispatchQueue.main.async { focusEditor() } }
    }

    /// Only pinned clipboards keep their type; the rest of the history comes and goes.
    private func rememberType(_ type: ClipboardEditorModel.DataType) {
        guard let id = selectedPinnedID else { return }
        TextEditorTypeStore.save(TextEditorTypeStore.updated(
            TextEditorTypeStore.load(), setting: type.rawValue, for: id,
            keeping: Set(pinned.map(\.id))))
    }

    private func switchTo(_ entry: ClipboardHistoryEntry) {
        guard entry.id != selectedPinnedID else { return }
        flushComposition()
        model.commit(to: history) { outcome in
            if outcome == .failed { NSSound.beep() }
        }
        onSwitch(entry)
    }

    // MARK: - Actions

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

    private func closeFindQuietly() {
        showFind = false
        showReplace = false
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
