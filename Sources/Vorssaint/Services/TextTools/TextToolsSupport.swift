//
//  TextToolsSupport.swift
//  Vorssaint
//
//  Created by Christian Gonzalez on 9/29/26.
//

import Foundation

/// Pure text transforms shared by every module that edits text: the clipboard
/// editor, the scratchpad and anything after them. Nothing here touches a
/// view, a pasteboard or a file, so each function can be tested on its own and
/// run off the main thread.
///
/// Every transform returns nil (or a failure) instead of guessing, so a caller
/// can leave the user's text alone when the input is not what the tool expects.
enum TextToolsSupport {
    enum Format: Equatable {
        case json
        case xml
    }

    enum ReplaceFailure: Error, Equatable {
        case emptyPattern
        case invalidPattern
    }

    struct ReplaceOptions: Equatable {
        var isRegex = false
        var caseSensitive = false
    }

    struct ReplaceResult: Equatable {
        let text: String
        let count: Int
    }

    private static let indentUnit = "  "

    // MARK: - Detecting and formatting

    /// The structured format the text parses as, or nil when it is neither
    /// valid JSON (an object or an array) nor well-formed XML.
    static func detectFormat(_ text: String) -> Format? {
        let source = trim(text)
        if isJSON(source) { return .json }
        if parseXML(source) != nil { return .xml }
        return nil
    }

    /// Indents JSON or XML, whichever the text is. Nil when it is neither.
    static func prettyPrint(_ text: String) -> String? {
        guard let format = detectFormat(text) else { return nil }
        switch format {
        case .json: return prettyPrintJSON(text)
        case .xml: return prettyPrintXML(text)
        }
    }

    /// Removes the layout whitespace from JSON or XML. Nil when it is neither.
    static func minify(_ text: String) -> String? {
        guard let format = detectFormat(text) else { return nil }
        switch format {
        case .json: return minifyJSON(text)
        case .xml: return minifyXML(text)
        }
    }

    // MARK: - JSON

    /// Validates first (strictly, see `JSONValidator`), then re-indents the
    /// original characters rather than parsing into values and writing them back. That keeps the key order and
    /// every number exactly as written (1.0 stays 1.0, a 20-digit id stays a
    /// 20-digit id), which a parse-and-serialize round trip would not.
    static func prettyPrintJSON(_ text: String) -> String? {
        let source = trim(text)
        guard isJSON(source) else { return nil }
        return reformatJSON(source, pretty: true)
    }

    static func minifyJSON(_ text: String) -> String? {
        let source = trim(text)
        guard isJSON(source) else { return nil }
        return reformatJSON(source, pretty: false)
    }

    /// Only objects and arrays count. A bare number, `true` or a quoted string
    /// is valid JSON on its own, but formatting it would be a surprise.
    private static func isJSON(_ trimmed: String) -> Bool {
        guard let first = trimmed.unicodeScalars.first, first == "{" || first == "[" else { return false }
        var validator = JSONValidator(trimmed)
        return validator.validate()
    }

    /// A strict RFC 8259 check. Foundation's JSON parser forgives some
    /// mistakes (it accepted a trailing comma on current macOS), and how much it
    /// forgives can change between macOS versions, so the tool decides for
    /// itself what counts as JSON and behaves the same everywhere.
    private struct JSONValidator {
        /// Deep enough for any real document; stops a hostile paste from
        /// exhausting the stack.
        private static let maxDepth = 512

        private let scalars: [Unicode.Scalar]
        private var index = 0

        init(_ text: String) {
            scalars = Array(text.unicodeScalars)
        }

        mutating func validate() -> Bool {
            skipSpace()
            guard parseValue(depth: 0) else { return false }
            skipSpace()
            return index == scalars.count
        }

        private var current: Unicode.Scalar? {
            index < scalars.count ? scalars[index] : nil
        }

        private mutating func skipSpace() {
            while let scalar = current, scalar == " " || scalar == "\t" || scalar == "\n" || scalar == "\r" {
                index += 1
            }
        }

        private mutating func parseValue(depth: Int) -> Bool {
            guard depth <= Self.maxDepth, let scalar = current else { return false }
            switch scalar {
            case "{": return parseObject(depth: depth)
            case "[": return parseArray(depth: depth)
            case "\"": return parseString()
            case "t": return parseLiteral("true")
            case "f": return parseLiteral("false")
            case "n": return parseLiteral("null")
            default: return parseNumber()
            }
        }

        private mutating func parseObject(depth: Int) -> Bool {
            index += 1
            skipSpace()
            if current == "}" {
                index += 1
                return true
            }
            while true {
                skipSpace()
                guard current == "\"", parseString() else { return false }
                skipSpace()
                guard current == ":" else { return false }
                index += 1
                skipSpace()
                guard parseValue(depth: depth + 1) else { return false }
                skipSpace()
                if current == "," {
                    index += 1
                    continue
                }
                if current == "}" {
                    index += 1
                    return true
                }
                return false
            }
        }

        private mutating func parseArray(depth: Int) -> Bool {
            index += 1
            skipSpace()
            if current == "]" {
                index += 1
                return true
            }
            while true {
                skipSpace()
                guard parseValue(depth: depth + 1) else { return false }
                skipSpace()
                if current == "," {
                    index += 1
                    continue
                }
                if current == "]" {
                    index += 1
                    return true
                }
                return false
            }
        }

        private mutating func parseString() -> Bool {
            index += 1
            while index < scalars.count {
                let scalar = scalars[index]
                index += 1
                if scalar == "\"" { return true }
                // A raw control character (a real tab or line break) must be escaped.
                if scalar.value < 0x20 { return false }
                guard scalar == "\\" else { continue }
                guard let escape = current else { return false }
                index += 1
                switch escape {
                case "\"", "\\", "/", "b", "f", "n", "r", "t":
                    break
                case "u":
                    for _ in 0..<4 {
                        guard let digit = current, Self.isHex(digit) else { return false }
                        index += 1
                    }
                default:
                    return false
                }
            }
            return false
        }

        /// -?(0|[1-9][0-9]*)(.[0-9]+)?([eE][+-]?[0-9]+)?
        private mutating func parseNumber() -> Bool {
            if current == "-" { index += 1 }
            guard let first = current, Self.isDigit(first) else { return false }
            if first == "0" {
                index += 1
            } else {
                skipDigits()
            }
            if current == "." {
                index += 1
                guard skipDigits() > 0 else { return false }
            }
            if current == "e" || current == "E" {
                index += 1
                if current == "+" || current == "-" { index += 1 }
                guard skipDigits() > 0 else { return false }
            }
            return true
        }

        private mutating func parseLiteral(_ word: String) -> Bool {
            for expected in word.unicodeScalars {
                guard current == expected else { return false }
                index += 1
            }
            return true
        }

        @discardableResult
        private mutating func skipDigits() -> Int {
            var count = 0
            while let scalar = current, Self.isDigit(scalar) {
                index += 1
                count += 1
            }
            return count
        }

        private static func isDigit(_ scalar: Unicode.Scalar) -> Bool {
            (0x30...0x39).contains(scalar.value)
        }

        private static func isHex(_ scalar: Unicode.Scalar) -> Bool {
            switch scalar.value {
            case 0x30...0x39, 0x41...0x46, 0x61...0x66: return true
            default: return false
            }
        }
    }

    /// Walks the text once, tracking whether it is inside a string so that a
    /// comma, colon or brace inside a value is never treated as structure.
    /// The input has already been validated, so the walk can trust its shape.
    private static func reformatJSON(_ text: String, pretty: Bool) -> String {
        let scalars = Array(text.unicodeScalars)
        let unit = Array(indentUnit.unicodeScalars)
        var output = String.UnicodeScalarView()
        var depth = 0
        var inString = false
        var escaped = false
        var index = 0

        func lineBreak() {
            output.append("\n")
            for _ in 0..<depth { output.append(contentsOf: unit) }
        }

        while index < scalars.count {
            let scalar = scalars[index]
            index += 1

            if inString {
                output.append(scalar)
                if escaped {
                    escaped = false
                } else if scalar == "\\" {
                    escaped = true
                } else if scalar == "\"" {
                    inString = false
                }
                continue
            }

            switch scalar {
            case "\"":
                inString = true
                output.append(scalar)
            case "{", "[":
                output.append(scalar)
                // An empty container stays on one line: {} and [].
                var next = index
                while next < scalars.count, isJSONSpace(scalars[next]) { next += 1 }
                let closer: Unicode.Scalar = scalar == "{" ? "}" : "]"
                if next < scalars.count, scalars[next] == closer {
                    output.append(closer)
                    index = next + 1
                } else if pretty {
                    depth += 1
                    lineBreak()
                }
            case "}", "]":
                if pretty {
                    depth -= 1
                    lineBreak()
                }
                output.append(scalar)
            case ",":
                output.append(scalar)
                if pretty { lineBreak() }
            case ":":
                output.append(scalar)
                if pretty { output.append(" ") }
            case " ", "\t", "\n", "\r":
                break
            default:
                output.append(scalar)
            }
        }
        return String(output)
    }

    private static func isJSONSpace(_ scalar: Unicode.Scalar) -> Bool {
        scalar == " " || scalar == "\t" || scalar == "\n" || scalar == "\r"
    }

    // MARK: - XML

    /// Indents well-formed XML. An XML declaration is kept when the text had
    /// one and is not added when it did not.
    static func prettyPrintXML(_ text: String) -> String? {
        let source = trim(text)
        guard let document = parseXML(source) else { return nil }
        var result = document.xmlString(options: [.nodePrettyPrint])
        if !source.hasPrefix("<?xml"), result.hasPrefix("<?xml"),
           let lineEnd = result.firstIndex(of: "\n") {
            result = String(result[result.index(after: lineEnd)...])
        }
        return trim(result)
    }

    /// Drops the whitespace-only gaps between tags. A text node that is only
    /// whitespace is dropped with them, which is fine for data and layout XML
    /// but would matter in a document that treats spaces as content.
    static func minifyXML(_ text: String) -> String? {
        let source = trim(text)
        guard parseXML(source) != nil else { return nil }
        return source.replacingOccurrences(of: ">\\s+<", with: "><", options: .regularExpression)
    }

    /// External entities are never loaded. The text comes from the clipboard,
    /// so an entity that points at a local file or a URL must not be followed.
    private static func parseXML(_ trimmed: String) -> XMLDocument? {
        guard trimmed.hasPrefix("<") else { return nil }
        return try? XMLDocument(xmlString: trimmed, options: [.nodeLoadExternalEntitiesNever])
    }

    // MARK: - Search and replace

    /// How many places the pattern matches; the count a find bar would show.
    static func matchCount(in text: String, find: String,
                           options: ReplaceOptions = ReplaceOptions()) -> Result<Int, ReplaceFailure> {
        expression(find: find, options: options).map { (regex: NSRegularExpression) -> Int in
            regex.numberOfMatches(in: text, range: NSRange(text.startIndex..., in: text))
        }
    }

    /// The match to jump to from `location`, wrapping around at either end.
    ///
    /// Forward finds the first match that starts at or after `location`;
    /// backward finds the last one that starts before it. A caller steps
    /// forward from the end of the current selection and backward from its
    /// start. Empty matches (`^` on its own, say) are skipped going forward
    /// from where they sit, so stepping cannot stay on one forever. Nil
    /// when nothing matches. The range is in UTF-16 units, as AppKit uses.
    static func nextMatch(in text: String, find: String, from location: Int, backwards: Bool = false,
                          options: ReplaceOptions = ReplaceOptions()) -> Result<NSRange?, ReplaceFailure> {
        expression(find: find, options: options).map { (regex: NSRegularExpression) -> NSRange? in
            let ranges = regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).map(\.range)
            guard !ranges.isEmpty else { return nil }
            if backwards {
                return ranges.last(where: { $0.location < location }) ?? ranges.last
            }
            return ranges.first(where: { $0.location > location || ($0.location == location && $0.length > 0) })
                ?? ranges.first
        }
    }

    /// Replaces every match. In regex mode the replacement may use `$1`-style
    /// capture groups; in literal mode both the pattern and the replacement are
    /// taken exactly as typed, so `.` and `$1` mean themselves.
    ///
    /// `^` and `$` match at each line, which is what editing a log or a list
    /// of values usually wants. A pattern can be slow on very long text, so
    /// callers with large input should run this off the main thread.
    static func replaceAll(in text: String, find: String, with replacement: String,
                           options: ReplaceOptions = ReplaceOptions()) -> Result<ReplaceResult, ReplaceFailure> {
        expression(find: find, options: options).map { (regex: NSRegularExpression) -> ReplaceResult in
            let range = NSRange(text.startIndex..., in: text)
            let count = regex.numberOfMatches(in: text, range: range)
            let template = options.isRegex ? replacement : NSRegularExpression.escapedTemplate(for: replacement)
            let replaced = regex.stringByReplacingMatches(in: text, range: range, withTemplate: template)
            return ReplaceResult(text: replaced, count: count)
        }
    }

    private static func expression(find: String,
                                   options: ReplaceOptions) -> Result<NSRegularExpression, ReplaceFailure> {
        guard !find.isEmpty else { return .failure(.emptyPattern) }
        let pattern = options.isRegex ? find : NSRegularExpression.escapedPattern(for: find)
        var flags: NSRegularExpression.Options = [.anchorsMatchLines]
        if !options.caseSensitive { flags.insert(.caseInsensitive) }
        do {
            return .success(try NSRegularExpression(pattern: pattern, options: flags))
        } catch {
            return .failure(.invalidPattern)
        }
    }

    // MARK: - Shared

    private static func trim(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
