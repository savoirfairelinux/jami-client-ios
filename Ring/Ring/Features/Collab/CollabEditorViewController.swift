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
import WebKit
import PhotosUI
import RxSwift
import RxRelay

/**
 A document of a conversation, opened for editing.

 The text itself lives in a web view. A shared document is a CRDT that the
 daemon moves around as opaque updates, and the replica that turns those
 updates into text has to agree, character for character and attribute for
 attribute, with the one the desktop client runs. Running the same library the
 other clients run is what makes that agreement a fact rather than an
 intention; reimplementing it in Swift would make it a hope.

 So this class carries updates and does not read them: bytes from the daemon go
 to the page, bytes from the page go to the daemon, and everything about what
 the document *says* stays on one side of that line.
 */
class CollabEditorViewController: UIViewController {

    private let viewModel: CollabEditorViewModel
    private let disposeBag = DisposeBag()

    private var webView: WKWebView!
    private var schemeHandler: CollabSchemeHandler!

    private let loadingView = UIActivityIndicatorView(style: .large)
    private let errorLabel = UILabel()

    private let formatBar = UIStackView()
    /// The rows of the bar: one where it all fits, two on a narrow screen.
    private var formatRows = [FormatRow]()
    /// The bar's controls in desktop order; a separator is drawn anew on each row.
    private var barViews = [(item: BarItem, view: UIView?)]()
    private var iconWidths = [NSLayoutConstraint]()
    private var barHeightConstraint: NSLayoutConstraint!
    private var isBarSplit: Bool?
    private let versionBar = UIStackView()
    private let versionLabel = UILabel()
    private let historyPanel = CollabHistoryPanel()

    private var buttons = [CollabFormat: UIButton]()
    private var choosers = [Chooser: UIButton]()
    private var barBottom: NSLayoutConstraint!

    /// The version list, on screen or just off the trailing edge.
    private var panelOpen: NSLayoutConstraint!
    private var panelClosed: NSLayoutConstraint!

    /// The document takes the whole width, or gives the list its share of it.
    private var webFullWidth: NSLayoutConstraint!
    private var webBesidePanel: NSLayoutConstraint!

    /// Updates produced by the page before it was allowed to talk to the daemon.
    private var pendingLocalUpdates = [String]()

    private var currentLink = ""
    private var currentHeader = 0
    private var currentFont = ""
    private var currentSize: Double = 0
    private var currentAlign = ""

    /// The fonts a document may name, as the page offers them.
    private var documentFonts = [DocumentFont]()

    private struct DocumentFont {
        let id: String
        let family: String
    }

    /// What the page can be asked to do, and what its buttons stand for.
    private enum CollabFormat: Hashable {
        case bold, italic, underline, strike
        case list(String)
        case link, image, clear, undo, redo
    }

    /// The buttons that open a list to choose from, as on the desktop.
    private enum Chooser: Hashable {
        case paragraphStyle, font, size, alignment
    }

    private enum BarItem {
        case format(FormatItem)
        case chooser(Chooser)
        case separator
    }

    init(viewModel: CollabEditorViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Life cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .systemBackground
        self.setUpNavigationBar()
        self.setUpWebView()
        self.setUpFormatBar()
        self.setUpVersionBar()
        self.setUpHistoryPanel()
        self.setUpStatusViews()
        self.bind()
        self.webView.load(URLRequest(url: CollabSchemeHandler.pageURL))
    }

    deinit {
        // The daemon has to know this replica is gone so the others stop
        // showing its caret.
        self.viewModel.close()
        self.webView?.configuration.userContentController
            .removeScriptMessageHandler(forName: CollabEditorViewController.bridgeName)
    }

    // MARK: - Views

    private func setUpNavigationBar() {
        self.showTitle()
        let close = UIBarButtonItem(title: L10n.Global.close,
                                    style: .plain,
                                    target: self,
                                    action: #selector(closeEditor))
        self.navigationItem.leftBarButtonItem = close
        let menu = UIBarButtonItem(image: UIImage(systemName: "ellipsis.circle"),
                                   style: .plain,
                                   target: self,
                                   action: #selector(showMenu))
        menu.accessibilityLabel = L10n.Collab.menu
        self.navigationItem.rightBarButtonItem = menu
    }

    @objc
    private func closeEditor() {
        self.dismiss(animated: true)
    }

    private func setUpWebView() {
        let configuration = WKWebViewConfiguration()
        self.schemeHandler = CollabSchemeHandler(viewModel: self.viewModel)
        configuration.setURLSchemeHandler(self.schemeHandler,
                                          forURLScheme: CollabSchemeHandler.scheme)
        configuration.userContentController.add(
            CollabWeakMessageHandler(self),
            name: CollabEditorViewController.bridgeName)
        // The document holds its own state; nothing about it belongs to this
        // device, so nothing of it is kept here between runs.
        configuration.websiteDataStore = .nonPersistent()

        self.webView = WKWebView(frame: .zero, configuration: configuration)
        self.webView.navigationDelegate = self
        self.webView.isOpaque = false
        self.webView.backgroundColor = .clear
        self.webView.scrollView.keyboardDismissMode = .interactive
        self.webView.isHidden = true
        self.webView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(self.webView)
    }

    private func setUpFormatBar() {
        self.formatBar.axis = .vertical
        self.formatBar.distribution = .fillEqually
        self.formatBar.translatesAutoresizingMaskIntoConstraints = false
        self.formatBar.backgroundColor = .jamiFormBackground
        self.view.addSubview(self.formatBar)

        self.formatRows = (0..<2).map { _ in FormatRow() }
        self.formatRows.forEach { self.formatBar.addArrangedSubview($0.scrollView) }

        for item in CollabEditorViewController.barItems {
            switch item {
            case .format(let format):
                let button = self.makeButton(format)
                self.buttons[format.format] = button
                self.barViews.append((item, button))
            case .chooser(let chooser):
                let button = self.makeChooser(chooser)
                self.choosers[chooser] = button
                self.barViews.append((item, button))
            case .separator:
                self.barViews.append((item, nil))
            }
        }
        self.showChoices()

        self.barBottom = self.formatBar.bottomAnchor
            .constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor)
        self.webFullWidth = self.webView.trailingAnchor
            .constraint(equalTo: self.view.trailingAnchor)
        self.barHeightConstraint = self.formatBar.heightAnchor
            .constraint(equalToConstant: CollabEditorViewController.barHeight)
        NSLayoutConstraint.activate([
            self.webView.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor),
            self.webView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            self.webFullWidth,
            self.webView.bottomAnchor.constraint(equalTo: self.formatBar.topAnchor),

            self.formatBar.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            self.formatBar.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            self.barHeightConstraint,
            self.barBottom
        ])
        self.arrangeFormatBar()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        self.arrangeFormatBar()
    }

    /**
     The whole bar fits on one row of a wide screen, in the desktop's order. A
     phone has no room for it: the choosers and undo go on top and the rest of
     the buttons below, each row spread to the width, so none is out of sight.
     */
    private func arrangeFormatBar() {
        let split = self.traitCollection.horizontalSizeClass != .regular
        guard split != self.isBarSplit else { return }
        self.isBarSplit = split

        let rows: [[UIView]]
        if split {
            let top = self.barViews.filter { CollabEditorViewController.isOnTopRow($0.item) != false }
            let bottom = self.barViews.filter { CollabEditorViewController.isOnTopRow($0.item) != true }
            rows = [self.rowViews(top), self.rowViews(bottom)]
        } else {
            rows = [self.rowViews(self.barViews), []]
        }
        self.formatRows.forEach { $0.clear() }
        for (row, views) in zip(self.formatRows, rows) {
            row.show(views, spread: split)
        }
        let iconWidth = split ? CollabEditorViewController.compactIconWidth
            : CollabEditorViewController.touchTarget
        self.iconWidths.forEach { $0.constant = iconWidth }
        self.barHeightConstraint.constant = CollabEditorViewController.barHeight
            * CGFloat(rows.filter { !$0.isEmpty }.count)
    }

    /// Which row of a phone's bar an item is on; a separator may be on either.
    private static func isOnTopRow(_ item: BarItem) -> Bool? {
        switch item {
        case .chooser:
            return true
        case .format(let format):
            return format.format == .undo || format.format == .redo
        case .separator:
            return nil
        }
    }

    /// Separators only stand between groups that are both on the row.
    private func rowViews(_ items: [(item: BarItem, view: UIView?)]) -> [UIView] {
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

    private func setUpVersionBar() {
        self.versionBar.axis = .horizontal
        self.versionBar.spacing = CollabEditorViewController.buttonSpacing
        self.versionBar.alignment = .center
        self.versionBar.isHidden = true
        self.versionBar.backgroundColor = .jamiFormBackground
        self.versionBar.isLayoutMarginsRelativeArrangement = true
        self.versionBar.layoutMargins = UIEdgeInsets(top: 0,
                                                     left: CollabEditorViewController.margin,
                                                     bottom: 0,
                                                     right: CollabEditorViewController.margin)
        self.versionBar.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(self.versionBar)

        self.versionLabel.font = .preferredFont(forTextStyle: .footnote)
        self.versionLabel.adjustsFontForContentSizeCategory = true
        self.versionLabel.numberOfLines = 2

        let leave = UIButton(type: .system)
        leave.setTitle(L10n.Collab.versionLeave, for: .normal)
        leave.titleLabel?.font = .preferredFont(forTextStyle: .footnote)
        leave.titleLabel?.adjustsFontForContentSizeCategory = true
        leave.addTarget(self, action: #selector(leaveVersion), for: .touchUpInside)

        let restore = UIButton(type: .system)
        restore.setTitle(L10n.Collab.versionRestore, for: .normal)
        restore.titleLabel?.font = .preferredFont(forTextStyle: .footnote)
        restore.titleLabel?.adjustsFontForContentSizeCategory = true
        restore.addTarget(self, action: #selector(restoreVersion), for: .touchUpInside)

        self.versionBar.addArrangedSubview(self.versionLabel)
        self.versionBar.addArrangedSubview(leave)
        self.versionBar.addArrangedSubview(restore)

        NSLayoutConstraint.activate([
            self.versionBar.leadingAnchor.constraint(equalTo: self.formatBar.leadingAnchor),
            self.versionBar.trailingAnchor.constraint(equalTo: self.formatBar.trailingAnchor),
            self.versionBar.topAnchor.constraint(equalTo: self.formatBar.topAnchor),
            self.versionBar.bottomAnchor.constraint(equalTo: self.formatBar.bottomAnchor)
        ])
    }

    private func setUpStatusViews() {
        self.loadingView.translatesAutoresizingMaskIntoConstraints = false
        self.loadingView.startAnimating()
        self.view.addSubview(self.loadingView)

        self.errorLabel.translatesAutoresizingMaskIntoConstraints = false
        self.errorLabel.font = .preferredFont(forTextStyle: .body)
        self.errorLabel.adjustsFontForContentSizeCategory = true
        self.errorLabel.textAlignment = .center
        self.errorLabel.numberOfLines = 0
        self.errorLabel.isHidden = true
        self.view.addSubview(self.errorLabel)

        NSLayoutConstraint.activate([
            self.loadingView.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            self.loadingView.centerYAnchor.constraint(equalTo: self.view.centerYAnchor),
            self.errorLabel.centerYAnchor.constraint(equalTo: self.view.centerYAnchor),
            self.errorLabel.leadingAnchor.constraint(equalTo: self.view.leadingAnchor,
                                                     constant: CollabEditorViewController.margin),
            self.errorLabel.trailingAnchor.constraint(equalTo: self.view.trailingAnchor,
                                                      constant: -CollabEditorViewController.margin)
        ])
    }

    private func makeButton(_ item: FormatItem) -> UIButton {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: item.symbol), for: .normal)
        button.accessibilityLabel = item.label
        button.alpha = CollabEditorViewController.inactiveAlpha
        button.tintColor = .jamiPrimaryControl
        button.translatesAutoresizingMaskIntoConstraints = false
        let side = CollabEditorViewController.touchTarget
        let width = button.widthAnchor.constraint(greaterThanOrEqualToConstant: side)
        width.isActive = true
        self.iconWidths.append(width)
        button.heightAnchor.constraint(equalToConstant: side).isActive = true
        button.addAction(UIAction { [weak self] _ in self?.apply(item.format) },
                         for: .touchUpInside)
        return button
    }

    /**
     A button that opens the list it chooses from. The list is built when it
     opens, so that it ticks what the text under the caret has then.
     */
    private func makeChooser(_ chooser: Chooser) -> UIButton {
        var configuration = UIButton.Configuration.plain()
        configuration.titleLineBreakMode = .byTruncatingTail
        configuration.imagePlacement = .trailing
        configuration.imagePadding = CollabEditorViewController.buttonSpacing
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 0,
                                                              leading: CollabEditorViewController.buttonSpacing,
                                                              bottom: 0,
                                                              trailing: CollabEditorViewController.buttonSpacing)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = .preferredFont(forTextStyle: .subheadline)
            return attributes
        }
        let button = UIButton(configuration: configuration)
        button.tintColor = .jamiPrimaryControl
        button.accessibilityLabel = self.label(of: chooser)
        button.showsMenuAsPrimaryAction = true
        button.menu = UIMenu(children: [
            UIDeferredMenuElement.uncached { [weak self] completion in
                completion(self?.choices(for: chooser) ?? [])
            }
        ])
        button.translatesAutoresizingMaskIntoConstraints = false
        // On a narrow row the names are what gives way, not the buttons.
        button.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let side = CollabEditorViewController.touchTarget
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(greaterThanOrEqualToConstant: side),
            button.widthAnchor.constraint(lessThanOrEqualToConstant: CollabEditorViewController.chooserMaxWidth),
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
            line.heightAnchor.constraint(equalToConstant: CollabEditorViewController.separatorHeight)
        ])
        return line
    }

    // MARK: - Binding

    private func bind() {
        self.viewModel.documentName
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in self?.showTitle() })
            .disposed(by: self.disposeBag)

        self.viewModel.otherParticipants
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in self?.showTitle() })
            .disposed(by: self.disposeBag)

        NotificationCenter.default.rx
            .notification(UIResponder.keyboardWillChangeFrameNotification)
            .subscribe(onNext: { [weak self] notification in
                self?.moveBar(with: notification)
            })
            .disposed(by: self.disposeBag)
    }

    /// Keeps the bar above the keyboard: it is what the caret is formatted with.
    private func moveBar(with notification: Notification) {
        guard let frame = notification
                .userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let overlap = max(0, self.view.bounds.maxY - self.view.convert(frame, from: nil).minY)
        let safeArea = self.view.safeAreaInsets.bottom
        self.barBottom.constant = overlap > 0 ? safeArea - overlap : 0
        self.view.layoutIfNeeded()
    }

    // MARK: - Document

    private func openDocument() {
        self.viewModel.open()
            .subscribe(onSuccess: { [weak self] state in
                guard let self = self else { return }
                if state.isEmpty {
                    self.showOpenFailure()
                    return
                }
                self.callEditor("applyUpdate", self.quote(state.base64EncodedString()))
                self.loadingView.stopAnimating()
                self.webView.isHidden = false
                // Whatever the page did while it waited now has a document to
                // apply to, and is worth sending.
                self.pendingLocalUpdates.forEach { self.send(update: $0) }
                self.pendingLocalUpdates.removeAll()
                self.listen()
                if self.viewModel.documentName.value.isEmpty { self.viewModel.refreshName() }
            }, onFailure: { [weak self] _ in
                self?.showOpenFailure()
            })
            .disposed(by: self.disposeBag)
    }

    private func showOpenFailure() {
        self.loadingView.stopAnimating()
        self.errorLabel.text = L10n.Collab.openError
        self.errorLabel.isHidden = false
    }

    private func listen() {
        self.viewModel.updates
            .subscribe(onNext: { [weak self] update in
                guard let self = self else { return }
                self.callEditor("applyUpdate", self.quote(update.base64EncodedString()))
            })
            .disposed(by: self.disposeBag)

        self.viewModel.awareness
            .subscribe(onNext: { [weak self] update, peer in
                guard let self = self else { return }
                self.callEditor("applyAwareness",
                                self.quote(update.peerId),
                                String(update.clientId),
                                self.quote(update.state),
                                self.quote(peer.displayName),
                                self.quote(peer.color))
            })
            .disposed(by: self.disposeBag)

        self.viewModel.departures
            .subscribe(onNext: { [weak self] left in
                guard let self = self else { return }
                self.callEditor("removeCursor", self.quote(left.peerId), String(left.clientId))
            })
            .disposed(by: self.disposeBag)

        self.viewModel.renames
            .subscribe()
            .disposed(by: self.disposeBag)

        self.viewModel.attachments
            .subscribe(onNext: { [weak self] attachmentId in
                guard let self = self else { return }
                self.callEditor("attachmentArrived", self.quote(attachmentId))
            })
            .disposed(by: self.disposeBag)

        self.viewModel.removals
            .subscribe(onNext: { [weak self] everywhere in
                self?.documentRemoved(everywhere: everywhere)
            })
            .disposed(by: self.disposeBag)
    }

    private func send(update base64: String) {
        guard let data = Data(base64Encoded: base64) else { return }
        self.viewModel.send(update: data)
            .subscribe(onError: { [weak self] _ in
                self?.showMessage(L10n.Collab.sendError)
            })
            .disposed(by: self.disposeBag)
    }

    // MARK: - The page

    private func callEditor(_ function: String, _ args: String...) {
        let call = args.joined(separator: ",")
        self.webView.evaluateJavaScript("window.JamiEditor.\(function)(\(call))")
    }

    /**
     Call the editor, and wait for what it answers.

     The page can fail to do what it was asked, and telling the user it was done
     when it was not leaves them believing in a document they do not have.
     */
    private func askEditor(_ function: String, then: @escaping (Bool?) -> Void) {
        self.webView.evaluateJavaScript("window.JamiEditor.\(function)()") { result, _ in
            then(result as? Bool)
        }
    }

    private func quote(_ value: String) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: [value], options: []),
              let json = String(data: data, encoding: .utf8) else { return "\"\"" }
        return String(json.dropFirst().dropLast())
    }

    // MARK: - Format bar

    private func apply(_ format: CollabFormat) {
        switch format {
        case .bold: self.callEditor("toggle", self.quote("bold"))
        case .italic: self.callEditor("toggle", self.quote("italic"))
        case .underline: self.callEditor("toggle", self.quote("underline"))
        case .strike: self.callEditor("toggle", self.quote("strike"))
        case .list(let kind): self.callEditor("setList", self.quote(kind))
        case .clear: self.callEditor("clearFormat")
        case .undo: self.callEditor("undo")
        case .redo: self.callEditor("redo")
        case .link: self.promptLink()
        case .image: self.pickImage()
        }
    }

    /// Lights up the buttons that describe the text under the caret.
    private func showFormats(_ json: String) {
        guard let data = json.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let formats = root["formats"] as? [String: Any] else { return }
        self.currentLink = formats["link"] as? String ?? ""
        self.currentHeader = formats["header"] as? Int ?? 0
        self.currentFont = formats["font"] as? String ?? ""
        self.currentSize = formats["size"] as? Double ?? 0
        self.currentAlign = formats["align"] as? String ?? ""
        self.showChoices()

        let list = formats["list"] as? String ?? ""

        func active(_ format: CollabFormat) -> Bool {
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
            button.alpha = selected ? 1 : CollabEditorViewController.inactiveAlpha
        }
    }

    // MARK: - Pieces

    private func showTitle() {
        self.navigationItem.title = self.viewModel.title
        self.navigationItem.prompt = self.viewModel.participantsDescription
    }

    // MARK: - Constants

    fileprivate static let bridgeName = "jami"

    private static let barHeight: CGFloat = 48
    private static let touchTarget: CGFloat = 44
    /// A phone's row of buttons is as tall to touch, a little narrower.
    private static let compactIconWidth: CGFloat = 38
    private static let buttonSpacing: CGFloat = 4
    private static let margin: CGFloat = 8
    private static let panelWidth: CGFloat = 300
    private static let inactiveAlpha: CGFloat = 0.55

    private static let chooserMaxWidth: CGFloat = 160
    private static let separatorHeight: CGFloat = 24

    /// The sizes offered, in points, as on the desktop.
    private static let fontSizes: [Double] = [8, 9, 10, 11, 12, 14, 16, 18, 20, 24, 28, 36, 48, 72]

    private static let sizeFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    private struct FormatItem {
        let format: CollabFormat
        let symbol: String
        let label: String

        init(_ format: CollabFormat, symbol: String, label: String) {
            self.format = format
            self.symbol = symbol
            self.label = label
        }
    }

    private struct Alignment {
        let value: String
        let symbol: String
        let label: String
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
            let margin = CollabEditorViewController.margin
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
            self.stack.spacing = spread ? 0 : CollabEditorViewController.buttonSpacing
            if spread {
                NSLayoutConstraint.activate(self.fillWidth)
            } else {
                NSLayoutConstraint.deactivate(self.fillWidth)
            }
        }
    }

    /// Left is the default, and is written as the absence of the attribute.
    private static let alignments: [Alignment] = [
        Alignment(value: "left", symbol: "text.alignleft", label: L10n.Collab.alignLeft),
        Alignment(value: "center", symbol: "text.aligncenter", label: L10n.Collab.alignCenter),
        Alignment(value: "right", symbol: "text.alignright", label: L10n.Collab.alignRight),
        Alignment(value: "justify", symbol: "text.justify", label: L10n.Collab.alignJustify)
    ]

    /// In the order of the desktop client's bar: what the text looks like, then
    /// how it is emphasized, how its paragraphs are laid out, and what it holds.
    private static let barItems: [BarItem] = [
        .chooser(.paragraphStyle),
        .chooser(.font),
        .chooser(.size),
        .separator,
        .format(FormatItem(.bold, symbol: "bold", label: L10n.Collab.bold)),
        .format(FormatItem(.italic, symbol: "italic", label: L10n.Collab.italic)),
        .format(FormatItem(.underline, symbol: "underline", label: L10n.Collab.underline)),
        .format(FormatItem(.strike, symbol: "strikethrough", label: L10n.Collab.strikethrough)),
        .separator,
        .chooser(.alignment),
        .format(FormatItem(.list("bullet"), symbol: "list.bullet", label: L10n.Collab.bulletList)),
        .format(FormatItem(.list("ordered"), symbol: "list.number", label: L10n.Collab.orderedList)),
        .separator,
        .format(FormatItem(.link, symbol: "link", label: L10n.Collab.linkTitle)),
        .format(FormatItem(.image, symbol: "photo", label: L10n.Collab.insertImage)),
        .format(FormatItem(.clear, symbol: "textformat", label: L10n.Collab.clearFormat)),
        .separator,
        .format(FormatItem(.undo, symbol: "arrow.uturn.backward", label: L10n.Collab.undo)),
        .format(FormatItem(.redo, symbol: "arrow.uturn.forward", label: L10n.Collab.redo))
    ]
}

// MARK: - Choosing a style, a font, a size, an alignment

extension CollabEditorViewController {

    private func label(of chooser: Chooser) -> String {
        switch chooser {
        case .paragraphStyle: return L10n.Collab.paragraphStyle
        case .font: return L10n.Collab.font
        case .size: return L10n.Collab.fontSize
        case .alignment: return L10n.Collab.alignment
        }
    }

    private func paragraphStyleName(_ level: Int) -> String {
        return level == 0 ? L10n.Collab.normalText : L10n.Collab.heading(level)
    }

    /// A font this client does not ship is named by its id: a newer client chose it.
    private var currentFontName: String {
        if self.currentFont.isEmpty { return L10n.Collab.defaultFont }
        return self.documentFonts.first { $0.id == self.currentFont }?.family ?? self.currentFont
    }

    private func sizeName(_ size: Double) -> String {
        return CollabEditorViewController.sizeFormatter.string(from: NSNumber(value: size)) ?? String(size)
    }

    private var currentAlignment: Alignment {
        let alignments = CollabEditorViewController.alignments
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
                self.choice(self.paragraphStyleName(level), on: self.currentHeader == level) {
                    $0.callEditor("setHeader", String(level))
                }
            }
        case .font:
            let fonts = self.documentFonts.map { font in
                self.choice(font.family, on: self.currentFont == font.id) {
                    $0.callEditor("setFont", $0.quote(font.id))
                }
            }
            return [
                self.choice(L10n.Collab.defaultFont, on: self.currentFont.isEmpty) {
                    $0.callEditor("setFont", $0.quote(""))
                },
                UIMenu(options: .displayInline, children: fonts)
            ]
        case .size:
            let sizes = CollabEditorViewController.fontSizes.map { size in
                self.choice(self.sizeName(size), on: self.currentSize == size) {
                    $0.callEditor("setSize", String(size))
                }
            }
            return [
                self.choice(L10n.Collab.baseSize, on: self.currentSize == 0) {
                    $0.callEditor("setSize", "0")
                },
                UIMenu(options: .displayInline, children: sizes)
            ]
        case .alignment:
            return CollabEditorViewController.alignments.map { alignment in
                self.choice(alignment.label,
                            symbol: alignment.symbol,
                            on: alignment.value == self.currentAlignment.value) {
                    $0.callEditor("setAlign", $0.quote(alignment.value))
                }
            }
        }
    }

    private func choice(_ title: String,
                        symbol: String? = nil,
                        on: Bool,
                        _ choose: @escaping (CollabEditorViewController) -> Void) -> UIAction {
        return UIAction(title: title,
                        image: symbol.flatMap { UIImage(systemName: $0) },
                        state: on ? .on : .off) { [weak self] _ in
            guard let self = self else { return }
            choose(self)
        }
    }

    /// The fonts are the page's: it is what has the files and draws them.
    private func loadFonts() {
        self.webView.evaluateJavaScript("window.JamiEditor.fonts()") { [weak self] result, _ in
            guard let self = self,
                  let json = result as? String,
                  let data = json.data(using: .utf8),
                  let list = try? JSONSerialization.jsonObject(with: data) as? [[String: String]] else { return }
            self.documentFonts = list.compactMap { entry in
                guard let id = entry["id"], let family = entry["family"] else { return nil }
                return DocumentFont(id: id, family: family)
            }
            self.showChoices()
        }
    }
}

// MARK: - Telling the user what became of the document

extension CollabEditorViewController {

    private func showMessage(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L10n.Global.ok, style: .default))
        self.present(alert, animated: true)
    }

    /**
     Says what happened, then closes.

     Closing on its own would make the screen vanish mid-sentence; staying would
     leave the user typing into something no longer backed by anything, where
     each keystroke is dropped without a word.
     */
    private func documentRemoved(everywhere: Bool) {
        let name = self.viewModel.documentName.value
        let named = name.isEmpty ? L10n.Collab.untitled : name
        let alert = UIAlertController(
            title: everywhere ? L10n.Collab.documentRemoved
                : L10n.Collab.documentRemovedLocally,
            message: everywhere ? L10n.Collab.documentRemovedMessage(named)
                : L10n.Collab.documentRemovedLocallyMessage(named),
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L10n.Global.ok, style: .default) { [weak self] _ in
            self?.closeEditor()
        })
        self.present(alert, animated: true)
    }
}

// MARK: - What the user asks of the document

extension CollabEditorViewController {

    @objc
    private func showMenu() {
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: L10n.Collab.rename, style: .default) { [weak self] _ in
            self?.promptRename()
        })
        sheet.addAction(UIAlertAction(title: L10n.Collab.history, style: .default) { [weak self] _ in
            self?.showHistory()
        })
        // An export during a preview would write the version, not the document.
        // A version becomes the document by being restored, which the others see.
        if self.versionBar.isHidden {
            sheet.addAction(UIAlertAction(title: L10n.Collab.export, style: .default) { [weak self] _ in
                self?.showExportMenu()
            })
        }
        sheet.addAction(UIAlertAction(title: L10n.Global.cancel, style: .cancel))
        sheet.popoverPresentationController?.barButtonItem = self.navigationItem.rightBarButtonItem
        self.present(sheet, animated: true)
    }

    private func promptRename() {
        let alert = UIAlertController(title: L10n.Collab.rename, message: nil, preferredStyle: .alert)
        alert.addTextField { field in
            field.text = self.viewModel.documentName.value
            field.placeholder = L10n.Collab.documentNameHint
        }
        alert.addAction(UIAlertAction(title: L10n.Global.ok, style: .default) { [weak self] _ in
            guard let self = self,
                  let name = alert.textFields?.first?.text?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                  !name.isEmpty else { return }
            self.viewModel.rename(to: name)
                .subscribe(onError: { [weak self] _ in
                    self?.showMessage(L10n.Collab.openError)
                })
                .disposed(by: self.disposeBag)
        })
        alert.addAction(UIAlertAction(title: L10n.Global.cancel, style: .cancel))
        self.present(alert, animated: true)
    }

    private func promptLink() {
        let alert = UIAlertController(title: L10n.Collab.linkTitle, message: nil, preferredStyle: .alert)
        alert.addTextField { field in
            field.text = self.currentLink
            field.placeholder = L10n.Collab.linkHint
            field.keyboardType = .URL
            field.autocapitalizationType = .none
        }
        alert.addAction(UIAlertAction(title: L10n.Collab.linkAdd, style: .default) { [weak self] _ in
            guard let self = self else { return }
            let address = alert.textFields?.first?.text?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            self.callEditor("setLink", self.quote(address))
        })
        if !self.currentLink.isEmpty {
            alert.addAction(UIAlertAction(title: L10n.Collab.linkRemove,
                                          style: .destructive) { [weak self] _ in
                guard let self = self else { return }
                self.callEditor("setLink", self.quote(""))
            })
        }
        alert.addAction(UIAlertAction(title: L10n.Global.cancel, style: .cancel))
        self.present(alert, animated: true)
    }
}

// MARK: - Past versions, images and export

extension CollabEditorViewController {

    private func setUpHistoryPanel() {
        self.view.addSubview(self.historyPanel)

        self.historyPanel.onSelect = { [weak self] version in
            self?.showVersion(version)
        }
        // One way out of the reading, whatever was being read.
        self.historyPanel.onClose = { [weak self] in
            self?.leaveVersion()
            self?.setHistory(open: false)
        }

        self.panelOpen = self.historyPanel.trailingAnchor
            .constraint(equalTo: self.view.trailingAnchor)
        self.panelClosed = self.historyPanel.leadingAnchor
            .constraint(equalTo: self.view.trailingAnchor)
        self.panelClosed.isActive = true

        // The list is read against the document, so it takes room from it
        // rather than lying over it.
        self.webBesidePanel = self.webView.trailingAnchor
            .constraint(equalTo: self.historyPanel.leadingAnchor)

        // Wide enough for a date and a name, and never so wide that the
        // document it is read against disappears behind it.
        let preferred = self.historyPanel.widthAnchor
            .constraint(equalToConstant: CollabEditorViewController.panelWidth)
        preferred.priority = .defaultHigh
        NSLayoutConstraint.activate([
            preferred,
            self.historyPanel.widthAnchor.constraint(lessThanOrEqualTo: self.view.widthAnchor,
                                                     multiplier: 0.6),
            self.historyPanel.topAnchor
                .constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor),
            self.historyPanel.bottomAnchor.constraint(equalTo: self.formatBar.topAnchor)
        ])
    }

    private func setHistory(open: Bool) {
        guard self.panelOpen.isActive != open else { return }
        self.panelClosed.isActive = !open
        self.panelOpen.isActive = open
        self.webFullWidth.isActive = !open
        self.webBesidePanel.isActive = open
        UIView.animate(withDuration: 0.25) {
            self.view.layoutIfNeeded()
        }
    }

    private func showHistory() {
        // A second tap on the menu entry puts the list away, as it opened it.
        if self.panelOpen.isActive {
            self.historyPanel.onClose?()
            return
        }
        self.viewModel.history()
            .subscribe(onSuccess: { [weak self] entries in
                guard let self = self else { return }
                if entries.isEmpty {
                    self.showMessage(L10n.Collab.noHistory)
                    return
                }
                self.historyPanel.show(entries)
                self.historyPanel.mark(commitId: "")
                self.setHistory(open: true)
            })
            .disposed(by: self.disposeBag)
    }

    private func showVersion(_ version: CollaborativeVersion) {
        self.viewModel.state(at: version.commitId)
            .subscribe(onSuccess: { [weak self] state in
                guard let self = self else { return }
                self.callEditor("showVersion", self.quote(state.base64EncodedString()))
                self.versionLabel.text = L10n.Collab.versionShown(self.viewModel.describe(version))
                self.versionBar.isHidden = false
                self.historyPanel.mark(commitId: version.commitId)
            })
            .disposed(by: self.disposeBag)
    }

    /// Back to the document itself. The list stays: the reading is not over.
    @objc
    private func leaveVersion() {
        guard !self.versionBar.isHidden else { return }
        self.callEditor("leaveVersion")
        self.versionBar.isHidden = true
        self.historyPanel.mark(commitId: "")
    }

    /**
     Put the document back to the version being read.

     The editor makes it an ordinary edit, so the others receive it the usual
     way and can take it back by restoring a later version. Nothing here rewinds
     anything: a document rewound on one device only is a document two people no
     longer share.
     */
    @objc
    private func restoreVersion() {
        self.askEditor("restoreVersion") { [weak self] restored in
            guard let self = self else { return }
            // The bar is what closes the version being read, so it stays until
            // the editor says it has left it. Taking it away on a failure would
            // leave the document shown read-only with no way back to it.
            switch restored {
            case .some(true):
                self.endVersionReading()
                self.showMessage(L10n.Collab.versionRestored)
            case .some(false):
                self.endVersionReading()
                self.showMessage(L10n.Collab.versionUnchanged)
            case .none:
                self.showMessage(L10n.Collab.versionRestoreError)
            }
        }
    }

    /// The editor has left the version on its own: the reading is over with it.
    private func endVersionReading() {
        self.versionBar.isHidden = true
        self.historyPanel.mark(commitId: "")
        self.setHistory(open: false)
    }

    // MARK: - Images

    private func pickImage() {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 1
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        self.present(picker, animated: true)
    }

    private func attach(image data: Data, width: Int, height: Int) {
        guard data.count <= CollabEditorViewModel.maxAttachmentBytes else {
            self.showMessage(L10n.Collab.imageTooLarge)
            return
        }
        self.viewModel.addAttachment(data)
            .subscribe(onSuccess: { [weak self] attachmentId in
                guard let self = self else { return }
                if attachmentId.isEmpty {
                    self.showMessage(L10n.Collab.imageError)
                    return
                }
                self.callEditor("insertImage",
                                self.quote(attachmentId),
                                String(width),
                                String(height))
            }, onFailure: { [weak self] _ in
                self?.showMessage(L10n.Collab.imageError)
            })
            .disposed(by: self.disposeBag)
    }

    // MARK: - Export

    private func exportToPdf() {
        let info = UIPrintInfo(dictionary: nil)
        info.jobName = self.viewModel.title
        info.outputType = .general
        let controller = UIPrintInteractionController.shared
        controller.printInfo = info
        controller.printFormatter = self.webView.viewPrintFormatter()
        controller.present(animated: true) { [weak self] _, _, error in
            if error != nil { self?.showMessage(L10n.Collab.exportError) }
        }
    }
}

// MARK: - Taking a copy of the document away

/**
 A document lives inside Jami, and the pictures in it live further in still:
 they are attachments of the conversation, named by an id that means nothing to
 any other reader. Exporting is therefore two things -- the page writes the
 document out in a format someone else's software reads, and the bytes of every
 picture are put in where it named one.

 PDF is not written this way: the system renders the page itself, pictures and
 all, through the print dialog.
 */
extension CollabEditorViewController {

    /// A format the page can write, and the file it is written to.
    private struct ExportFormat {
        let name: String
        let fileExtension: String
        let label: String
        /// What the file is, for a share sheet that would otherwise guess from
        /// the extension. Markdown is plain text as far as the system knows,
        /// and saying so is what keeps it shareable at all.
        let type: String
    }

    private static let exportFormats = [
        ExportFormat(name: "html", fileExtension: "html",
                     label: L10n.Collab.exportHtml, type: "public.html"),
        ExportFormat(name: "md", fileExtension: "md",
                     label: L10n.Collab.exportMarkdown, type: "public.plain-text"),
        ExportFormat(name: "txt", fileExtension: "txt",
                     label: L10n.Collab.exportText, type: "public.plain-text")
    ]

    private func showExportMenu() {
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: L10n.Collab.exportPdf, style: .default) { [weak self] _ in
            self?.exportToPdf()
        })
        for format in CollabEditorViewController.exportFormats {
            sheet.addAction(UIAlertAction(title: format.label, style: .default) { [weak self] _ in
                self?.export(format)
            })
        }
        sheet.addAction(UIAlertAction(title: L10n.Global.cancel, style: .cancel))
        sheet.popoverPresentationController?.barButtonItem = self.navigationItem.rightBarButtonItem
        self.present(sheet, animated: true)
    }

    /// The document as the page wrote it, and what it left for the application.
    private struct WrittenDocument {
        let text: String
        let attachments: [String]
        /// What the pictures are named under, this time: drawn afresh for every
        /// export so that no text in the document can be taken for one.
        let scheme: String
    }

    private func export(_ format: ExportFormat, without missing: [String] = []) {
        self.writeDocument(format, without: missing) { [weak self] written in
            guard let self = self else { return }
            guard !written.attachments.isEmpty else {
                self.share(written.text, as: format)
                return
            }
            self.viewModel.attachments(written.attachments)
                .observe(on: MainScheduler.instance)
                .subscribe(onSuccess: { [weak self] bytes in
                    guard let self = self else { return }
                    let absent = written.attachments.filter { bytes[$0]?.isEmpty ?? true }
                    guard absent.isEmpty else {
                        // Written again without them: a picture left as an
                        // address no reader can follow is a hole in a file that
                        // is supposed to stand on its own.
                        self.confirmMissingPictures(absent.count) { [weak self] in
                            // Together with the ones already left out: a
                            // picture dropped once stays dropped, or a second
                            // pass would write back what the first removed.
                            self?.export(format, without: missing + absent)
                        }
                        return
                    }
                    let filled = self.viewModel.embed(bytes,
                                                      in: written.text,
                                                      under: written.scheme)
                    self.share(filled, as: format)
                }, onFailure: { [weak self] _ in
                    self?.showMessage(L10n.Collab.exportError)
                })
                .disposed(by: self.disposeBag)
        }
    }

    /// Ask the page for the document, and for the pictures it left to be put in.
    private func writeDocument(_ format: ExportFormat,
                               without missing: [String],
                               then use: @escaping (WrittenDocument) -> Void) {
        let dropped = (try? JSONSerialization.data(withJSONObject: missing, options: []))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        let call = "window.JamiEditor.exportAs("
            + "\(self.quote(format.name)),\(self.quote(self.viewModel.title)),\(dropped))"
        self.webView.evaluateJavaScript(call) { [weak self] result, _ in
            guard let self = self else { return }
            guard let answer = result as? [String: Any],
                  let text = answer["text"] as? String,
                  let scheme = answer["scheme"] as? String else {
                self.showMessage(L10n.Collab.exportError)
                return
            }
            use(WrittenDocument(text: text,
                                attachments: answer["attachments"] as? [String] ?? [],
                                scheme: scheme))
        }
    }

    private func confirmMissingPictures(_ count: Int, then export: @escaping () -> Void) {
        let alert = UIAlertController(title: L10n.Collab.export,
                                      message: L10n.Collab.exportMissingImages(count),
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L10n.Collab.exportAnyway,
                                      style: .default) { _ in export() })
        alert.addAction(UIAlertAction(title: L10n.Global.cancel, style: .cancel))
        self.present(alert, animated: true)
    }

    /// Handed over rather than saved: where a copy of a document belongs is the
    /// user's business, and the share sheet is where every answer to that is.
    private func share(_ text: String, as format: ExportFormat) {
        guard let file = self.viewModel.exportFile(text, fileExtension: format.fileExtension) else {
            self.showMessage(L10n.Collab.exportError)
            return
        }
        let item = CollabExportItem(file: file, type: format.type,
                                    name: self.viewModel.title)
        let sheet = UIActivityViewController(activityItems: [item], applicationActivities: nil)
        sheet.popoverPresentationController?.barButtonItem = self.navigationItem.rightBarButtonItem
        sheet.completionWithItemsHandler = { _, _, _, _ in
            // The directory, not the file: it was made for this export alone.
            try? FileManager.default.removeItem(at: file.deletingLastPathComponent())
        }
        self.present(sheet, animated: true)
    }
}

// MARK: - What the page is allowed to ask of the application

extension CollabEditorViewController: WKScriptMessageHandler {

    func userContentController(_ controller: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let name = body["name"] as? String else { return }
        let args = body["args"] as? [Any] ?? []
        let first = args.first as? String ?? ""

        switch name {
        case "onReady":
            self.loadFonts()
            self.openDocument()
        case "onUpdate":
            if self.viewModel.opened {
                self.send(update: first)
            } else {
                // The page starts empty and immediately reports the state it is
                // in. Sending that before the document has been read would tell
                // the others this replica had emptied it.
                self.pendingLocalUpdates.append(first)
            }
        case "onAwareness":
            self.viewModel.report(awareness: first)
        case "onSelection":
            self.showFormats(first)
        case "onLog":
            print("collab editor: \(first)")
        default:
            break
        }
    }
}

// MARK: - Navigation

extension CollabEditorViewController: WKNavigationDelegate {

    /**
     A document can hold a link to anywhere.

     Following one inside the editor would leave the user typing into a web
     page; it belongs to the browser, and only if it is a link and not a script.
     */
    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }
        if url.scheme == CollabSchemeHandler.scheme {
            decisionHandler(.allow)
            return
        }
        if navigationAction.targetFrame?.isMainFrame ?? true,
           let scheme = url.scheme,
           CollabEditorViewController.openableSchemes.contains(scheme) {
            UIApplication.shared.open(url)
        }
        decisionHandler(.cancel)
    }

    private static let openableSchemes: Set<String> = ["http", "https", "mailto"]
}

// MARK: - Image picking

extension CollabEditorViewController: PHPickerViewControllerDelegate {

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider,
              provider.canLoadObject(ofClass: UIImage.self) else { return }
        provider.loadDataRepresentation(forTypeIdentifier: "public.image") { [weak self] data, _ in
            guard let self = self, let data = data else { return }
            // Only the size is needed to lay the image out; the pixels are not
            // needed at all, and the bytes travel as they came.
            let image = UIImage(data: data)
            let width = Int(image?.size.width ?? 0)
            let height = Int(image?.size.height ?? 0)
            DispatchQueue.main.async {
                self.attach(image: data, width: width, height: height)
            }
        }
    }
}

/**
 A file handed over, saying what it is.

 A share sheet types a file by its extension, and iOS knows nothing of `.md`:
 the file is then offered as content of no type at all, which the other side
 refuses. Naming the type leaves it nothing to guess at.
 */
private class CollabExportItem: NSObject, UIActivityItemSource {

    private let file: URL
    private let type: String
    private let name: String

    init(file: URL, type: String, name: String) {
        self.file = file
        self.type = type
        self.name = name
    }

    func activityViewControllerPlaceholderItem(_ controller: UIActivityViewController) -> Any {
        return self.file
    }

    func activityViewController(_ controller: UIActivityViewController,
                                itemForActivityType activity: UIActivity.ActivityType?) -> Any? {
        return self.file
    }

    func activityViewController(_ controller: UIActivityViewController,
                                dataTypeIdentifierForActivityType
                                    activity: UIActivity.ActivityType?) -> String {
        return self.type
    }

    func activityViewController(_ controller: UIActivityViewController,
                                subjectForActivityType activity: UIActivity.ActivityType?)
    -> String {
        return self.name
    }
}

/**
 A message handler the content controller does not keep alive.

 WKUserContentController holds its handlers strongly, and the handler here is
 the view controller that owns the web view, so registering it directly would
 be a cycle no one breaks.
 */
private class CollabWeakMessageHandler: NSObject, WKScriptMessageHandler {

    private weak var handler: WKScriptMessageHandler?

    init(_ handler: WKScriptMessageHandler) {
        self.handler = handler
    }

    func userContentController(_ controller: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        self.handler?.userContentController(controller, didReceive: message)
    }
}
