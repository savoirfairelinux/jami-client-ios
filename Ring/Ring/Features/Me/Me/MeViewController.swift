/*
 *  Copyright (C) 2017-2019 Savoir-faire Linux Inc.
 *
 *  Author: Edric Ladent-Milaret <edric.ladent-milaret@savoirfairelinux.com>
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
 *  Author: Quentin Muret <quentin.muret@savoirfairelinux.com>
 *  Author: Alireza Toghiani Khorasgani <alireza.toghiani@savoirfairelinux.com>
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
import Reusable
import RxSwift
import RxCocoa
import RxDataSources

// swiftlint:disable type_body_length
// swiftlint:disable file_length
class MeViewController: EditProfileViewController, StoryboardBased, ViewModelBased {
    // MARK: - outlets
    @IBOutlet private weak var settingsTable: SettingsTableView!

    // MARK: - members
    var viewModel: MeViewModel!
    private let disposeBag = DisposeBag()
    private var stretchyHeader: AccountHeader!

    var sipCredentialsMargin: CGFloat = 0
    var connectivityMargin: CGFloat = 0
    let sipCredentialsTAG: Int = 100

    private let sipAccountCredentialsCell = "sipAccountCredentialsCell"
    private let jamiIDCell = "jamiIDCell"
    private let turnCell = "turnCell"
    private let jamiUserNameCell = "jamiUserNameCell"
    private let accountStateCell = "accountStateCell"
    var loadingViewPresenter = LoadingViewPresenter()

    // MARK: - functio
    override func viewDidLoad() {
        self.view.backgroundColor = .systemGroupedBackground
        setupTableView()
        self.addHeaderView()
        super.viewDidLoad()
        self.applyL10n()
        self.configureBindings()
        self.calculateSipCredentialsMargin()
        self.calculateConnectivityMargin()
        self.adaptTableToKeyboardState(for: self.settingsTable,
                                       with: self.disposeBag,
                                       topOffset: self.stretchyHeader.minimumContentHeight)
        NotificationCenter
            .default
            .addObserver(self,
                         selector: #selector(preferredContentSizeChanged(_:)),
                         name: UIContentSizeCategory.didChangeNotification,
                         object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleContentSizeCategoryDidChange),
            name: UIContentSizeCategory.didChangeNotification,
            object: nil
        )
    }

    @objc
    private func preferredContentSizeChanged(_ notification: NSNotification) {
        self.calculateSipCredentialsMargin()
        self.calculateConnectivityMargin()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.navigationBar.layer.shadowColor = UIColor.clear.cgColor
        self.navigationController?.navigationBar
            .titleTextAttributes = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 18, weight: .medium)]
        self.configureNavigationBar(backgroundColor: .systemGroupedBackground)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.configureNavigationBar()
        self.navigationController?.navigationBar.layer.shadowColor = UIColor.jamiNavigationBarShadow.cgColor
    }

    func setupTableView() {
        self.settingsTable.separatorInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        self.settingsTable.alwaysBounceHorizontal = false
        if #available(iOS 15.0, *) {
            self.settingsTable.sectionHeaderTopPadding = 0
        }
    }

    func applyL10n() {
        self.navigationItem.title = L10n.Global.accountSettings
        self.profileName.placeholder = L10n.Global.name
    }

    private func addHeaderView() {
        guard let nibViews = Bundle.main
                .loadNibNamed("AccountHeader", owner: self, options: nil) else {
            supportEditProfile()
            return
        }
        guard let headerView = nibViews.first as? AccountHeader else {
            supportEditProfile()
            return
        }
        headerView.backgroundColor = .systemGroupedBackground
        self.stretchyHeader = headerView
        let point = CGPoint(x: 0, y: 120)
        self.stretchyHeader.frame.origin = point
        self.settingsTable.addSubview(self.stretchyHeader)
        self.settingsTable.delegate = self
        self.profileImageView = stretchyHeader.profileImageView
        self.profileName = stretchyHeader.profileName
    }

    private func supportEditProfile() {
        // if loading grom nib failed add empty views requered by EditProfileViewController
        let image = UIImageView()
        let name = UITextField()
        self.view.addSubview(image)
        self.view.addSubview(name)
        self.profileImageView = image
        self.profileName = name
    }

    private func configureBindings() {
        let imageQrCode = UIImage(asset: Asset.qrCode) as UIImage?
        let qrCodeButton = UIButton(type: UIButton.ButtonType.custom) as UIButton
        qrCodeButton.setImage(imageQrCode, for: .normal)
        self.viewModel.isAccountSip
            .asObservable()
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak qrCodeButton](isSip) in
                qrCodeButton?.isHidden = isSip
                qrCodeButton?.isEnabled = !isSip
            })
            .disposed(by: self.disposeBag)
        let qrCodeButtonItem = UIBarButtonItem(customView: qrCodeButton)
        qrCodeButton.rx.tap.throttle(Durations.halfSecond.toTimeInterval(), scheduler: MainScheduler.instance)
            .subscribe(onNext: { [weak self] in
                self?.qrCodeItemTapped()
            })
            .disposed(by: self.disposeBag)
        self.viewModel.showActionState.asObservable()
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self](action) in
                switch action {
                case .noAction:
                    break
                case .hideLoading:
                    self?.stopLoadingView()
                case .showLoading:
                    self?.showLoadingView()
                case .deviceRevokedWithSuccess(let deviceId):
                    self?.showDeviceRevokedAlert(deviceId: deviceId)
                case .deviceRevocationError(let deviceId, let errorMessage):
                    self?.showDeviceRevocationError(deviceId: deviceId, errorMessage: errorMessage)
                case .usernameRegistered:
                    self?.stopLoadingView()
                case .usernameRegistrationFailed(let errorMessage):
                    self?.showNameRegisterationFailed(error: errorMessage)
                }
            })
            .disposed(by: self.disposeBag)
        self.navigationItem.rightBarButtonItem = qrCodeButtonItem

        // setup Table
        self.settingsTable.estimatedRowHeight = 35
        self.settingsTable.rowHeight = UITableView.automaticDimension
        self.settingsTable.tableFooterView = UIView()

        // Register cell
        self.setUpDataSource()
        self.settingsTable.register(cellType: DeviceCell.self)
    }

    private func openBlockedList() {
        self.viewModel.showBlockedContacts()
    }

    private func showLoadingView() {
        loadingViewPresenter.presentWithMessage(message: L10n.AccountPage.deviceRevocationProgress, presentingVC: self, animated: true)
    }

    private func showNameRegistration() {
        loadingViewPresenter.presentWithMessage(message: L10n.AccountPage.usernameRegistering, presentingVC: self, animated: true)
    }

    private func showDeviceRevocationError(deviceId: String, errorMessage: String) {
        loadingViewPresenter.hide(animated: true) { [weak self] in
            guard let self = self else { return }
            let alert = UIAlertController(title: errorMessage,
                                          message: nil,
                                          preferredStyle: .alert)
            let actionCancel = UIAlertAction(title: L10n.Global.cancel,
                                             style: .cancel)
            let actionAgain = UIAlertAction(title: L10n.AccountPage.deviceRevocationTryAgain,
                                            style: .default) { [weak self] _ in
                self?.confirmRevokeDeviceAlert(deviceID: deviceId)
            }
            alert.addAction(actionCancel)
            alert.addAction(actionAgain)
            self.present(alert, animated: true, completion: nil)
        }
    }

    private func showDeviceRevokedAlert(deviceId: String) {
        loadingViewPresenter.hide(animated: true) { [weak self] in
            guard let self = self else { return }
            let alert = UIAlertController(title: L10n.AccountPage.deviceRevocationSuccess,
                                          message: nil,
                                          preferredStyle: .alert)
            let actionOk = UIAlertAction(title: L10n.Global.ok,
                                         style: .default)
            alert.addAction(actionOk)
            self.present(alert, animated: true, completion: nil)
        }
    }

    private func showNameRegisterationFailed(error: String) {
        loadingViewPresenter.hide(animated: true) { [weak self] in
            guard let self = self else { return }
            let alert = UIAlertController(title: error,
                                          message: nil,
                                          preferredStyle: .alert)
            let actionOk = UIAlertAction(title: L10n.Global.ok,
                                         style: .default)
            alert.addAction(actionOk)
            self.present(alert, animated: true, completion: nil)
        }
    }

    private func qrCodeItemTapped() {
        let alert = UIAlertController(title: "", message: "", preferredStyle: .alert)
        guard let ringId = viewModel.getRingId() else { return }
        let imageQRCode = UIImageView(image: generateQRCode(from: ringId))
        imageQRCode.layer.cornerRadius = 8.0
        imageQRCode.clipsToBounds = true
        imageQRCode.translatesAutoresizingMaskIntoConstraints = false
        alert.view.addSubview(imageQRCode)
        alert.view.addConstraint(NSLayoutConstraint(item: imageQRCode, attribute: .centerX, relatedBy: .equal, toItem: alert.view, attribute: .centerX, multiplier: 1, constant: 0))
        alert.view.addConstraint(NSLayoutConstraint(item: imageQRCode, attribute: .centerY, relatedBy: .equal, toItem: alert.view, attribute: .top, multiplier: 1, constant: 0.0))
        alert.view.addConstraint(NSLayoutConstraint(item: imageQRCode, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: 270))
        alert.view.addConstraint(NSLayoutConstraint(item: imageQRCode, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: 270))
        self.present(alert, animated: true, completion: {
            alert.view.superview?.isUserInteractionEnabled = true
            alert.view.superview?.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.alertControllerBackgroundTapped)))
        })
    }

    @objc
    func alertControllerBackgroundTapped() {
        self.dismiss(animated: true, completion: nil)
    }

    func generateQRCode(from string: String) -> UIImage? {
        let data = string.data(using: String.Encoding.ascii)
        if let filter = CIFilter(name: "CIQRCodeGenerator") {
            filter.setValue(data, forKey: "inputMessage")
            let transform = CGAffineTransform(scaleX: 100, y: 100)
            if let output = filter.outputImage?.transformed(by: transform) {
                return UIImage(ciImage: output)
            }
        }
        return nil
    }

    // swiftlint:disable function_body_length
    // swiftlint:disable cyclomatic_complexity
    // swiftlint:disable closure_body_length
    private func setUpDataSource() {

        let configureCell: (TableViewSectionedDataSource, UITableView, IndexPath, SettingsSection.Item)
            -> UITableViewCell = {
                ( dataSource: TableViewSectionedDataSource<SettingsSection>,
                  tableView: UITableView,
                  indexPath: IndexPath,
                  _: SettingsSection.Item) in
                switch dataSource[indexPath] {
                case .autoRegistration:
                    let cell = DisposableCell()
                    cell.textLabel?.text = L10n.AccountPage.autoRegistration
                    cell.textLabel?.numberOfLines = 0
                    let switchView = UISwitch()
                    switchView.onTintColor = .jamiButtonDark
                    cell.selectionStyle = .none
                    cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                    cell.accessoryView = switchView
                    self.viewModel.keepAliveEnabled
                        .asObservable()
                        .startWith(self.viewModel.keepAliveEnabled.value)
                        .observe(on: MainScheduler.instance)
                        .bind(to: switchView.rx.value)
                        .disposed(by: cell.disposeBag)
                    switchView.rx
                        .isOn.changed
                        .debounce(Durations.switchThrottlingDuration.toTimeInterval(), scheduler: MainScheduler.instance)
                        .distinctUntilChanged()
                        .asObservable()
                        .subscribe(onNext: {[weak self] enable in
                            self?.viewModel.enableKeepAlive(enable: enable)
                        })
                        .disposed(by: cell.disposeBag)
                    return cell
                case .device(let device):
                    let cell = tableView.dequeueReusableCell(for: indexPath, cellType: DeviceCell.self)
                    cell.deviceIdLabel.text = device.deviceId
                    cell.deviceIdLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
                    cell.textLabel?.numberOfLines = 0
                    cell.deviceIdLabel.sizeToFit()
                    if let deviceName = device.deviceName {
                        cell.deviceNameLabel.text = deviceName
                        cell.deviceNameLabel.font = UIFont.preferredFont(forTextStyle: .body)
                        cell.deviceNameLabel.sizeToFit()
                    }
                    cell.selectionStyle = .none
                    cell.removeDevice.isHidden = device.isCurrent
                    cell.removeDevice.rx.tap
                        .subscribe(onNext: { [weak self, device] in
                            self?.confirmRevokeDeviceAlert(deviceID: device.deviceId)
                        })
                        .disposed(by: cell.disposeBag)
                    cell.sizeToFit()
                    return cell
                case .linkNew:
                    let cell = DisposableCell()
                    cell.textLabel?.text = L10n.AccountPage.linkDeviceTitle
                    cell.textLabel?.textColor = UIColor.jamiButtonDark
                    cell.textLabel?.textAlignment = .center
                    cell.textLabel?.numberOfLines = 0
                    cell.selectionStyle = .none
                    cell.sizeToFit()
                    let button = UIButton.init(frame: cell.frame)
                    let size = CGSize(width: self.settingsTable.frame.width, height: button.frame.height)
                    button.frame.size = size
                    cell.addSubview(button)
                    button.rx.tap
                        .subscribe(onNext: { [weak self] in
                            self?.viewModel.linkDevice()
                        })
                        .disposed(by: cell.disposeBag)
                    return cell
                case .blockedList:
                    let cell = DisposableCell()
                    cell.textLabel?.text = L10n.AccountPage.blockedContacts
                    cell.textLabel?.font = UIFont.preferredFont(forTextStyle: .body)
                    cell.textLabel?.numberOfLines = 0
                    cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                    cell.selectionStyle = .none
                    cell.sizeToFit()
                    let button = UIButton.init(frame: cell.frame)
                    let size = CGSize(width: self.settingsTable.frame.width, height: button.frame.height)
                    button.frame.size = size
                    cell.addSubview(button)
                    button.rx.tap
                        .subscribe(onNext: { [weak self] in
                            self?.openBlockedList()
                        })
                        .disposed(by: cell.disposeBag)
                    return cell
                case .removeAccount:
                    let cell = DisposableCell()
                    cell.textLabel?.text = L10n.Global.removeAccount
                    cell.textLabel?.textColor = UIColor.systemRed
                    cell.textLabel?.textAlignment = .center
                    cell.textLabel?.numberOfLines = 0
                    cell.selectionStyle = .none
                    cell.sizeToFit()
                    let button = UIButton.init(frame: cell.frame)
                    let size = CGSize(width: self.settingsTable.frame.width, height: 25)
                    button.frame.size = size
                    cell.addSubview(button)
                    button.rx.tap
                        .subscribe(onNext: { [weak self] in
                            self?.confirmRemoveAccountAlert()
                        })
                        .disposed(by: cell.disposeBag)
                    return cell
                case .jamiUserName(let label):
                    if !label.isEmpty {
                        return self.configureCellWithEnableTextCopy(text: L10n.Global.username,
                                                                    secondaryText: label,
                                                                    style: .callout, accessibilityIdentifier: AccessibilityIdentifiers.accountRegisteredName)
                    }
                    let cell = DisposableCell()
                    cell.textLabel?.text = L10n.Global.registerAUsername
                    cell.textLabel?.textColor = UIColor.jamiButtonDark
                    cell.textLabel?.textAlignment = .center
                    cell.textLabel?.numberOfLines = 0
                    cell.sizeToFit()
                    cell.selectionStyle = .none
                    let button = UIButton.init(frame: cell.frame)
                    let size = CGSize(width: self.settingsTable.frame.width, height: button.frame.height)
                    button.frame.size = size
                    cell.addSubview(button)
                    button.rx.tap
                        .subscribe(onNext: { [weak self] in
                            self?.registerUsername()
                        })
                        .disposed(by: cell.disposeBag)
                    return cell
                case .jamiID(let label):
                    return self.configureCellWithEnableTextCopy(text: "Jami ID",
                                                                secondaryText: label,
                                                                style: .footnote, accessibilityIdentifier: AccessibilityIdentifiers.accountJamiId)
                case .ordinary(let label):
                    let cell = UITableViewCell()
                    cell.textLabel?.text = label
                    cell.textLabel?.numberOfLines = 0
                    cell.selectionStyle = .none
                    return cell
                case .shareAccountDetails:
                    let cell = DisposableCell()
                    cell.textLabel?.text = L10n.AccountPage.inviteFriends
                    cell.textLabel?.textColor = UIColor.jamiButtonDark
                    cell.textLabel?.textAlignment = .center
                    cell.textLabel?.numberOfLines = 0
                    cell.sizeToFit()
                    cell.selectionStyle = .none
                    let button = UIButton.init(frame: cell.frame)
                    let size = CGSize(width: cell.contentView.bounds.width, height: button.frame.height)
                    button.frame.size = size
                    cell.contentView.addSubview(button)
                    button.rx.tap
                        .subscribe(onNext: { [weak self] in
                            self?.shareAccountInfo()
                        })
                        .disposed(by: cell.disposeBag)
                    return cell
                case .changePassword:
                    let cell = DisposableCell()
                    let title = self.viewModel.hasPassword() ?
                        L10n.AccountPage.changePassword : L10n.AccountPage.createPassword
                    cell.textLabel?.text = title
                    cell.textLabel?.textColor = UIColor.jamiButtonDark
                    cell.textLabel?.textAlignment = .center
                    cell.textLabel?.numberOfLines = 0
                    cell.sizeToFit()
                    cell.selectionStyle = .none
                    let button = UIButton.init(frame: cell.frame)
                    let size = CGSize(width: self.settingsTable.frame.width, height: button.frame.height)
                    button.frame.size = size
                    cell.addSubview(button)
                    button.rx.tap
                        .subscribe(onNext: { [weak self] in
                            self?.changePassword(title: title)
                        })
                        .disposed(by: cell.disposeBag)
                    return cell
                case .notifications:
                    let cell = DisposableCell()
                    cell.textLabel?.text = L10n.AccountPage.enableNotifications
                    cell.textLabel?.numberOfLines = 0
                    let switchView = UISwitch()
                    switchView.onTintColor = .jamiButtonDark
                    cell.selectionStyle = .none
                    cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                    cell.accessoryView = switchView
                    self.viewModel.notificationsEnabledObservable
                        .observe(on: MainScheduler.instance)
                        .bind(to: switchView.rx.value)
                        .disposed(by: cell.disposeBag)
                    switchView.setOn(self.viewModel.notificationsEnabled, animated: false)
                    switchView.rx
                        .isOn.changed
                        .debounce(Durations.switchThrottlingDuration.toTimeInterval(), scheduler: MainScheduler.instance)
                        .distinctUntilChanged()
                        .asObservable()
                        .subscribe(onNext: {[weak self] value in
                            self?.viewModel.enableNotifications(enable: value)
                        })
                        .disposed(by: cell.disposeBag)
                    return cell
                case .peerDiscovery:
                    let cell = DisposableCell()
                    cell.textLabel?.text = L10n.AccountPage.peerDiscovery
                    cell.textLabel?.numberOfLines = 0
                    let switchView = UISwitch()
                    switchView.onTintColor = .jamiButtonDark
                    cell.selectionStyle = .none
                    cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                    cell.accessoryView = switchView
                    self.viewModel.peerDiscoveryEnabled
                        .asObservable()
                        .startWith(self.viewModel.peerDiscoveryEnabled.value)
                        .observe(on: MainScheduler.instance)
                        .bind(to: switchView.rx.value)
                        .disposed(by: cell.disposeBag)
                    switchView.rx
                        .isOn.changed
                        .debounce(Durations.switchThrottlingDuration.toTimeInterval(), scheduler: MainScheduler.instance)
                        .distinctUntilChanged()
                        .asObservable()
                        .subscribe(onNext: {[weak self] enable in
                            self?.viewModel.enablePeerDiscovery(enable: enable)
                        })
                        .disposed(by: cell.disposeBag)
                    return cell
                case .proxy:
                    let cell = DisposableCell(style: .value1, reuseIdentifier: self.sipAccountCredentialsCell)
                    cell.backgroundColor = UIColor.jamiBackgroundColor
                    cell.selectionStyle = .none
                    let text = UITextField()
                    text.autocorrectionType = .no
                    text.font = UIFont.preferredFont(forTextStyle: .callout)
                    text.returnKeyType = .done
                    text.text = self.viewModel.proxyAddress.value
                    text.sizeToFit()
                    text.rx.controlEvent(.editingDidEndOnExit)
                        .observe(on: MainScheduler.instance)
                        .subscribe(onNext: { [weak self] _ in
                            guard let text = text.text else { return }
                            self?.viewModel.changeProxy(proxyServer: text)
                        })
                        .disposed(by: cell.disposeBag)
                    cell.textLabel?.text = "Proxy server"
                    cell.textLabel?.sizeToFit()
                    cell.sizeToFit()
                    cell.detailTextLabel?.font = UIFont.preferredFont(forTextStyle: .callout)
                    cell.detailTextLabel?.textColor = UIColor.clear
                    var frame = CGRect(x: self.sipCredentialsMargin, y: 0,
                                       width: self.view.frame.width - self.sipCredentialsMargin,
                                       height: cell.frame.height)
                    if self.view.frame.width - self.sipCredentialsMargin < text.frame.size.width {
                        let origin = CGPoint(x: 10, y: cell.textLabel!.frame.size.height + 25)
                        let size = text.frame.size
                        frame.origin = origin
                        frame.size = size
                        cell.detailTextLabel?.text = self.viewModel.proxyAddress.value
                    } else {
                        cell.detailTextLabel?.text = ""
                    }
                    cell.detailTextLabel?.sizeToFit()
                    text.frame = frame
                    cell.contentView.addSubview(text)
                    cell.sizeToFit()
                    return cell
                case .sipUserName(let value):
                    let cell = self
                        .configureSipCredentialsCell(cellType: .sipUserName(value: value),
                                                     value: value)
                    return cell
                case .sipPassword(let value):
                    let cell = self
                        .configureSipCredentialsCell(cellType: .sipPassword(value: value),
                                                     value: value)
                    return cell
                case .sipServer(let value):
                    let cell = self
                        .configureSipCredentialsCell(cellType: .sipServer(value: value),
                                                     value: value)
                    return cell
                case .proxyServer(let value):
                    let cell = self
                        .configureSipCredentialsCell(cellType: .proxyServer(value: value),
                                                     value: value)
                    return cell
                case .port(let value):
                    let cell = self
                        .configureSipCredentialsCell(cellType: .port(value: value),
                                                     value: value)
                    return cell
                case .accountState(let state):
                    let cell = DisposableCell(style: .value1, reuseIdentifier: self.accountStateCell)
                    cell.textLabel?.text = L10n.Account.accountStatus
                    cell.textLabel?.numberOfLines = 0
                    cell.selectionStyle = .none
                    cell.textLabel?.sizeToFit()
                    cell.detailTextLabel?.font = UIFont.preferredFont(forTextStyle: .callout)
                    cell.detailTextLabel?.text = state.value
                    state.asObservable()
                        .observe(on: MainScheduler.instance)
                        .subscribe(onNext: { (status) in
                            cell.detailTextLabel?.text = status
                        })
                        .disposed(by: cell.disposeBag)
                    return cell
                case .enableAccount:
                    let cell = DisposableCell()
                    cell.textLabel?.text = L10n.Account.enableAccount
                    cell.textLabel?.numberOfLines = 0
                    let switchView = UISwitch()
                    switchView.onTintColor = .jamiButtonDark
                    cell.selectionStyle = .none
                    cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                    cell.accessoryView = switchView
                    switchView.setOn(self.viewModel.accountEnabled.value,
                                     animated: false)
                    self.viewModel.accountEnabled
                        .asObservable()
                        .observe(on: MainScheduler.instance)
                        .bind(to: switchView.rx.value)
                        .disposed(by: cell.disposeBag)
                    switchView.rx
                        .isOn.changed
                        .debounce(Durations.switchThrottlingDuration.toTimeInterval(), scheduler: MainScheduler.instance)
                        .distinctUntilChanged()
                        .asObservable()
                        .subscribe(onNext: {[weak self] enable in
                            self?.viewModel.enableAccount(enable: enable)
                        })
                        .disposed(by: cell.disposeBag)
                    return cell
                case .turnEnabled:
                    let cell = DisposableCell()
                    cell.textLabel?.text = L10n.AccountPage.turnEnabled
                    cell.textLabel?.numberOfLines = 0
                    let switchView = UISwitch()
                    switchView.onTintColor = .jamiButtonDark
                    cell.selectionStyle = .none
                    cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                    cell.accessoryView = switchView
                    self.viewModel.turnEnabled
                        .asObservable()
                        .startWith(self.viewModel.turnEnabled.value)
                        .observe(on: MainScheduler.instance)
                        .bind(to: switchView.rx.value)
                        .disposed(by: cell.disposeBag)
                    switchView.rx
                        .isOn.changed
                        .debounce(Durations.switchThrottlingDuration.toTimeInterval(), scheduler: MainScheduler.instance)
                        .distinctUntilChanged()
                        .asObservable()
                        .subscribe(onNext: {[weak self] enable in
                            self?.viewModel.enableTurn(enable: enable)
                        })
                        .disposed(by: cell.disposeBag)
                    return cell
                case .upnpEnabled:
                    let cell = DisposableCell()
                    cell.textLabel?.text = L10n.AccountPage.upnpEnabled
                    cell.textLabel?.numberOfLines = 0
                    let switchView = UISwitch()
                    switchView.onTintColor = .jamiButtonDark
                    cell.selectionStyle = .none
                    cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                    cell.accessoryView = switchView
                    self.viewModel.upnpEnabled
                        .asObservable()
                        .startWith(self.viewModel.upnpEnabled.value)
                        .observe(on: MainScheduler.instance)
                        .bind(to: switchView.rx.value)
                        .disposed(by: cell.disposeBag)
                    switchView.rx
                        .isOn.changed
                        .debounce(Durations.switchThrottlingDuration.toTimeInterval(), scheduler: MainScheduler.instance)
                        .distinctUntilChanged()
                        .asObservable()
                        .subscribe(onNext: {[weak self] enable in
                            self?.viewModel.enableUpnp(enable: enable)
                        })
                        .disposed(by: cell.disposeBag)
                    return cell
                case .turnServer:
                    let cell = self
                        .configureTurnCell(cellType: .turnServer,
                                           value: self.viewModel.turnServer.value)
                    return cell
                case .turnUsername:
                    let cell = self
                        .configureTurnCell(cellType: .turnUsername,
                                           value: self.viewModel.turnUsername.value)
                    return cell
                case .turnPassword:
                    let cell = self
                        .configureTurnCell(cellType: .turnPassword,
                                           value: self.viewModel.turnPassword.value)
                    return cell
                case .turnRealm:
                    let cell = self
                        .configureTurnCell(cellType: .turnRealm,
                                           value: self.viewModel.turnRealm.value)
                    return cell
                case .donationCampaign:
                    return self.createDonationNotificationCell()
                case .donate:
                    return self.createDonationCell()
                }
            }

        let settingsItemDataSource = RxTableViewSectionedReloadDataSource<SettingsSection>(configureCell: configureCell)
        settingsItemDataSource.titleForHeaderInSection = { dataSource, sectionIndex in
            return dataSource[sectionIndex].title
        }
        self.viewModel.settings
            .bind(to: self.settingsTable.rx.items(dataSource: settingsItemDataSource))
            .disposed(by: disposeBag)
    }

    func createDonationCell() -> UITableViewCell {
        let cell = DisposableCell()
        cell.textLabel?.text = L10n.Global.donate
        cell.textLabel?.textColor = UIColor.jamiButtonDark
        cell.textLabel?.textAlignment = .center
        cell.textLabel?.numberOfLines = 0
        cell.selectionStyle = .none
        cell.sizeToFit()
        let button = UIButton.init(frame: cell.frame)
        let size = CGSize(width: self.settingsTable.frame.width, height: button.frame.height)
        button.frame.size = size
        cell.addSubview(button)
        button.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.viewModel.donate()
            })
            .disposed(by: cell.disposeBag)
        return cell
    }

    func createDonationNotificationCell() -> DisposableCell {
        let cell = DisposableCell()
        cell.textLabel?.text = L10n.GeneralSettings.enableDonationCampaign
        let switchView = UISwitch()
        switchView.onTintColor = .jamiButtonDark
        cell.selectionStyle = .none
        cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
        cell.accessoryView = switchView
        self.viewModel.enableDonationCampaign
            .asObservable()
            .observe(on: MainScheduler.instance)
            .startWith(viewModel.enableDonationCampaign.value)
            .bind(to: switchView.rx.value)
            .disposed(by: cell.disposeBag)
        switchView.rx.value
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] (enabled) in
                self?.viewModel.togleEnableDonationCampaign(enable: enabled)
            })
            .disposed(by: cell.disposeBag)
        return cell
    }

    func configureCellWithEnableTextCopy(text: String, secondaryText: String, style: UIFont.TextStyle, accessibilityIdentifier: String) -> DisposableCell {
        let cell = DisposableCell(style: .subtitle, reuseIdentifier: self.jamiIDCell)
        cell.selectionStyle = .none
        cell.textLabel?.text = text
        cell.textLabel?.sizeToFit()
        if secondaryText.isEmpty {
            return cell
        }
        cell.detailTextLabel?.text = secondaryText
        cell.detailTextLabel?.lineBreakMode = .byCharWrapping
        cell.detailTextLabel?.numberOfLines = 0
        cell.detailTextLabel?.font = UIFont.preferredFont(forTextStyle: style)
        cell.detailTextLabel?.sizeToFit()
        cell.detailTextLabel?.textColor = UIColor.clear
        cell.sizeToFit()
        cell.layoutIfNeeded()
        let textView = CustomActionTextView()
        textView.backgroundColor = .secondarySystemGroupedBackground
        textView.text = secondaryText
        textView.accessibilityIdentifier = accessibilityIdentifier
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.textContainer.lineBreakMode = .byCharWrapping
        textView.tintColor = .clear
        textView.textColor = UIColor(red: 85, green: 85, blue: 85, alpha: 1.0)
        textView.isScrollEnabled = true
        textView.font = UIFont.preferredFont(forTextStyle: style)
        textView.sizeToFit()
        textView.actionsToRemove = [.paste, .cut, .lookUp, .delete]
        textView.inputView = UIView(frame: CGRect.zero)
        cell.contentView.addSubview(textView)
        textView.topAnchor.constraint(equalTo: cell.detailTextLabel!.topAnchor, constant: 0).isActive = true
        textView.leadingAnchor.constraint(equalTo: cell.detailTextLabel!.leadingAnchor, constant: 0).isActive = true
        textView.bottomAnchor.constraint(equalTo: cell.detailTextLabel!.bottomAnchor, constant: 0).isActive = true
        textView.trailingAnchor.constraint(equalTo: cell.detailTextLabel!.trailingAnchor, constant: 0).isActive = true
        textView.actionsToRemove = [.paste, .cut, .lookUp, .delete]
        textView.inputView = UIView(frame: CGRect.zero)
        cell.sizeToFit()
        return cell
    }

    func getSettingsFont() -> UIFont {
        return UIFont.systemFont(ofSize: 18, weight: .light)
    }

    func configureTurnCell(cellType: SettingsSection.SectionRow,
                           value: String) -> UITableViewCell {
        let textField = UITextField()
        textField.font = UIFont.preferredFont(forTextStyle: .callout)
        textField.returnKeyType = .done
        textField.text = value
        textField.sizeToFit()

        let style: UITableViewCell.CellStyle = self.settingsTable.frame.width - self.connectivityMargin - 40 < textField.frame.size.width ? .subtitle : .value1

        let cell = EditableDetailTableViewCell(style: style, reuseIdentifier: turnCell)
        cell.selectionStyle = .none
        textField.rx.controlEvent(.editingDidEndOnExit)
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in
                self?.viewModel.updateTurnSettings()
            })
            .disposed(by: cell.disposeBag)
        self.viewModel.turnEnabled
            .asObservable()
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { enabled in
                cell.contentView.layer.opacity = enabled ? 1 : 0.5
                cell.contentView.isUserInteractionEnabled = enabled
            })
            .disposed(by: cell.disposeBag)
        switch cellType {
        case .turnServer:
            textField.rx.text.orEmpty.distinctUntilChanged()
                .bind(to: self.viewModel.turnServer)
                .disposed(by: cell.disposeBag)
            cell.textLabel?.text = L10n.AccountPage.turnServer
        case .turnUsername:
            textField.rx.text.orEmpty.distinctUntilChanged()
                .bind(to: self.viewModel.turnUsername)
                .disposed(by: cell.disposeBag)
            cell.textLabel?.text = L10n.AccountPage.turnUsername
        case .turnPassword:
            textField.rx.text.orEmpty.distinctUntilChanged()
                .bind(to: self.viewModel.turnPassword)
                .disposed(by: cell.disposeBag)
            cell.textLabel?.text = L10n.AccountPage.turnPassword
        case .turnRealm:
            textField.rx.text.orEmpty.distinctUntilChanged()
                .bind(to: self.viewModel.turnRealm)
                .disposed(by: cell.disposeBag)
            cell.textLabel?.text = L10n.AccountPage.turnRealm
        default:
            break
        }
        cell.textLabel?.numberOfLines = 0
        cell.textLabel?.sizeToFit()
        cell.sizeToFit()
        cell.setEditText(withTitle: value)

        return cell
    }

    @objc func handleContentSizeCategoryDidChange(notification: Notification) {
        self.settingsTable.reloadData()
    }

    func configureSipCredentialsCell(cellType: SettingsSection.SectionRow,
                                     value: String) -> UITableViewCell {
        let cell = DisposableCell(style: .value1, reuseIdentifier: sipAccountCredentialsCell)
        cell.selectionStyle = .none
        let textField = UITextField()
        textField.tag = self.sipCredentialsTAG
        textField.font = UIFont.preferredFont(forTextStyle: .callout)
        textField.returnKeyType = .done
        textField.text = value
        textField.sizeToFit()
        textField.rx.controlEvent(.editingDidEndOnExit)
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in
                self?.viewModel.updateSipSettings()
            })
            .disposed(by: cell.disposeBag)
        switch cellType {
        case .port:
            textField.rx.text.orEmpty.distinctUntilChanged()
                .bind(to: self.viewModel.port)
                .disposed(by: cell.disposeBag)
            cell.textLabel?.text = L10n.Account.port
        case .proxyServer:
            textField.rx.text.orEmpty.distinctUntilChanged()
                .bind(to: self.viewModel.proxyServer)
                .disposed(by: cell.disposeBag)
            cell.textLabel?.text = L10n.Account.proxyServer
        case .sipServer:
            textField.rx.text.orEmpty.distinctUntilChanged()
                .bind(to: self.viewModel.sipServer)
                .disposed(by: cell.disposeBag)
            cell.textLabel?.text = L10n.Account.sipServer
        case .sipPassword:
            cell.textLabel?.text = L10n.Global.password
            // show password button
            let rightButton = UIButton(type: .custom)
            var insets = rightButton.contentEdgeInsets
            insets.right = 60
            rightButton.contentEdgeInsets = insets
            self.viewModel.secureTextEntry
                .asObservable()
                .observe(on: MainScheduler.instance)
                .subscribe(onNext: { (secure) in
                    textField.isSecureTextEntry = secure
                    if secure {
                        rightButton.setImage(UIImage(asset: Asset.icHideInput),
                                             for: .normal)
                    } else {
                        rightButton.setImage(UIImage(asset: Asset.icShowInput),
                                             for: .normal)
                    }
                })
                .disposed(by: cell.disposeBag)
            rightButton.tintColor = UIColor.darkGray
            textField.rightViewMode = .always
            textField.rightView = rightButton
            rightButton.rx.tap
                .subscribe(onNext: { [weak self] _ in
                    self?.viewModel.secureTextEntry
                        .onNext(!textField.isSecureTextEntry)
                })
                .disposed(by: cell.disposeBag)
            textField.rx.text.orEmpty.distinctUntilChanged()
                .bind { [weak self, weak rightButton] newText in
                    self?.viewModel.sipPassword.accept(newText)
                    rightButton?.isHidden = newText.isEmpty
                    rightButton?.isEnabled = !newText.isEmpty
                }
                .disposed(by: cell.disposeBag)
        case .sipUserName:
            textField.rx.text.orEmpty.distinctUntilChanged()
                .bind(to: self.viewModel.sipUsername)
                .disposed(by: cell.disposeBag)
            cell.textLabel?.text = L10n.Account.sipUsername
        default:
            break
        }
        cell.textLabel?.sizeToFit()
        cell.sizeToFit()
        cell.detailTextLabel?.font = UIFont.preferredFont(forTextStyle: .callout)
        cell.detailTextLabel?.textColor = UIColor.clear
        var frame = CGRect(x: self.sipCredentialsMargin, y: 0,
                           width: self.settingsTable.frame.width - self.sipCredentialsMargin,
                           height: cell.frame.height)
        if self.settingsTable.frame.width - self.sipCredentialsMargin < textField.frame.size.width {
            let origin = CGPoint(x: 10, y: cell.textLabel!.frame.size.height + 25)
            let size = textField.frame.size
            frame.origin = origin
            frame.size = size
            cell.detailTextLabel?.text = value
        } else {
            cell.detailTextLabel?.text = ""
        }
        cell.detailTextLabel?.sizeToFit()
        textField.frame = frame
        cell.contentView.addSubview(textField)
        cell.sizeToFit()
        return cell
    }

    func calculateSipCredentialsMargin() {
        let margin: CGFloat = 30
        var usernameLength, passwordLength,
            sipServerLength, portLength, proxyLength: CGFloat
        let username = L10n.Account.sipUsername
        let password = L10n.Global.password
        let sipServer = L10n.Account.port
        let port = L10n.Account.sipServer
        let proxy = L10n.Account.proxyServer
        let label = UITextView()
        label.font = UIFont.preferredFont(forTextStyle: .body)
        label.text = username
        label.sizeToFit()
        usernameLength = label.frame.size.width
        label.text = password
        label.sizeToFit()
        passwordLength = label.frame.size.width
        label.text = sipServer
        label.sizeToFit()
        sipServerLength = label.frame.size.width
        label.text = port
        label.sizeToFit()
        portLength = label.frame.size.width
        label.text = proxy
        label.sizeToFit()
        proxyLength = label.frame.size.width
        sipCredentialsMargin = max(max(max(max(usernameLength, passwordLength), sipServerLength), portLength), proxyLength) + margin
    }

    func calculateConnectivityMargin() {
        var serverLength, usernameLength, passwordLength, realmLength: CGFloat
        let server = L10n.AccountPage.turnServer
        let username = L10n.AccountPage.turnUsername
        let password = L10n.AccountPage.turnPassword
        let realm = L10n.AccountPage.turnRealm
        let label = UITextView()
        label.font = UIFont.preferredFont(forTextStyle: .body)
        label.text = server
        label.sizeToFit()
        serverLength = label.frame.size.width
        label.text = username
        label.sizeToFit()
        usernameLength = label.frame.size.width
        connectivityMargin = max(serverLength, usernameLength)
        label.text = password
        label.sizeToFit()
        passwordLength = label.frame.size.width
        connectivityMargin = max(connectivityMargin, passwordLength)
        label.text = realm
        label.sizeToFit()
        realmLength = label.frame.size.width
        connectivityMargin = max(connectivityMargin, realmLength)
        connectivityMargin += 30
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if self.profileName.isFirstResponder {
            resetProfileName()
            self.viewModel.updateSipSettings()
            self.profileName.resignFirstResponder()
            return
        }
        guard let activeField = self
                .findActiveTextField(in: settingsTable) else { return }
        activeField.resignFirstResponder()
        if activeField.tag != sipCredentialsTAG { return }
        self.viewModel.updateSipSettings()
    }

    let boothConfirmation = ConfirmationAlert()

    func changePassword(title: String) {
        let message = L10n.AccountPage.createPasswordExplanation
        let controller = UIAlertController(title: title,
                                           message: message,
                                           preferredStyle: .alert)
        let actionCancel = UIAlertAction(title: L10n.Global.cancel,
                                         style: .cancel)
        let actionChange = UIAlertAction(title: L10n.Actions.doneAction,
                                         style: .default) { [weak self] _ in
            guard let textFields = controller.textFields else {
                return
            }
            self?.showLoadingViewWithoutText()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if textFields.count == 2, let password = textFields[1].text {
                    _ = self?.viewModel
                        .changePassword(oldPassword: "",
                                        newPassword: password)
                    self?.stopLoadingView()
                } else if textFields.count == 4,
                          let oldPassword = textFields[0].text, !oldPassword.isEmpty,
                          let password = textFields[2].text {
                    let result = self?.viewModel.changePassword(oldPassword: oldPassword, newPassword: password)
                    if result ?? true {
                        self?.stopLoadingView()
                        return
                    }
                    self?.present(controller, animated: true, completion: nil)
                    textFields[1].text = L10n.AccountPage.changePasswordError
                    self?.stopLoadingView()
                }
            }
        }
        controller.addAction(actionCancel)
        controller.addAction(actionChange)
        if self.viewModel.hasPassword() {
            controller.addTextField {(textField) in
                textField.placeholder = L10n.AccountPage.oldPasswordPlaceholder
                textField.isSecureTextEntry = true
            }
            controller.addTextField {(textField) in
                textField.text = ""
                textField.isUserInteractionEnabled = false
                textField.textColor = UIColor.red
                textField.textAlignment = .center
                textField.borderStyle = .none
                textField.backgroundColor = UIColor.clear
                textField.font = UIFont.systemFont(ofSize: 11, weight: .thin)
            }
        }

        controller.addTextField {(textField) in
            textField.placeholder = L10n.AccountPage.newPasswordPlaceholder
            textField.isSecureTextEntry = true
        }

        controller.addTextField {(textField) in
            textField.placeholder = L10n.AccountPage.newPasswordConfirmPlaceholder
            textField.isSecureTextEntry = true
        }

        if let textFields = controller.textFields {
            if textFields.count == 4 {
                Observable
                    .combineLatest(textFields[3].rx.text,
                                   textFields[2].rx.text) {(text1, text2) -> Bool in
                        return text1 == text2
                    }
                    .bind(to: actionChange.rx.isEnabled)
                    .disposed(by: self.disposeBag)
            } else {
                Observable
                    .combineLatest(textFields[0].rx.text,
                                   textFields[1].rx.text) {(text1, text2) -> Bool in
                        return text1 == text2
                    }
                    .bind(to: actionChange.rx.isEnabled)
                    .disposed(by: self.disposeBag)
            }
        }
        self.present(controller, animated: true, completion: nil)
        if self.viewModel.hasPassword() {
            // remove border around text view
            controller.textFields?[1].superview?.backgroundColor = .clear
            controller.textFields?[1].superview?.superview?.subviews[0].removeFromSuperview()
        }
    }

    var nameRegistrationBag = DisposeBag()

    func registerUsername() {
        nameRegistrationBag = DisposeBag()
        let controller = UIAlertController(title: L10n.Global.registerAUsername,
                                           message: nil,
                                           preferredStyle: .alert)
        let actionCancel = UIAlertAction(title: L10n.Global.cancel,
                                         style: .cancel) { [weak self] _ in
            self?.nameRegistrationBag = DisposeBag()
        }
        let actionRegister = UIAlertAction(title: L10n.AccountPage.usernameRegisterAction,
                                           style: .default) { [weak self, weak controller] _ in
            self?.nameRegistrationBag = DisposeBag()
            self?.showNameRegistration()
            guard let textFields = controller?.textFields else {
                self?.stopLoadingView()
                return
            }
            if textFields.count == 2, let name = textFields[0].text,
               !name.isEmpty {
                self?.viewModel.registerUsername(username: name, password: "")
            } else if textFields.count == 3, let name = textFields[0].text,
                      !name.isEmpty, let password = textFields[2].text,
                      !password.isEmpty {
                self?.viewModel.registerUsername(username: name, password: password)
            }
        }
        controller.addAction(actionCancel)
        controller.addAction(actionRegister)
        // username textfield
        controller.addTextField {(textField) in
            textField.placeholder = L10n.AccountPage.usernamePlaceholder
        }
        // error rext field
        controller.addTextField {(textField) in
            textField.text = ""
            textField.isUserInteractionEnabled = false
            textField.textColor = UIColor.red
            textField.textAlignment = .center
            textField.borderStyle = .none
            textField.backgroundColor = UIColor.clear
            textField.font = UIFont.systemFont(ofSize: 11, weight: .thin)
        }
        // password text field
        if self.viewModel.hasPassword() {
            controller.addTextField {(textField) in
                textField.placeholder = L10n.AccountPage.passwordPlaceholder
                textField.isSecureTextEntry = true
            }
        }
        self.present(controller, animated: true, completion: nil)
        self.viewModel.subscribeForNameLokup(disposeBug: nameRegistrationBag)
        self.viewModel.usernameValidationState.asObservable()
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak controller] (state) in
                // update name lookup message
                guard let textFields = controller?.textFields,
                      textFields.count >= 2 else { return }
                textFields[1].text = state.message
                textFields[1].textColor = state.isAvailable ? UIColor.jamiSuccess : UIColor.jamiFailure
            }, onError: { (_) in
            })
            .disposed(by: nameRegistrationBag)
        guard let textFields = controller.textFields else {
            return
        }
        if textFields.count < 2 {
            return
        }
        textFields[0].rx.text.orEmpty.distinctUntilChanged().bind(to: self.viewModel.newUsername).disposed(by: nameRegistrationBag)
        let userNameEmptyObservable = textFields[0]
            .rx.text.map({text -> Bool in
                if let text = text {
                    return text.isEmpty
                }
                return true
            })
        // do not have a password could register when username not empty and valid
        if textFields.count == 2 {
            Observable
                .combineLatest(self.viewModel
                                .usernameValidationState.asObservable(),
                               userNameEmptyObservable) {(state, usernameEmpty) -> Bool in
                    if state.isAvailable && !usernameEmpty {
                        return true
                    }
                    return false
                }
                .bind(to: actionRegister.rx.isEnabled)
                .disposed(by: nameRegistrationBag)
        } else if textFields.count == 3 {
            // have a password. Could register when username not empty and valid and password not empty
            let passwordEmptyObservable = textFields[2]
                .rx.text.map({text -> Bool in
                    if let text = text {
                        return text.isEmpty
                    }
                    return true
                })
            Observable
                .combineLatest(self.viewModel
                                .usernameValidationState.asObservable(),
                               userNameEmptyObservable,
                               passwordEmptyObservable) {(state, nameEmpty, passwordEmpty) -> Bool in
                    if state.isAvailable && !nameEmpty && !passwordEmpty {
                        return true
                    }
                    return false
                }
                .bind(to: actionRegister.rx.isEnabled)
                .disposed(by: nameRegistrationBag)
        }
        // remove border around text view
        controller.textFields?[1].superview?.backgroundColor = .clear
        controller.textFields?[1].superview?.superview?.subviews[0].removeFromSuperview()
    }

    func confirmRevokeDeviceAlert(deviceID: String) {
        let alert = UIAlertController(title: L10n.AccountPage.revokeDeviceTitle,
                                      message: L10n.AccountPage.revokeDeviceMessage,
                                      preferredStyle: .alert)
        let actionCancel = UIAlertAction(title: L10n.Global.cancel,
                                         style: .cancel)
        let actionConfirm = UIAlertAction(title: L10n.AccountPage.revokeDeviceButton,
                                          style: .default) { [weak self] _ in
            self?.showLoadingView()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if let textFields = alert.textFields,
                   !textFields.isEmpty,
                   let text = textFields[0].text,
                   !text.isEmpty {
                    self?.viewModel.revokeDevice(deviceId: deviceID, accountPassword: text)
                } else {
                    self?.viewModel.revokeDevice(deviceId: deviceID, accountPassword: "")
                    self?.stopLoadingView()
                }
            }
        }
        alert.addAction(actionCancel)
        alert.addAction(actionConfirm)

        if self.viewModel.hasPassword() {
            alert.addTextField {(textField) in
                textField.placeholder = L10n.AccountPage.revokeDevicePlaceholder
                textField.isSecureTextEntry = true
            }
            if let textFields = alert.textFields {
                textFields[0].rx.text
                    .map({text in
                        if let text = text {
                            return !text.isEmpty
                        }
                        return false
                    })
                    .bind(to: actionConfirm.rx.isEnabled)
                    .disposed(by: self.disposeBag)
            }
        }
        self.present(alert, animated: true, completion: nil)
    }

    func confirmRemoveAccountAlert() {
        let alert = UIAlertController(title: L10n.Global.removeAccount,
                                      message: L10n.AccountPage.removeAccountMessage,
                                      preferredStyle: .alert)
        let actionCancel = UIAlertAction(title: L10n.Global.cancel,
                                         style: .cancel)
        let actionConfirm = UIAlertAction(title: L10n.AccountPage.removeAccountButton,
                                          style: .destructive) { [weak self] _ in
            self?.viewModel.startAccountRemoving()
        }
        alert.addAction(actionCancel)
        alert.addAction(actionConfirm)
        self.present(alert, animated: true, completion: nil)
    }
}

extension MeViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if let dataSourceProxy = tableView.dataSource as? RxTableViewDataSourceProxy,
           let actualDataSource = dataSourceProxy.forwardToDelegate() as? RxTableViewSectionedReloadDataSource<SettingsSection> {
            let headerTitle = actualDataSource[section].title
            if headerTitle == nil || headerTitle == .some("") {
                return 10
            }
        }
        return 50
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return nil
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return CGFloat.leastNonzeroMagnitude
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let navigationHeight = self.navigationController?.navigationBar.bounds.height
        var size = self.view.bounds.size
        let screenSize = UIScreen.main.bounds.size
        if let height = navigationHeight {
            // height for ihoneX
            if UIDevice.current.userInterfaceIdiom == UIUserInterfaceIdiom.phone,
               screenSize.height == 812.0 {
                size.height -= (height - 10)
            }
        }
        if scrollView.contentSize.height < size.height {
            scrollView.contentSize = size
        }

        // hide keebord if it was open when user performe scrolling
        if self.stretchyHeader.frame.height < self.stretchyHeader.maximumContentHeight * 0.5 {
            resetProfileName()
            self.profileName.resignFirstResponder()
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        self.scrollViewDidStopScrolling()
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            self.scrollViewDidStopScrolling()
        }
    }

    func shareAccountInfo() {
        guard let content = self.viewModel.accountInfoToShare else { return }

        let sourceView: UIView
        if UIDevice.current.userInterfaceIdiom == .phone {
            sourceView = self.view
        } else {
            sourceView = stretchyHeader
        }

        SharedActionsPresenter.shareAccountInfo(onViewController: self, sourceView: sourceView, content: content)
    }

    private func scrollViewDidStopScrolling() {
        var contentOffset = self.settingsTable.contentOffset
        if self.stretchyHeader.frame.height <= self.stretchyHeader.minimumContentHeight {
            return
        }
        let middle = (self.stretchyHeader.maximumContentHeight - self.stretchyHeader.minimumContentHeight) * 0.4
        if self.stretchyHeader.frame.height > middle {
            contentOffset.y = -self.stretchyHeader.maximumContentHeight
        } else {
            contentOffset.y = -self.stretchyHeader.minimumContentHeight
        }
        self.settingsTable.setContentOffset(contentOffset, animated: true)
    }

    internal func stopLoadingView() {
        loadingViewPresenter.hide(animated: false)
    }

    internal func showLoadingViewWithoutText() {
        loadingViewPresenter.presentWithMessage(message: "", presentingVC: self, animated: true)
    }
}
