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

    /// What the page can be asked to do, and what the buttons stand for.
    enum Format: Hashable {
        case bold, italic, underline, strike
        case header(Int)
        case list(String)
        case align(String)
        case link, image, clear, undo, redo
    }

    /// A button was tapped: do what it stands for.
    var onFormat: ((Format) -> Void)?

    /// The address of the link under the caret, if there is one.
    private(set) var currentLink = ""

    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private var buttons = [Format: UIButton]()

    private static let height: CGFloat = 48
    private static let touchTarget: CGFloat = 44
    private static let buttonSpacing: CGFloat = 4
    private static let margin: CGFloat = 8
    private static let inactiveAlpha: CGFloat = 0.55

    init() {
        super.init(frame: .zero)
        self.setUp()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setUp() {
        self.backgroundColor = .jamiFormBackground
        self.scrollView.translatesAutoresizingMaskIntoConstraints = false
        self.scrollView.showsHorizontalScrollIndicator = false
        self.addSubview(self.scrollView)

        self.stack.axis = .horizontal
        self.stack.spacing = CollabFormatBar.buttonSpacing
        self.stack.alignment = .center
        self.stack.translatesAutoresizingMaskIntoConstraints = false
        self.scrollView.addSubview(self.stack)

        for item in CollabFormatBar.items {
            let button = self.makeButton(item)
            self.buttons[item.format] = button
            self.stack.addArrangedSubview(button)
        }

        let content = self.scrollView.contentLayoutGuide
        let frame = self.scrollView.frameLayoutGuide
        NSLayoutConstraint.activate([
            self.heightAnchor.constraint(equalToConstant: CollabFormatBar.height),
            self.scrollView.topAnchor.constraint(equalTo: self.topAnchor),
            self.scrollView.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            self.scrollView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            self.scrollView.trailingAnchor.constraint(equalTo: self.trailingAnchor),

            self.stack.topAnchor.constraint(equalTo: content.topAnchor),
            self.stack.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            self.stack.leadingAnchor.constraint(equalTo: content.leadingAnchor,
                                                constant: CollabFormatBar.margin),
            self.stack.trailingAnchor.constraint(equalTo: content.trailingAnchor,
                                                 constant: -CollabFormatBar.margin),
            self.stack.heightAnchor.constraint(equalTo: frame.heightAnchor)
        ])
    }

    private func makeButton(_ item: Item) -> UIButton {
        let button = UIButton(type: .system)
        if let symbol = item.symbol {
            button.setImage(UIImage(systemName: symbol), for: .normal)
        } else {
            button.setTitle(item.title, for: .normal)
            button.titleLabel?.font = .preferredFont(forTextStyle: .headline)
            button.titleLabel?.adjustsFontForContentSizeCategory = true
        }
        button.accessibilityLabel = item.label
        button.alpha = CollabFormatBar.inactiveAlpha
        button.tintColor = .jamiPrimaryControl
        button.translatesAutoresizingMaskIntoConstraints = false
        let side = CollabFormatBar.touchTarget
        button.widthAnchor.constraint(greaterThanOrEqualToConstant: side).isActive = true
        button.heightAnchor.constraint(equalToConstant: side).isActive = true
        button.addAction(UIAction { [weak self] _ in self?.onFormat?(item.format) },
                         for: .touchUpInside)
        return button
    }

    /// Lights up the buttons that describe the text under the caret, as the
    /// page reports it.
    func show(_ formats: [String: Any]) {
        self.currentLink = formats["link"] as? String ?? ""

        let header = formats["header"] as? Int ?? 0
        let list = formats["list"] as? String ?? ""
        let align = formats["align"] as? String ?? ""

        func active(_ format: Format) -> Bool {
            switch format {
            case .bold: return formats["bold"] as? Bool ?? false
            case .italic: return formats["italic"] as? Bool ?? false
            case .underline: return formats["underline"] as? Bool ?? false
            case .strike: return formats["strike"] as? Bool ?? false
            case .header(let level): return header == level
            case .list(let kind): return list == kind
            // Left alignment is the absence of the attribute.
            case .align(let side): return side == "left" ? align.isEmpty : align == side
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

    // MARK: - Buttons

    private struct Item {
        let format: Format
        let symbol: String?
        let title: String?
        let label: String

        init(_ format: Format, symbol: String? = nil, title: String? = nil, label: String) {
            self.format = format
            self.symbol = symbol
            self.title = title
            self.label = label
        }
    }

    private static let items: [Item] = [
        Item(.bold, symbol: "bold", label: L10n.Collab.bold),
        Item(.italic, symbol: "italic", label: L10n.Collab.italic),
        Item(.underline, symbol: "underline", label: L10n.Collab.underline),
        Item(.strike, symbol: "strikethrough", label: L10n.Collab.strikethrough),
        Item(.header(1), title: "H1", label: L10n.Collab.heading(1)),
        Item(.header(2), title: "H2", label: L10n.Collab.heading(2)),
        Item(.header(3), title: "H3", label: L10n.Collab.heading(3)),
        Item(.list("bullet"), symbol: "list.bullet", label: L10n.Collab.bulletList),
        Item(.list("ordered"), symbol: "list.number", label: L10n.Collab.orderedList),
        Item(.align("left"), symbol: "text.alignleft", label: L10n.Collab.alignLeft),
        Item(.align("center"), symbol: "text.aligncenter", label: L10n.Collab.alignCenter),
        Item(.align("right"), symbol: "text.alignright", label: L10n.Collab.alignRight),
        Item(.align("justify"), symbol: "text.justify", label: L10n.Collab.alignJustify),
        Item(.link, symbol: "link", label: L10n.Collab.linkTitle),
        Item(.image, symbol: "photo", label: L10n.Collab.insertImage),
        Item(.clear, symbol: "textformat", label: L10n.Collab.clearFormat),
        Item(.undo, symbol: "arrow.uturn.backward", label: L10n.Collab.undo),
        Item(.redo, symbol: "arrow.uturn.forward", label: L10n.Collab.redo)
    ]
}
