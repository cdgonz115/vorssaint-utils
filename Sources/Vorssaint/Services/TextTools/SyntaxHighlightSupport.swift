//
//  SyntaxHighlightSupport.swift
//  Vorssaint
//
//  Created by Christian Gonzalez on 10/22/26.
//
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Splits JSON and XML into the pieces an editor colors: names apart from
/// values, and the punctuation around them apart from both.
///
/// This only finds ranges. It does not validate, and it never fails: broken
/// or half-typed text gets the same treatment as far as it makes sense, so
/// the colors keep up while someone types. Colors are the caller's choice;
/// a kind says what a range is, not what it looks like. Ranges are in UTF-16
/// units, as AppKit uses.
enum SyntaxHighlightSupport {
    enum Kind: Equatable {
        /// A JSON object key.
        case key
        /// A quoted string: a JSON value or an XML attribute value.
        case string
        case number
        /// `true`, `false` or `null`.
        case literal
        /// `{ } [ ] , :` in JSON; `< > </ /> = ? !` in XML.
        case punctuation
        /// An XML element name.
        case tag
        /// An XML attribute name.
        case attribute
        /// Text between XML tags, and CDATA.
        case value
        case comment
    }

    struct Token: Equatable {
        let range: NSRange
        let kind: Kind
    }

    /// Longer text is left uncolored: it is scanned again on every keystroke.
    static let maximumLength = 200_000

    static func tokens(in text: String, format: TextToolsSupport.Format) -> [Token] {
        let units = Array(text.utf16)
        guard units.count <= maximumLength else { return [] }
        switch format {
        case .json: return jsonTokens(units)
        case .xml: return xmlTokens(units)
        }
    }

    // MARK: - JSON

    private static func jsonTokens(_ u: [UInt16]) -> [Token] {
        var tokens: [Token] = []
        var i = 0
        while i < u.count {
            let c = u[i]
            switch c {
            case quote:
                let end = endOfQuoted(u, from: i)
                var next = end
                while next < u.count, isSpace(u[next]) { next += 1 }
                let isKey = next < u.count && u[next] == colon
                tokens.append(Token(range: NSRange(location: i, length: end - i), kind: isKey ? .key : .string))
                i = end
            case openBrace, closeBrace, openBracket, closeBracket, comma, colon:
                tokens.append(Token(range: NSRange(location: i, length: 1), kind: .punctuation))
                i += 1
            case minus, digit0...digit9:
                var end = i + 1
                while end < u.count, isNumberPart(u[end]) { end += 1 }
                tokens.append(Token(range: NSRange(location: i, length: end - i), kind: .number))
                i = end
            case _ where isLetter(c):
                var end = i + 1
                while end < u.count, isLetter(u[end]) { end += 1 }
                let word = String(utf16CodeUnits: Array(u[i..<end]), count: end - i)
                if word == "true" || word == "false" || word == "null" {
                    tokens.append(Token(range: NSRange(location: i, length: end - i), kind: .literal))
                }
                i = end
            default:
                i += 1
            }
        }
        return tokens
    }

    // MARK: - XML

    private static func xmlTokens(_ u: [UInt16]) -> [Token] {
        var tokens: [Token] = []
        var i = 0
        while i < u.count {
            guard u[i] == lessThan else {
                // Text up to the next tag, without the whitespace around it.
                var end = i
                while end < u.count, u[end] != lessThan { end += 1 }
                var start = i
                var last = end
                while start < last, isSpace(u[start]) { start += 1 }
                while last > start, isSpace(u[last - 1]) { last -= 1 }
                if last > start {
                    tokens.append(Token(range: NSRange(location: start, length: last - start), kind: .value))
                }
                i = end
                continue
            }
            if matches(u, at: i, "<!--") {
                let end = find(u, "-->", from: i + 4).map { $0 + 3 } ?? u.count
                tokens.append(Token(range: NSRange(location: i, length: end - i), kind: .comment))
                i = end
            } else if matches(u, at: i, "<![CDATA[") {
                let end = find(u, "]]>", from: i + 9).map { $0 + 3 } ?? u.count
                tokens.append(Token(range: NSRange(location: i, length: end - i), kind: .value))
                i = end
            } else {
                i = xmlTag(u, from: i, into: &tokens)
            }
        }
        return tokens
    }

    /// One tag, `<name a="b">` or `</name>` or `<?xml ... ?>`; returns where it ends.
    private static func xmlTag(_ u: [UInt16], from start: Int, into tokens: inout [Token]) -> Int {
        var i = start + 1
        if i < u.count, u[i] == slash || u[i] == question || u[i] == bang { i += 1 }
        tokens.append(Token(range: NSRange(location: start, length: i - start), kind: .punctuation))

        let nameStart = i
        while i < u.count, !isSpace(u[i]), u[i] != greaterThan, u[i] != slash, u[i] != question { i += 1 }
        if i > nameStart {
            tokens.append(Token(range: NSRange(location: nameStart, length: i - nameStart), kind: .tag))
        }

        while i < u.count {
            let c = u[i]
            if isSpace(c) {
                i += 1
            } else if c == greaterThan {
                tokens.append(Token(range: NSRange(location: i, length: 1), kind: .punctuation))
                return i + 1
            } else if c == slash || c == question || c == equals {
                tokens.append(Token(range: NSRange(location: i, length: 1), kind: .punctuation))
                i += 1
            } else if c == quote || c == apostrophe {
                let end = endOfQuoted(u, from: i)
                tokens.append(Token(range: NSRange(location: i, length: end - i), kind: .string))
                i = end
            } else if c == lessThan {
                // A tag that was never closed: leave this `<` to the caller.
                return i
            } else {
                let attributeStart = i
                while i < u.count, !isSpace(u[i]), u[i] != equals, u[i] != greaterThan,
                      u[i] != slash, u[i] != question, u[i] != lessThan { i += 1 }
                if i == attributeStart { i += 1 }
                tokens.append(Token(range: NSRange(location: attributeStart, length: i - attributeStart),
                                    kind: .attribute))
            }
        }
        return i
    }

    // MARK: - Scanning helpers

    private static let quote: UInt16 = 0x22
    private static let apostrophe: UInt16 = 0x27
    private static let backslash: UInt16 = 0x5C
    private static let openBrace: UInt16 = 0x7B
    private static let closeBrace: UInt16 = 0x7D
    private static let openBracket: UInt16 = 0x5B
    private static let closeBracket: UInt16 = 0x5D
    private static let comma: UInt16 = 0x2C
    private static let colon: UInt16 = 0x3A
    private static let minus: UInt16 = 0x2D
    private static let digit0: UInt16 = 0x30
    private static let digit9: UInt16 = 0x39
    private static let lessThan: UInt16 = 0x3C
    private static let greaterThan: UInt16 = 0x3E
    private static let slash: UInt16 = 0x2F
    private static let question: UInt16 = 0x3F
    private static let bang: UInt16 = 0x21
    private static let equals: UInt16 = 0x3D

    /// The index just past the quoted run that starts at `start` (a quote of
    /// either kind), or the end of the text when it is never closed. In JSON a
    /// backslash escapes the next character; XML has no escapes, but a
    /// backslash before the closing quote is rare enough to share the code.
    private static func endOfQuoted(_ u: [UInt16], from start: Int) -> Int {
        let mark = u[start]
        var i = start + 1
        while i < u.count {
            if u[i] == backslash, mark == quote { i += 2; continue }
            if u[i] == mark { return i + 1 }
            i += 1
        }
        return u.count
    }

    private static func isSpace(_ c: UInt16) -> Bool {
        c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D
    }

    private static func isLetter(_ c: UInt16) -> Bool {
        (c >= 0x61 && c <= 0x7A) || (c >= 0x41 && c <= 0x5A)
    }

    private static func isNumberPart(_ c: UInt16) -> Bool {
        (c >= digit0 && c <= digit9) || c == 0x2E || c == 0x65 || c == 0x45 || c == 0x2B || c == minus
    }

    private static func matches(_ u: [UInt16], at index: Int, _ literal: String) -> Bool {
        let pattern = Array(literal.utf16)
        guard index + pattern.count <= u.count else { return false }
        for offset in 0..<pattern.count where u[index + offset] != pattern[offset] { return false }
        return true
    }

    private static func find(_ u: [UInt16], _ literal: String, from start: Int) -> Int? {
        let pattern = Array(literal.utf16)
        guard start >= 0, u.count >= pattern.count else { return nil }
        var i = start
        while i + pattern.count <= u.count {
            if matches(u, at: i, literal) { return i }
            i += 1
        }
        return nil
    }
}
