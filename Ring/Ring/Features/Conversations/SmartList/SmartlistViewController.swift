/*
 *  Copyright (C) 2017-2023 Savoir-faire Linux Inc.
 *
 *  Author: Silbino Gonçalves Matado <silbino.gmatado@savoirfairelinux.com>
 *  Author: Quentin Muret <quentin.muret@savoirfairelinux.com>
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
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
import RxSwift
import RxDataSources
import RxCocoa
import Reusable
import SwiftyBeaver
import ContactsUI
import QuartzCore
import SwiftUI

// Constants
struct SmartlistConstants {
    static let smartlistRowHeight: CGFloat = 70.0
    static let tableHeaderViewHeight: CGFloat = 30.0
}

// swiftlint:disable type_body_length
class SmartlistViewController: UIViewController, StoryboardBased, ViewModelBased, UISearchControllerDelegate {

    private let log = SwiftyBeaver.self

    // MARK: outlets
    @IBOutlet weak var conversationsTableView: UITableView!
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var noConversationLabel: UILabel!
    @IBOutlet weak var networkAlertLabel: UILabel!
    @IBOutlet weak var cellularAlertLabel: UILabel!
    @IBOutlet weak var settingsButton: UIButton!
    @IBOutlet weak var widgetsTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var networkAlertView: UIView!
    @IBOutlet weak var donationBaner: UIView!
    @IBOutlet weak var donateButton: UIButton!
    @IBOutlet weak var disableDonationButton: UIButton!
    @IBOutlet weak var donationLabel: UILabel!

    // account selection
    private var accounPicker = UIPickerView()
    private let accountPickerTextView = UITextField(frame: CGRect.zero)
    private let accountsAdapter = AccountPickerAdapter()
    private var accountsDismissTapRecognizer: UITapGestureRecognizer!

    var viewModel: SmartlistViewModel!
    private let disposeBag = DisposeBag()

    private let contactPicker = CNContactPickerViewController()


    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupUI()
        self.applyL10n()
        self.configureNavigationBar()
        self.confugureAccountPicker()
        accountsDismissTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        let contentView = UIHostingController(rootView: SmartListView(model: viewModel.conversationsModel))
        addChild(contentView)
        view.addSubview(contentView.view)
        contentView.view.translatesAutoresizingMaskIntoConstraints = false
        contentView.view.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        contentView.view.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        contentView.view.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        contentView.view.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.viewModel.closeAllPlayers()
        self.navigationController?.setNavigationBarHidden(false, animated: false)
        self.viewModel.updateDonationBunnerVisiblity()
       self.navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
       // self.navigationController?.setNavigationBarHidden(false, animated: false)
    }

    @objc
    func dismissKeyboard() {
        accountPickerTextView.resignFirstResponder()
        view.removeGestureRecognizer(accountsDismissTapRecognizer)
    }

    private func applyL10n() {
        self.navigationItem.title = L10n.Smartlist.conversations
        self.noConversationLabel.text = L10n.Smartlist.noConversation
        self.networkAlertLabel.text = L10n.Smartlist.noNetworkConnectivity
        self.cellularAlertLabel.text = L10n.Smartlist.cellularAccess

        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.jamiButtonDark,
            .font: UIFont.systemFont(ofSize: 14)]
        let disableDonationTitle = NSAttributedString(string: L10n.Smartlist.disableDonation, attributes: attributes)
        let donateTitle = NSAttributedString(string: L10n.Global.donate, attributes: attributes)

        self.disableDonationButton.setAttributedTitle(disableDonationTitle, for: .normal)
        self.donateButton.setAttributedTitle(donateTitle, for: .normal)
        self.donationLabel.text = L10n.Smartlist.donationExplanation
    }

    private func setupUI() {
        self.viewModel.connectionState
            .observe(on: MainScheduler.instance)
            .startWith(self.viewModel.networkConnectionState())
            .subscribe(onNext: { [weak self] _ in
                self?.updateNetworkUI()
            })
            .disposed(by: self.disposeBag)

        self.settingsButton.backgroundColor = nil
        self.settingsButton.setTitle("", for: .normal)
        self.settingsButton.rx.tap
            .subscribe(onNext: { _ in
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url, completionHandler: nil)
                }
            })
            .disposed(by: self.disposeBag)
        // create account button
        let accountButton = UIButton(type: .custom)
        self.viewModel.profileImage.bind(to: accountButton.rx.image(for: .normal))
            .disposed(by: disposeBag)
        accountButton.roundedCorners = true
        accountButton.clipsToBounds = true
        accountButton.imageView?.contentMode = .scaleAspectFill
        accountButton.cornerRadius = smartListAccountSize * 0.5
        accountButton.frame = CGRect(x: 0, y: 0, width: smartListAccountSize, height: smartListAccountSize)
        accountButton.imageEdgeInsets = UIEdgeInsets(top: -smartListAccountMargin, left: -smartListAccountMargin, bottom: -smartListAccountMargin, right: -smartListAccountMargin)
        let accountButtonItem = UIBarButtonItem(customView: accountButton)
        accountButtonItem
            .customView?
            .translatesAutoresizingMaskIntoConstraints = false
        accountButtonItem.customView?
            .heightAnchor
            .constraint(equalToConstant: smartListAccountSize).isActive = true
        accountButtonItem.customView?
            .widthAnchor
            .constraint(equalToConstant: smartListAccountSize).isActive = true
        accountButton.rx.tap
            .throttle(Durations.halfSecond.toTimeInterval(), scheduler: MainScheduler.instance)
            .subscribe(onNext: { [weak self] in
                self?.openAccountsList()
            })
            .disposed(by: self.disposeBag)
        self.navigationItem.leftBarButtonItem = accountButtonItem
        let space = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
        space.width = 20
        self.navigationItem.rightBarButtonItems = [createSearchButton(), space, createMenuButton()]
        self.conversationsTableView.tableFooterView = UIView()
        self.viewModel.donationBannerVisible
            .observe(on: MainScheduler.instance)
            .startWith(self.viewModel.donationBannerVisible.value)
            .map { !$0 }
            .bind(to: self.donationBaner.rx.isHidden)
            .disposed(by: disposeBag)
        self.donateButton.rx.tap
            .subscribe(onNext: { [weak self] _ in
                guard let self = self else { return }
                SharedActionsPresenter.openDonationLink()
                self.viewModel.temporaryDisableDonationCampaign()
            })
            .disposed(by: self.disposeBag)
        self.disableDonationButton.rx.tap
            .subscribe(onNext: { [weak self] _ in
                guard let self = self else { return }
                self.viewModel.temporaryDisableDonationCampaign()
            })
            .disposed(by: self.disposeBag)
    }

    private func createSearchButton() -> UIBarButtonItem {
        let imageSettings = UIImage(systemName: "square.and.pencil") as UIImage?
        let generalSettingsButton = UIButton(type: UIButton.ButtonType.system) as UIButton
        generalSettingsButton.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
        generalSettingsButton.setImage(imageSettings, for: .normal)
        generalSettingsButton.tintColor = .jamiButtonDark
        return UIBarButtonItem(customView: generalSettingsButton)
    }

    private func createMenuButton() -> UIBarButtonItem {
        let imageSettings = UIImage(systemName: "ellipsis.circle") as UIImage?
        let generalSettingsButton = UIButton(type: UIButton.ButtonType.system) as UIButton
        generalSettingsButton.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
        generalSettingsButton.setImage(imageSettings, for: .normal)
        generalSettingsButton.menu = createMenu()
        generalSettingsButton.tintColor = .jamiButtonDark
        generalSettingsButton.showsMenuAsPrimaryAction = true
        return UIBarButtonItem(customView: generalSettingsButton)
    }

    private func shareAccountInfo() {
        guard let content = self.viewModel.accountInfoToShare else { return }

        let sourceView: UIView
        if UIDevice.current.userInterfaceIdiom == .phone {
            sourceView = self.view
        } else if let navigationBar = self.navigationController?.navigationBar {
            sourceView = navigationBar
        } else {
            sourceView = self.view
        }

        SharedActionsPresenter.shareAccountInfo(onViewController: self, sourceView: sourceView, content: content)
    }

    func confugureAccountPicker() {
        accountPickerTextView.inputView = accounPicker
        view.addSubview(accountPickerTextView)

        accounPicker.backgroundColor = .jamiBackgroundSecondaryColor
        self.viewModel.accounts
            .observe(on: MainScheduler.instance)
            .bind(to: accounPicker.rx.items(adapter: accountsAdapter))
            .disposed(by: disposeBag)
        if let account = self.viewModel.currentAccount,
           let row = accountsAdapter.rowForAccountId(account: account) {
            accounPicker.selectRow(row, inComponent: 0, animated: true)
        }
        self.viewModel.currentAccountChanged
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] currentAccount in
                guard let self = self else { return }
                if let account = currentAccount,
                   let row = self.accountsAdapter.rowForAccountId(account: account) {
                    self.accounPicker.selectRow(row, inComponent: 0, animated: true)
                }
            })
            .disposed(by: disposeBag)
        accounPicker.rx.modelSelected(AccountItem.self)
            .subscribe(onNext: { [weak self] model in
                let account = model[0].account
                self?.viewModel.changeCurrentAccount(accountId: account.id)
            })
            .disposed(by: disposeBag)
        let accountsLabel = UILabel(frame: CGRect(x: 0, y: 20, width: self.view.frame.width, height: 40))
        accountsLabel.text = L10n.Smartlist.accountsTitle
        accountsLabel.font = UIFont.systemFont(ofSize: 25, weight: .light)
        accountsLabel.textColor = .jamiSecondary
        accountsLabel.textAlignment = .center
        let addAccountButton = UIButton(type: .custom)
        addAccountButton.frame = CGRect(x: 0, y: 0, width: 250, height: 40)
        addAccountButton.contentHorizontalAlignment = .right
        addAccountButton.setTitle(L10n.Smartlist.addAccountButton, for: .normal)
        addAccountButton.setTitleColor(.jamiButtonDark, for: .normal)
        addAccountButton.titleLabel?.font = UIFont(name: "HelveticaNeue-Light", size: 23)

        // Enable auto-shrink
        addAccountButton.titleLabel?.adjustsFontSizeToFitWidth = true
        addAccountButton.titleLabel?.minimumScaleFactor = 0.5 // The minimum scale factor for the font size
        addAccountButton.sizeToFit()

        let flexibleBarButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.flexibleSpace, target: self, action: nil)
        let addBarButton = UIBarButtonItem(customView: addAccountButton)
        let toolbar = UIToolbar()
        toolbar.barTintColor = .jamiBackgroundSecondaryColor
        toolbar.isTranslucent = false

        toolbar.sizeToFit()
        toolbar.center = CGPoint(x: self.view.frame.width * 0.5, y: 200)

        toolbar.items = [flexibleBarButton, addBarButton]
        accountPickerTextView.inputAccessoryView = toolbar
        addAccountButton.rx.tap
            .throttle(Durations.halfSecond.toTimeInterval(), scheduler: MainScheduler.instance)
            .subscribe(onNext: { [weak self] in
                self?.startAccountCreation()
            })
            .disposed(by: self.disposeBag)
    }

    func updateNetworkUI() {
        let isHidden = self.viewModel.networkConnectionState() == .none ? false : true
        self.networkAlertView.isHidden = isHidden
        self.view.layoutIfNeeded()
    }

    private func setupUIForSipAccount(customNavBar: SmartListNavigationBar) {
        let bookButton = createSearchBarButtonWithImage(named: "book.circle", weight: .regular, width: 27)
        bookButton.setImage(UIImage(asset: Asset.phoneBook), for: .normal)
        bookButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.presentContactPicker()
            })
            .disposed(by: customNavBar.disposeBag)

        let dialpadCodeButton = createSearchBarButtonWithImage(named: "square.grid.3x3.topleft.filled", weight: .regular, width: 25)
        dialpadCodeButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.viewModel.showDialpad()
            })
            .disposed(by: customNavBar.disposeBag)

        customNavBar.addTopView(with: [bookButton, dialpadCodeButton])
    }

    private func setupUIForNonSipAccount(customNavBar: SmartListNavigationBar) {
        let qrCodeButton = createSearchBarButtonWithImage(named: "qrcode", weight: .medium, width: 25)
        qrCodeButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.viewModel.showQRCode()
            })
            .disposed(by: customNavBar.disposeBag)

        let swarmButton = createSearchBarButtonWithImage(named: "person.2", weight: .medium, width: 32)
        swarmButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.viewModel.createGroup()
            })
            .disposed(by: customNavBar.disposeBag)

        customNavBar.addTopView(with: [qrCodeButton, swarmButton])
    }

    private func presentContactPicker() {
        contactPicker.delegate = self
        present(contactPicker, animated: true, completion: nil)
    }

    private func createSearchBarButtonWithImage(named imageName: String, weight: UIImage.SymbolWeight, width: CGFloat) -> UIButton {
        let button = UIButton()
        let configuration = UIImage.SymbolConfiguration(pointSize: 40, weight: weight, scale: .large)
        button.setImage(UIImage(systemName: imageName, withConfiguration: configuration), for: .normal)
        button.tintColor = .jamiButtonDark
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: width).isActive = true
        button.heightAnchor.constraint(equalToConstant: 23).isActive = true
        return button
    }

    func startAccountCreation() {
        accountPickerTextView.resignFirstResponder()
        self.viewModel.createAccount()
    }

    func openAccountsList() {
        if accountPickerTextView.isFirstResponder {
            accountPickerTextView.resignFirstResponder()
            return
        }
        accountPickerTextView.becomeFirstResponder()
        self.view.addGestureRecognizer(accountsDismissTapRecognizer)
    }

    private func showRemoveConversationConfirmation(atIndex: IndexPath) {
        let alert = UIAlertController(title: L10n.Alerts.confirmDeleteConversationTitle, message: L10n.Alerts.confirmDeleteConversation, preferredStyle: .alert)
        let deleteAction = UIAlertAction(title: L10n.Actions.deleteAction, style: .destructive) { (_: UIAlertAction!) -> Void in
            if let convToDelete: ConversationViewModel = try? self.conversationsTableView.rx.model(at: atIndex) {
                self.viewModel.delete(conversationViewModel: convToDelete)
            }
        }
        let cancelAction = UIAlertAction(title: L10n.Global.cancel, style: .default) { (_: UIAlertAction!) -> Void in }
        alert.addAction(deleteAction)
        alert.addAction(cancelAction)
        self.present(alert, animated: true, completion: nil)
    }

    private func showBlockContactConfirmation(atIndex: IndexPath) {
        let alert = UIAlertController(title: L10n.Global.blockContact, message: L10n.Alerts.confirmBlockContact, preferredStyle: .alert)
        let blockAction = UIAlertAction(title: L10n.Global.block, style: .destructive) { (_: UIAlertAction!) -> Void in
            if let conversation: ConversationViewModel = try? self.conversationsTableView.rx.model(at: atIndex) {
                self.viewModel.blockConversationsContact(conversationViewModel: conversation)
            }
        }
        let cancelAction = UIAlertAction(title: L10n.Global.cancel, style: .default) { (_: UIAlertAction!) -> Void in }
        alert.addAction(blockAction)
        alert.addAction(cancelAction)
        self.present(alert, animated: true, completion: nil)
    }
}

extension SmartlistViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, editActionsForRowAt: IndexPath) -> [UITableViewRowAction]? {
        let block = UITableViewRowAction(style: .normal, title: "Block") { _, index in
            self.showBlockContactConfirmation(atIndex: index)
        }
        block.backgroundColor = .red

        let delete = UITableViewRowAction(style: .normal, title: "Delete") { _, index in
            self.showRemoveConversationConfirmation(atIndex: index)
        }
        delete.backgroundColor = .orange

        return [delete, block]
    }

    private func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if self.navigationController?.topViewController == self {
            if let convToShow: ConversationViewModel = try? tableView.rx.model(at: indexPath) {
                self.viewModel.showConversation(withConversationViewModel: convToShow)
            }
        }
    }
}

extension SmartlistViewController: CNContactPickerDelegate {

    func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
        let phoneNumberCount = contact.phoneNumbers.count
        guard phoneNumberCount > 0 else {
            dismiss(animated: true)
            let alert = UIAlertController(title: L10n.Smartlist.noNumber,
                                          message: nil,
                                          preferredStyle: .alert)
            let cancelAction = UIAlertAction(title: L10n.Global.ok,
                                             style: .default) { (_: UIAlertAction!) -> Void in }
            alert.addAction(cancelAction)
            self.present(alert, animated: true, completion: nil)
            return
        }

        if phoneNumberCount == 1 {
            setNumberFromContact(contactNumber: contact.phoneNumbers[0].value.stringValue)
        } else {
            let alert = UIAlertController(title: L10n.Smartlist.selectOneNumber, message: nil, preferredStyle: .alert)
            for contact in contact.phoneNumbers {
                let contactAction = UIAlertAction(title: contact.value.stringValue,
                                                  style: .default) { [weak self](_: UIAlertAction!) -> Void in
                    self?.setNumberFromContact(contactNumber: contact.value.stringValue)
                }
                alert.addAction(contactAction)
            }
            let cancelAction = UIAlertAction(title: L10n.Global.cancel,
                                             style: .default) { (_: UIAlertAction!) -> Void in }
            alert.addAction(cancelAction)
            dismiss(animated: true)
            self.present(alert, animated: true, completion: nil)
        }
    }

    func setNumberFromContact(contactNumber: String) {
        self.viewModel.showSipConversation(withNumber: contactNumber.trimmedSipNumber())
    }

    func contactPickerDidCancel(_ picker: CNContactPickerViewController) {

    }
}

// MARK: - menu
extension SmartlistViewController {
    private func createMenu() -> UIMenu {
        return UIMenu(title: "", children: [createSwarmAction(), inviteFriendsAction(), accountsAction(), openAccountAction(), openSettingsAction(), donateAction(), aboutJamiAction()])
    }

    private func createTintedImage(systemName: String, configuration: UIImage.SymbolConfiguration, tintColor: UIColor) -> UIImage? {
        let image = UIImage(systemName: systemName, withConfiguration: configuration)
        return image?.withTintColor(tintColor, renderingMode: .alwaysOriginal)
    }

    // MARK: - Action creation functions

    private var configuration: UIImage.SymbolConfiguration {
        return UIImage.SymbolConfiguration(scale: .medium)
    }

    private func createSwarmAction() -> UIAction {
        let image = createTintedImage(systemName: "person.2", configuration: configuration, tintColor: .jamiButtonDark)
        return UIAction(title: L10n.Swarm.newSwarm, image: image, identifier: nil, discoverabilityTitle: nil, attributes: [], state: .off) { [weak self] _ in
            self?.viewModel.createGroup()
        }
    }

    private func inviteFriendsAction() -> UIAction {
        let image = createTintedImage(systemName: "envelope.open", configuration: configuration, tintColor: .jamiButtonDark)
        return UIAction(title: L10n.Smartlist.inviteFriends, image: image, identifier: nil, discoverabilityTitle: nil, attributes: [], state: .off) { [weak self] _ in
            self?.shareAccountInfo()
        }
    }

    private func donateAction() -> UIAction {
        let image = createTintedImage(systemName: "heart", configuration: configuration, tintColor: .jamiDonation)
        return UIAction(title: L10n.Global.donate, image: image, identifier: nil, discoverabilityTitle: nil, attributes: [], state: .off) { _ in
            SharedActionsPresenter.openDonationLink()
        }
    }

    private func accountsAction() -> UIAction {
        let image = createTintedImage(systemName: "list.bullet", configuration: configuration, tintColor: .jamiButtonDark)
        return UIAction(title: L10n.Smartlist.accounts, image: image, identifier: nil, discoverabilityTitle: nil, attributes: [], state: .off) { [weak self] _ in
            self?.openAccountsList()
        }
    }

    private func openAccountAction() -> UIAction {
        let image = createTintedImage(systemName: "person.circle", configuration: configuration, tintColor: .jamiButtonDark)
        return UIAction(title: L10n.Global.accountSettings, image: image, identifier: nil, discoverabilityTitle: nil, attributes: [], state: .off) { [weak self] _ in
            self?.viewModel.showAccountSettings()
        }
    }

    private func openSettingsAction() -> UIAction {
        let image = createTintedImage(systemName: "gearshape", configuration: configuration, tintColor: .jamiButtonDark)
        return UIAction(title: L10n.Global.advancedSettings, image: image, identifier: nil, discoverabilityTitle: nil, attributes: [], state: .off) { [weak self] _ in
            self?.viewModel.showGeneralSettings()
        }
    }

    private func aboutJamiAction() -> UIAction {
        let image = UIImage(asset: Asset.jamiIcon)?.resizeImageWith(newSize: CGSize(width: 22, height: 22), opaque: false)
        return UIAction(title: L10n.Smartlist.aboutJami, image: image, identifier: nil, discoverabilityTitle: nil, attributes: [], state: .off) { [weak self] _ in
            self?.viewModel.openAboutJami()
        }
    }
}
