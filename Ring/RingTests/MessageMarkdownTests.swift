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

// swiftlint:disable type_body_length
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
        static var blockquoteWithURL: String { "> see \(linkURL)" }
        static var headingWithURL: String { "### Title \(linkURL)" }
        static var orderedListWithURL: String { "1. item \(linkURL)" }
        static var wwwMarkdownLink: String { "[\(text)](www.example.com)" }
        static var blockquoteMultiline: String { "> \(text)\n> \(text)" }
        static var fencedCode: String { "```\n\(text)\n```" }
        static var fencedCodeWithURL: String { "```\n\(linkURL)\n```" }
        static var fencedCodeWithMarkdown: String { "```\n**\(text)** [\(text)](\(linkURL))\n```" }
        static var fencedCodeWithListLine: String { "```\n1. not a list\n```" }
        static var inlineCodeWithMarkdown: String { "`**\(text)**`" }
        static var inlineCodeWithLink: String { "`[\(text)](\(linkURL))`" }
        static var inlineCodeWithURL: String { "`\(linkURL)`" }
        static var linkWithParenURL: String { "[\(text)](http://x.com/a(b))" }
        static var linkWithNestedParensURL: String { "[t](http://x.com/a(b)c(d))" }
        static let invalidLinkUnclosed = "[text](http://x.com/unclosed"
        static let emptyLabelLink = "[](https://example.com)"
        static var link: String { "[\(text)](\(linkURL))" }
        static var javascriptLink: String { "[\(text)](javascript:alert(1))" }
        static var telLink: String { "[\(text)](tel:1234567890)" }
        static var linkInPhrase: String { "\(phrase) [\(text)](\(linkURL))" }
        static var boldInPhrase: String { "\(phrase) **\(text)**" }
        static var italicInPhrase: String { "\(phrase) *\(text)*" }
        static var boldInPhraseSentence: String { "\(phrase) \(bold)" }
        static var boldWithBareURL: String { "**\(text)** \(linkURL)" }

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

    func test_stripValidConstructs_preservesFencedCodeLiterals() {
        let expected = "**\(Sample.text)** [\(Sample.text)](\(Sample.linkURL))"
        XCTAssertEqual(
            MessageMarkdownPlainText.stripValidConstructs(from: Sample.fencedCodeWithMarkdown),
            expected
        )
        XCTAssertEqual(
            MessageMarkdownPlainText.stripValidConstructs(from: Sample.fencedCodeWithListLine),
            "1. not a list"
        )
    }

    func test_stripValidConstructs_preservesInlineCodeLiterals() {
        XCTAssertEqual(
            MessageMarkdownPlainText.stripValidConstructs(from: Sample.inlineCodeWithMarkdown),
            "**\(Sample.text)**"
        )
        XCTAssertEqual(
            MessageMarkdownPlainText.stripValidConstructs(from: Sample.inlineCodeWithLink),
            "[\(Sample.text)](\(Sample.linkURL))"
        )
    }

    func test_stripMarkdownLinks_parenInURL() {
        XCTAssertEqual(MessageMarkdownSupport.stripMarkdownLinks(in: Sample.linkWithParenURL), Sample.text)
    }

    func test_stripMarkdownLinks_nestedParens() {
        XCTAssertEqual(MessageMarkdownSupport.stripMarkdownLinks(in: Sample.linkWithNestedParensURL), "t")
    }

    func test_stripMarkdownLinks_multipleLinks() {
        let input = "[one](https://one.example) and [two](https://two.example/path(a))"
        XCTAssertEqual(MessageMarkdownSupport.stripMarkdownLinks(in: input), "one and two")
    }

    func test_stripMarkdownLinks_disallowedSchemeUnchanged() {
        XCTAssertEqual(MessageMarkdownSupport.stripMarkdownLinks(in: Sample.javascriptLink), Sample.javascriptLink)
        XCTAssertEqual(MessageMarkdownSupport.stripMarkdownLinks(in: Sample.telLink), Sample.telLink)
    }

    func test_stripMarkdownLinks_malformedUnchanged() {
        XCTAssertEqual(MessageMarkdownSupport.stripMarkdownLinks(in: Sample.invalidLinkUnclosed), Sample.invalidLinkUnclosed)
    }

    func test_containsRenderableMarkdown_linkWithParenURL() {
        XCTAssertTrue(MessageMarkdownSupport.containsRenderableMarkdown(in: Sample.linkWithParenURL))
    }

    func test_containsRenderableMarkdown_disallowedLink_returnsFalse() {
        XCTAssertFalse(MessageMarkdownSupport.containsRenderableMarkdown(in: Sample.javascriptLink))
        XCTAssertFalse(MessageMarkdownSupport.containsRenderableMarkdown(in: Sample.telLink))
    }

    func test_markdownLinkRanges_emptyLabel_returnsEmpty() {
        XCTAssertTrue(MessageMarkdownSupport.markdownLinkRanges(in: Sample.emptyLabelLink).isEmpty)
    }

    func test_display_emptyLabelLink_unchanged() {
        XCTAssertFalse(MessageMarkdownSupport.containsRenderableMarkdown(in: Sample.emptyLabelLink))
        XCTAssertEqual(MessageMarkdown.displayText(from: Sample.emptyLabelLink), Sample.emptyLabelLink)
        XCTAssertEqual(
            MessageMarkdownSupport.stripMarkdownLinks(in: Sample.emptyLabelLink),
            Sample.emptyLabelLink
        )
    }

    func test_stripValidConstructs_placeholderCollision_reverseRestore() {
        let block0Body = "\u{FFFC}F1\u{FFFC}literal"
        let input = "```\n\(block0Body)\n```\n```\nsecond\n```"
        let expected = "\(block0Body)\nsecond"
        XCTAssertEqual(MessageMarkdownPlainText.stripValidConstructs(from: input), expected)
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
            hasInlineLinks: false
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
            hasInlineLinks: false
        )
        guard case .rich(let storage) = body.kind,
              let attributed = storage as? AttributedString else {
            return XCTFail("Expected rich body")
        }
        XCTAssertTrue(String(attributed.characters).contains(Sample.text))
        XCTAssertEqual(body.fallbackPlain, Sample.text)
    }

    func test_normalizedFullMessageURL_www() {
        XCTAssertEqual(
            MessageMarkdownSupport.normalizedFullMessageURL(from: "www.example.com")?.absoluteString,
            "http://www.example.com"
        )
    }

    func test_normalizedFullMessageURL_rejectsDisallowedSchemes() {
        XCTAssertNil(MessageMarkdownSupport.normalizedFullMessageURL(from: "javascript:alert(1)"))
    }

    @available(iOS 15.0, *)
    func test_resolveBubbleBody_fencedCodeWithURL_returnsPlainLiteral() {
        let body = MessageMarkdown.resolveBubbleBody(
            content: Sample.fencedCodeWithURL,
            linkColor: .blue,
            baseFont: .callout,
            hasInlineLinks: true
        )
        guard case .plain(let text) = body.kind else {
            return XCTFail("Expected plain body for URL inside fenced code")
        }
        XCTAssertEqual(text, Sample.linkURL)
        XCTAssertEqual(body.fallbackPlain, Sample.linkURL)
    }

    @available(iOS 15.0, *)
    func test_resolveBubbleBody_fencedCodeWithMarkdown_preservesLiterals() {
        let expected = "**\(Sample.text)** [\(Sample.text)](\(Sample.linkURL))"
        let body = MessageMarkdown.resolveBubbleBody(
            content: Sample.fencedCodeWithMarkdown,
            linkColor: .blue,
            baseFont: .callout,
            hasInlineLinks: false
        )
        guard case .plain(let text) = body.kind else {
            return XCTFail("Expected plain body for fenced code")
        }
        XCTAssertEqual(text, expected)
        XCTAssertEqual(body.fallbackPlain, expected)
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
                hasInlineLinks: false
            )
            guard case .plain(let text) = body.kind else {
                return XCTFail("Expected plain body for block syntax: \(testCase.content)")
            }
            XCTAssertEqual(text, testCase.expected, "Content: \(testCase.content)")
            XCTAssertEqual(body.fallbackPlain, testCase.expected)
        }
    }

    @available(iOS 15.0, *)
    func test_resolveBubbleBody_blockSyntaxWithInlineLink_returnsPlain() {
        let cases: [(content: String, expectedDisplay: String)] = [
            (Sample.blockquoteWithURL, "see \(Sample.linkURL)"),
            (Sample.headingWithURL, "Title \(Sample.linkURL)"),
            (Sample.orderedListWithURL, "item \(Sample.linkURL)")
        ]
        for testCase in cases {
            let body = MessageMarkdown.resolveBubbleBody(
                content: testCase.content,
                linkColor: .blue,
                baseFont: .callout,
                hasInlineLinks: true
            )
            guard case .plain(let text) = body.kind else {
                return XCTFail("Expected plain body for block syntax with inline link: \(testCase.content)")
            }
            XCTAssertEqual(text, testCase.expectedDisplay, testCase.content)
            XCTAssertEqual(body.fallbackPlain, testCase.expectedDisplay, testCase.content)
        }
    }

    @available(iOS 15.0, *)
    func test_resolveBubbleBody_invalidBold_isPlainLiteral() {
        for input in [Sample.invalidBoldEmpty, Sample.invalidBoldOpen, Sample.invalidBoldDoubled] {
            let body = MessageMarkdown.resolveBubbleBody(
                content: input,
                linkColor: .blue,
                baseFont: .callout,
                hasInlineLinks: false
            )
            guard case .plain(let text) = body.kind else {
                return XCTFail("Expected plain body for \(input)")
            }
            XCTAssertEqual(text, input)
            XCTAssertEqual(body.fallbackPlain, input)
        }
    }

    @available(iOS 15.0, *)
    func test_resolveBubbleBody_disallowedMarkdownLink_isPlainLiteral() {
        let body = MessageMarkdown.resolveBubbleBody(
            content: Sample.javascriptLink,
            linkColor: .blue,
            baseFont: .callout,
            hasInlineLinks: false
        )
        guard case .plain(let text) = body.kind else {
            return XCTFail("Expected plain body for disallowed markdown link")
        }
        XCTAssertEqual(text, Sample.javascriptLink)
        XCTAssertEqual(body.fallbackPlain, Sample.javascriptLink)
    }

    @available(iOS 15.0, *)
    func test_attributedString_inlineCodeWithURL_doesNotAutolink() {
        guard let attributed = MessageMarkdown.attributedString(
            from: Sample.inlineCodeWithURL,
            linkColor: .blue
        ) else {
            return XCTFail("Expected attributed string for inline code URL")
        }
        XCTAssertFalse(attributed.runs.contains { $0.link != nil })
        XCTAssertTrue(attributed.runs.contains { $0.inlinePresentationIntent?.contains(.code) == true })
    }

    @available(iOS 15.0, *)
    func test_attributedString_bareURLOutsideCode_stillAutolinks() {
        guard let attributed = MessageMarkdown.attributedString(
            from: Sample.boldWithBareURL,
            linkColor: .blue
        ) else {
            return XCTFail("Expected attributed string for bare URL")
        }
        XCTAssertTrue(attributed.runs.contains { $0.link?.absoluteString == Sample.linkURL })
    }

    @available(iOS 15.0, *)
    func test_resolveBubbleBody_markdownWithBareURL_appliesLink() {
        let body = MessageMarkdown.resolveBubbleBody(
            content: Sample.boldWithBareURL,
            linkColor: .blue,
            baseFont: .callout,
            hasInlineLinks: false
        )
        guard case .rich(let storage) = body.kind,
              let attributed = storage as? AttributedString else {
            return XCTFail("Expected rich body")
        }
        XCTAssertTrue(attributed.runs.contains { $0.link?.absoluteString == Sample.linkURL })
    }

    func test_normalizedBubbleLinkURL_www() {
        XCTAssertEqual(
            MessageMarkdownSupport.normalizedBubbleLinkURL(URL(string: "www.example.com")!)?.absoluteString,
            "http://www.example.com"
        )
    }

    @available(iOS 15.0, *)
    func test_attributedString_markdownLink_wwwSchemeNormalized() {
        guard let attributed = MessageMarkdown.attributedString(from: Sample.wwwMarkdownLink, linkColor: .blue) else {
            return XCTFail("Expected attributed string for www markdown link")
        }
        XCTAssertTrue(attributed.runs.contains { $0.link?.scheme == "http" })
    }

    func test_isAllowedBubbleLinkURL_webSchemes() {
        XCTAssertTrue(MessageMarkdownSupport.isAllowedBubbleLinkURL(URL(string: "https://example.com")!))
        XCTAssertTrue(MessageMarkdownSupport.isAllowedBubbleLinkURL(URL(string: "http://example.com")!))
        XCTAssertFalse(MessageMarkdownSupport.isAllowedBubbleLinkURL(URL(string: "javascript:alert(1)")!))
        XCTAssertFalse(MessageMarkdownSupport.isAllowedBubbleLinkURL(URL(string: "tel:123")!))
    }

    @available(iOS 15.0, *)
    func test_attributedString_markdownLink_disallowedSchemeReturnsNil() {
        for input in [Sample.javascriptLink, Sample.telLink] {
            XCTAssertNil(MessageMarkdown.attributedString(from: input, linkColor: .blue), input)
        }
    }

    @available(iOS 15.0, *)
    func test_attributedString_markdownLink_httpsSchemeLinked() {
        guard let attributed = MessageMarkdown.attributedString(from: Sample.link, linkColor: .blue) else {
            return XCTFail("Expected attributed string for https markdown link")
        }
        XCTAssertTrue(attributed.runs.contains { $0.link?.scheme == "https" })
    }

    @available(iOS 15.0, *)
    func test_resolveBubbleBody_prefersInlineLinkWhenNoMarkdown() {
        let context = "\(Sample.phrase) \(Sample.linkURL)"
        let body = MessageMarkdown.resolveBubbleBody(
            content: context,
            linkColor: .blue,
            baseFont: .callout,
            hasInlineLinks: true
        )
        guard case .rich(let storage) = body.kind,
              let attributed = storage as? AttributedString else {
            return XCTFail("Expected rich body")
        }
        XCTAssertTrue(attributed.runs.contains { $0.link != nil })
        XCTAssertEqual(body.fallbackPlain, context)
    }
}
