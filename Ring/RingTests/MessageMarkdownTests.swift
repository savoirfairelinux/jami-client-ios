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

    func test_containsRenderableMarkdown_invalidBold_returnsFalse() {
        for input in [Sample.invalidBoldEmpty, Sample.invalidBoldOpen, Sample.invalidBoldDoubled] {
            XCTAssertFalse(MessageMarkdownSupport.containsRenderableMarkdown(in: input))
        }
    }

    func test_containsRenderableMarkdown_literals_returnFalse() {
        for input in [
            Sample.literalMath,
            Sample.literalProduct,
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
    }

    func test_requiresFullSyntax_inlineBold_returnsFalse() {
        XCTAssertFalse(MessageMarkdownSupport.requiresFullSyntax(in: Sample.bold))
    }

    func test_syntaxMode_boldOnly_isInline() {
        XCTAssertEqual(
            MessageMarkdownSupport.syntaxMode(for: Sample.bold),
            .inlineOnlyPreservingWhitespace
        )
    }

    func test_syntaxMode_heading_isFull() {
        XCTAssertEqual(
            MessageMarkdownSupport.syntaxMode(for: Sample.heading),
            .full
        )
    }

    // MARK: - MessageMarkdownPlainText — valid constructs

    func test_display_plainText_unchanged() {
        XCTAssertEqual(MessageMarkdownPlainText.display(from: Sample.phrase), Sample.phrase)
    }

    func test_preview_stripsInlineMarkers() {
        XCTAssertEqual(MessageMarkdownPlainText.preview(from: Sample.boldInPhrase), "\(Sample.phrase) \(Sample.text)")
        XCTAssertEqual(MessageMarkdownPlainText.preview(from: Sample.italicInPhrase), "\(Sample.phrase) \(Sample.text)")
        XCTAssertEqual(MessageMarkdownPlainText.preview(from: Sample.boldItalic), Sample.text)
        XCTAssertEqual(MessageMarkdownPlainText.preview(from: Sample.strike), Sample.text)
        XCTAssertEqual(MessageMarkdownPlainText.preview(from: Sample.underscoreBold), Sample.text)
        XCTAssertEqual(MessageMarkdownPlainText.preview(from: Sample.inlineCode), Sample.text)
    }

    func test_preview_stripsLinkSyntax() {
        XCTAssertEqual(MessageMarkdownPlainText.preview(from: Sample.linkInPhrase), "\(Sample.phrase) \(Sample.text)")
    }

    func test_preview_stripsBlockMarkers() {
        XCTAssertEqual(MessageMarkdownPlainText.preview(from: Sample.heading), Sample.text)
        XCTAssertEqual(MessageMarkdownPlainText.preview(from: Sample.blockquoteMultiline), "\(Sample.text)\n\(Sample.text)")
        XCTAssertEqual(MessageMarkdownPlainText.preview(from: Sample.fencedCode), Sample.text)
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
            XCTAssertEqual(MessageMarkdownPlainText.display(from: input), input)
        }
    }

    func test_display_literals_unchanged() {
        for input in [
            Sample.literalMath,
            Sample.literalProduct,
            Sample.literalHashTag,
            Sample.literalSnakeCase,
            Sample.literalBracket,
            Sample.literalDecimal
        ] {
            XCTAssertEqual(MessageMarkdownPlainText.display(from: input), input)
        }
    }

    func test_display_voiceOverSpokenText_stripsValidMarkdown() {
        XCTAssertEqual(MessageMarkdownPlainText.display(from: Sample.bold), Sample.text)
        XCTAssertEqual(MessageMarkdownPlainText.display(from: Sample.linkInPhrase), "\(Sample.phrase) \(Sample.text)")
    }

    // MARK: - MessageMarkdown rendering

    @available(iOS 15.0, *)
    func test_attributedString_heading_stripsHashMarkers() {
        let result = MessageMarkdown.attributedString(from: Sample.heading, linkColor: .blue, baseFont: .callout)
        XCTAssertNotNil(result)
        XCTAssertTrue(String(result!.characters).contains(Sample.text))
        XCTAssertFalse(String(result!.characters).contains("#"))
    }

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
