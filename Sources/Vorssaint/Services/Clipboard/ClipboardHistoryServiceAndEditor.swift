//
//  ClipboardHistoryServiceAndEditor..swift
//  Vorssaint
//
//  Created by Christian Gonzalez on 9/30/26.
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit

/// The service already has exactly these members, so the conformance is empty.
/// It lives in its own file because the model's file is also compiled by the
/// test build, which does not include the service.
extension ClipboardHistoryService: ClipboardEditorHistory {}

extension ClipboardHistoryService {
    /// The text on the clipboard right now, for the editor to open on.
    ///
    /// Read the way the history reads it: on the shared pasteboard lane, never
    /// blocking the main thread, and never when the app that copied it marked
    /// it as a secret (what password managers do), so a copied password is not
    /// put on screen. Nil when there is no text, or the read did not finish in
    /// time; the editor then opens empty. The completion runs on the main queue.
    static func readLiveClipboardText(completion: @escaping (String?) -> Void) {
        GeneralPasteboardAccess.shared.async(timeout: 2, { isExpired -> String? in
            let pasteboard = NSPasteboard.general
            guard !ClipboardHistorySensitiveText.isConcealed((pasteboard.types ?? []).map(\.rawValue)),
                  !isExpired()
            else { return nil }
            return ClipboardHistoryPasteboardText.preferredText(webURLString: nil,
                                                                plainText: pasteboard.string(forType: .string))
        }, then: completion)
    }
}
