/*
 *  Copyright (C) 2017-2021 Savoir-faire Linux Inc.
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
class SmartlistViewController: UIViewController, StoryboardBased, ViewModelBased {

    private let log = SwiftyBeaver.self

    // MARK: outlets
    @IBOutlet weak var conversationsTableView: UITableView!
    @IBOutlet weak var containerView: UIView!
    //    @IBOutlet weak var noConversationsView: UIView!
    //    @IBOutlet weak var noConversationLabel: UILabel!
    //    @IBOutlet weak var networkAlertLabel: UILabel!
    //    @IBOutlet weak var cellularAlertLabel: UILabel!
    //    @IBOutlet weak var settingsButton: UIButton!
    //    @IBOutlet weak var dialpadButton: UIButton!
    //    @IBOutlet weak var dialpadButtonShadow: UIView!
    //    @IBOutlet weak var networkAlertView: UIView!
    @IBOutlet weak var searchView: JamiSearchView!

    // account selection
    var accounPicker = UIPickerView()
    let accountPickerTextView = UITextField(frame: CGRect.zero)
    let accountsAdapter = AccountPickerAdapter()
    var accountsDismissTapRecognizer: UITapGestureRecognizer!
    var accountView = UIView()
    var accountWidth = NSLayoutConstraint()
    let nameLabelTag = 100
    let triangleTag = 200
    let openAccountTag = 300
    let margin: CGFloat = 10
    let size: CGFloat = 32
    let triangleViewSize: CGFloat = 12
    var headerView: SmartListHeaderView?

    var contactRequestVC: ContactRequestsViewController?

    // MARK: members
    var viewModel: SmartlistViewModel!
    private let disposeBag = DisposeBag()

    private let contactPicker = CNContactPickerViewController()

    // MARK: functions
    @IBAction func openScan() {
        self.viewModel.showQRCode()
    }
    @IBAction func createGroup() {
        self.viewModel.createGroup()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupDataSources()
        self.setupTableView()
        self.setupUI()
        self.applyL10n()
        self.configureLargeTitleNavigationBar()
        self.confugureAccountPicker()
        accountsDismissTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        let nib = UINib(nibName: "SmartListHeaderView", bundle: nil)
        if let view = nib.instantiate(withOwner: nil, options: nil).first as? SmartListHeaderView {
            self.headerView = view
            self.conversationsTableView.tableHeaderView = self.headerView
            self.headerView?.conversationsSegmentControl.addTarget(self, action: #selector(segmentAction), for: .valueChanged)
        }

        /*
         Register to keyboard notifications to adjust tableView insets when the keybaord appears
         or disappears
         */
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(withNotification:)), name: UIResponder.keyboardDidShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(withNotification:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        self.setupSearchBar()
        searchView.configure(with: viewModel.injectionBag, source: viewModel, isIncognito: false, delegate: viewModel)
        self.setUpContactRequest()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        // Waiting for screen size change
        //        DispatchQueue.global(qos: .background).async {
        //            sleep(UInt32(0.5))
        //            DispatchQueue.main.async { [weak self] in
        //                guard let self = self,
        //                      UIDevice.current.portraitOrLandscape else { return }
        //                self.updateAccountItemSize()
        //                let messages: Int = Int(self.conversationBadge.title(for: .normal) ?? "0") ?? 0
        //                let requests: Int = Int(self.requestsBadge.title(for: .normal) ?? "0") ?? 0
        //                self.setUpSegmemtControl(messages: messages, requests: requests)
        //                // self.searchController.sizeChanged(to: size.width, totalItems: 2.0)
        //            }
        //        }
        super.viewWillTransition(to: size, with: coordinator)
    }

    @objc
    func segmentAction(_ segmentedControl: UISegmentedControl) {
        switch segmentedControl.selectedSegmentIndex {
        case 0:
            contactRequestVC?.view.isHidden = true
            searchView.showSearchResult = true
        case 1:
            contactRequestVC?.view.isHidden = false
            searchView.showSearchResult = false
        default:
            break
        }
    }

    func addContactRequestVC(controller: ContactRequestsViewController) {
        contactRequestVC = controller
    }

    func setUpContactRequest() {
        guard let controller = contactRequestVC else { return }
        addChild(controller)

        // make sure that the child view controller's view is the right size
        controller.view.frame = containerView.bounds
        containerView.addSubview(controller.view)

        // you must call this at the end per Apple's documentation
        controller.didMove(toParent: self)
        controller.view.isHidden = true
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

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        //        self.navigationController?.navigationBar.layer.shadowColor = UIColor.jamiNavigationBarShadow.cgColor
        //        self.navigationController?.navigationBar
        //            .titleTextAttributes = [NSAttributedString.Key.font: UIFont(name: "HelveticaNeue-Light", size: 25)!,
        //                                    NSAttributedString.Key.foregroundColor: UIColor.jamiMain]
        self.viewModel.closeAllPlayers()
    }

    override func viewDidAppear(_ animated: Bool) {
        // self.searchController.sizeChanged(to: self.view.frame.size.width, totalItems: 2.0)
        super.viewDidAppear(animated)
        //        viewContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 15).isActive = true
        //        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        self.navigationController?.setNavigationBarHidden(false, animated: false)
        //        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        // self.navigationController?.setNavigationBarHidden(false, animated: false)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        //        if scrollView.isTracking || scrollView.isDragging || scrollView.isDecelerating {
        //            if scrollView.panGestureRecognizer.translation(in: scrollView.superview).y > 0 {
        //                self.navigationController?.setNavigationBarHidden(false, animated: true)
        //            } else {
        //                self.navigationController?.setNavigationBarHidden(true, animated: true)
        //            }
        //        }
    }

    func applyL10n() {
        //        noConversationLabel.text = L10n.Smartlist.noConversation
        //        self.networkAlertLabel.text = L10n.Smartlist.noNetworkConnectivity
        //        self.cellularAlertLabel.text = L10n.Smartlist.cellularAccess
    }

    func setUpSegmemtControl(messages: Int, requests: Int) {
        //        if requests == 0 {
        //            segmentControlContainer.isHidden = true
        //            conversationBadge.setTitle(String(messages), for: .normal)
        //            requestsBadge.setTitle(String(requests), for: .normal)
        //            return
        //        }
        //        if segmentControlContainer.isHidden {
        //            conversationsSegmentControl.selectedSegmentIndex = 0
        //        }
        //        segmentControlContainer.isHidden = false
        //        let unreadMessages = messages
        //        let unreadRequests = requests
        //        let margin: CGFloat = 5
        //
        //        self.conversationBadge.isHidden = unreadMessages == 0
        //        self.requestsBadge.isHidden = unreadRequests == 0
        //        let titleFont = UIFont.systemFont(ofSize: 12, weight: .medium)
        //        let attributes = [NSAttributedString.Key.font: titleFont]
        //        let conversationTitle = L10n.Smartlist.conversations
        //        let requestsTitle = L10n.Smartlist.invitations
        //        conversationsSegmentControl.setTitleTextAttributes(attributes, for: .normal)
        //        conversationsSegmentControl.setTitle(conversationTitle, forSegmentAt: 0)
        //        conversationsSegmentControl.setTitle(requestsTitle, forSegmentAt: 1)
        //        conversationBadge.setTitle(String(unreadMessages), for: .normal)
        //        requestsBadge.setTitle(String(unreadRequests), for: .normal)
        //        self.conversationBadge.sizeToFit()
        //        self.requestsBadge.sizeToFit()
        //        self.conversationBadge.setNeedsDisplay()
        //        self.requestsBadge.setNeedsDisplay()
        //
        //        let convBageWidth = unreadMessages == 0 ? 0 : conversationBadge.frame.width
        //        let requestBageWidth = unreadRequests == 0 ? 0 : requestsBadge.frame.size.width
        //        let widthConversation = conversationTitle.size(withAttributes: attributes).width
        //        let widthRequests = requestsTitle.size(withAttributes: attributes).width
        //
        //        let segmentWidth = conversationsSegmentControl.frame.size.width * 0.5
        //        let convContentWidth = convBageWidth + widthConversation + margin
        //        let reqContentWidth = requestBageWidth + widthRequests + margin
        //        conversationsSegmentControl.setContentOffset(CGSize(width: -(convBageWidth + margin) * 0.5, height: 0), forSegmentAt: 0)
        //        conversationsSegmentControl.setContentOffset(CGSize(width: -(requestBageWidth + margin) * 0.5, height: 0), forSegmentAt: 1)
        //        let conversationConstraint = (segmentWidth - convContentWidth) * 0.5 + widthConversation + margin
        //        self.conversationBadgeLeadingConstraint.constant = conversationConstraint
        //        let requestConstraint = (segmentWidth - reqContentWidth) * 0.5
        //        self.requestBadgeTrailingConstraint.constant = requestConstraint
    }

    // swiftlint:disable function_body_length
    func setupUI() {
        self.viewModel.updateSegmentControl.subscribe { [weak self] (messages, requests) in
            if let header = self?.headerView as? SmartListHeaderView {
                header.setUnread(messages: messages, requests: requests)
            }
        }
        .disposed(by: self.disposeBag)

        view.backgroundColor = UIColor.jamiBackgroundColor
        conversationsTableView.backgroundColor = UIColor.jamiBackgroundColor
        //        noConversationsView.backgroundColor = UIColor.jamiBackgroundColor
        //        noConversationLabel.backgroundColor = UIColor.jamiBackgroundColor
        //        noConversationLabel.textColor = UIColor.jamiLabelColor
        //        dialpadButtonShadow.backgroundColor = UIColor.jamiBackgroundSecondaryColor
        //        dialpadButtonShadow.layer.shadowColor = UIColor.jamiLabelColor.cgColor
        //        dialpadButtonShadow.layer.shadowOffset = CGSize.zero
        //        dialpadButtonShadow.layer.shadowRadius = 1
        //        dialpadButtonShadow.layer.shadowOpacity = 0.6
        //        dialpadButtonShadow.layer.masksToBounds = false
        //        self.viewModel.hideNoConversationsMessage
        //            .bind(to: self.noConversationsView.rx.isHidden)
        //            .disposed(by: disposeBag)
        //        let isHidden = self.viewModel.networkConnectionState() == .none ? false : true
        //        self.networkAlertView.isHidden = isHidden
        //        self.viewModel.connectionState
        //            .subscribe(onNext: { [weak self] connectionState in
        //                let isHidden = connectionState == .none ? false : true
        //                self?.networkAlertView.isHidden = isHidden
        //            })
        //            .disposed(by: self.disposeBag)
        //
        //        self.settingsButton.backgroundColor = nil
        //        self.settingsButton.rx.tap
        //            .subscribe(onNext: { _ in
        //                if let url = URL(string: UIApplication.openSettingsURLString) {
        //                    UIApplication.shared.open(url, completionHandler: nil)
        //                }
        //            })
        //            .disposed(by: self.disposeBag)
        //        self.viewModel.currentAccountChanged
        //            .observe(on: MainScheduler.instance)
        //            .subscribe(onNext: { [weak self] currentAccount in
        //                if let account = currentAccount {
        //                    let accountSip = account.type == AccountType.sip
        //                    self?.dialpadButtonShadow.isHidden = !accountSip
        //                    self?.updateSearchBar()
        //                }
        //            })
        //            .disposed(by: disposeBag)
        // create accounts button
        let accountButton = UIButton(type: .custom)
        self.viewModel.profileImage.bind(to: accountButton.rx.image(for: .normal))
            .disposed(by: disposeBag)
        accountButton.roundedCorners = true
        accountButton.clipsToBounds = true
        accountButton.contentMode = .scaleAspectFill
        accountButton.cornerRadius = size * 0.5
        accountButton.frame = CGRect(x: 0, y: 0, width: size, height: size)
        accountButton.imageEdgeInsets = UIEdgeInsets(top: -4, left: -4, bottom: -4, right: -4)
        //        let screenRect = UIScreen.main.bounds
        //        let screenWidth = screenRect.size.width
        //        let window = UIApplication.shared.keyWindow
        //        let leftPadding: CGFloat = window?.safeAreaInsets.left ?? 0
        //        let navControllerMargin = self.navigationController?.systemMinimumLayoutMargins.leading ?? 20
        //        let maxWidth: CGFloat = screenWidth - 32 - navControllerMargin * 3 - leftPadding * 2
        //        let accountNameX: CGFloat = accountButton.frame.origin.x + accountButton.frame.size.width + margin
        //        let triangleViewX: CGFloat = maxWidth - triangleViewSize
        //        let triangleViewY: CGFloat = size * 0.5
        //        let accountNameWidth: CGFloat = maxWidth - triangleViewSize - size - margin * 2
        //        let accountName = UILabel(frame: CGRect(x: accountNameX, y: 5, width: accountNameWidth, height: size))
        //        accountName.tag = nameLabelTag
        //        let triangleView = UIView(frame: CGRect(x: triangleViewX, y: triangleViewY, width: triangleViewSize, height: triangleViewSize))
        //        triangleView.tag = triangleTag
        //        let heightWidth = triangleView.frame.size.width
        //        let path = CGMutablePath()
        //
        //        path.move(to: CGPoint(x: 0, y: 0))
        //        path.addLine(to: CGPoint(x: heightWidth / 2, y: heightWidth / 2))
        //        path.addLine(to: CGPoint(x: heightWidth, y: 0))
        //        path.addLine(to: CGPoint(x: 0, y: 0))
        //
        //        let shape = CAShapeLayer()
        //        shape.path = path
        //        shape.fillColor = UIColor.jamiTextBlue.cgColor
        //        triangleView.layer.insertSublayer(shape, at: 0)
        //        accountName.textAlignment = .left
        //        accountName.font = UIFont.systemFont(ofSize: 18.0)
        //        accountName.lineBreakMode = .byTruncatingTail
        //        accountName.textColor = UIColor.jamiTextBlue
        //        let openButton = UIButton(type: .custom)
        //        openButton.frame = CGRect(x: 0, y: 0, width: maxWidth, height: size)
        //        openButton.tag = openAccountTag
        //        self.viewModel.accountName
        //            .observe(on: MainScheduler.instance)
        //            .subscribe(onNext: { name in
        //                accountName.text = name
        //                accountName.sizeToFit()
        //                var frame = accountName.frame
        //                frame.size.width = min(frame.size.width, maxWidth - 70)
        //                accountName.frame = frame
        //            })
        //            .disposed(by: self.disposeBag)
        //        accountView = UIView(frame: CGRect(x: 0, y: 0, width: maxWidth, height: size))
        //        accountView.addSubview(accountButton)
        //        accountView.addSubview(accountName)
        //        accountView.addSubview(triangleView)
        //        accountView.addSubview(openButton)
        let accountButtonItem = UIBarButtonItem(customView: accountButton)
        accountButtonItem
            .customView?
            .translatesAutoresizingMaskIntoConstraints = false
        accountButtonItem.customView?
            .heightAnchor
            .constraint(equalToConstant: size).isActive = true
        accountButtonItem.customView?
            .widthAnchor
            .constraint(equalToConstant: size).isActive = true
        accountButton.rx.tap
            .throttle(Durations.halfSecond.toTimeInterval(), scheduler: MainScheduler.instance)
            .subscribe(onNext: { [weak self] in
                self?.openAccountsList()
            })
            .disposed(by: self.disposeBag)
        self.navigationItem.leftBarButtonItem = accountButtonItem
        self.navigationItem.rightBarButtonItem = createMenuButton()

        //        dialpadButton.rx.tap
        //            .subscribe(onNext: { [weak self] in
        //                self?.viewModel.showDialpad()
        //            })
        //            .disposed(by: self.disposeBag)
        self.conversationsTableView.tableFooterView = UIView()
    }

    func createMenuButton() -> UIBarButtonItem {
        let imageSettings = UIImage(systemName: "ellipsis.circle") as UIImage?
        let generalSettingsButton = UIButton(type: UIButton.ButtonType.system) as UIButton
        generalSettingsButton.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
        generalSettingsButton.setImage(imageSettings, for: .normal)
        generalSettingsButton.menu = createMenu()
        generalSettingsButton.tintColor = .jamiMain
        generalSettingsButton.showsMenuAsPrimaryAction = true
        return UIBarButtonItem(customView: generalSettingsButton)
    }

    func createMenu() -> UIMenu {
        let configuration = UIImage.SymbolConfiguration(pointSize: 40, weight: .regular, scale: .large)
        let accountImage = UIImage(systemName: "person.circle", withConfiguration: configuration)
        let tintedAccountImage = accountImage?.withTintColor(.jamiMain, renderingMode: .alwaysOriginal)

        let generalImage = UIImage(systemName: "gearshape", withConfiguration: configuration)
        let tintedGeneralImage = generalImage?.withTintColor(.jamiMain, renderingMode: .alwaysOriginal)

        let aboutImage = UIImage(asset: Asset.jamiIcon)

        let openAccount = UIAction(title: L10n.Global.accountSettings, image: tintedAccountImage, identifier: nil, discoverabilityTitle: nil, attributes: [], state: .off) { [weak self] _ in
            self?.viewModel.showAccountSettings()
        }

        let openSettings = UIAction(title: L10n.Global.advancedSettings, image: tintedGeneralImage, identifier: nil, discoverabilityTitle: nil, attributes: [], state: .off) { [weak self] _ in
            self?.viewModel.showGeneralSettings()
        }

        let aboutJami = UIAction(title: L10n.Smartlist.aboutJami, image: aboutImage, identifier: nil, discoverabilityTitle: nil, attributes: [], state: .off) { _ in
            AppInfoHelper.showAboutJamiAlert(onViewController: self)
        }

        return UIMenu(title: "", children: [openAccount, openSettings, aboutJami])
    }

    private func updateAccountItemSize() {
        return
        let screenRect = UIScreen.main.bounds
        let screenWidth = screenRect.size.width
        let window = UIApplication.shared.keyWindow
        let leftPadding: CGFloat = window?.safeAreaInsets.left ?? 0
        let navControllerMargin = self.navigationController?.systemMinimumLayoutMargins.leading ?? 20
        let maxWidth: CGFloat = screenWidth - 32 - navControllerMargin * 3 - leftPadding * 2
        accountWidth.constant = maxWidth
        var accountFrame = accountView.frame
        accountFrame.size.width = maxWidth
        accountView.frame = accountFrame
        if let triangle = accountView.subviews.filter({ view in
            return view.tag == triangleTag
        }).first {
            var triangleFrame = triangle.frame
            let triangleViewX: CGFloat = maxWidth - triangleViewSize - 2
            triangleFrame.origin.x = triangleViewX
            triangle.frame = triangleFrame
        }
        if let name = accountView.subviews.filter({ view in
            return view.tag == nameLabelTag
        }).first {
            var nameFrame = name.frame
            let accountNameWidth: CGFloat = maxWidth - triangleViewSize - size - margin * 2
            nameFrame.size.width = accountNameWidth
            name.frame = nameFrame
        }
        if let button = accountView.subviews.filter({ view in
            return view.tag == openAccountTag
        }).first {
            var buttonFrame = button.frame
            buttonFrame.size.width = maxWidth
            button.frame = buttonFrame
        }
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
            // dialpadButtonShadow.isHidden = account.type == AccountType.ring
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
        addAccountButton.setTitleColor(.jamiMain, for: .normal)
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

    @objc
    func keyboardWillShow(withNotification notification: Notification) {
        guard let userInfo: Dictionary = notification.userInfo else { return }
        guard let keyboardFrame: NSValue = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }
        let keyboardRectangle = keyboardFrame.cgRectValue
        let keyboardHeight = keyboardRectangle.height
        self.conversationsTableView.contentInset.bottom = keyboardHeight
        self.searchView.searchResultsTableView.contentInset.bottom = keyboardHeight
        self.conversationsTableView.scrollIndicatorInsets.bottom = keyboardHeight
        self.searchView.searchResultsTableView.scrollIndicatorInsets.bottom = keyboardHeight
    }

    @objc
    func keyboardWillHide(withNotification notification: Notification) {
        self.conversationsTableView.contentInset.bottom = 0
        self.searchView.searchResultsTableView.contentInset.bottom = 0

        self.conversationsTableView.scrollIndicatorInsets.bottom = 0
        self.searchView.searchResultsTableView.scrollIndicatorInsets.bottom = 0
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
    }

    let searchController = UISearchController(searchResultsController: nil)
    //    : CustomSearchController = {
    //        let searchController = CustomSearchController(searchResultsController: nil)
    //        // searchController.searchBar.searchBarStyle = .minimal
    //        searchController.obscuresBackgroundDuringPresentation = false
    //        searchController.definesPresentationContext = true
    //        searchController.hidesNavigationBarDuringPresentation = true
    //        return searchController
    //    }()

    func updateSearchBar() {
        //        guard let account = self.viewModel.currentAccount else { return }
        //        let accountSip = account.type == AccountType.sip
        //        let image = accountSip ? UIImage(asset: Asset.phoneBook) : UIImage(asset: Asset.qrCode)
        //        guard let buttonImage = image else { return }
        //        searchController.updateSearchBar(image: buttonImage)
        //        if !accountSip {
        //            let image1 = UIImage(asset: Asset.createSwarm)
        //            guard let buttonImage = image1 else { return }
        //            searchController.updateSearchBar(image: buttonImage)
        //        }
    }
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        // -100 from total width as number of buttons in navigation items are 2
        if let container = self.searchController.searchBar.superview {
            container.frame = CGRect(x: container.frame.origin.x, y: container.frame.origin.y, width: self.view.frame.size.width - 100, height: container.frame.size.height)
        }
    }

    func setupSearchBar() {
        guard let account = self.viewModel.currentAccount else { return }
        let accountSip = account.type == AccountType.sip
        //        let image = accountSip ? UIImage(asset: Asset.phoneBook) : UIImage(asset: Asset.qrCode)
        //        guard let buttonImage = image else { return }
        //        searchController
        //            .configureSearchBar(image: buttonImage, position: 1,
        //                                buttonPressed: { [weak self] in
        //                                    guard let self = self else { return }
        //                                    guard let account = self.viewModel.currentAccount else { return }
        //                                    let accountSip = account.type == AccountType.sip
        //                                    if accountSip {
        //                                        self.contactPicker.delegate = self
        //                                        self.present(self.contactPicker, animated: true, completion: nil)
        //                                    } else {
        //                                        self.openScan()
        //                                    }
        //                                })
        if !accountSip {
            let image1 = UIImage(asset: Asset.createSwarm)
            guard let buttonImage1 = image1 else { return }
            //            searchController
            //                .configureSearchBar(image: buttonImage1, position: 2,
            //                                    buttonPressed: { [weak self] in
            //                                        guard let self = self else { return }
            //                                        //                                        guard let account = self.viewModel.currentAccount else { return }
            //                                        //                                        let accountSip = account.type == AccountType.sip
            //                                        //                                        if accountSip {
            //                                        //                                            self.contactPicker.delegate = self
            //                                        //                                            self.present(self.contactPicker, animated: true, completion: nil)
            //                                        //                                        } else {
            //                                        self.createGroup()
            //                                        //                                        }
            //                                    })
            //        }
            // searchController.searchResultsUpdater = self
            searchController.obscuresBackgroundDuringPresentation = false
            searchController.searchBar.placeholder = "Search"
            navigationItem.searchController = searchController
            definesPresentationContext = true

            navigationItem.searchController = searchController
            navigationController?.navigationBar.prefersLargeTitles = true
            navigationItem.title = "Conversations"

            navigationItem.hidesSearchBarWhenScrolling = false
            searchView.searchBar = searchController.searchBar
            self.searchView.editSearch
                .subscribe(onNext: {[weak self] (editing) in
                    self?.viewModel.searching.onNext(editing)
                })
                .disposed(by: disposeBag)
        }
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
