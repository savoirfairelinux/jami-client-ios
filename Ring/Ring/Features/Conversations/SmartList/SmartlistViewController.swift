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
    @IBOutlet weak var searchView: JamiSearchView!
    @IBOutlet weak var donationBaner: UIView!
    @IBOutlet weak var donateButton: UIButton!
    @IBOutlet weak var disableDonationButton: UIButton!
    @IBOutlet weak var donationLabel: UILabel!
    @IBOutlet weak var searchModeActionsContainer: UIView!
    @IBOutlet weak var searchModeActionsStack: UIStackView!

    // account selection
    private var accounPicker = UIPickerView()
    private let accountPickerTextView = UITextField(frame: CGRect.zero)
    private let accountsAdapter = AccountPickerAdapter()
    private var accountsDismissTapRecognizer: UITapGestureRecognizer!

    private var selectedSegmentIndex = BehaviorRelay<Int>(value: 0)
    var viewModel: SmartlistViewModel!
    private let disposeBag = DisposeBag()

    private let contactPicker = CNContactPickerViewController()
    private var headerView: SmartListHeaderView?

    private var contactRequestVC: ContactRequestsViewController?

    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupDataSources()
        self.setupTableView()
        self.setupUI()
        self.applyL10n()
        self.configureNavigationBar()
        self.confugureAccountPicker()
        accountsDismissTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        self.setupSearchBar()
        searchView.configure(with: viewModel.injectionBag, source: viewModel, isIncognito: false, delegate: viewModel)
        if !self.viewModel.isSipAccount() {
            self.setUpContactRequest()
            self.setupUIForNonSipAccount()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.viewModel.closeAllPlayers()
        self.navigationController?.setNavigationBarHidden(false, animated: false)
        configureCustomNavBar(usingCustomSize: true)
        self.viewModel.updateDonationBunnerVisiblity()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        configureCustomNavBar(usingCustomSize: false)
    }

    func setupTableViewHeader(for tableView: UITableView) {
        guard let headerView = loadHeaderView() else { return }

        setupHeaderViewConstraints(headerView, in: tableView)
        bindSegmentControlActions(headerView)
        bindViewModelUpdates(to: headerView, in: tableView)
    }

    private func loadHeaderView() -> SmartListHeaderView? {
        let nib = UINib(nibName: "SmartListHeaderView", bundle: nil)
        return nib.instantiate(withOwner: nil, options: nil).first as? SmartListHeaderView
    }

    private func setupHeaderViewConstraints(_ headerView: SmartListHeaderView, in tableView: UITableView) {
        tableView.tableHeaderView = headerView
        NSLayoutConstraint.activate([
            headerView.widthAnchor.constraint(equalTo: tableView.widthAnchor, constant: -30),
            headerView.centerXAnchor.constraint(equalTo: tableView.centerXAnchor)
        ])
    }

    private func bindSegmentControlActions(_ headerView: SmartListHeaderView) {
        headerView.conversationsSegmentControl.addTarget(self, action: #selector(segmentAction), for: .valueChanged)

        self.selectedSegmentIndex.subscribe { [weak headerView] index in
            headerView?.conversationsSegmentControl.selectedSegmentIndex = index
        }
        .disposed(by: self.disposeBag)
    }

    private func bindViewModelUpdates(to headerView: SmartListHeaderView, in tableView: UITableView) {
        self.viewModel.updateSegmentControl
            .subscribe { [weak headerView, weak tableView, weak self] (messages, requests) in
                guard let headerView = headerView, let tableView = tableView else { return }

                let height: CGFloat = requests == 0 ? 0 : 32
                var frame = headerView.frame
                frame.size.height = height
                headerView.frame = frame

                headerView.setUnread(messages: messages, requests: requests)

                if requests == 0 {
                    headerView.conversationsSegmentControl.selectedSegmentIndex = 0
                    self?.navigationItem.title = L10n.Smartlist.conversations
                }

                // Resetting the header after adjusting its frame.
                tableView.tableHeaderView = headerView
            }
            .disposed(by: self.disposeBag)
    }

    @objc
    func segmentAction(_ segmentedControl: UISegmentedControl) {
        switch segmentedControl.selectedSegmentIndex {
        case 0:
            contactRequestVC?.view.isHidden = true
            searchView.showSearchResult = true
            self.navigationItem.title = L10n.Smartlist.conversations
        case 1:
            contactRequestVC?.view.isHidden = false
            searchView.showSearchResult = false
            self.navigationItem.title = L10n.Smartlist.invitations
        default:
            break
        }
        self.selectedSegmentIndex.accept(segmentedControl.selectedSegmentIndex)
    }

    func addContactRequestVC(controller: ContactRequestsViewController) {
        contactRequestVC = controller
    }

    private func setUpContactRequest() {
        guard let controller = contactRequestVC else { return }
        addChild(controller)

        // make sure that the child view controller's view is the right size
        controller.view.frame = containerView.bounds
        containerView.addSubview(controller.view)

        // you must call this at the end per Apple's documentation
        controller.didMove(toParent: self)
        controller.view.isHidden = true
        self.setupTableViewHeader(for: controller.tableView)
        self.searchView.searchBar.rx.text.orEmpty
            .debounce(Durations.textFieldThrottlingDuration.toTimeInterval(), scheduler: MainScheduler.instance)
            .bind(to: (self.contactRequestVC?.viewModel.filter)!)
            .disposed(by: disposeBag)
    }

    @objc
    func dismissKeyboard() {
        accountPickerTextView.resignFirstResponder()
        view.removeGestureRecognizer(accountsDismissTapRecognizer)
    }

    private func configureCustomNavBar(usingCustomSize: Bool) {
//        return
//        guard let customNavBar = navigationController?.navigationBar as? SmartListNavigationBar else { return }
//
//        if usingCustomSize {
//            self.updateSearchBarIfActive()
//            customNavBar.usingCustomSize = true
//        } else {
//            customNavBar.removeTopView()
//            customNavBar.usingCustomSize = false
//        }
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
        self.viewModel.hideNoConversationsMessage
            .bind(to: self.noConversationLabel.rx.isHidden)
            .disposed(by: disposeBag)
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
//        self.viewModel.currentAccountChanged
//            .observe(on: MainScheduler.instance)
//            .subscribe(onNext: { [weak self] _ in
//                self?.searchBarNotActive()
//            })
//            .disposed(by: disposeBag)
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
        generalSettingsButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.searchController.isActive = true
            })
            .disposed(by: self.disposeBag)
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

    func setupDataSources() {
        // Configure cells closure for the datasources
        let configureCell: (TableViewSectionedDataSource, UITableView, IndexPath, ConversationSection.Item)
            -> UITableViewCell = {
                (   _: TableViewSectionedDataSource<ConversationSection>,
                    tableView: UITableView,
                    indexPath: IndexPath,
                    conversationItem: ConversationSection.Item) in

                let cell = tableView.dequeueReusableCell(for: indexPath, cellType: SmartListCell.self)
                cell.configureFromItem(conversationItem)
                return cell
            }

        // Create DataSources for conversations and filtered conversations
        let conversationsDataSource = RxTableViewSectionedReloadDataSource<ConversationSection>(configureCell: configureCell)
        // Allows to delete
        conversationsDataSource.canEditRowAtIndexPath = { _, _  in
            return true
        }

        // Bind TableViews to DataSources
        self.viewModel.conversations
            .bind(to: self.conversationsTableView.rx.items(dataSource: conversationsDataSource))
            .disposed(by: disposeBag)
    }

    func setupTableView() {
        // Set row height
        self.conversationsTableView.rowHeight = SmartlistConstants.smartlistRowHeight

        // Register Cell
        self.conversationsTableView.register(cellType: SmartListCell.self)
        // Deselect the rows
        self.conversationsTableView.rx.itemSelected
            .subscribe(onNext: { [weak self] indexPath in
                self?.conversationsTableView.deselectRow(at: indexPath, animated: true)
            })
            .disposed(by: disposeBag)

        self.conversationsTableView.rx.setDelegate(self).disposed(by: disposeBag)

        // table header
        setupTableViewHeader(for: self.conversationsTableView)
    }

    let searchController: UISearchController = {
        let searchController = UISearchController(searchResultsController: nil)
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.definesPresentationContext = true
        searchController.hidesNavigationBarDuringPresentation = true
        return searchController
    }()

    func setupSearchBar() {
        searchController.delegate = self
//        let navBar = SmartListNavigationBar()
//        self.navigationController?.setValue(navBar, forKey: "navigationBar")

        navigationItem.searchController = searchController
        if #available(iOS 16.0, *) {
            navigationItem.preferredSearchBarPlacement = .stacked
        }

        navigationItem.hidesSearchBarWhenScrolling = false
        searchView.searchBar = searchController.searchBar
        self.searchView.editSearch
            .subscribe(onNext: {[weak self] (editing) in
                self?.viewModel.searching.onNext(editing)
            })
            .disposed(by: disposeBag)
    }

    func animateHorizontalStackView(shouldAppear: Bool) {
        self.searchModeActionsStack.isHidden = !shouldAppear
        UIView.animate(withDuration: 0.3, animations: { [weak self] in
            guard let self = self else { return}
            self.searchModeActionsContainer.isHidden = !shouldAppear
            self.view.layoutIfNeeded()
        })
    }

    func willPresentSearchController(_ searchController: UISearchController) {
        animateHorizontalStackView(shouldAppear: true)
       // self.searchButtons.isHidden = false
        //self.searchBarActive()
    }

    func updateSearchBarIfActive() {
//        if searchController.isActive {
//            searchBarActive()
//        }
    }

    func updateNetworkUI() {
        let isHidden = self.viewModel.networkConnectionState() == .none ? false : true
        self.networkAlertView.isHidden = isHidden
        self.view.layoutIfNeeded()
    }

//    func searchBarNotActive() {
//        return
//        guard let customNavBar = self.navigationController?.navigationBar as? SmartListNavigationBar else { return }
//        self.navigationItem.title = selectedSegmentIndex.value == 0 ?
//            L10n.Smartlist.conversations : L10n.Smartlist.invitations
//        self.widgetsTopConstraint.constant = 0
//        updateNetworkUI()
//        customNavBar.customHeight = 44
//        customNavBar.searchActive = false
//        customNavBar.removeTopView()
//    }

//    func searchBarActive() {
//        return
//        guard let customNavBar = navigationController?.navigationBar as? SmartListNavigationBar else { return }
//
//        setupCommonUI(customNavBar: customNavBar)
//
//        if viewModel.isSipAccount() {
//            setupUIForSipAccount(customNavBar: customNavBar)
//        } else {
//            setupUIForNonSipAccount(customNavBar: customNavBar)
//        }
//    }

//    private func setupCommonUI(customNavBar: SmartListNavigationBar) {
//        navigationItem.title = ""
//        widgetsTopConstraint.constant = 42
//        customNavBar.customHeight = 70
//        customNavBar.searchActive = true
//    }

//    private func setupUIForSipAccount(customNavBar: SmartListNavigationBar) {
//        let bookButton = createSearchBarButtonWithImage(named: "book.circle", weight: .regular, width: 27)
//        bookButton.setImage(UIImage(asset: Asset.phoneBook), for: .normal)
//        bookButton.rx.tap
//            .subscribe(onNext: { [weak self] in
//                self?.presentContactPicker()
//            })
//            .disposed(by: customNavBar.disposeBag)
//
//        let dialpadCodeButton = createSearchBarButtonWithImage(named: "square.grid.3x3.topleft.filled", weight: .regular, width: 25)
//        dialpadCodeButton.rx.tap
//            .subscribe(onNext: { [weak self] in
//                self?.viewModel.showDialpad()
//            })
//            .disposed(by: customNavBar.disposeBag)
//
//        customNavBar.addTopView(with: [bookButton, dialpadCodeButton])
//    }
//
    private func setupUIForNonSipAccount() {
        let qrCodeButton = UIButton(type: .system)
        qrCodeButton.setImage(UIImage(systemName: "qrcode"), for: .normal)
        qrCodeButton.setTitle("Add Contact", for: .normal)
        qrCodeButton.tintColor = .jamiButtonDark
        let spacing: CGFloat = 5
        qrCodeButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: -spacing, bottom: 0, right: spacing)
        qrCodeButton.titleEdgeInsets = UIEdgeInsets(top: 0, left: spacing, bottom: 0, right: -spacing)
        qrCodeButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: spacing, bottom: 0, right: spacing)

        qrCodeButton.layer.borderColor = UIColor.lightGray.cgColor
        qrCodeButton.layer.borderWidth = 1.0
        qrCodeButton.layer.cornerRadius = 10.0
        qrCodeButton.contentEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
                qrCodeButton.rx.tap
                    .subscribe(onNext: { [weak self] in
                        self?.viewModel.showQRCode()
                    })
                    .disposed(by: self.disposeBag)
        let swarmButton = UIButton(type: .system)
        swarmButton.setImage(UIImage(systemName: "person.2"), for: .normal)
        swarmButton.setTitle("Add Contact", for: .normal)
        swarmButton.tintColor = .jamiButtonDark
        swarmButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: -spacing, bottom: 0, right: spacing)
        swarmButton.titleEdgeInsets = UIEdgeInsets(top: 0, left: spacing, bottom: 0, right: -spacing)
        swarmButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: spacing, bottom: 0, right: spacing)

        swarmButton.layer.borderColor = UIColor.lightGray.cgColor
        swarmButton.layer.borderWidth = 1.0
        swarmButton.layer.cornerRadius = 10.0
        swarmButton.contentEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        swarmButton.rx.tap
                    .subscribe(onNext: { [weak self] in
                        self?.viewModel.createGroup()
                    })
                    .disposed(by: self.disposeBag)
        searchModeActionsStack.addArrangedSubview(qrCodeButton)
        searchModeActionsStack.addArrangedSubview(swarmButton)
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

    func willDismissSearchController(_ searchController: UISearchController) {
        animateHorizontalStackView(shouldAppear: false)
        //searchButtons.isHidden = true
        //searchBarNotActive()
    }

    func startAccountCreation() {
        accountPickerTextView.resignFirstResponder()
        self.viewModel.createAccount()
    }

    func openAccountsList() {
        if searchView.searchBar.isFirstResponder {
            return
        }
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
