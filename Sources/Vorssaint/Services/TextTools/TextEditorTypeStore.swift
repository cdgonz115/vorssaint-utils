//
//  TextEditorTypeStore.swift
//  Vorssaint
//
//  Created by Christian Gonzalez on 10/27/26.
//
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// The type each text was last read as in the island's editors (text, JSON,
/// XML, Markdown), kept per pinned clipboard and per scratchpad tab so a text
/// opens the way it was left.
///
/// Types are kept by the item's id as the raw value of the type. The key is not
/// a registered default and so not part of a settings backup: the ids belong
/// to this Mac's history and pads.
enum TextEditorTypeStore {
    static let defaultsKey = "textEditorTypes"

    /// The stored type of `id`, if any.
    static func rawType(for id: UUID, in stored: [String: String]) -> String? {
        stored[id.uuidString]
    }

    /// `stored` with `id` set to `raw`; Text is the default, so it is dropped
    /// rather than kept. Ids that are not in `keeping` are dropped too, which
    /// stops the store from growing with items that are gone.
    static func updated(_ stored: [String: String], setting raw: String, for id: UUID,
                        keeping live: Set<UUID>) -> [String: String] {
        var result = stored
        result[id.uuidString] = raw
        let alive = Set(live.map(\.uuidString)).union([id.uuidString])
        result = result.filter { alive.contains($0.key) && $0.value != "text" }
        return result
    }

    static func load(_ defaults: UserDefaults = .standard) -> [String: String] {
        defaults.dictionary(forKey: defaultsKey) as? [String: String] ?? [:]
    }

    static func save(_ stored: [String: String], _ defaults: UserDefaults = .standard) {
        defaults.set(stored, forKey: defaultsKey)
    }
}
