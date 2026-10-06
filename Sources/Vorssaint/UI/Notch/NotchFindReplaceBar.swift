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
    /// Esc inside either field: the owner puts the bar away.
    let onClose: () -> Void

    @ObservedObject private var l10n = L10n.shared
    @State private var find = ""
    @State private var replacement = ""
    @State private var isRegex = false
    @State private var caseSensitive = false
    /// The replace row stays out of the way until it is asked for, as in a
    /// code editor: most searches are only searches.
    @State private var showReplace = false
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

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Button {
                    showReplace.toggle()
                    if !showReplace { findFocused = true }
                } label: {
                    Image(systemName: showReplace ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.55))
                        .frame(width: 16, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(strings.replace)
                .accessibilityLabel(strings.replace)
                .accessibilityAddTraits(showReplace ? .isSelected : [])
                TextField(strings.find, text: $find)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .monospaced))
                    .focused($findFocused)
                    .onSubmit { step(backwards: NSEvent.modifierFlags.contains(.shift)) }
                    .onExitCommand(perform: onClose)
                    .accessibilityLabel(strings.find)
                Text(statusText)
                    .font(.system(size: 10.5))
                    .foregroundStyle(statusIsError ? Color.orange : .white.opacity(0.6))
                    .lineLimit(1)
                NotchIconButton(symbol: "chevron.up", title: strings.previous) { step(backwards: true) }
                NotchIconButton(symbol: "chevron.down", title: strings.next) { step(backwards: false) }
                NotchIconButton(symbol: "textformat", title: strings.matchCase, selected: caseSensitive) {
                    caseSensitive.toggle()
                }
                RegexToggle(title: strings.regex, isOn: $isRegex)
            }
            if showReplace {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.turn.down.right")
                        .foregroundStyle(.secondary)
                        .frame(width: 16)
                    TextField(strings.replace, text: $replacement)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, design: .monospaced))
                        .onSubmit(replaceAll)
                        .onExitCommand(perform: onClose)
                        .accessibilityLabel(strings.replace)
                    Button(action: replaceAll) {
                        Text(strings.replaceAll)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(find.isEmpty ? 0.35 : 0.85))
                            .padding(.horizontal, 10)
                            .frame(height: 24)
                            .background(.white.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(find.isEmpty)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .modifier(NotchControlSurface(cornerRadius: 14))
        .onAppear {
            prefillFromSelection()
            findFocused = true
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

/// A `.*` button in the same square as the island's icon buttons.
private struct RegexToggle: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Button { isOn.toggle() } label: {
            Text(".*")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(isOn ? .white : .white.opacity(0.55))
                .frame(width: 28, height: 28)
                .background(.white.opacity(isOn ? 0.12 : 0),
                            in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(NotchButtonStyle(cornerRadius: 9))
        .help(title)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
