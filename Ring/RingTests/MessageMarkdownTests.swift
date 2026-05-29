/*
 *  Copyright (C) 2026-2026 Savoir-faire Linux Inc.
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA.
 */

import XCTest
@testable import Ring

final class MessageMarkdownTests: XCTestCase {

    private enum Sample {
        static let text = "text"
        static let phrase = "plain phrase"
        static let linkURL = "https://example.com"

        static var bold: String { "**\(text)**" }
        static var italic: String { "*\(text)*" }
        static var boldItalic: String { "***\(text)***" }
        static var strike: String { "~~\(text)~~" }
        static var underscoreBold: String { "__\(text)__" }
        static var inlineCode: String { "`\(text)`" }
        static var heading: String { "### \(text)" }
        static var orderedList: String { "1. \(text)" }
        static var orderedListMultiline: String { "1. \(text)\n2. \(text)" }
        static var unorderedListMultiline: String { "- \(text)\n- \(text)" }
        static var mixedBoldAndList: String { "See **\(text)** here.\n\n- \(text)\n- \(text)" }
        static var blockquote: String { "> \(text)" }
        static var blockquoteMultiline: String { "> \(text)\n> \(text)" }
        static var fencedCode: String { "```\n\(text)\n```" }
        static var link: String { "[\(text)](\(linkURL))" }
        static var linkInPhrase: String { "\(phrase) [\(text)](\(linkURL))" }
        static var boldInPhrase: String { "\(phrase) **\(text)**" }
        static var italicInPhrase: String { "\(phrase) *\(text)*" }
        static var boldInPhraseSentence: String { "\(phrase) \(bold)" }

        static let invalidBoldEmpty = "**"
        static let invalidBoldOpen = "**\(text)"
        static let invalidBoldDoubled = "****"
        static let invalidItalicOpen = "*\(text)"
        static let invalidStrikeOpen = "~~\(text)"
        static let invalidCodeOpen = "`\(text)"
        static let invalidUnderscoreEmpty = "__"
        static let invalidBlockquote = ">"
        static let invalidBlockquoteDoubled = ">>"
        static let invalidFenceInline = "```\(text)```"

        static let literalMath = "3*4=12"
        static let literalProduct = "a*b*c"
        static let literalSpacedProduct = "a * b * c"
        static let literalItalicSpaceClose = "*text *"
        static let literalItalicWordSuffix = "*word*s"
        static let listMarkerWithSpace = "* text*"
        static let literalHashTag = "C# role"
        static let literalSnakeCase = "a_b_c"
        static let literalBracket = "[\(text)]"
        static let literalDecimal = "2.5 units"
        static let literalTilde = "~\(text)"
    }

    // MARK: - MessageMarkdownSupport

    func test_containsRenderableMarkdown_plainText_returnsFalse() {
        XCTAssertFalse(MessageMarkdownSupport.containsRenderableMarkdown(in: Sample.phrase))
    }

    func test_containsRenderableMarkdown_validBold_returnsTrue() {
        XCTAssertTrue(MessageMarkdownSupport.containsRenderableMarkdown(in: Sample.boldInPhrase))
    }

    func test_containsRenderableMarkdown_orderedList_returnsTrue() {
        XCTAssertTrue(MessageMarkdownSupport.containsRenderableMarkdown(in: Sample.orderedList))
    }

    func test_containsRenderableMarkdown_invalidBold_returnsFalse() {
        for input in [Sample.invalidBoldEmpty, Sample.invalidBoldOpen, Sample.invalidBoldDoubled] {
            XCTAssertFalse(MessageMarkdownSupport.containsRenderableMarkdown(in: input))
        }
    }

    func test_containsRenderableMarkdown_literals_returnFalse() {
        for input in [
            Sample.literalMath,
            Sample.literalProduct,
            Sample.literalSpacedProduct,
            Sample.literalItalicSpaceClose,
            Sample.literalItalicWordSuffix,
            Sample.literalHashTag,
            Sample.literalBracket,
            Sample.literalSnakeCase,
            Sample.literalTilde,
            Sample.invalidItalicOpen
        ] {
            XCTAssertFalse(MessageMarkdownSupport.containsRenderableMarkdown(in: input))
        }
    }

    func test_requiresFullSyntax_blockConstructs_returnTrue() {
        XCTAssertTrue(MessageMarkdownSupport.requiresFullSyntax(in: Sample.heading))
        XCTAssertTrue(MessageMarkdownSupport.requiresFullSyntax(in: Sample.blockquote))
        XCTAssertTrue(MessageMarkdownSupport.requiresFullSyntax(in: Sample.orderedList))
    }

    func test_requiresFullSyntax_inlineBold_returnsFalse() {
        XCTAssertFalse(MessageMarkdownSupport.requiresFullSyntax(in: Sample.bold))
    }

    func test_italicAsterisk_boundaries() {
        let renderable: [(input: String, expected: String)] = [
            (Sample.italic, Sample.text),
            ("*hello world*", "hello world"),
            ("phrase *text*.", "phrase text.")
        ]
        for testCase in renderable {
            XCTAssertTrue(
                MessageMarkdownSupport.containsRenderableMarkdown(in: testCase.input),
                testCase.input
            )
            XCTAssertEqual(
                MessageMarkdown.displayText(from: testCase.input),
                testCase.expected,
                testCase.input
            )
            XCTAssertEqual(
                MessageMarkdownPlainText.stripValidConstructs(from: testCase.input),
                testCase.expected,
                testCase.input
            )
        }

        for input in [
            Sample.literalProduct,
            Sample.literalSpacedProduct,
            Sample.literalItalicSpaceClose,
            Sample.literalItalicWordSuffix
        ] {
            XCTAssertFalse(
                MessageMarkdownSupport.containsRenderableMarkdown(in: input),
                input
            )
            XCTAssertEqual(MessageMarkdown.displayText(from: input), input, input)
            XCTAssertEqual(MessageMarkdownPlainText.stripValidConstructs(from: input), input, input)
        }

        // `* text*` matches unordered-list line syntax in this subset, not italic.
        XCTAssertTrue(MessageMarkdownSupport.containsRenderableMarkdown(in: Sample.listMarkerWithSpace))
        XCTAssertEqual(MessageMarkdown.displayText(from: Sample.listMarkerWithSpace), "text*")
    }

    // MARK: - MessageMarkdownPlainText — valid constructs

    func test_display_plainText_unchanged() {
        XCTAssertEqual(MessageMarkdown.displayText(from: Sample.phrase), Sample.phrase)
    }

    func test_stripValidConstructs_stripsInlineMarkers() {
        XCTAssertEqual(MessageMarkdownPlainText.stripValidConstructs(from: Sample.boldInPhrase), "\(Sample.phrase) \(Sample.text)")
        XCTAssertEqual(MessageMarkdownPlainText.stripValidConstructs(from: Sample.italicInPhrase), "\(Sample.phrase) \(Sample.text)")
        XCTAssertEqual(MessageMarkdownPlainText.stripValidConstructs(from: Sample.boldItalic), Sample.text)
        XCTAssertEqual(MessageMarkdownPlainText.stripValidConstructs(from: Sample.strike), Sample.text)
        XCTAssertEqual(MessageMarkdownPlainText.stripValidConstructs(from: Sample.underscoreBold), Sample.text)
        XCTAssertEqual(MessageMarkdownPlainText.stripValidConstructs(from: Sample.inlineCode), Sample.text)
    }

    func test_stripValidConstructs_stripsLinkSyntax() {
        XCTAssertEqual(MessageMarkdownPlainText.stripValidConstructs(from: Sample.linkInPhrase), "\(Sample.phrase) \(Sample.text)")
    }

    func test_stripValidConstructs_stripsBlockMarkers() {
        XCTAssertEqual(MessageMarkdownPlainText.stripValidConstructs(from: Sample.heading), Sample.text)
        XCTAssertEqual(MessageMarkdownPlainText.stripValidConstructs(from: Sample.blockquoteMultiline), "\(Sample.text)\n\(Sample.text)")
        XCTAssertEqual(MessageMarkdownPlainText.stripValidConstructs(from: Sample.fencedCode), Sample.text)
        XCTAssertEqual(MessageMarkdownPlainText.stripValidConstructs(from: Sample.orderedList), Sample.text)
    }

    // MARK: - MessageMarkdownPlainText — invalid / literal

    func test_display_invalidMarkers_unchanged() {
        for input in [
            Sample.invalidBoldEmpty,
            Sample.invalidBoldOpen,
            Sample.invalidBoldDoubled,
            Sample.invalidItalicOpen,
            Sample.invalidStrikeOpen,
            Sample.invalidCodeOpen,
            Sample.invalidUnderscoreEmpty,
            Sample.invalidBlockquote,
            Sample.invalidBlockquoteDoubled,
            Sample.invalidFenceInline
        ] {
            XCTAssertEqual(MessageMarkdown.displayText(from: input), input)
        }
    }

    func test_display_literals_unchanged() {
        for input in [
            Sample.literalMath,
            Sample.literalProduct,
            Sample.literalSpacedProduct,
            Sample.literalItalicSpaceClose,
            Sample.literalItalicWordSuffix,
            Sample.literalHashTag,
            Sample.literalSnakeCase,
            Sample.literalBracket,
            Sample.literalDecimal
        ] {
            XCTAssertEqual(MessageMarkdown.displayText(from: input), input)
        }
    }

    func test_display_voiceOverSpokenText_stripsValidMarkdown() {
        XCTAssertEqual(MessageMarkdown.displayText(from: Sample.bold), Sample.text)
        XCTAssertEqual(MessageMarkdown.displayText(from: Sample.linkInPhrase), "\(Sample.phrase) \(Sample.text)")
        XCTAssertEqual(MessageMarkdown.displayText(from: Sample.orderedList), Sample.text)
    }

    // MARK: - MessageMarkdown rendering

    @available(iOS 15.0, *)
    func test_attributedString_bold_parses() {
        let result = MessageMarkdown.attributedString(from: Sample.boldInPhraseSentence, linkColor: .blue)
        XCTAssertNotNil(result)
        XCTAssertTrue(String(result!.characters).contains(Sample.text))
    }

    @available(iOS 15.0, *)
    func test_attributedString_plainText_returnsNil() {
        XCTAssertNil(MessageMarkdown.attributedString(from: Sample.phrase, linkColor: .blue))
    }

    @available(iOS 15.0, *)
    func test_attributedString_invalidBold_returnsNil() {
        for input in [Sample.invalidBoldEmpty, Sample.invalidBoldOpen, Sample.invalidBoldDoubled] {
            XCTAssertNil(MessageMarkdown.attributedString(from: input, linkColor: .blue))
        }
    }

    @available(iOS 15.0, *)
    func test_resolveBubbleBody_plainText() {
        let body = MessageMarkdown.resolveBubbleBody(
            content: Sample.text,
            linkColor: .blue,
            baseFont: .callout,
            inlineLinkAttributed: nil
        )
        guard case .plain(let text) = body.kind else {
            return XCTFail("Expected plain body")
        }
        XCTAssertEqual(text, Sample.text)
    }

    @available(iOS 15.0, *)
    func test_resolveBubbleBody_markdown_returnsRich() {
        let body = MessageMarkdown.resolveBubbleBody(
            content: Sample.bold,
            linkColor: .blue,
            baseFont: .callout,
            inlineLinkAttributed: nil
        )
        guard case .rich(let storage) = body.kind,
              let attributed = storage as? AttributedString else {
            return XCTFail("Expected rich body")
        }
        XCTAssertTrue(String(attributed.characters).contains(Sample.text))
    }

    @available(iOS 15.0, *)
    func test_resolveBubbleBody_blockSyntax_returnsPlainWithNewlines() {
        let cases: [(content: String, expected: String)] = [
            (Sample.orderedListMultiline, "\(Sample.text)\n\(Sample.text)"),
            (Sample.unorderedListMultiline, "\(Sample.text)\n\(Sample.text)"),
            (Sample.blockquoteMultiline, "\(Sample.text)\n\(Sample.text)"),
            (Sample.heading, Sample.text),
            (Sample.fencedCode, Sample.text),
            (Sample.mixedBoldAndList, "See \(Sample.text) here.\n\n\(Sample.text)\n\(Sample.text)")
        ]
        for testCase in cases {
            let body = MessageMarkdown.resolveBubbleBody(
                content: testCase.content,
                linkColor: .blue,
                baseFont: .callout,
                inlineLinkAttributed: nil
            )
            guard case .plain(let text) = body.kind else {
                return XCTFail("Expected plain body for block syntax: \(testCase.content)")
            }
            XCTAssertEqual(text, testCase.expected, "Content: \(testCase.content)")
            XCTAssertEqual(body.fallbackPlain, testCase.expected)
        }
    }

    @available(iOS 15.0, *)
    func test_resolveBubbleBody_invalidBold_isPlainLiteral() {
        for input in [Sample.invalidBoldEmpty, Sample.invalidBoldOpen, Sample.invalidBoldDoubled] {
            let body = MessageMarkdown.resolveBubbleBody(
                content: input,
                linkColor: .blue,
                baseFont: .callout,
                inlineLinkAttributed: nil
            )
            guard case .plain(let text) = body.kind else {
                return XCTFail("Expected plain body for \(input)")
            }
            XCTAssertEqual(text, input)
            XCTAssertEqual(body.fallbackPlain, input)
        }
    }

    @available(iOS 15.0, *)
    func test_resolveBubbleBody_prefersInlineLinkWhenNoMarkdown() {
        let context = "\(Sample.phrase) \(Sample.linkURL)"
        var link = AttributedString(Sample.linkURL)
        link.link = URL(string: Sample.linkURL)
        let body = MessageMarkdown.resolveBubbleBody(
            content: context,
            linkColor: .blue,
            baseFont: .callout,
            inlineLinkAttributed: link
        )
        guard case .rich(let storage) = body.kind,
              let attributed = storage as? AttributedString else {
            return XCTFail("Expected rich body")
        }
        XCTAssertNotNil(attributed.runs.first?.link)
    }
}
