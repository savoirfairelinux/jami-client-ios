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
    var fonts = [Font]()

    /// The address of the link under the caret, if there is one.
    private(set) var currentLink = ""
    private var currentHeader = 0
    private var currentFont = ""
    private var currentSize: Double = 0
    /// The size, in points, of text with none of its own, as the page says.
    private var baseSize: Double = 0
    private var currentAlign = ""
    private var activeFormats = Set<Format>()

    private let capsule = CollabFormatBar.makeCapsule()
    private let stack = UIStackView()
    private var buttons = [Format: UIButton]()
    private var wideOnly = [UIView]()

    private static let capsuleHeight: CGFloat = 48
    private static let capsuleInset: CGFloat = 4
    private static let touchTarget: CGFloat = 44
    private static let selectionSide: CGFloat = 34
    private static let groupSpacing: CGFloat = 4
    private static let margin: CGFloat = 8
    private static let separatorHeight: CGFloat = 24
    private static let symbolConfiguration = UIImage.SymbolConfiguration(pointSize: 17)

    init() {
        super.init(frame: .zero)
        self.setUp()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setUp() {
        self.backgroundColor = .clear
        self.addInteraction(UILargeContentViewerInteraction())

        if #unavailable(iOS 26.0) {
            self.layer.shadowColor = UIColor.black.cgColor
            self.layer.shadowOpacity = 0.12
            self.layer.shadowRadius = 8
            self.layer.shadowOffset = CGSize(width: 0, height: 2)
        }
        self.stack.alignment = .center
        [self.capsule, self.stack].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        self.addSubview(self.capsule)
        self.capsule.contentView.addSubview(self.stack)

        self.stack.addArrangedSubview(self.makeFormatMenu())
        for group in CollabFormatBar.groups {
            let views = [self.makeSeparator()] + group.buttons.map { self.makeButton($0) }
            views.forEach { self.stack.addArrangedSubview($0) }
            if group.isWideOnly { self.wideOnly += views }
        }
        self.showWideOnly(false)

        let guide = self.safeAreaLayoutGuide
        let content = self.capsule.contentView
        let margin = CollabFormatBar.margin
        let inset = CollabFormatBar.capsuleInset
        NSLayoutConstraint.activate([
            self.capsule.heightAnchor.constraint(equalToConstant: CollabFormatBar.capsuleHeight),
            self.capsule.topAnchor.constraint(equalTo: self.topAnchor, constant: margin),
            self.capsule.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -margin),
            self.capsule.centerXAnchor.constraint(equalTo: guide.centerXAnchor),
            self.capsule.leadingAnchor.constraint(greaterThanOrEqualTo: guide.leadingAnchor, constant: margin),
            self.capsule.trailingAnchor.constraint(lessThanOrEqualTo: guide.trailingAnchor, constant: -margin),

            self.stack.centerYAnchor.constraint(equalTo: content.centerYAnchor),
            self.stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: inset),
            self.stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -inset)
        ])
    }

    private static var wideWidth: CGFloat {
        let groups = CollabFormatBar.groups
        let buttons = 1 + groups.reduce(0) { $0 + $1.buttons.count }
        return CGFloat(buttons) * CollabFormatBar.touchTarget
            + CGFloat(groups.count) * CollabFormatBar.separatorWidth
            + 2 * CollabFormatBar.capsuleInset
    }

    private static var separatorWidth: CGFloat {
        return 1 + 2 * CollabFormatBar.groupSpacing
    }

    private func showWideOnly(_ isWide: Bool) {
        guard self.wideOnly.first?.isHidden == isWide else { return }
        self.wideOnly.forEach { $0.isHidden = !isWide }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let available = self.safeAreaLayoutGuide.layoutFrame.width - 2 * CollabFormatBar.margin
        self.showWideOnly(available >= CollabFormatBar.wideWidth)
        self.layer.shadowPath = UIBezierPath(roundedRect: self.capsule.frame,
                                             cornerRadius: CollabFormatBar.capsuleHeight / 2).cgPath
    }

    /// Shows what the text under the caret has, as the page reports it, with
    /// the size of text that has none of its own.
    func show(_ formats: [String: Any], baseSize: Double) {
        self.currentLink = formats["link"] as? String ?? ""
        self.currentHeader = formats["header"] as? Int ?? 0
        self.currentFont = formats["font"] as? String ?? ""
        self.currentSize = formats["size"] as? Double ?? 0
        self.baseSize = baseSize
        self.currentAlign = formats["align"] as? String ?? ""

        var active = Set<Format>()
        let attributes: [(String, Format)] = [("bold", .bold), ("italic", .italic),
                                              ("underline", .underline), ("strike", .strike)]
        for (name, format) in attributes where formats[name] as? Bool ?? false {
            active.insert(format)
        }
        if let list = formats["list"] as? String {
            active.insert(.list(list))
        }
        if !self.currentLink.isEmpty {
            active.insert(.link)
        }
        self.activeFormats = active

        for (format, button) in self.buttons {
            button.isSelected = active.contains(format)
        }
    }
}

// MARK: - The controls

extension CollabFormatBar {

    private static func makeCapsule() -> UIVisualEffectView {
        if #available(iOS 26.0, *) {
            let view = UIVisualEffectView(effect: UIGlassEffect())
            view.cornerConfiguration = .capsule()
            return view
        }
        let view = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
        view.layer.cornerRadius = CollabFormatBar.capsuleHeight / 2
        view.layer.cornerCurve = .continuous
        view.clipsToBounds = true
        return view
    }

    private func makeIconButton(symbol: UIImage?, label: String) -> UIButton {
        var configuration = UIButton.Configuration.plain()
        configuration.image = symbol
        configuration.preferredSymbolConfigurationForImage = CollabFormatBar.symbolConfiguration
        configuration.baseForegroundColor = .jamiPrimaryControl
        configuration.contentInsets = .zero
        let side = CollabFormatBar.selectionSide
        let inset = (CollabFormatBar.touchTarget - side) / 2
        configuration.cornerStyle = .fixed
        configuration.background.cornerRadius = side / 2
        configuration.background.backgroundInsets = NSDirectionalEdgeInsets(
            top: inset, leading: inset, bottom: inset, trailing: inset)
        let button = UIButton(configuration: configuration)
        button.configurationUpdateHandler = { button in
            button.configuration?.background.backgroundColor = button.isSelected ? .secondarySystemFill : .clear
        }
        button.accessibilityLabel = label
        button.showsLargeContentViewer = true
        button.largeContentTitle = label
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: CollabFormatBar.touchTarget),
            button.heightAnchor.constraint(equalToConstant: CollabFormatBar.touchTarget)
        ])
        return button
    }

    private func makeButton(_ item: Button) -> UIButton {
        let button = self.makeIconButton(symbol: item.image, label: item.label)
        button.addAction(UIAction { [weak self] _ in self?.onFormat?(item.format) },
                         for: .touchUpInside)
        self.buttons[item.format] = button
        return button
    }

    private func makeFormatMenu() -> UIButton {
        let button = self.makeIconButton(symbol: UIImage(systemName: "textformat"),
                                         label: L10n.Collab.textFormat)
        button.showsMenuAsPrimaryAction = true
        if #available(iOS 16.0, *) {
            button.preferredMenuElementOrder = .fixed
        }
        button.menu = UIMenu(children: [
            UIDeferredMenuElement.uncached { [weak self] completion in
                completion(self?.formatMenu() ?? [])
            }
        ])
        return button
    }

    private func makeSeparator() -> UIView {
        let container = UIView()
        let line = UIView()
        line.backgroundColor = .separator
        [container, line].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        container.addSubview(line)
        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(equalToConstant: CollabFormatBar.separatorWidth),
            container.heightAnchor.constraint(equalToConstant: CollabFormatBar.separatorHeight),
            line.widthAnchor.constraint(equalToConstant: 1),
            line.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            line.topAnchor.constraint(equalTo: container.topAnchor),
            line.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        return container
    }
}

// MARK: - The text format menu

extension CollabFormatBar {

    private func paragraphStyleName(_ level: Int) -> String {
        return level == 0 ? L10n.Collab.normalText : L10n.Collab.heading(level)
    }

    /// A font this client does not offer is shown as unavailable: a newer client chose it.
    private var currentFontName: String {
        if self.currentFont.isEmpty { return L10n.Collab.defaultFont }
        return self.fonts.first { $0.id == self.currentFont }?.family ?? L10n.Collab.unavailableFont
    }

    private func sizeName(_ size: Double) -> String {
        return CollabFormatBar.sizeFormatter.string(from: NSNumber(value: size)) ?? String(size)
    }

    private var currentAlignment: Alignment {
        let alignments = CollabFormatBar.alignments
        return alignments.first { $0.value == self.currentAlign } ?? alignments[0]
    }

    private func value(of chooser: Chooser) -> String {
        switch chooser {
        case .paragraphStyle:
            return self.paragraphStyleName(self.currentHeader)
        case .font:
            return self.currentFontName
        case .size:
            if self.currentSize > 0 { return self.sizeName(self.currentSize) }
            return self.baseSize > 0 ? self.sizeName(self.baseSize) : L10n.Collab.defaultSize
        }
    }

    private func formatMenu() -> [UIMenuElement] {
        let choosers = Chooser.allCases.map { chooser -> UIMenuElement in
            let menu = UIMenu(title: chooser.label, children: self.choices(for: chooser))
            menu.subtitle = self.value(of: chooser)
            return menu
        }
        let alignments = CollabFormatBar.alignments.map { alignment in
            self.choice(alignment.label, .align(alignment.value), symbol: alignment.symbol,
                        isCurrent: alignment.value == self.currentAlignment.value)
        }
        return [
            self.palette(CollabFormatBar.marks.map { self.action(for: $0) }),
            UIMenu(options: .displayInline, children: choosers),
            self.palette(alignments),
            UIMenu(options: .displayInline, children: CollabFormatBar.lists.map { self.action(for: $0) }),
            self.action(for: CollabFormatBar.clear)
        ]
    }

    private func palette(_ children: [UIMenuElement]) -> UIMenu {
        let menu = UIMenu(options: .displayInline, children: children)
        if #available(iOS 16.0, *) {
            menu.preferredElementSize = .small
        }
        return menu
    }

    private func action(for item: Button) -> UIAction {
        return UIAction(title: item.label, image: item.image,
                        state: self.activeFormats.contains(item.format) ? .on : .off) { [weak self] _ in
            self?.onFormat?(item.format)
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
                self.choice(L10n.Collab.defaultSize, .size(0), isCurrent: self.currentSize == 0),
                UIMenu(options: .displayInline, children: sizes)
            ]
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
        let symbols: [String]
        let label: String

        init(_ format: Format, symbols: String..., label: String) {
            self.format = format
            self.symbols = symbols
            self.label = label
        }

        var image: UIImage? {
            return self.symbols.lazy.compactMap { UIImage(systemName: $0) }.first
        }
    }

    /// The lists of the text format menu, as on the desktop.
    private enum Chooser: CaseIterable {
        case paragraphStyle, font, size

        var label: String {
            switch self {
            case .paragraphStyle: return L10n.Collab.paragraphStyle
            case .font: return L10n.Collab.font
            case .size: return L10n.Collab.fontSize
            }
        }
    }

    private struct Group {
        let buttons: [Button]
        var isWideOnly = false
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

    private static let marks: [Button] = [
        Button(.bold, symbols: "bold", label: L10n.Collab.bold),
        Button(.italic, symbols: "italic", label: L10n.Collab.italic),
        Button(.underline, symbols: "underline", label: L10n.Collab.underline),
        Button(.strike, symbols: "strikethrough", label: L10n.Collab.strikethrough)
    ]

    private static let lists: [Button] = [
        Button(.list("bullet"), symbols: "list.bullet", label: L10n.Collab.bulletList),
        Button(.list("ordered"), symbols: "list.number", label: L10n.Collab.orderedList)
    ]

    private static let clear = Button(.clear, symbols: "eraser", "clear", label: L10n.Collab.clearFormat)

    /// After the text format menu: how the text is emphasized, where there is
    /// room, then how its paragraphs are laid out, what it holds, and its history.
    private static let groups: [Group] = [
        Group(buttons: Array(CollabFormatBar.marks.prefix(3)) + [CollabFormatBar.clear], isWideOnly: true),
        Group(buttons: CollabFormatBar.lists),
        Group(buttons: [Button(.link, symbols: "link", label: L10n.Collab.linkTitle),
                        Button(.image, symbols: "photo", label: L10n.Collab.insertImage)]),
        Group(buttons: [Button(.undo, symbols: "arrow.uturn.backward", label: L10n.Collab.undo),
                        Button(.redo, symbols: "arrow.uturn.forward", label: L10n.Collab.redo)])
    ]
}
