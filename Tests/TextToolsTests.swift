//
//  TextToolsTest.swift
//  Vorssaint
//
//  Created by Christian Gonzalez on 9/29/26.
//
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

enum TextToolsTests {
    static func run(_ suite: TestSuite) {
        suite.run("text tools json") { json(suite) }
        suite.run("text tools xml") { xml(suite) }
        suite.run("text tools detection") { detection(suite) }
        suite.run("text tools replace") { replace(suite) }
        suite.run("text tools navigation") { navigation(suite) }
        suite.run("text tools syntax") { syntax(suite) }
        suite.run("text editor preferences") { preferences(suite) }
    }

    private static func json(_ suite: TestSuite) {
        let compact = #"{"a":1,"b":[1,2,{"c":null}],"d":{},"e":[]}"#
        let expected = [
            "{",
            "  \"a\": 1,",
            "  \"b\": [",
            "    1,",
            "    2,",
            "    {",
            "      \"c\": null",
            "    }",
            "  ],",
            "  \"d\": {},",
            "  \"e\": []",
            "}",
        ].joined(separator: "\n")
        let pretty = TextToolsSupport.prettyPrintJSON(compact)
        suite.expect(pretty == expected, "JSON is indented, with empty containers on one line")
        suite.expect(pretty.flatMap(TextToolsSupport.minifyJSON) == compact, "minify undoes the indentation")
        suite.expect(pretty.flatMap(TextToolsSupport.prettyPrintJSON) == pretty, "formatting twice changes nothing")

        // Structure characters inside a string are content, and numbers are
        // written back exactly as they came in.
        let tricky = #"{"s":"has, comma: and \"quote\" { [","n":1.0,"big":12345678901234567890}"#
        let formatted = TextToolsSupport.prettyPrintJSON(tricky) ?? ""
        suite.expect(formatted.contains(#""s": "has, comma: and \"quote\" { [""#), "string contents are untouched")
        suite.expect(formatted.contains(#""n": 1.0"#), "1.0 keeps its decimal")
        suite.expect(formatted.contains(#""big": 12345678901234567890"#), "a long integer keeps every digit")
        suite.expect(TextToolsSupport.minifyJSON(tricky) == tricky, "a compact string minifies to itself")

        suite.expect(TextToolsSupport.prettyPrintJSON("  {\"a\" : \"x/y\"}  ") == "{\n  \"a\": \"x/y\"\n}",
                     "padding is trimmed and a slash is not escaped")
        suite.expect(TextToolsSupport.prettyPrintJSON("[ ]") == "[]", "an empty array with a space closes up")
        let keys = TextToolsSupport.prettyPrintJSON(#"{"z":1,"a":2}"#) ?? ""
        suite.expect((keys.range(of: "\"z\"")?.lowerBound ?? keys.endIndex)
                        < (keys.range(of: "\"a\"")?.lowerBound ?? keys.startIndex),
                     "key order is preserved")

        // Everything here is a common way for pasted "JSON" to be broken, and
        // none of it may be reformatted as if it were valid.
        let invalid = [
            #"{"a":1,}"#, "[1,]", #"{"a":1,,"b":2}"#, "[,1]", "{'a':1}", #"{"a" 1}"#, #"{"a":01}"#,
            #"{"a":tru}"#, "[1 2]", #"{"a":1}}"#, #"{"a":1} x"#, #"{"a":"\x"}"#, "{\"a\":\"tab\there\"}",
            #"{"a":1.}"#, #"{"a":.5}"#, #"{"a":1e}"#, #"{"a":+1}"#, #"["\u12G4"]"#, "[NaN]", "{a:1}",
            "[1,2", "{\"a\":", "123", "true", "plain text", "", "   ",
        ]
        for text in invalid {
            suite.expect(TextToolsSupport.prettyPrintJSON(text) == nil, "\(text) is not formatted as JSON")
        }

        // Every literal form JSON allows must be accepted and survive untouched.
        let literals = #"[-0.5E+10,true,false,null,"\u00e9","a\"b",0,-1,{"k":[]}]"#
        suite.expect(TextToolsSupport.minifyJSON(literals) == literals, "every JSON literal form is accepted")

        let deep = String(repeating: "[", count: 500) + String(repeating: "]", count: 500)
        suite.expect(TextToolsSupport.minifyJSON(deep) == deep, "ordinary deep nesting is accepted")
        let tooDeep = String(repeating: "[", count: 600) + String(repeating: "]", count: 600)
        suite.expect(TextToolsSupport.minifyJSON(tooDeep) == nil, "absurd nesting is refused, not crashed on")
    }

    private static func xml(_ suite: TestSuite) {
        let compact = "<a><b>1</b></a>"
        let pretty = TextToolsSupport.prettyPrintXML(compact) ?? ""
        suite.expect(pretty.hasPrefix("<a>"), "no declaration is added to XML that had none")
        // XMLDocument chooses the indent width (four spaces today), so the test
        // checks the shape: three lines, with the child indented on its own.
        let lines = pretty.components(separatedBy: "\n")
        suite.expect(lines.count == 3 && lines[1].hasPrefix(" ")
                        && lines[1].trimmingCharacters(in: .whitespaces) == "<b>1</b>",
                     "child elements are indented on their own line, got \(pretty.debugDescription)")
        suite.expect(TextToolsSupport.minifyXML(pretty) == compact, "minify undoes the indentation")

        suite.expect(TextToolsSupport.prettyPrintXML("<?xml version=\"1.0\"?><a/>")?.hasPrefix("<?xml") == true,
                     "an existing declaration is kept")
        suite.expect(TextToolsSupport.prettyPrintXML("<a><b></a>") == nil, "malformed XML is not formatted")
        suite.expect(TextToolsSupport.prettyPrintXML("plain text") == nil, "text that is not XML is not formatted")

        // An external entity must never be read from disk.
        let entity = "<!DOCTYPE a [<!ENTITY x SYSTEM \"file:///etc/hosts\">]><a>&x;</a>"
        suite.expect(!(TextToolsSupport.prettyPrintXML(entity) ?? "").contains("localhost"),
                     "an external entity is not loaded")
    }

    private static func detection(_ suite: TestSuite) {
        suite.expect(TextToolsSupport.detectFormat(#"{"a":1}"#) == .json, "an object is JSON")
        suite.expect(TextToolsSupport.detectFormat("[1, 2]") == .json, "an array is JSON")
        suite.expect(TextToolsSupport.detectFormat("<a><b/></a>") == .xml, "well-formed markup is XML")
        suite.expect(TextToolsSupport.detectFormat("hello") == nil, "plain text is neither")
        suite.expect(TextToolsSupport.detectFormat("<a>") == nil, "unclosed markup is neither")
        suite.expect(TextToolsSupport.prettyPrint("hello") == nil, "prettyPrint leaves plain text alone")
        suite.expect(TextToolsSupport.minify("hello") == nil, "minify leaves plain text alone")
        suite.expect(TextToolsSupport.prettyPrint("[1]") == "[\n  1\n]", "prettyPrint picks JSON")
        suite.expect(TextToolsSupport.render("[1]", as: .json, minified: false) == "[\n  1\n]",
                     "render indents as the format that was asked for")
        suite.expect(TextToolsSupport.render("[ 1 ]", as: .json, minified: true) == "[1]",
                     "render can remove the layout instead")
        suite.expect(TextToolsSupport.render("<a><b>1</b></a>", as: .xml, minified: true) == "<a><b>1</b></a>",
                     "render handles XML as well")
        suite.expect(TextToolsSupport.render("<a/>", as: .json, minified: false) == nil
                        && TextToolsSupport.render("[1]", as: .xml, minified: false) == nil,
                     "text that is not in the chosen format is refused, not read as another one")
    }

    private static func replace(_ suite: TestSuite) {
        typealias Replaced = TextToolsSupport.ReplaceResult
        let literal = TextToolsSupport.ReplaceOptions()
        let caseSensitive = TextToolsSupport.ReplaceOptions(caseSensitive: true)
        let regex = TextToolsSupport.ReplaceOptions(isRegex: true)

        suite.expect(TextToolsSupport.replaceAll(in: "Foo foo FOO", find: "foo", with: "x", options: literal)
                        == .success(Replaced(text: "x x x", count: 3)),
                     "matching ignores case by default")
        suite.expect(TextToolsSupport.replaceAll(in: "Foo foo FOO", find: "foo", with: "x", options: caseSensitive)
                        == .success(Replaced(text: "Foo x FOO", count: 1)),
                     "case-sensitive matching replaces only the exact case")
        suite.expect(TextToolsSupport.replaceAll(in: "a.b axb", find: "a.b", with: "X", options: literal)
                        == .success(Replaced(text: "X axb", count: 1)),
                     "a literal dot is only a dot")
        suite.expect(TextToolsSupport.replaceAll(in: "cat", find: "cat", with: "$1", options: literal)
                        == .success(Replaced(text: "$1", count: 1)),
                     "a literal replacement is not a template")
        suite.expect(TextToolsSupport.replaceAll(in: "2026-09-29", find: #"(\d+)-(\d+)-(\d+)"#,
                                                 with: "$3/$2/$1", options: regex)
                        == .success(Replaced(text: "29/09/2026", count: 1)),
                     "regex capture groups work in the replacement")
        suite.expect(TextToolsSupport.replaceAll(in: "a\nb", find: "^", with: "> ", options: regex)
                        == .success(Replaced(text: "> a\n> b", count: 2)),
                     "^ matches at the start of every line")
        suite.expect(TextToolsSupport.replaceAll(in: "abc", find: "z", with: "y", options: literal)
                        == .success(Replaced(text: "abc", count: 0)),
                     "no match leaves the text and reports zero")

        suite.expect(TextToolsSupport.replaceAll(in: "abc", find: "(", with: "", options: regex)
                        == .failure(.invalidPattern),
                     "a broken regex is reported, not crashed on")
        suite.expect(TextToolsSupport.replaceAll(in: "abc", find: "", with: "x", options: literal)
                        == .failure(.emptyPattern),
                     "an empty search is refused")
        suite.expect(TextToolsSupport.matchCount(in: "a a a", find: "a", options: literal) == .success(3),
                     "matchCount counts every match")
        suite.expect(TextToolsSupport.matchCount(in: "a a a", find: "[", options: regex) == .failure(.invalidPattern),
                     "matchCount reports a broken regex")
    }

    private static func navigation(_ suite: TestSuite) {
        let literal = TextToolsSupport.ReplaceOptions()
        let regex = TextToolsSupport.ReplaceOptions(isRegex: true)
        let text = "ab ab ab"  // matches start at 0, 3 and 6
        func next(_ from: Int, back: Bool = false, find: String = "ab",
                  options: TextToolsSupport.ReplaceOptions = literal) -> NSRange? {
            if case .success(let range) = TextToolsSupport.nextMatch(in: text, find: find, from: from,
                                                                    backwards: back, options: options) {
                return range
            }
            return nil
        }
        suite.expect(next(0) == NSRange(location: 0, length: 2), "a caret on a match selects that match")
        suite.expect(next(2) == NSRange(location: 3, length: 2), "stepping on from the end of a match finds the next")
        suite.expect(next(7) == NSRange(location: 0, length: 2), "stepping past the last match wraps to the first")
        suite.expect(next(6, back: true) == NSRange(location: 3, length: 2), "backward finds the one before")
        suite.expect(next(0, back: true) == NSRange(location: 6, length: 2), "backward past the first wraps to the last")
        suite.expect(next(0, find: "zz") == nil, "no match gives nil")
        suite.expect(TextToolsSupport.nextMatch(in: text, find: "(", from: 0, options: regex) == .failure(.invalidPattern),
                     "a broken regex is reported")
        suite.expect(TextToolsSupport.nextMatch(in: text, find: "", from: 0) == .failure(.emptyPattern),
                     "an empty search is refused")
        // Empty matches: `^` matches at the start of each of three lines.
        if case .success(let range) = TextToolsSupport.nextMatch(in: "a\nb\nc", find: "^", from: 0, options: regex) {
            suite.expect(range == NSRange(location: 2, length: 0),
                         "an empty match at the caret is skipped going forward, so stepping moves on")
        } else {
            suite.expect(false, "^ is a valid pattern")
        }
        suite.expect(next(0, find: #"\d+"#, options: regex) == nil, "no digits, no match")
        // Replacing the match at a range.
        func one(_ range: NSRange, find: String = "ab", with replacement: String = "X", in source: String = text,
                 options: TextToolsSupport.ReplaceOptions = literal) -> String? {
            if case .success(let result) = TextToolsSupport.replacement(in: source, find: find, with: replacement,
                                                                       at: range, options: options) {
                return result
            }
            return nil
        }
        suite.expect(one(NSRange(location: 3, length: 2)) == "X", "a range that is a match gives its replacement")
        suite.expect(one(NSRange(location: 1, length: 2)) == nil, "a range that is not a match gives nil")
        suite.expect(one(NSRange(location: 3, length: 1)) == nil, "part of a match is not a match")
        suite.expect(one(NSRange(location: 0, length: 3), find: #"(\d+)-(\d+)"#, with: "$2/$1", in: "12-34",
                         options: regex) == nil,
                     "the range has to be the whole match")
        suite.expect(one(NSRange(location: 0, length: 5), find: #"(\d+)-(\d+)"#, with: "$2/$1", in: "12-34",
                         options: regex) == "34/12",
                     "regex replacements use capture groups")
        suite.expect(one(NSRange(location: 0, length: 3), find: "cat", with: "$1", in: "cat") == "$1",
                     "a literal replacement is taken as typed")
        suite.expect(TextToolsSupport.replacement(in: text, find: "", with: "x", at: NSRange(location: 0, length: 0))
                     == .failure(.emptyPattern), "an empty search is refused")
    }

    private static func syntax(_ suite: TestSuite) {
        typealias Token = SyntaxHighlightSupport.Token
        func tokens(_ text: String, _ format: TextToolsSupport.Format) -> [Token] {
            SyntaxHighlightSupport.tokens(in: text, format: format)
        }
        func kinds(_ text: String, _ format: TextToolsSupport.Format) -> [SyntaxHighlightSupport.Kind] {
            tokens(text, format).map(\.kind)
        }

        // {"a": [1, true]}
        suite.expect(kinds(#"{"a": [1, true]}"#, .json)
                     == [.punctuation, .key, .punctuation, .punctuation, .number, .punctuation, .literal,
                         .punctuation, .punctuation],
                     "json: keys, numbers, literals and punctuation are told apart")
        suite.expect(kinds(#"{"a":"b"}"#, .json) == [.punctuation, .key, .punctuation, .string, .punctuation],
                     "json: a string before a colon is a key, after it a value")
        suite.expect(tokens(#"["x"]"#, .json)[1] == Token(range: NSRange(location: 1, length: 3), kind: .string),
                     "json: a string token covers its quotes")
        suite.expect(kinds(#"["a\"b"]"#, .json) == [.punctuation, .string, .punctuation],
                     "json: an escaped quote does not end the string")
        suite.expect(tokens("[-1.5e3]", .json)[1] == Token(range: NSRange(location: 1, length: 6), kind: .number),
                     "json: a number takes its sign, fraction and exponent")
        suite.expect(kinds("[nope]", .json) == [.punctuation, .punctuation],
                     "json: a word that is not true, false or null is left plain")
        suite.expect(kinds(#"{"a": "unclosed"#, .json) == [.punctuation, .key, .punctuation, .string],
                     "json: half-typed text is colored as far as it goes")

        suite.expect(kinds("<a b=\"c\">d</a>", .xml)
                     == [.punctuation, .tag, .attribute, .punctuation, .string, .punctuation, .value,
                         .punctuation, .tag, .punctuation],
                     "xml: tag, attribute, value and punctuation are told apart")
        suite.expect(kinds("<a/>", .xml) == [.punctuation, .tag, .punctuation, .punctuation],
                     "xml: a self-closing tag")
        suite.expect(kinds("<!-- x --><a/>", .xml).first == .comment, "xml: comments")
        suite.expect(kinds("<a><![CDATA[<b>]]></a>", .xml).contains(.value), "xml: CDATA is a value")
        suite.expect(kinds("<?xml version=\"1.0\"?>", .xml)
                     == [.punctuation, .tag, .attribute, .punctuation, .string, .punctuation, .punctuation],
                     "xml: the declaration")
        suite.expect(tokens("<a>  x y  </a>", .xml)[3] == Token(range: NSRange(location: 5, length: 3), kind: .value),
                     "xml: text between tags leaves out the whitespace around it")
        suite.expect(!kinds("<a b=\"c", .xml).isEmpty, "xml: an unclosed tag does not stop the scan")

        suite.expect(SyntaxHighlightSupport.opens("  {\"a\"", as: .json)
                        && SyntaxHighlightSupport.opens("[1,", as: .json)
                        && SyntaxHighlightSupport.opens("\n<a", as: .xml),
                     "a half-typed document still opens like its format")
        suite.expect(!SyntaxHighlightSupport.opens("hello", as: .json)
                        && !SyntaxHighlightSupport.opens("{", as: .xml)
                        && !SyntaxHighlightSupport.opens("   ", as: .json),
                     "anything else does not, and empty text opens like nothing")

        // Offsets are UTF-16 units, as AppKit counts them.
        suite.expect(tokens("[\"é😀\", 1]", .json).last?.range == NSRange(location: 9, length: 1),
                     "ranges count UTF-16 units, so an emoji is two")
        suite.expect(tokens(String(repeating: "1", count: SyntaxHighlightSupport.maximumLength + 1), .json).isEmpty,
                     "text over the limit is left uncolored")
        suite.expect(tokens("", .json).isEmpty && tokens("", .xml).isEmpty, "empty text has nothing to color")
    }

    private static func preferences(_ suite: TestSuite) {
        typealias Prefs = TextEditorPreferences
        suite.expect(Prefs.formats == [.json, .xml], "settings lists every format")
        for format in Prefs.formats {
            suite.expect(!Prefs.kinds(for: format).isEmpty, "\(format) has something to color")
            for kind in Prefs.kinds(for: format) {
                suite.expect(Prefs.normalizedHex(Prefs.defaultHex(for: kind)) == Prefs.defaultHex(for: kind),
                             "the built-in color of \(kind) is a clean #RRGGBB")
            }
        }

        // Nothing stored: the built-in colors.
        let plain = Prefs.palette(for: .json, stored: "")
        suite.expect(plain[.key] == Prefs.defaultHex(for: .key) && plain[.tag] == nil,
                     "no changes gives the built-in colors, for that format's kinds only")

        // A changed color is stored alone, and wins.
        let stored = Prefs.storing("#112233", for: .key, in: "")
        suite.expect(stored == ##"{"key":"#112233"}"##, "only the changed color is stored")
        suite.expect(Prefs.palette(for: .json, stored: stored)[.key] == "#112233"
                        && Prefs.palette(for: .json, stored: stored)[.string] == Prefs.defaultHex(for: .string),
                     "a stored color wins and the rest stay built-in")
        let two = Prefs.storing("#445566", for: .string, in: stored)
        suite.expect(Prefs.overrides(from: two)[.key] == "#112233" && Prefs.overrides(from: two)[.string] == "#445566",
                     "changes add up")

        // Putting a color back clears it.
        suite.expect(Prefs.storing(Prefs.defaultHex(for: .key), for: .key, in: stored) == "",
                     "choosing the built-in color again stores nothing")
        suite.expect(Prefs.storing(nil, for: .key, in: stored) == "", "nil puts a color back")
        suite.expect(Prefs.storing("#112233", for: .key, in: stored) == stored, "storing the same color is stable")

        // Stored text that is not ours cannot break anything.
        for junk in ["", "garbage", "[]", "{", ##"{"nope":"#112233"}"##, #"{"key":"red"}"#, #"{"key":5}"#] {
            suite.expect(Prefs.palette(for: .json, stored: junk)[.key] == Prefs.defaultHex(for: .key),
                         "unusable stored colors (\(junk)) leave the built-in one")
        }
        suite.expect(Prefs.overrides(from: ##"{"key":"#abc"}"##)[.key] == "#AABBCC",
                     "a short or lower-case color is cleaned to #RRGGBB")

        suite.expect(Prefs.hexString(red: 1, green: 0, blue: 0.5) == "#FF0080", "hex from components")
        suite.expect(Prefs.hexString(red: 2, green: -1, blue: 0) == "#FF0000", "components are clamped")
        suite.expect(Prefs.normalizedHex("#7dbeff") == "#7DBEFF", "hex is upper-cased")

        // Defaults and backup.
        let registered = Defaults.registeredDefaults
        for format in Prefs.formats {
            suite.expect(registered[Prefs.enabledKey(format)] as? Bool == true, "\(format) is on by default")
            suite.expect(registered[Prefs.colorsKey(format)] as? String == "", "\(format) starts with no color changes")
        }
        suite.expect(Prefs.enabledKey(.json) != Prefs.enabledKey(.xml)
                        && Prefs.colorsKey(.json) != Prefs.colorsKey(.xml),
                     "each format has keys of its own")
        let exported = SettingsBackupSupport.exportKeys()
        suite.expect(Prefs.formats.allSatisfy { exported.contains(Prefs.enabledKey($0)) && exported.contains(Prefs.colorsKey($0)) },
                     "the text editor settings travel in a backup")
        suite.expect(!SettingsBackupSupport.valueLooksRight(Prefs.colorsKey(.json), true)
                        && SettingsBackupSupport.valueLooksRight(Prefs.colorsKey(.json), stored),
                     "restored colors have to be text")
    }
}
