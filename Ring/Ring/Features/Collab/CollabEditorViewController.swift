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

    private let formatBar = UIScrollView()
    private let formatStack = UIStackView()
    private let versionBar = UIStackView()
    private let versionLabel = UILabel()
    private let historyPanel = CollabHistoryPanel()

    private var buttons = [CollabFormat: UIButton]()
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

    /// What the page can be asked to do, and what its buttons stand for.
    private enum CollabFormat: Hashable {
        case bold, italic, underline, strike
        case header(Int)
        case list(String)
        case align(String)
        case link, image, clear, undo, redo
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
        self.formatBar.translatesAutoresizingMaskIntoConstraints = false
        self.formatBar.showsHorizontalScrollIndicator = false
        self.formatBar.backgroundColor = .jamiFormBackground
        self.view.addSubview(self.formatBar)

        self.formatStack.axis = .horizontal
        self.formatStack.spacing = CollabEditorViewController.buttonSpacing
        self.formatStack.alignment = .center
        self.formatStack.translatesAutoresizingMaskIntoConstraints = false
        self.formatBar.addSubview(self.formatStack)

        for item in CollabEditorViewController.formatItems {
            let button = self.makeButton(item)
            self.buttons[item.format] = button
            self.formatStack.addArrangedSubview(button)
        }

        self.barBottom = self.formatBar.bottomAnchor
            .constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor)
        self.webFullWidth = self.webView.trailingAnchor
            .constraint(equalTo: self.view.trailingAnchor)
        let height = CollabEditorViewController.barHeight
        NSLayoutConstraint.activate([
            self.webView.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor),
            self.webView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            self.webFullWidth,
            self.webView.bottomAnchor.constraint(equalTo: self.formatBar.topAnchor),

            self.formatBar.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            self.formatBar.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            self.formatBar.heightAnchor.constraint(equalToConstant: height),
            self.barBottom,

            self.formatStack.topAnchor.constraint(equalTo: self.formatBar.topAnchor),
            self.formatStack.bottomAnchor.constraint(equalTo: self.formatBar.bottomAnchor),
            self.formatStack.leadingAnchor.constraint(equalTo: self.formatBar.leadingAnchor,
                                                      constant: CollabEditorViewController.margin),
            self.formatStack.trailingAnchor.constraint(equalTo: self.formatBar.trailingAnchor,
                                                       constant: -CollabEditorViewController.margin),
            self.formatStack.heightAnchor.constraint(equalTo: self.formatBar.heightAnchor)
        ])
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
        if let symbol = item.symbol {
            button.setImage(UIImage(systemName: symbol), for: .normal)
        } else {
            button.setTitle(item.title, for: .normal)
            button.titleLabel?.font = .preferredFont(forTextStyle: .headline)
            button.titleLabel?.adjustsFontForContentSizeCategory = true
        }
        button.accessibilityLabel = item.label
        button.alpha = CollabEditorViewController.inactiveAlpha
        button.tintColor = .jamiPrimaryControl
        button.translatesAutoresizingMaskIntoConstraints = false
        let side = CollabEditorViewController.touchTarget
        button.widthAnchor.constraint(greaterThanOrEqualToConstant: side).isActive = true
        button.heightAnchor.constraint(equalToConstant: side).isActive = true
        button.addAction(UIAction { [weak self] _ in self?.apply(item.format) },
                         for: .touchUpInside)
        return button
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
        case .header(let level): self.callEditor("setHeader", String(level))
        case .list(let kind): self.callEditor("setList", self.quote(kind))
        case .align(let side): self.callEditor("setAlign", self.quote(side))
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

        let header = formats["header"] as? Int ?? 0
        let list = formats["list"] as? String ?? ""
        let align = formats["align"] as? String ?? ""

        func active(_ format: CollabFormat) -> Bool {
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
    private static let buttonSpacing: CGFloat = 4
    private static let margin: CGFloat = 8
    private static let panelWidth: CGFloat = 300
    private static let inactiveAlpha: CGFloat = 0.55

    private struct FormatItem {
        let format: CollabFormat
        let symbol: String?
        let title: String?
        let label: String

        init(_ format: CollabFormat, symbol: String? = nil, title: String? = nil, label: String) {
            self.format = format
            self.symbol = symbol
            self.title = title
            self.label = label
        }
    }

    private static let formatItems: [FormatItem] = [
        FormatItem(.bold, symbol: "bold", label: L10n.Collab.bold),
        FormatItem(.italic, symbol: "italic", label: L10n.Collab.italic),
        FormatItem(.underline, symbol: "underline", label: L10n.Collab.underline),
        FormatItem(.strike, symbol: "strikethrough", label: L10n.Collab.strikethrough),
        FormatItem(.header(1), title: "H1", label: L10n.Collab.heading(1)),
        FormatItem(.header(2), title: "H2", label: L10n.Collab.heading(2)),
        FormatItem(.header(3), title: "H3", label: L10n.Collab.heading(3)),
        FormatItem(.list("bullet"), symbol: "list.bullet", label: L10n.Collab.bulletList),
        FormatItem(.list("ordered"), symbol: "list.number", label: L10n.Collab.orderedList),
        FormatItem(.align("left"), symbol: "text.alignleft", label: L10n.Collab.alignLeft),
        FormatItem(.align("center"), symbol: "text.aligncenter", label: L10n.Collab.alignCenter),
        FormatItem(.align("right"), symbol: "text.alignright", label: L10n.Collab.alignRight),
        FormatItem(.align("justify"), symbol: "text.justify", label: L10n.Collab.alignJustify),
        FormatItem(.link, symbol: "link", label: L10n.Collab.linkTitle),
        FormatItem(.image, symbol: "photo", label: L10n.Collab.insertImage),
        FormatItem(.clear, symbol: "textformat", label: L10n.Collab.clearFormat),
        FormatItem(.undo, symbol: "arrow.uturn.backward", label: L10n.Collab.undo),
        FormatItem(.redo, symbol: "arrow.uturn.forward", label: L10n.Collab.redo)
    ]
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
        // A past version is read over the document itself, which is what would
        // be written: offering the action here would export something other
        // than what is on screen.
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
                            self?.export(format, without: absent)
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
            try? FileManager.default.removeItem(at: file)
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
