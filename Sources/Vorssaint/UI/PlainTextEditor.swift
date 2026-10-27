// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// An AppKit text view configured as a pure plain-text surface: no smart
/// quotes or dashes, no substitutions, no rich paste, with undo. SwiftUI's
/// editor cannot switch all of that off, and its TextEditor(text:selection:)
/// would cover the caret tracking below but needs macOS 15, a version past
/// this app's floor.
struct PlainTextEditor: NSViewRepresentable {
    /// Both shared with callers that overlay their own text on the editor,
    /// so a placeholder can be positioned from the same numbers as the
    /// first line rather than from literals that drift apart.
    /// `lineFragmentPadding` sits inside the inset and is set on the text
    /// container below rather than assumed, so this stays the source of
    /// the number instead of a copy of AppKit's default.
    static let defaultFontSize: CGFloat = 13
    static let lineFragmentPadding: CGFloat = 5

    /// The point size this editor draws at. Callers that overlay their own
    /// text pass the same number rather than the default, or the placeholder
    /// stops sitting on the first line as soon as the size is changed.
    var fontSize: CGFloat = PlainTextEditor.defaultFontSize

    /// Whether the keyboard is in a find bar's search field rather than in
    /// the text it searches, so Esc can put the search away before the pad.
    static func findBarHasKeyboard(in window: NSWindow?) -> Bool {
        guard let field = window?.firstResponder as? NSTextView, field.isFieldEditor,
              let control = field.delegate as? NSView else { return false }
        return sequence(first: control, next: \.superview).contains { view in
            guard let bar = (view as? NSScrollView)?.findBarView else { return false }
            return control.isDescendant(of: bar)
        }
    }

    @Binding var text: String
    /// Character offsets rather than String.Index: an index computed
    /// against one version of the text is undefined behavior to read back
    /// against another, and this binding outlives the edit that produced
    /// it. Offsets can simply be clamped by whoever reads them.
    var selectedRange: Binding<Range<Int>?>?
    /// Appearance is applied when the view is made, not on update, so
    /// these are configuration rather than state: a caller that derives
    /// one from something that changes will not see it re-applied.
    var textColor: NSColor?
    var textContainerInset: NSSize?
    /// Turns on AppKit's own find bar: the real Command-F, with its counter,
    /// its highlighting and Command-G, none of which is worth rewriting.
    var usesFindBar = false
    /// Gives this editor an undo history of its own, discarded with the editor.
    /// By default a text view uses its window's undo manager, which every text
    /// view in that window shares and which outlives them: an entry left by a
    /// text view that has since been freed is still on that stack, and undoing
    /// into it crashes. A view that is created and destroyed as pages change,
    /// like the island's, should not share one.
    var ownsUndoManager = false
    /// Colors parts of the text: the ranges to color and the color of each,
    /// asked for after every change. The text itself is untouched (colors are
    /// attributes, which neither the binding nor undo ever sees), and
    /// everything outside the ranges keeps the editor's text color.
    ///
    /// A struct rather than a bare closure, so a trailing closure at a call
    /// site still means `onCreate`.
    struct Highlighting {
        /// Names what `spans` was built from. The text is colored again when
        /// this changes without the text changing, as when a setting turns
        /// colors on or off; a closure cannot be compared, so the caller says.
        let id: String
        let spans: (String) -> [(range: NSRange, color: NSColor)]
    }
    var highlighting: Highlighting?
    /// Room kept above the text, inside the scroll view, for something floating
    /// over it (a find bar). The text starts below it when scrolled to the top
    /// and scrolls up under it, and the text does not move when this changes
    /// unless it was at the top.
    var topContentInset: CGFloat = 0
    /// Handed the text view once, for callers that need to reach it later.
    var onCreate: ((NSTextView) -> Void)?

    init(text: Binding<String>,
         fontSize: CGFloat = PlainTextEditor.defaultFontSize,
         selectedRange: Binding<Range<Int>?>? = nil,
         textColor: NSColor? = nil,
         textContainerInset: NSSize? = nil,
         usesFindBar: Bool = false,
         topContentInset: CGFloat = 0,
         ownsUndoManager: Bool = false,
         highlighting: Highlighting? = nil,
         onCreate: ((NSTextView) -> Void)? = nil) {
        self._text = text
        self.fontSize = fontSize
        self.selectedRange = selectedRange
        self.textColor = textColor
        self.textContainerInset = textContainerInset
        self.usesFindBar = usesFindBar
        self.topContentInset = topContentInset
        self.ownsUndoManager = ownsUndoManager
        self.highlighting = highlighting
        self.onCreate = onCreate
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        guard let textView = scroll.documentView as? NSTextView else { return scroll }
        applyTopContentInset(to: scroll)
        textView.drawsBackground = false
        textView.font = .systemFont(ofSize: fontSize)
        textView.textContainer?.lineFragmentPadding = Self.lineFragmentPadding
        textView.allowsUndo = true
        textView.isRichText = false
        textView.importsGraphics = false
        textView.usesFontPanel = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isAutomaticDataDetectionEnabled = false
        textView.smartInsertDeleteEnabled = false
        if usesFindBar {
            textView.usesFindBar = true
            textView.isIncrementalSearchingEnabled = true
        }
        if let textColor {
            textView.textColor = textColor
        }
        if let textContainerInset {
            textView.textContainerInset = textContainerInset
        }
        textView.string = text
        context.coordinator.baseColor = textColor ?? .labelColor
        context.coordinator.highlighting = highlighting
        context.coordinator.applyHighlighting(to: textView)
        // Delegate last: assigning .string posts a selection notification
        // synchronously, and makeNSView runs inside SwiftUI's update pass,
        // where writing state is undefined behavior.
        textView.delegate = context.coordinator
        onCreate?(textView)
        return scroll
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        // Size is a preference and can change under a view that is already up,
        // so it is applied before the text guard below rather than after it.
        if textView.font?.pointSize != fontSize {
            textView.font = .systemFont(ofSize: fontSize)
        }
        applyTopContentInset(to: nsView)
        let coordinator = context.coordinator
        let highlightChanged = coordinator.highlighting?.id != highlighting?.id
        coordinator.highlighting = highlighting
        guard textView.string != text, !textView.hasMarkedText() else {
            if highlightChanged { coordinator.applyHighlighting(to: textView) }
            return
        }
        // Setting .string posts a selection notification, and answering it
        // here would write state from inside a view update.
        context.coordinator.isApplyingExternalText = true
        textView.string = text
        context.coordinator.isApplyingExternalText = false
        // Programmatic replaces (load, retention, restore) invalidate undo
        // entries recorded against the old storage; replaying one would
        // resurrect cleared text or throw a range exception.
        textView.undoManager?.removeAllActions()
        coordinator.applyHighlighting(to: textView)
    }

    /// The room above the text is the scroll view's own inset, so the text
    /// can scroll up under whatever floats there. Only a view that is at the top
    /// follows the change; one scrolled down keeps its text where it is.
    private func applyTopContentInset(to scroll: NSScrollView) {
        guard scroll.contentInsets.top != topContentInset || scroll.automaticallyAdjustsContentInsets else { return }
        let clip = scroll.contentView
        let old = scroll.contentInsets.top
        let before = clip.bounds.origin
        let wasAtTop = before.y <= -old + 0.5
        scroll.automaticallyAdjustsContentInsets = false
        scroll.contentInsets = NSEdgeInsets(top: topContentInset, left: 0, bottom: 0, right: 0)
        // Changing the inset moves the scroll position along with it, which
        // would push the text down. At the top that is wanted; anywhere else
        // the position is put back so the text stays where it was.
        clip.scroll(to: wasAtTop ? NSPoint(x: before.x, y: -topContentInset) : before)
        scroll.reflectScrolledClipView(clip)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, selectedRange: selectedRange, ownsUndoManager: ownsUndoManager)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        private let text: Binding<String>
        private let selectedRange: Binding<Range<Int>?>?
        var isApplyingExternalText = false
        /// What the text is drawn in outside any colored range.
        var baseColor: NSColor = .labelColor
        var highlighting: PlainTextEditor.Highlighting?
        /// Whether colors are on the text now, so turning them off puts the
        /// base color back and an editor that never colors does no work.
        private var isColored = false
        /// Nil unless the editor asked for its own history. The coordinator
        /// lives exactly as long as the editor, so the history goes with it.
        private let ownUndoManager: UndoManager?

        init(text: Binding<String>, selectedRange: Binding<Range<Int>?>?, ownsUndoManager: Bool) {
            self.text = text
            self.selectedRange = selectedRange
            self.ownUndoManager = ownsUndoManager ? UndoManager() : nil
        }

        /// NSTextView asks its delegate first. An editor that did not ask for
        /// its own history is handed the window's, which is what it used before
        /// this method existed.
        func undoManager(for view: NSTextView) -> UndoManager? {
            ownUndoManager ?? view.window?.undoManager
        }

        func textDidChange(_ notification: Notification) {
            guard !isApplyingExternalText, let textView = notification.object as? NSTextView else { return }
            let current = textView.string
            if text.wrappedValue != current { text.wrappedValue = current }
            publishSelection(of: textView, in: current)
            applyHighlighting(to: textView)
        }

        /// Colors the text as the highlighting says, or clears the colors.
        /// Only attributes change, outside the editing path, so this is not an
        /// edit: no change notification, nothing on the undo stack.
        func applyHighlighting(to textView: NSTextView) {
            guard let storage = textView.textStorage else { return }
            guard let highlighting else {
                if isColored {
                    storage.addAttribute(.foregroundColor, value: baseColor,
                                         range: NSRange(location: 0, length: storage.length))
                    isColored = false
                }
                return
            }
            let length = storage.length
            storage.beginEditing()
            storage.addAttribute(.foregroundColor, value: baseColor, range: NSRange(location: 0, length: length))
            for span in highlighting.spans(textView.string) where NSMaxRange(span.range) <= length {
                storage.addAttribute(.foregroundColor, value: span.color, range: span.range)
            }
            storage.endEditing()
            isColored = true
        }

        /// Publishes the caret only. Never writes the text binding: a caret
        /// move would then republish whatever the view currently holds,
        /// which for a caller that reloads its text out-of-band means
        /// writing stale content back over the fresh content.
        func textViewDidChangeSelection(_ notification: Notification) {
            guard !isApplyingExternalText,
                  selectedRange != nil,
                  let textView = notification.object as? NSTextView else { return }
            publishSelection(of: textView, in: textView.string)
        }

        private func publishSelection(of textView: NSTextView, in current: String) {
            guard let selectedRange else { return }
            // A selection that will not convert leaves the last known caret
            // alone, since nil here would read as "caret at the end".
            guard let converted = Range(textView.selectedRange(), in: current) else { return }
            selectedRange.wrappedValue =
                current.distance(from: current.startIndex, to: converted.lowerBound)
                    ..< current.distance(from: current.startIndex, to: converted.upperBound)
        }
    }
}
