//
//  NotchFindReplaceBar.swift
//  Vorssaint
//
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// Find and replace for a text view in the island, with the two things the
/// system find bar does not have: regular expressions (with `$1` capture
/// groups in the replacement) and a match count that follows the typing.
///
/// The search itself is `TextToolsSupport`; this view only collects the
/// settings and moves the selection. Replace all goes through the text view,
/// so Command-Z takes it back. It reads the text view when a button is
/// pressed rather than holding it, since the editor owns the view.
struct NotchFindReplaceBar: View {
    /// The editor's text view, asked for when a button is pressed.
    let textView: () -> NSTextView?
    /// The editor's text as it is now, so the count follows what is typed.
    let text: String
    /// Whether the replace row is showing. The owner holds it so a shortcut
    /// can show or hide it along with the bar.
    @Binding var showReplace: Bool
    /// A request from outside to step to the next or previous match, as the
    /// owner's Command-G does. A new serial is a new request.
    var stepRequest: FindStepRequest?
    /// Esc inside either field: the owner puts the bar away.
    let onClose: () -> Void

    @ObservedObject private var l10n = L10n.shared
    @State private var find = ""
    @State private var replacement = ""
    @State private var isRegex = false
    @State private var caseSensitive = false
    @State private var count: Result<Int, TextToolsSupport.ReplaceFailure>?
    /// What the last replace did; cleared when the search changes.
    @State private var replacedNote: String?
    @FocusState private var findFocused: Bool
    private var strings: TextToolsStrings { FeatureStrings.textTools(l10n.language) }

    private var options: TextToolsSupport.ReplaceOptions {
        TextToolsSupport.ReplaceOptions(isRegex: isRegex, caseSensitive: caseSensitive)
    }

    /// Everything the count depends on, so it is recomputed (after a short
    /// pause) when any of it changes.
    private struct CountKey: Equatable {
        let find: String
        let text: String
        let isRegex: Bool
        let caseSensitive: Bool
    }

    /// The room a floating bar takes, with the margin around it: what the
    /// text above is moved down by. The rows are a fixed height, so this is
    /// known without measuring the bar after it is up.
    static func floatingHeight(showingReplace: Bool) -> CGFloat {
        let row: CGFloat = 22
        let bar = 4 + row + (showingReplace ? 3 + row : 0) + 4
        return bar + 12
    }

    var body: some View {
        VStack(spacing: 3) {
            HStack(spacing: 4) {
                Button {
                    showReplace.toggle()
                    if !showReplace { findFocused = true }
                } label: {
                    Image(systemName: showReplace ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.55))
                        .frame(width: 14, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(strings.replace)
                .accessibilityLabel(strings.replace)
                .accessibilityAddTraits(showReplace ? .isSelected : [])
                TextField(strings.find, text: $find)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, design: .monospaced))
                    .focused($findFocused)
                    .frame(minWidth: 70)
                    .onSubmit { step(backwards: NSEvent.modifierFlags.contains(.shift)) }
                    .onExitCommand(perform: onClose)
                    // Up and Down step through the matches like the buttons do;
                    // in a one-line field they have nothing else to do.
                    .onKeyPress(.upArrow) {
                        step(backwards: true)
                        return .handled
                    }
                    .onKeyPress(.downArrow) {
                        step(backwards: false)
                        return .handled
                    }
                    .accessibilityLabel(strings.find)
                Text(statusText)
                    .font(.system(size: 10))
                    .foregroundStyle(statusIsError ? Color.orange : .white.opacity(0.6))
                    .lineLimit(1)
                NotchIconButton(symbol: "chevron.up", title: strings.previous, size: 22) { step(backwards: true) }
                NotchIconButton(symbol: "chevron.down", title: strings.next, size: 22) { step(backwards: false) }
                NotchIconButton(symbol: "textformat", title: strings.matchCase, selected: caseSensitive, size: 22) {
                    caseSensitive.toggle()
                }
                RegexToggle(title: strings.regex, isOn: $isRegex)
            }
            if showReplace {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.turn.down.right")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .frame(width: 14)
                    TextField(strings.replace, text: $replacement)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11, design: .monospaced))
                        .onSubmit(replaceOne)
                        .onExitCommand(perform: onClose)
                        .accessibilityLabel(strings.replace)
                    replaceButton("arrowshape.turn.up.left", title: strings.replace, action: replaceOne)
                    replaceButton("arrowshape.turn.up.left.2", title: strings.replaceAll, action: replaceAll)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        // Nearly opaque black under the glass, like the island, so the text
        // never shows through the bar.
        .background(Color.black.opacity(0.97), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .modifier(NotchControlSurface(cornerRadius: 11))
        // The grey of a selected tab.
        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
            .strokeBorder(.white.opacity(0.14), lineWidth: 1))
        .onAppear {
            prefillFromSelection()
            focusFindField()
        }
        .onChange(of: stepRequest) { _, request in
            guard let request else { return }
            step(backwards: request.backwards)
        }
        .onChange(of: find) { _, _ in replacedNote = nil }
        .onChange(of: isRegex) { _, _ in replacedNote = nil }
        .onChange(of: caseSensitive) { _, _ in replacedNote = nil }
        .task(id: CountKey(find: find, text: text, isRegex: isRegex, caseSensitive: caseSensitive)) {
            await refreshCount()
        }
    }

    // MARK: - Status

    private var statusIsError: Bool {
        if case .failure(.invalidPattern) = count { return true }
        return false
    }

    private var statusText: String {
        if let replacedNote { return replacedNote }
        guard !find.isEmpty, let count else { return "" }
        switch count {
        case .success(0): return strings.noMatches
        case .success(let number): return "\(strings.matches): \(number)"
        case .failure(.invalidPattern): return strings.invalidPattern
        case .failure: return ""
        }
    }

    /// Counting runs off the main thread after a short pause, so typing in a
    /// large clipboard stays smooth and a slow pattern cannot freeze the island.
    private func refreshCount() async {
        guard !find.isEmpty else {
            count = nil
            return
        }
        try? await Task.sleep(for: .milliseconds(150))
        guard !Task.isCancelled else { return }
        let (text, find, options) = (text, find, options)
        let result = await Task.detached(priority: .userInitiated) {
            TextToolsSupport.matchCount(in: text, find: find, options: options)
        }.value
        guard !Task.isCancelled else { return }
        count = result
    }

    // MARK: - Actions

    /// The bar usually appears while the text view holds the keyboard. Asking
    /// for focus in the same pass that creates the field does not take it
    /// from the text view, so the request waits for the field to exist.
    private func focusFindField() {
        DispatchQueue.main.async {
            textView()?.window?.makeFirstResponder(nil)
            findFocused = true
        }
    }

    /// A short single-line selection becomes the search, as in any find bar.
    private func prefillFromSelection() {
        guard find.isEmpty, let view = textView() else { return }
        let range = view.selectedRange()
        guard range.length > 0, range.length <= 200,
              let swiftRange = Range(range, in: view.string) else { return }
        let selected = String(view.string[swiftRange])
        if !selected.contains("\n") { find = selected }
    }

    /// Selects the next (or previous) match and scrolls to it.
    private func step(backwards: Bool) {
        guard !find.isEmpty, let view = textView() else { return }
        let selection = view.selectedRange()
        let from = backwards ? selection.location : NSMaxRange(selection)
        switch TextToolsSupport.nextMatch(in: view.string, find: find, from: from,
                                          backwards: backwards, options: options) {
        case .success(let range?):
            view.setSelectedRange(range)
            view.scrollRangeToVisible(range)
            if range.length > 0 { view.showFindIndicator(for: range) }
        case .success(nil), .failure:
            NSSound.beep()
        }
    }

    /// Replaces the selected match and moves on to the next one. When the
    /// selection is not a match yet, it only goes to the next match, so the
    /// first press shows what is about to change.
    private func replaceOne() {
        guard !find.isEmpty, let view = textView() else { return }
        let selection = view.selectedRange()
        switch TextToolsSupport.replacement(in: view.string, find: find, with: replacement,
                                            at: selection, options: options) {
        case .success(let text?):
            view.replaceText(in: selection, with: text)
            replacedNote = nil
            // The next match, if any; running out is not an error here.
            let caret = view.selectedRange().location
            if case .success(let range?) = TextToolsSupport.nextMatch(in: view.string, find: find, from: caret,
                                                                      options: options) {
                view.setSelectedRange(range)
                view.scrollRangeToVisible(range)
                if range.length > 0 { view.showFindIndicator(for: range) }
            }
        case .success(nil):
            step(backwards: false)
        case .failure:
            NSSound.beep()
        }
    }

    /// An icon button like the ones in the search row; the words are the
    /// tooltip and the accessibility label.
    private func replaceButton(_ symbol: String, title: String, action: @escaping () -> Void) -> some View {
        NotchIconButton(symbol: symbol, title: title, size: 22, action: action)
            .disabled(find.isEmpty)
            .opacity(find.isEmpty ? 0.4 : 1)
    }

    private func replaceAll() {
        guard !find.isEmpty, let view = textView() else { return }
        switch TextToolsSupport.replaceAll(in: view.string, find: find, with: replacement, options: options) {
        case .success(let result) where result.count > 0:
            if result.text != view.string { view.replaceAllText(with: result.text) }
            replacedNote = "\(strings.replaced): \(result.count)"
        case .success, .failure:
            NSSound.beep()
        }
    }
}

/// One request to step through the matches. Equal requests are the same
/// request, so the owner bumps `serial` to ask again.
struct FindStepRequest: Equatable {
    let serial: Int
    let backwards: Bool
}

/// A `.*` button in the same square as the island's icon buttons.
private struct RegexToggle: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Button { isOn.toggle() } label: {
            Text(".*")
                .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                .foregroundStyle(isOn ? .white : .white.opacity(0.55))
                .frame(width: 22, height: 22)
                .background(.white.opacity(isOn ? 0.12 : 0),
                            in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(NotchButtonStyle(cornerRadius: 7))
        .help(title)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
