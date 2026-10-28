// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// The scratchpad's document inside the island: the editor or its formatted
/// reading fills the page, and the island's top row holds the pads: their tabs
/// in a row that scrolls, with a button for a new one after them. The chosen
/// tab opens a menu of what a pad can do. The same editor as the clipboard's
/// sits under it, with the type of the text and what goes with it on the bar
/// below. Everything the floating pad does, at the island's size: tabs close
/// from their own cross, Command-T and Command-W work, a new or chosen pad
/// puts the caret in its text, and a cleared pad comes back with one undo.
struct NotchScratchpadView: View {
    @ObservedObject var service: NotchService
    @ObservedObject private var pad = ScratchpadService.shared
    @ObservedObject private var l10n = L10n.shared
    @State private var loadFailed = false
    @State private var copied = false
    @State private var hoveredPadID: UUID?
    @State private var editor = EditorHandle()
    @State private var preview = EditorHandle()
    @State private var showFind = false
    @State private var showReplace = false
    @State private var findStep: FindStepRequest?
    /// The type each pad's text is, as chosen under the editor, kept between
    /// launches. Pads start on Text.
    @State private var types: [String: String] = TextEditorTypeStore.load()
    private let formatSettings = TextEditorFormatSettings()
    @AppStorage(DefaultsKey.scratchpadTextSize) private var storedTextSize = ScratchpadSupport.defaultTextSize
    private var text: ScratchpadFeatureStrings { FeatureStrings.scratchpad(l10n.language) }
    private var textSize: CGFloat { CGFloat(ScratchpadSupport.sanitizedTextSize(storedTextSize)) }
    private static let editorInset = NSSize(width: 6, height: 6)

    /// Holds the editor's text view so a tab change can aim the caret at it
    /// and a clear can go through its undo. Weak, since the view belongs to
    /// the editor.
    private final class EditorHandle {
        weak var view: NSTextView?
    }

    private var currentType: ClipboardEditorModel.DataType {
        pad.selectedPadID
            .flatMap { TextEditorTypeStore.rawType(for: $0, in: types) }
            .flatMap(ClipboardEditorModel.DataType.init(rawValue:)) ?? .text
    }

    private var dataType: Binding<ClipboardEditorModel.DataType> {
        Binding(get: { currentType },
                set: { type in
                    guard let id = pad.selectedPadID else { return }
                    types = TextEditorTypeStore.updated(types, setting: type.rawValue, for: id,
                                                        keeping: Set(pad.pads.map(\.id)))
                    TextEditorTypeStore.save(types)
                })
    }

    private var selectedPad: ScratchpadPad? { pad.pads.first { $0.id == pad.selectedPadID } }

    var body: some View {
        Group {
            if loadFailed {
                NotchEmptyView(symbol: "exclamationmark.triangle", message: text.loadFailed)
            } else {
                VStack(spacing: 6) {
                    if pad.saveFailed {
                        Label(text.saveFailed, systemImage: "exclamationmark.triangle")
                            .font(.system(size: 10.5)).foregroundStyle(.white.opacity(0.6))
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    // The writing tools get a row of their own above the text,
                    // whenever Markdown is being edited.
                    if currentType == .markdown && !pad.isPreviewing {
                        markRow
                    }
                    editorSurface
                    NotchEditorBottomBar(dataType: dataType,
                                         isPreviewing: pad.isPreviewing, isEmpty: pad.text.isEmpty,
                                         textView: { editor.view }, onTogglePreview: pad.togglePreview)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .notchBand(leading: {
            if !loadFailed { padControls }
        }, trailing: {
            if !loadFailed { noteActions }
        })
        // Command-R is a button of its own: the island answers Command-F and
        // Command-G itself (through the serial below) and never sees this one.
        .background {
            Button(action: toggleFindAndReplace) { EmptyView() }
                .keyboardShortcut("r", modifiers: .command)
                .opacity(0)
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
        }
        // Leaving Markdown puts its tools and preview away.
        .onChange(of: currentType) { _, type in
            guard type != .markdown else { return }
            if pad.isPreviewing { pad.togglePreview() }
        }
        .onAppear {
            loadFailed = !pad.loadForEmbedding()
            openMarkdownPreview()
        }
        .onDisappear { pad.commitEdits() }
        .onChange(of: pad.selectedPadID) { _, _ in
            DispatchQueue.main.async {
                if !openMarkdownPreview() { focusEditor() }
            }
        }
        .onChange(of: pad.isPreviewing) { _, previewing in
            guard let view = editor.view else { return }
            if previewing {
                // A preview is searched but not replaced in.
                showReplace = false
                if view.window?.firstResponder === view {
                    view.window?.makeFirstResponder(nil)
                }
            } else {
                DispatchQueue.main.async {
                    // Preview took the keyboard, so a text without it now was
                    // not given it by Command-F on its way out of preview.
                    guard !showFind, view.window?.firstResponder !== view else { return }
                    focusEditor()
                }
            }
        }
        .onChange(of: service.scratchpadCloseSerial) { _, _ in
            guard let selectedPad else { return }
            requestClose(selectedPad)
        }
        .onChange(of: service.scratchpadFindSerial) { _, _ in
            handleFind(service.scratchpadFindAction)
        }
        .task(id: copied) {
            guard copied else { return }
            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled else { return }
            copied = false
        }
    }

    /// The find bar floats over the top right of the text, as in a code
    /// editor, and the text gets room above it instead of shrinking.
    @ViewBuilder
    private var findBar: some View {
        if showFind {
            NotchFindReplaceBar(textView: { pad.isPreviewing ? preview.view : editor.view },
                                text: pad.isPreviewing ? (preview.view?.string ?? "") : pad.text,
                                showReplace: $showReplace, allowsReplace: !pad.isPreviewing,
                                stepRequest: findStep, onClose: closeFind)
                .frame(maxWidth: 420)
                .padding(6)
        }
    }

    /// Room above the text for the find bar while it is showing.
    private var topInset: CGFloat {
        showFind ? NotchFindReplaceBar.floatingHeight(showingReplace: showReplace && !pad.isPreviewing) : 0
    }

    private var editorSurface: some View {
        ZStack(alignment: .topLeading) {
            PlainTextEditor(text: $pad.text, fontSize: textSize,
                            textColor: .white,
                            textContainerInset: Self.editorInset,
                            usesFindBar: false,
                            completesTaskBoxes: true,
                            continuesLists: true,
                            onCommandReturn: { pad.togglePreview() },
                            isActive: !pad.isPreviewing,
                            topContentInset: topInset,
                            ownsUndoManager: true,
                            highlighting: formatSettings.highlighting(for: currentType.structured)) { view in
                view.insertionPointColor = .white
                editor.view = view
                DispatchQueue.main.async { focusEditor() }
            }
            .opacity(pad.isPreviewing ? 0 : 1)
            .allowsHitTesting(!pad.isPreviewing)
            .accessibilityHidden(pad.isPreviewing)
            if pad.isPreviewing {
                MarkdownPreview(blocks: ScratchpadSupport.markdownPreview(pad.text),
                                baseSize: textSize,
                                taskStates: (done: text.taskDone, notDone: text.taskNotDone),
                                onToggleTask: { pad.toggleTask(box: $0, through: editor.view) },
                                topContentInset: topInset,
                                onCreate: { preview.view = $0 })
            } else if pad.text.isEmpty {
                Text(text.placeholder)
                    .font(.system(size: textSize))
                    .foregroundStyle(.white.opacity(0.35))
                    .padding(.leading, Self.editorInset.width + PlainTextEditor.lineFragmentPadding)
                    .padding(.top, Self.editorInset.height + topInset)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            // Over the text, whatever the text view does with its layers.
            findBar
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .zIndex(10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .modifier(NotchControlSurface(cornerRadius: 12, interactive: false))
    }

    private var tabStrip: some View {
        NotchChipStrip(items: pad.pads, selectedID: pad.selectedPadID) { tab($0) }
    }

    private var tabStrip: some View {
        NotchChipStrip(items: pad.pads, selectedID: pad.selectedPadID) { tab($0) }
    }

    private var markRow: some View {
        ScratchpadFormatBar(style: .island, editor: editor.view)
            .frame(height: 28)
    }

    /// The pads' tabs in a row that scrolls, as in the clipboard, with the
    /// button for a new pad always after them. The chosen tab opens the menu of
    /// what a pad can do.
    private var padControls: some View {
        HStack(spacing: 6) {
            tabStrip
            NotchIconButton(symbol: "plus", title: newPadTitle) {
                pad.createPad(defaultName: text.pageTitle)
            }
            .disabled(!pad.canCreatePad)
        }
    }

    /// The preview and the writing tools live with the editor, under and over
    /// the text, so the row keeps only the copy.
    private var noteActions: some View {
        NotchIconButton(symbol: copied ? "checkmark" : "doc.on.doc", title: copied ? text.copied : text.copyAll) {
            pad.copyAll()
            copied = true
        }
        .disabled(pad.text.isEmpty)
    }

    private var newPadTitle: String {
        pad.canCreatePad ? text.newPad : String(format: text.padLimitFormat, ScratchpadDocument.maximumPadCount)
    }

    /// The pads, where the row shows only the chosen one, then what a pad
    /// can do, each with the confirmation or dialog it always had.
    private func padItems(listsPads: Bool) -> [NotchMenuItem] {
        let current = selectedPad
        var items: [NotchMenuItem] = []
        if listsPads, !pad.pads.isEmpty {
            items = pad.pads.map { entry in
                NotchMenuItem(title: entry.name, checked: entry.id == pad.selectedPadID) { pad.selectPad(entry.id) }
            }
            items.append(.separator)
        }
        items += [
            NotchMenuItem(title: newPadTitle, enabled: pad.canCreatePad) { pad.createPad(defaultName: text.pageTitle) },
            NotchMenuItem(title: text.renamePad, enabled: current != nil) {
                if let current { presentRename(current) }
            },
            NotchMenuItem(title: text.closePad, enabled: current != nil && pad.canClosePad) {
                if let current { requestClose(current) }
            },
            .separator,
            NotchMenuItem(title: text.exportAction, enabled: !pad.text.isEmpty) {
                guard let window = service.presentationWindow else { return }
                let ext = currentType.fileExtension
                pad.exportText(suggestedName: ScratchpadSupport.exportFileName(title: pad.selectedPadName, date: Date(),
                                                                               fileExtension: ext),
                               fileExtension: ext, from: window)
            },
            NotchMenuItem(title: text.clearAction, enabled: !pad.text.isEmpty) { pad.clear(through: editor.view) },
            .separator,
            NotchMenuItem(title: text.openButton) { service.perform { pad.show(allowsIsland: false) } }
        ]
        return items
    }

    /// The chosen tab opens the pad's menu, as the pad's name does beside the
    /// camera. Another tab shows its cross under the pointer, as in the
    /// floating pad, while the strip keeps two pads or more.
    private func tab(_ entry: ScratchpadPad) -> some View {
        let selected = entry.id == pad.selectedPadID
        return Group {
            if selected {
                NotchMenuButton(title: text.padActions, items: padItems(listsPads: false), cornerRadius: 11) {
                    tabLabel(entry, selected: true)
                }
                .accessibilityValue(entry.name)
            } else {
                Button { pad.selectPad(entry.id) } label: { tabLabel(entry, selected: false) }
                    .buttonStyle(NotchButtonStyle(cornerRadius: 11, lifts: false))
            }
        }
        .onHover { hovering in
            if hovering { hoveredPadID = entry.id } else if hoveredPadID == entry.id { hoveredPadID = nil }
        }
        .contextMenu {
            Button(text.renamePad) { presentRename(entry) }
            Button(text.closePad, role: .destructive) { requestClose(entry) }
                .disabled(!pad.canClosePad)
        }
        .accessibilityAddTraits(selected ? .isSelected : [])
        .help(selected ? text.padActions : entry.name)
    }

    private func tabLabel(_ entry: ScratchpadPad, selected: Bool) -> some View {
        let showsClose = !selected && pad.canClosePad && hoveredPadID == entry.id
        return HStack(spacing: 4) {
            Text(entry.name)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
            if selected {
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
            } else if showsClose {
                Button { requestClose(entry) } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(width: 14, height: 14)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(text.closePad)
                .accessibilityLabel(text.closePad)
            }
        }
        .foregroundStyle(selected ? .white : .white.opacity(0.6))
        .padding(.leading, 10)
        .padding(.trailing, showsClose ? 5 : selected ? 8 : 10)
        .frame(height: 22)
        .background(.white.opacity(selected ? 0.14 : 0.05), in: Capsule())
        .contentShape(Capsule())
    }

    // MARK: - Find and text tools

    /// What the island asked for with Command-F or Command-G. A pad in preview
    /// is searched as it reads, without the replace row.
    private func handleFind(_ action: NSTextFinder.Action) {
        switch action {
        case .showFindInterface:
            toggleFind()
        case .nextMatch, .previousMatch:
            if showFind {
                findStep = FindStepRequest(serial: (findStep?.serial ?? 0) + 1,
                                           backwards: action == .previousMatch)
            } else {
                showFind = true
            }
        default:
            break
        }
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
        // A preview has no replace row, so this is only the find bar.
        if pad.isPreviewing {
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

    /// Puts the bar away and gives the keyboard back to the text, leaving the
    /// caret and the last match where they are.
    private func closeFind() {
        showFind = false
        showReplace = false
        DispatchQueue.main.async {
            guard let view = editor.view, let window = view.window, window.isKeyWindow else { return }
            window.makeFirstResponder(view)
        }
    }

    /// A Markdown pad opens as its preview, the way it reads best. Returns
    /// whether it did.
    @discardableResult
    private func openMarkdownPreview() -> Bool {
        guard currentType == .markdown, !pad.isPreviewing, !pad.text.isEmpty else { return false }
        pad.togglePreview()
        return true
    }

    /// The caret lands at the end of the pad's text, as the floating pad
    /// puts it after a tab change.
    private func focusEditor() {
        guard !pad.isPreviewing, let view = editor.view, let window = view.window, window.isKeyWindow else { return }
        window.makeFirstResponder(view)
        let end = NSRange(location: (view.string as NSString).length, length: 0)
        view.setSelectedRange(end)
        view.scrollRangeToVisible(end)
    }

    private func presentRename(_ entry: ScratchpadPad) {
        DispatchQueue.main.async {
            let field = NSTextField(string: entry.name)
            field.frame = NSRect(x: 0, y: 0, width: 240, height: 24)
            let alert = NSAlert()
            alert.messageText = text.renamePad
            alert.accessoryView = field
            alert.addButton(withTitle: text.saveName)
            alert.addButton(withTitle: text.cancel)
            alert.window.initialFirstResponder = field
            guard NotchIslandAlert.run(alert, above: service.presentationWindow) == .alertFirstButtonReturn else { return }
            pad.renamePad(entry.id, to: field.stringValue)
        }
    }

    /// An empty pad goes without asking, like in the floating pad.
    private func requestClose(_ entry: ScratchpadPad) {
        guard pad.canClosePad else { return }
        guard ScratchpadSupport.requiresCloseConfirmation(entry) else { _ = pad.closePad(entry.id); return }
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = text.closePad
            alert.informativeText = String(format: text.deletePadMessageFormat, entry.name)
            alert.addButton(withTitle: text.closePad).hasDestructiveAction = true
            alert.addButton(withTitle: text.cancel)
            guard NotchIslandAlert.run(alert, above: service.presentationWindow) == .alertFirstButtonReturn else { return }
            _ = pad.closePad(entry.id)
        }
    }
}
