/*
 *  Copyright (C) 2004-2026 Savoir-faire Linux Inc.
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

import UIKit

/**
 The bar under a document: what the text under the caret looks like, and the
 buttons that change it.

 It does not talk to the page. What a button asks for is handed to `onFormat`,
 and what the page says of the text under the caret is given to `show(_:)`.
 */
class CollabFormatBar: UIView {

    /// What the page can be asked to do from the bar.
    enum Format: Hashable {
        case bold, italic, underline, strike
        case header(Int)
        case font(String)
        case size(Double)
        case list(String)
        case align(String)
        case link, image, clear, undo, redo
    }

    /// A font a document may name, as the page offers it.
    struct Font {
        let id: String
        let family: String
    }

    /// A button was tapped or a choice made: do what it stands for.
    var onFormat: ((Format) -> Void)?

    /// The fonts to choose from.
    var fonts = [Font]() {
        didSet { self.showChoices() }
    }

    /// The address of the link under the caret, if there is one.
    private(set) var currentLink = ""
    private var currentHeader = 0
    private var currentFont = ""
    private var currentSize: Double = 0
    private var currentAlign = ""

    private let rowStack = UIStackView()
    /// The rows of the bar: one where it all fits, two on a narrow screen.
    private var rows = [FormatRow]()
    /// The bar's controls in desktop order; a separator is drawn anew on each row.
    private var controls = [(item: Item, view: UIView?)]()
    private var buttons = [Format: UIButton]()
    private var choosers = [Chooser: UIButton]()
    private var iconWidths = [NSLayoutConstraint]()
    private var heightConstraint: NSLayoutConstraint!
    private var isSplit: Bool?

    private static let height: CGFloat = 48
    private static let touchTarget: CGFloat = 44
    /// A phone's row of buttons is as tall to touch, a little narrower.
    private static let compactIconWidth: CGFloat = 38
    private static let buttonSpacing: CGFloat = 4
    private static let margin: CGFloat = 8
    private static let inactiveAlpha: CGFloat = 0.55
    private static let chooserMaxWidth: CGFloat = 160
    private static let separatorHeight: CGFloat = 24

    init() {
        super.init(frame: .zero)
        self.setUp()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setUp() {
        self.backgroundColor = .jamiFormBackground
        self.rowStack.axis = .vertical
        self.rowStack.distribution = .fillEqually
        self.rowStack.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(self.rowStack)

        self.rows = (0..<2).map { _ in FormatRow() }
        self.rows.forEach { self.rowStack.addArrangedSubview($0.scrollView) }

        for item in CollabFormatBar.items {
            switch item {
            case .button(let button):
                let view = self.makeButton(button)
                self.buttons[button.format] = view
                self.controls.append((item, view))
            case .chooser(let chooser):
                let view = self.makeChooser(chooser)
                self.choosers[chooser] = view
                self.controls.append((item, view))
            case .separator:
                self.controls.append((item, nil))
            }
        }
        self.showChoices()

        self.heightConstraint = self.heightAnchor.constraint(equalToConstant: CollabFormatBar.height)
        NSLayoutConstraint.activate([
            self.heightConstraint,
            self.rowStack.topAnchor.constraint(equalTo: self.topAnchor),
            self.rowStack.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            self.rowStack.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            self.rowStack.trailingAnchor.constraint(equalTo: self.trailingAnchor)
        ])
        self.arrange()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        self.arrange()
    }

    /// Shows what the text under the caret has, as the page reports it.
    func show(_ formats: [String: Any]) {
        self.currentLink = formats["link"] as? String ?? ""
        self.currentHeader = formats["header"] as? Int ?? 0
        self.currentFont = formats["font"] as? String ?? ""
        self.currentSize = formats["size"] as? Double ?? 0
        self.currentAlign = formats["align"] as? String ?? ""
        self.showChoices()

        let list = formats["list"] as? String ?? ""

        func active(_ format: Format) -> Bool {
            switch format {
            case .bold: return formats["bold"] as? Bool ?? false
            case .italic: return formats["italic"] as? Bool ?? false
            case .underline: return formats["underline"] as? Bool ?? false
            case .strike: return formats["strike"] as? Bool ?? false
            case .list(let kind): return list == kind
            case .link: return !self.currentLink.isEmpty
            default: return false
            }
        }

        for (format, button) in self.buttons {
            let selected = active(format)
            button.isSelected = selected
            button.alpha = selected ? 1 : CollabFormatBar.inactiveAlpha
        }
    }
}

// MARK: - Rows

extension CollabFormatBar {

    /**
     The whole bar fits on one row of a wide screen, in the desktop's order. A
     phone has no room for it: the choosers and undo go on top and the rest of
     the buttons below, each row spread to the width, so none is out of sight.
     */
    private func arrange() {
        let split = self.traitCollection.horizontalSizeClass != .regular
        guard split != self.isSplit else { return }
        self.isSplit = split

        let views: [[UIView]]
        if split {
            let top = self.controls.filter { CollabFormatBar.isOnTopRow($0.item) != false }
            let bottom = self.controls.filter { CollabFormatBar.isOnTopRow($0.item) != true }
            views = [self.rowViews(top), self.rowViews(bottom)]
        } else {
            views = [self.rowViews(self.controls), []]
        }
        self.rows.forEach { $0.clear() }
        for (row, rowViews) in zip(self.rows, views) {
            row.show(rowViews, spread: split)
        }
        let iconWidth = split ? CollabFormatBar.compactIconWidth : CollabFormatBar.touchTarget
        self.iconWidths.forEach { $0.constant = iconWidth }
        self.heightConstraint.constant = CollabFormatBar.height
            * CGFloat(views.filter { !$0.isEmpty }.count)
    }

    /// Which row of a phone's bar an item is on; a separator may be on either.
    private static func isOnTopRow(_ item: Item) -> Bool? {
        switch item {
        case .chooser:
            return true
        case .button(let button):
            return button.format == .undo || button.format == .redo
        case .separator:
            return nil
        }
    }

    /// Separators only stand between groups that are both on the row.
    private func rowViews(_ items: [(item: Item, view: UIView?)]) -> [UIView] {
        var views = [UIView]()
        var separatorPending = false
        for (_, view) in items {
            guard let view = view else {
                separatorPending = !views.isEmpty
                continue
            }
            if separatorPending {
                views.append(self.makeSeparator())
                separatorPending = false
            }
            views.append(view)
        }
        return views
    }

    /**
     One row of the bar. What does not fit can still be scrolled to; on a phone
     the row is spread to the width, and its choosers give up room to the
     buttons before it scrolls.
     */
    private final class FormatRow {
        let scrollView = UIScrollView()
        private let stack = UIStackView()
        private var fillWidth = [NSLayoutConstraint]()

        init() {
            self.scrollView.showsHorizontalScrollIndicator = false
            self.stack.axis = .horizontal
            self.stack.alignment = .center
            self.stack.translatesAutoresizingMaskIntoConstraints = false
            self.scrollView.addSubview(self.stack)

            let content = self.scrollView.contentLayoutGuide
            let frame = self.scrollView.frameLayoutGuide
            let margin = CollabFormatBar.margin
            let spread = self.stack.widthAnchor
                .constraint(equalTo: frame.widthAnchor, constant: -2 * margin)
            spread.priority = .defaultHigh
            self.fillWidth = [
                self.stack.widthAnchor
                    .constraint(greaterThanOrEqualTo: frame.widthAnchor, constant: -2 * margin),
                spread
            ]
            NSLayoutConstraint.activate([
                self.stack.topAnchor.constraint(equalTo: content.topAnchor),
                self.stack.bottomAnchor.constraint(equalTo: content.bottomAnchor),
                self.stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: margin),
                self.stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -margin),
                self.stack.heightAnchor.constraint(equalTo: frame.heightAnchor)
            ])
        }

        func clear() {
            self.stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        }

        func show(_ views: [UIView], spread: Bool) {
            views.forEach { self.stack.addArrangedSubview($0) }
            self.scrollView.isHidden = views.isEmpty
            self.stack.distribution = spread ? .equalSpacing : .fill
            self.stack.spacing = spread ? 0 : CollabFormatBar.buttonSpacing
            if spread {
                NSLayoutConstraint.activate(self.fillWidth)
            } else {
                NSLayoutConstraint.deactivate(self.fillWidth)
            }
        }
    }
}

// MARK: - The controls

extension CollabFormatBar {

    private func makeButton(_ item: Button) -> UIButton {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: item.symbol), for: .normal)
        button.accessibilityLabel = item.label
        button.alpha = CollabFormatBar.inactiveAlpha
        button.tintColor = .jamiPrimaryControl
        button.translatesAutoresizingMaskIntoConstraints = false
        let side = CollabFormatBar.touchTarget
        let width = button.widthAnchor.constraint(greaterThanOrEqualToConstant: side)
        width.isActive = true
        self.iconWidths.append(width)
        button.heightAnchor.constraint(equalToConstant: side).isActive = true
        button.addAction(UIAction { [weak self] _ in self?.onFormat?(item.format) },
                         for: .touchUpInside)
        return button
    }

    /**
     A button that opens the list it chooses from. The list is built when it
     opens, so that it ticks what the text under the caret has then.
     */
    private func makeChooser(_ chooser: Chooser) -> UIButton {
        let spacing = CollabFormatBar.buttonSpacing
        var configuration = UIButton.Configuration.plain()
        configuration.titleLineBreakMode = .byTruncatingTail
        configuration.imagePlacement = .trailing
        configuration.imagePadding = spacing
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: spacing,
                                                              bottom: 0, trailing: spacing)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = .preferredFont(forTextStyle: .subheadline)
            return attributes
        }
        let button = UIButton(configuration: configuration)
        button.tintColor = .jamiPrimaryControl
        button.accessibilityLabel = chooser.label
        button.showsMenuAsPrimaryAction = true
        button.menu = UIMenu(children: [
            UIDeferredMenuElement.uncached { [weak self] completion in
                completion(self?.choices(for: chooser) ?? [])
            }
        ])
        button.translatesAutoresizingMaskIntoConstraints = false
        // On a narrow row the names are what gives way, not the buttons.
        button.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let side = CollabFormatBar.touchTarget
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(greaterThanOrEqualToConstant: side),
            button.widthAnchor.constraint(lessThanOrEqualToConstant: CollabFormatBar.chooserMaxWidth),
            button.heightAnchor.constraint(equalToConstant: side)
        ])
        return button
    }

    private func makeSeparator() -> UIView {
        let line = UIView()
        line.backgroundColor = .separator
        line.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            line.widthAnchor.constraint(equalToConstant: 1),
            line.heightAnchor.constraint(equalToConstant: CollabFormatBar.separatorHeight)
        ])
        return line
    }
}

// MARK: - Choosing a style, a font, a size, an alignment

extension CollabFormatBar {

    private func paragraphStyleName(_ level: Int) -> String {
        return level == 0 ? L10n.Collab.normalText : L10n.Collab.heading(level)
    }

    /// A font this client does not ship is named by its id: a newer client chose it.
    private var currentFontName: String {
        if self.currentFont.isEmpty { return L10n.Collab.defaultFont }
        return self.fonts.first { $0.id == self.currentFont }?.family ?? self.currentFont
    }

    private func sizeName(_ size: Double) -> String {
        return CollabFormatBar.sizeFormatter.string(from: NSNumber(value: size)) ?? String(size)
    }

    private var currentAlignment: Alignment {
        let alignments = CollabFormatBar.alignments
        return alignments.first { $0.value == self.currentAlign } ?? alignments[0]
    }

    /// Shows on each chooser what the text under the caret has.
    private func showChoices() {
        let chevron = UIImage(systemName: "chevron.down",
                              withConfiguration: UIImage.SymbolConfiguration(textStyle: .caption2))
        for (chooser, button) in self.choosers {
            var title: String?
            var image = chevron
            let value: String
            switch chooser {
            case .paragraphStyle:
                value = self.paragraphStyleName(self.currentHeader)
                title = value
            case .font:
                value = self.currentFontName
                title = value
            case .size:
                // Text with no size of its own follows the reader's text size.
                if self.currentSize > 0 {
                    value = self.sizeName(self.currentSize)
                    title = value
                } else {
                    value = L10n.Collab.baseSize
                    image = UIImage(systemName: "textformat.size")
                }
            case .alignment:
                value = self.currentAlignment.label
                image = UIImage(systemName: self.currentAlignment.symbol)
            }
            button.configuration?.title = title
            button.configuration?.image = image
            button.accessibilityValue = value
        }
    }

    private func choices(for chooser: Chooser) -> [UIMenuElement] {
        switch chooser {
        case .paragraphStyle:
            return (0...3).map { level in
                self.choice(self.paragraphStyleName(level), .header(level),
                            isCurrent: self.currentHeader == level)
            }
        case .font:
            let fonts = self.fonts.map { font in
                self.choice(font.family, .font(font.id), isCurrent: self.currentFont == font.id)
            }
            return [
                self.choice(L10n.Collab.defaultFont, .font(""), isCurrent: self.currentFont.isEmpty),
                UIMenu(options: .displayInline, children: fonts)
            ]
        case .size:
            let sizes = CollabFormatBar.fontSizes.map { size in
                self.choice(self.sizeName(size), .size(size), isCurrent: self.currentSize == size)
            }
            return [
                self.choice(L10n.Collab.baseSize, .size(0), isCurrent: self.currentSize == 0),
                UIMenu(options: .displayInline, children: sizes)
            ]
        case .alignment:
            return CollabFormatBar.alignments.map { alignment in
                self.choice(alignment.label, .align(alignment.value),
                            symbol: alignment.symbol,
                            isCurrent: alignment.value == self.currentAlignment.value)
            }
        }
    }

    private func choice(_ title: String, _ format: Format,
                        symbol: String? = nil, isCurrent: Bool) -> UIAction {
        return UIAction(title: title,
                        image: symbol.flatMap { UIImage(systemName: $0) },
                        state: isCurrent ? .on : .off) { [weak self] _ in
            self?.onFormat?(format)
        }
    }
}

// MARK: - What the bar holds

extension CollabFormatBar {

    private struct Button {
        let format: Format
        let symbol: String
        let label: String

        init(_ format: Format, symbol: String, label: String) {
            self.format = format
            self.symbol = symbol
            self.label = label
        }
    }

    /// The buttons that open a list to choose from, as on the desktop.
    private enum Chooser: Hashable {
        case paragraphStyle, font, size, alignment

        var label: String {
            switch self {
            case .paragraphStyle: return L10n.Collab.paragraphStyle
            case .font: return L10n.Collab.font
            case .size: return L10n.Collab.fontSize
            case .alignment: return L10n.Collab.alignment
            }
        }
    }

    private enum Item {
        case button(Button)
        case chooser(Chooser)
        case separator
    }

    private struct Alignment {
        let value: String
        let symbol: String
        let label: String
    }

    /// The sizes offered, in points, as on the desktop.
    private static let fontSizes: [Double] = [8, 9, 10, 11, 12, 14, 16, 18, 20, 24, 28, 36, 48, 72]

    private static let sizeFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    /// Left is the default, and is written as the absence of the attribute.
    private static let alignments: [Alignment] = [
        Alignment(value: "left", symbol: "text.alignleft", label: L10n.Collab.alignLeft),
        Alignment(value: "center", symbol: "text.aligncenter", label: L10n.Collab.alignCenter),
        Alignment(value: "right", symbol: "text.alignright", label: L10n.Collab.alignRight),
        Alignment(value: "justify", symbol: "text.justify", label: L10n.Collab.alignJustify)
    ]

    /// In the order of the desktop client's bar: what the text looks like, then
    /// how it is emphasized, how its paragraphs are laid out, and what it holds.
    private static let items: [Item] = [
        .chooser(.paragraphStyle),
        .chooser(.font),
        .chooser(.size),
        .separator,
        .button(Button(.bold, symbol: "bold", label: L10n.Collab.bold)),
        .button(Button(.italic, symbol: "italic", label: L10n.Collab.italic)),
        .button(Button(.underline, symbol: "underline", label: L10n.Collab.underline)),
        .button(Button(.strike, symbol: "strikethrough", label: L10n.Collab.strikethrough)),
        .separator,
        .chooser(.alignment),
        .button(Button(.list("bullet"), symbol: "list.bullet", label: L10n.Collab.bulletList)),
        .button(Button(.list("ordered"), symbol: "list.number", label: L10n.Collab.orderedList)),
        .separator,
        .button(Button(.link, symbol: "link", label: L10n.Collab.linkTitle)),
        .button(Button(.image, symbol: "photo", label: L10n.Collab.insertImage)),
        .button(Button(.clear, symbol: "textformat", label: L10n.Collab.clearFormat)),
        .separator,
        .button(Button(.undo, symbol: "arrow.uturn.backward", label: L10n.Collab.undo)),
        .button(Button(.redo, symbol: "arrow.uturn.forward", label: L10n.Collab.redo))
    ]
}
