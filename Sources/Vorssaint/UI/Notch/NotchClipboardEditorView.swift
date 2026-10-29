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
    @State private var preview = EditorHandle()
    @State private var showFind = false
    /// The replace row stays out of the way until it is asked for, as in a
    /// code editor: most searches are only searches.
    @State private var showReplace = false
    // Read here so a change in the text editor's settings shows up at once.
    private let formatSettings = TextEditorFormatSettings()
    private var text: ClipboardEditorStrings { FeatureStrings.clipboardEditor(l10n.language) }
    private var padText: ScratchpadFeatureStrings { FeatureStrings.scratchpad(l10n.language) }

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
            // The writing tools are there whenever Markdown is being edited.
            if isMarkdown && !model.isPreviewing {
                ScratchpadFormatBar(style: .island, editor: editor.view,
                                    onApply: { editor.view?.applyMark($0) })
                    .frame(height: Self.barHeight)
            }

            editorSurface

            NotchEditorBottomBar(dataType: $model.dataType,
                                 isPreviewing: model.isPreviewing, isEmpty: model.draft.isEmpty,
                                 textView: { editor.view }, onTogglePreview: togglePreview)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // The way back and the pinned clipboards sit in the island's top row,
        // as the scratchpad's pads do.
        .notchBand(leading: { topBar })
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

    /// In the island's top row: the way back to the history and a menu of the
    /// pinned clipboards to switch to. Find is the keyboard's: Command-F and
    /// Command-R.
    private var topBar: some View {
        HStack(spacing: 6) {
            NotchIconButton(symbol: "list.bullet", title: text.defaultViewHistory) { commitAndLeave() }
            NotchMenuButton(title: text.defaultViewEditor, items: pinnedItems, cornerRadius: 9) {
                NotchBandMenuLabel(title: currentName, symbol: selectedPinnedID == nil ? nil : "pin.fill")
            }
            .disabled(pinned.isEmpty)
        }
    }

    /// The pinned clipboards to switch to, the open one checked. Each reads
    /// as its place among the pins and the start of its text.
    private var pinnedItems: [NotchMenuItem] {
        pinned.enumerated().map { index, entry in
            NotchMenuItem(title: "\(index + 1)  \(preview(of: entry))", checked: entry.id == selectedPinnedID,
                          symbol: "pin.fill") { switchTo(entry) }
        }
    }

    /// What the menu's button reads: the pin's number, or the editor's own
    /// name for what is on the clipboard now.
    private var currentName: String {
        guard let id = selectedPinnedID, let index = pinned.firstIndex(where: { $0.id == id }) else {
            return text.defaultViewEditor
        }
        return "\(index + 1)"
    }

    /// The first line that has anything on it, short enough for a menu.
    private func preview(of entry: ClipboardHistoryEntry) -> String {
        let line = entry.text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty } ?? "…"
        return line.count > 28 ? String(line.prefix(28)) + "…" : line
    }

    private var pinned: [ClipboardHistoryEntry] {
        history.pinnedEntries.filter { $0.kind == .text }
    }

    private var selectedPinnedID: UUID? {
        if case .entry(let id) = model.source { return id }
        return nil
    }

    // MARK: - Text

    private var editorSurface: some View {
        ZStack {
            PlainTextEditor(text: $model.draft,
                            fontSize: Self.fontSize,
                            textColor: .white,
                            textContainerInset: Self.editorInset,
                            usesFindBar: false,
                            topContentInset: topInset,
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
                                baseSize: Self.fontSize,
                                taskStates: (done: padText.taskDone, notDone: padText.taskNotDone),
                                onToggleTask: toggleTask,
                                topContentInset: topInset,
                                onCreate: { preview.view = $0 })
            }
            // Over the text, whatever the text view does with its layers.
            findBar
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .zIndex(10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .modifier(NotchControlSurface(cornerRadius: 12, interactive: false))
    }

    /// The find bar floats over the top right of the text, as in a code
    /// editor, and the text gets room above it instead of shrinking.
    @ViewBuilder
    private var findBar: some View {
        if showFind {
            NotchFindReplaceBar(textView: { model.isPreviewing ? preview.view : editor.view },
                                text: model.isPreviewing ? (preview.view?.string ?? "") : model.draft,
                                showReplace: $showReplace, allowsReplace: !model.isPreviewing,
                                onClose: closeFind)
                .frame(maxWidth: 420)
                .padding(6)
        }
    }

    /// Room above the text for the find bar while it is showing.
    private var topInset: CGFloat {
        showFind ? NotchFindReplaceBar.floatingHeight(showingReplace: showReplace && !model.isPreviewing) : 0
    }

    // MARK: - Actions

    /// A checkbox clicked in the preview flips its box through the text view,
    /// as one edit that undo takes back, the way the scratchpad does.
    private func toggleTask(box: Int) {
        guard let view = editor.view else { return }
        if view.hasMarkedText() { view.unmarkText() }
        guard let edit = ScratchpadSupport.taskToggleEdit(box: box, in: view.string) else { return }
        view.breakUndoCoalescing()
        guard view.shouldChangeText(in: edit.range, replacementString: edit.replacement) else { return }
        view.replaceCharacters(in: edit.range, with: edit.replacement)
        view.didChangeText()
    }

    private func togglePreview() {
        flushComposition()
        // A preview is searched but not replaced in.
        showReplace = false
        withAnimation(.easeOut(duration: 0.15)) { model.isPreviewing.toggle() }
        if !model.isPreviewing && !showFind { DispatchQueue.main.async { focusEditor() } }
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
        // A preview has no replace row, so this is only the find bar.
        if model.isPreviewing {
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
        if let view = editor.view, view.hasMarkedText() { view.unmarkText() }
    }

    /// The caret starts at the top, where the beginning of the data is.
    private func focusEditor() {
        guard !model.isPreviewing, let view = editor.view, let window = view.window, window.isKeyWindow else { return }
        window.makeFirstResponder(view)
    }
}
