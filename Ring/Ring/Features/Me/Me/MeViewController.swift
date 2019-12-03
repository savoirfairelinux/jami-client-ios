/*
 *  Copyright (C) 2017-2019 Savoir-faire Linux Inc.
 *
 *  Author: Edric Ladent-Milaret <edric.ladent-milaret@savoirfairelinux.com>
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
 *  Author: Quentin Muret <quentin.muret@savoirfairelinux.com>
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
import PKHUD

// swiftlint:disable type_body_length
// swiftlint:disable file_length
class MeViewController: EditProfileViewController, StoryboardBased, ViewModelBased {
    // MARK: - outlets
    @IBOutlet private weak var settingsTable: SettingsTableView!

    // MARK: - members
    var viewModel: MeViewModel!
    fileprivate let disposeBag = DisposeBag()
    private var stretchyHeader: AccountHeader!

    var sipCredentialsMargin: CGFloat = 0
    let sipCredentialsTAG: Int = 100

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .default
    }

    // MARK: - functions
    override func viewDidLoad() {
        self.addHeaderView()
        super.viewDidLoad()
        self.applyL10n()
        self.configureBindings()
        self.configureRingNavigationBar()
        self.calculateSipCredentialsMargin()
        self.adaptTableToKeyboardState(for: self.settingsTable, with: self.disposeBag,
                                       topOffset: self.stretchyHeader.minimumContentHeight)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(preferredContentSizeChanged(_:)),
                                               name: UIContentSizeCategory.didChangeNotification,
                                               object: nil)
    }

    @objc private func preferredContentSizeChanged(_ notification: NSNotification) {
        self.calculateSipCredentialsMargin()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.navigationBar
            .titleTextAttributes = [NSAttributedString.Key.font: UIFont(name: "HelveticaNeue-Light", size: 25)!,
                                    NSAttributedString.Key.foregroundColor: UIColor.jamiMain]
    }

    func applyL10n() {
        self.navigationItem.title = L10n.Global.meTabBarTitle
        self.profileName.placeholder = L10n.AccountPage.namePlaceholder
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
        self.stretchyHeader = headerView
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
        let infoButton = UIButton(type: .infoLight)
        let imageQrCode = UIImage(asset: Asset.qrCode) as UIImage?
        let qrCodeButton   = UIButton(type: UIButton.ButtonType.custom) as UIButton
        qrCodeButton.setImage(imageQrCode, for: .normal)
        self.viewModel.isAccountSip
            .asObservable()
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak qrCodeButton](isSip) in
                qrCodeButton?.isHidden = isSip
                qrCodeButton?.isEnabled = !isSip
            }).disposed(by: self.disposeBag)
        let infoItem = UIBarButtonItem(customView: infoButton)
        let qrCodeButtonItem = UIBarButtonItem(customView: qrCodeButton)
        infoButton.rx.tap.throttle(0.5, scheduler: MainScheduler.instance)
            .subscribe(onNext: { [unowned self] in
                self.infoItemTapped()
            })
            .disposed(by: self.disposeBag)
        qrCodeButton.rx.tap.throttle(0.5, scheduler: MainScheduler.instance)
            .subscribe(onNext: { [unowned self] in
                self.qrCodeItemTapped()
            })
            .disposed(by: self.disposeBag)
        self.viewModel.showActionState.asObservable()
            .observeOn(MainScheduler.instance)
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
                case .deviceRevokationError(let deviceId, let errorMessage):
                    self?.showDeviceRevocationError(deviceId: deviceId, errorMessage: errorMessage)
                }
            }).disposed(by: self.disposeBag)
        self.navigationItem.rightBarButtonItem = infoItem
        self.navigationItem.leftBarButtonItem = qrCodeButtonItem

        //setup Table
        self.settingsTable.estimatedRowHeight = 35
        self.settingsTable.rowHeight = UITableView.automaticDimension
        self.settingsTable.tableFooterView = UIView()

        //Register cell
        self.setUpDataSource()
        self.settingsTable.register(cellType: DeviceCell.self)
        self.settingsTable.register(cellType: BlockContactsCell.self)

        self.settingsTable.rx.itemSelected
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] indexPath in
                if (self?.settingsTable.cellForRow(at: indexPath) as? BlockContactsCell) != nil {
                    self?.openBlockedList()
                    self?.settingsTable.deselectRow(at: indexPath, animated: true)
                }
            }).disposed(by: self.disposeBag)
    }

    private func openBlockedList() {
        self.viewModel.showBlockedContacts()
    }

    private func stopLoadingView() {
        HUD.hide(animated: false)
    }

    private func showLoadingView() {
        HUD.show(.labeledProgress(title: L10n.AccountPage.deviceRevocationProgress, subtitle: nil))
    }

    private func showDeviceRevocationError(deviceId: String, errorMessage: String) {
        HUD.hide(animated: true) { _ in
            let alert = UIAlertController(title: errorMessage,
                                          message: nil,
                                          preferredStyle: .alert)
            let actionCancel = UIAlertAction(title: L10n.Actions.cancelAction,
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
        HUD.hide(animated: true) { _ in
            let alert = UIAlertController(title: L10n.AccountPage.deviceRevocationSuccess,
                                          message: nil,
                                          preferredStyle: .alert)
            let actionOk = UIAlertAction(title: L10n.Global.ok,
                                         style: .default)
            alert.addAction(actionOk)
            self.present(alert, animated: true, completion: nil)
        }
    }

    private func infoItemTapped() {
        var compileDate: String {
            let dateDefault = "20180131"
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "YYYYMMdd"
            let bundleName = Bundle.main.infoDictionary!["CFBundleName"] as? String ?? "Info.plist"
            if let infoPath = Bundle.main.path(forResource: bundleName, ofType: nil),
                let infoAttr = try? FileManager.default.attributesOfItem(atPath: infoPath),
                let infoDate = infoAttr[FileAttributeKey.creationDate] as? Date {
                return dateFormatter.string(from: infoDate)
            }
            return dateDefault
        }
        let versionName = L10n.Global.versionName
        let alert = UIAlertController(title: "\nJami\nbuild: \(compileDate)\n\(versionName)", message: "", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L10n.Global.ok, style: .default, handler: nil))
        let image = UIImageView(image: UIImage(asset: Asset.jamiIcon))
        alert.view.addSubview(image)
        image.translatesAutoresizingMaskIntoConstraints = false
        alert.view.addConstraint(NSLayoutConstraint(item: image, attribute: .centerX, relatedBy: .equal, toItem: alert.view, attribute: .centerX, multiplier: 1, constant: 0))
        alert.view.addConstraint(NSLayoutConstraint(item: image, attribute: .centerY, relatedBy: .equal, toItem: alert.view, attribute: .top, multiplier: 1, constant: 0.0))
        alert.view.addConstraint(NSLayoutConstraint(item: image, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: 64.0))
        alert.view.addConstraint(NSLayoutConstraint(item: image, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: 64.0))
        self.present(alert, animated: true, completion: nil)
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

    @objc func alertControllerBackgroundTapped() {
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
    private func setUpDataSource() {

        let configureCell: (TableViewSectionedDataSource, UITableView, IndexPath, SettingsSection.Item)
            -> UITableViewCell = {
                ( dataSource: TableViewSectionedDataSource<SettingsSection>,
                tableView: UITableView,
                indexPath: IndexPath,
                item: SettingsSection.Item) in
                switch dataSource[indexPath] {

                case .device(let device):
                    let cell = tableView.dequeueReusableCell(for: indexPath, cellType: DeviceCell.self)

                    cell.deviceIdLabel.text = device.deviceId
                    if let deviceName = device.deviceName {
                        cell.deviceNameLabel.text = deviceName
                    }
                    cell.selectionStyle = .none
                    cell.removeDevice.isHidden = device.isCurrent
                    cell.removeDevice.rx.tap.subscribe(onNext: { [weak self, device] in
                        self?.confirmRevokeDeviceAlert(deviceID: device.deviceId)
                    }).disposed(by: cell.disposeBag)
                    cell.sizeToFit()
                    return cell

                case .linkNew:
                    let cell = DisposableCell()
                    cell.textLabel?.text = L10n.AccountPage.linkDeviceTitle
                    cell.textLabel?.textColor = UIColor.jamiMain
                    cell.textLabel?.textAlignment = .center
                    cell.selectionStyle = .none
                    cell.sizeToFit()
                    let button = UIButton.init(frame: cell.frame)
                    let size = CGSize(width: self.view.frame.width, height: button.frame.height)
                    button.frame.size = size
                    cell.addSubview(button)
                    button.rx.tap.subscribe(onNext: { [weak self] in
                        self?.viewModel.linkDevice()
                    }).disposed(by: cell.disposeBag)
                    return cell

                case .blockedList:
                    let cell = tableView.dequeueReusableCell(for: indexPath,
                    cellType: BlockContactsCell.self)
                    cell.label.text = L10n.AccountPage.blockedContacts
                    cell.label.font = UIFont.preferredFont(forTextStyle: .body)
                    return cell

                case .sectionHeader(let title):
                    let cell = UITableViewCell()
                    cell.textLabel?.text = title
                    cell.backgroundColor = UIColor.jamiNavigationBar
                    cell.selectionStyle = .none
                    return cell

                case .removeAccount:
                    let cell = DisposableCell()
                    cell.textLabel?.text = L10n.AccountPage.removeAccountTitle
                    cell.textLabel?.textColor = UIColor.jamiMain
                    cell.textLabel?.textAlignment = .center
                    cell.selectionStyle = .none
                    cell.sizeToFit()
                    let button = UIButton.init(frame: cell.frame)
                    let size = CGSize(width: self.view.frame.width, height: button.frame.height)
                    button.frame.size = size
                    cell.addSubview(button)
                    button.rx.tap.subscribe(onNext: { [weak self] in
                        self?.confirmRemoveAccountAlert()
                    }).disposed(by: cell.disposeBag)
                    return cell

                case .ordinary(let label):
                    let cell = UITableViewCell()
                    cell.textLabel?.text = label
                    cell.selectionStyle = .none
                    return cell
                case .shareAccountDetails:
                    let cell = DisposableCell()
                    cell.textLabel?.text = L10n.AccountPage.shareAccountDetails
                    cell.textLabel?.textColor = UIColor.jamiMain
                    cell.textLabel?.textAlignment = .center
                    cell.sizeToFit()
                    cell.selectionStyle = .none
                    let button = UIButton.init(frame: cell.frame)
                    let size = CGSize(width: self.view.frame.width, height: button.frame.height)
                    button.frame.size = size
                    cell.addSubview(button)
                    button.rx.tap.subscribe(onNext: { [weak self] in
                        self?.shareAccountInfo()
                    }).disposed(by: cell.disposeBag)
                    return cell

                case .notifications:
                    let cell = DisposableCell()
                    cell.textLabel?.text = L10n.AccountPage.enableNotifications
                    let switchView = UISwitch()
                    cell.selectionStyle = .none
                    cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                    cell.accessoryView = switchView
                    switchView.setOn(self.viewModel.notificationsEnabled.value,
                                     animated: false)
                    self.viewModel.notificationsEnabled
                        .asObservable()
                        .observeOn(MainScheduler.instance)
                        .bind(to: switchView.rx.value)
                        .disposed(by: cell.disposeBag)
                    switchView.rx.value
                    //.skip(1)
                        .observeOn(MainScheduler.instance)
                        .subscribe(onNext: { [weak self] (enable) in
                            self?.viewModel.enableNotifications(enable: enable)
                        }).disposed(by: cell.disposeBag)
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
                    let cell = DisposableCell(style: .value1, reuseIdentifier: "AccountStateCell")

                    cell.textLabel?.text = L10n.Account.accountStatus
                    cell.selectionStyle = .none
                    cell.textLabel?.sizeToFit()
                    cell.detailTextLabel?.font = UIFont.preferredFont(forTextStyle: .callout)
                    cell.detailTextLabel?.text = state.value
                    state.asObservable()
                        .observeOn(MainScheduler.instance)
                        .subscribe(onNext: { (status) in
                                                   cell.detailTextLabel?.text = status
                                               }).disposed(by: cell.disposeBag)
                    cell.layoutIfNeeded()
                    return cell
                case .enableAccount:
                    let cell = DisposableCell()
                    cell.textLabel?.text = L10n.Account.enableAccount
                    let switchView = UISwitch()
                    cell.selectionStyle = .none
                    cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                    cell.accessoryView = switchView
                    switchView.setOn(self.viewModel.accountEnabled.value,
                                     animated: false)
                    self.viewModel.accountEnabled
                        .asObservable()
                        .observeOn(MainScheduler.instance)
                        .bind(to: switchView.rx.value)
                        .disposed(by: cell.disposeBag)
                    switchView.rx.value
                        .observeOn(MainScheduler.instance)
                        .subscribe(onNext: { [weak self] (enable) in
                            self?.viewModel.enableAccount(enable: enable)
                        }).disposed(by: cell.disposeBag)
                    return cell
                }
        }

        let settingsItemDataSource = RxTableViewSectionedReloadDataSource<SettingsSection>(configureCell: configureCell)
        self.viewModel.settings
            .bind(to: self.settingsTable.rx.items(dataSource: settingsItemDataSource))
            .disposed(by: disposeBag)
    }

    func getSettingsFont() -> UIFont {
        return UIFont.systemFont(ofSize: 18, weight: .light)
    }

    func configureSipCredentialsCell(cellType: SettingsSection.SectionRow,
                                     value: String) -> UITableViewCell {
        let cell = DisposableCell(style: .value1, reuseIdentifier: "AccountSIPCredentialsCell")
        cell.selectionStyle = .none
        let text = UITextField()
        text.tag = self.sipCredentialsTAG
        text.font = UIFont.preferredFont(forTextStyle: .caption2)
        text.returnKeyType = .done
        text.text = value
        text.sizeToFit()
        text.rx.controlEvent(.editingDidEndOnExit)
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in
                self?.viewModel.updateSipSettings()
            }).disposed(by: cell.disposeBag)
        switch cellType {
        case .port:
            text.rx.text.orEmpty.distinctUntilChanged()
                .bind(to: self.viewModel.port)
                .disposed(by: cell.disposeBag)
            cell.textLabel?.text = L10n.Account.port
        case .proxyServer:
            text.rx.text.orEmpty.distinctUntilChanged()
                .bind(to: self.viewModel.proxyServer)
                .disposed(by: cell.disposeBag)
            cell.textLabel?.text = L10n.Account.proxyServer
        case .sipServer:
            text.rx.text.orEmpty.distinctUntilChanged()
                .bind(to: self.viewModel.sipServer)
                .disposed(by: cell.disposeBag)
            cell.textLabel?.text = L10n.Account.sipServer
        case .sipPassword:
            cell.textLabel?.text = L10n.Account.sipPassword
            //show password button
            let rightButton  = UIButton(type: .custom)
            rightButton.frame = CGRect(x: 0, y: 0, width: 55, height: 30)
            self.viewModel.secureTextEntry
                .asObservable()
                .observeOn(MainScheduler.instance)
                .subscribe(onNext: { (secure) in
                    text.isSecureTextEntry = secure
                    if secure {
                        rightButton.setImage(UIImage(asset: Asset.icHideInput),
                                             for: .normal)
                    } else {
                        rightButton.setImage(UIImage(asset: Asset.icShowInput),
                                             for: .normal)
                    }
                }).disposed(by: cell.disposeBag)
            rightButton.tintColor = UIColor.darkGray
            text.rightViewMode = .always
            text.rightView = rightButton
            rightButton.rx.tap
                .subscribe(onNext: { [unowned self] _ in
                    self.viewModel.secureTextEntry
                        .onNext(!text.isSecureTextEntry)
                }).disposed(by: cell.disposeBag)
            text.rx.text.orEmpty.distinctUntilChanged()
                .bind { [weak self, weak rightButton] newText in
                    self?.viewModel.sipPassword.value = newText
                    rightButton?.isHidden = newText.isEmpty
                    rightButton?.isEnabled = !newText.isEmpty
                }.disposed(by: cell.disposeBag)
        case .sipUserName:
            text.rx.text.orEmpty.distinctUntilChanged()
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
                                  width: self.view.frame.width - self.sipCredentialsMargin,
                                  height: cell.frame.height)
        if self.view.frame.width - self.sipCredentialsMargin < text.frame.size.width {
            let origin = CGPoint(x: 10, y: cell.textLabel!.frame.size.height + 25)
            let size = text.frame.size
            frame.origin = origin
            frame.size = size
            cell.detailTextLabel?.text = value
        } else {
            cell.detailTextLabel?.text = ""
        }
        cell.detailTextLabel?.sizeToFit()
        text.frame = frame
        cell.contentView.addSubview(text)
        cell.sizeToFit()
        cell.setNeedsLayout()
        cell.setNeedsDisplay()
        return cell
    }

    func calculateSipCredentialsMargin() {
        let margin: CGFloat = 30
        var usernameLength, passwordLength,
        sipServerLength, portLength, proxyLength: CGFloat
        let username = L10n.Account.sipUsername
        let password = L10n.Account.sipPassword
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

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if self.profileName.isFirstResponder {
            resetProfileName()
            self.viewModel.updateSipSettings()
            self.profileName.resignFirstResponder()
            return
        }
        guard let activeField = self
            .findActiveTextField(in: settingsTable) else {return}
        activeField.resignFirstResponder()
        if activeField.tag != sipCredentialsTAG {return}
        self.viewModel.updateSipSettings()
    }

    func confirmRevokeDeviceAlert(deviceID: String) {
        let alert = UIAlertController(title: L10n.AccountPage.revokeDeviceTitle,
                                      message: L10n.AccountPage.revokeDeviceMessage,
                                      preferredStyle: .alert)
        let actionCancel = UIAlertAction(title: L10n.Actions.cancelAction,
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

        if self.viewModel.havePassord {
            alert.addTextField {(textField) in
                textField.placeholder = L10n.AccountPage.revokeDevicePlaceholder
                textField.isSecureTextEntry = true
            }
            if let textFields = alert.textFields {
                textFields[0].rx.text.map({text in
                    if let text = text {
                        return !text.isEmpty
                    }
                    return false
                }).bind(to: actionConfirm.rx.isEnabled).disposed(by: self.disposeBag)
            }
        }
        self.present(alert, animated: true, completion: nil)
    }

    func confirmRemoveAccountAlert() {
        let alert = UIAlertController(title: L10n.AccountPage.removeAccountTitle,
                                      message: L10n.AccountPage.removeAccountMessage,
                                      preferredStyle: .alert)
        let actionCancel = UIAlertAction(title: L10n.Actions.cancelAction,
                                         style: .cancel)
        let actionConfirm = UIAlertAction(title: L10n.AccountPage.removeAccountButton,
                                          style: .destructive) { [weak self] _ in
                                            UIView.animate(withDuration: 0.1, animations: {
                                                self?.view.alpha = 0
                                            }, completion: { _ in
                                                self?.viewModel.startAccountRemoving()
                                                self?.view.alpha = 1
                                            })
        }
        alert.addAction(actionCancel)
        alert.addAction(actionConfirm)
        self.present(alert, animated: true, completion: nil)
    }
}

extension MeViewController: UITableViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let navigationHeight = self.navigationController?.navigationBar.bounds.height
        var size = self.view.bounds.size
        let screenSize = UIScreen.main.bounds.size
        if let height = navigationHeight {
            //height for ihoneX
            if UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiom.phone,
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
        guard let content = self.viewModel.accountInfoToShare else {return}
        let title = L10n.AccountPage.contactMeOnJamiTitle
        let activityViewController = UIActivityViewController(activityItems: content,
                                                              applicationActivities: nil)
        activityViewController.setValue(title, forKey: "Subject")
        activityViewController.popoverPresentationController?.sourceView = self.view
        self.present(activityViewController, animated: true, completion: nil)
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
}
