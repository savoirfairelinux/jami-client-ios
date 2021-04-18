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
    private let disposeBag = DisposeBag()
    private var stretchyHeader: AccountHeader!

    var sipCredentialsMargin: CGFloat = 0
    let sipCredentialsTAG: Int = 100

    private let sipAccountCredentialsCell = "sipAccountCredentialsCell"
    private let jamiIDCell = "jamiIDCell"
    private let jamiUserNameCell = "jamiUserNameCell"
    private let accountStateCell = "accountStateCell"

    // MARK: - functions
    override func viewDidLoad() {
        self.view.backgroundColor = UIColor.jamiBackgroundColor
        self.settingsTable.backgroundColor = UIColor.jamiBackgroundColor
        self.addHeaderView()
        super.viewDidLoad()
        self.applyL10n()
        self.configureBindings()
        self.configureRingNavigationBar()
        self.calculateSipCredentialsMargin()
        self.adaptTableToKeyboardState(for: self.settingsTable,
                                       with: self.disposeBag,
                                       topOffset: self.stretchyHeader.minimumContentHeight)
        NotificationCenter
            .default
            .addObserver(self,
                         selector: #selector(preferredContentSizeChanged(_:)),
                         name: UIContentSizeCategory.didChangeNotification,
                         object: nil)
    }

    @objc
    private func preferredContentSizeChanged(_ notification: NSNotification) {
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
        headerView.backgroundColor = UIColor.jamiBackgroundColor
        self.stretchyHeader = headerView
        let point = CGPoint(x: 0, y: 100)
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
        let infoButton = UIButton(type: .infoLight)
        let imageQrCode = UIImage(asset: Asset.qrCode) as UIImage?
        let qrCodeButton = UIButton(type: UIButton.ButtonType.custom) as UIButton
        qrCodeButton.setImage(imageQrCode, for: .normal)
        self.viewModel.isAccountSip
            .asObservable()
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak qrCodeButton](isSip) in
                qrCodeButton?.isHidden = isSip
                qrCodeButton?.isEnabled = !isSip
            })
            .disposed(by: self.disposeBag)
        let infoItem = UIBarButtonItem(customView: infoButton)
        let qrCodeButtonItem = UIBarButtonItem(customView: qrCodeButton)
        infoButton.rx.tap.throttle(Durations.halfSecond.toTimeInterval(), scheduler: MainScheduler.instance)
            .subscribe(onNext: { [weak self] in
                self?.infoItemTapped()
            })
            .disposed(by: self.disposeBag)
        qrCodeButton.rx.tap.throttle(Durations.halfSecond.toTimeInterval(), scheduler: MainScheduler.instance)
            .subscribe(onNext: { [weak self] in
                self?.qrCodeItemTapped()
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
                case .usernameRegistered:
                    self?.stopLoadingView()
                case .usernameRegistrationFailed(let errorMessage):
                    self?.showNameRegisterationFailed(error: errorMessage)
                }
            })
            .disposed(by: self.disposeBag)
        self.navigationItem.rightBarButtonItem = infoItem
        self.navigationItem.leftBarButtonItem = qrCodeButtonItem

        //setup Table
        self.settingsTable.estimatedRowHeight = 35
        self.settingsTable.rowHeight = UITableView.automaticDimension
        self.settingsTable.tableFooterView = UIView()

        //Register cell
        self.setUpDataSource()
        self.settingsTable.register(cellType: DeviceCell.self)
    }

    private func openBlockedList() {
        self.viewModel.showBlockedContacts()
    }

    private func showLoadingView() {
        HUD.show(.labeledProgress(title: L10n.AccountPage.deviceRevocationProgress, subtitle: nil))
    }

    private func showNameRegistration() {
        HUD.show(.labeledProgress(title: L10n.AccountPage.usernameRegistering, subtitle: nil))
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

    private func showNameRegisterationFailed(error: String) {
        HUD.hide(animated: true) { _ in
            let alert = UIAlertController(title: error,
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
            let dateDefault = ""
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

        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""

        let versionName = L10n.Global.versionName
        let alert = UIAlertController(title: "\nJami\nversion: \(appVersion)(\(compileDate))\n\(versionName)", message: "", preferredStyle: .alert)
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
                    cell.backgroundColor = UIColor.jamiBackgroundColor
                    cell.textLabel?.text = L10n.AccountPage.autoRegistration
                    let switchView = UISwitch()
                    cell.selectionStyle = .none
                    cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                    cell.accessoryView = switchView
                    self.viewModel.keepAliveEnabled
                        .asObservable()
                        .startWith(self.viewModel.keepAliveEnabled.value)
                        .observeOn(MainScheduler.instance)
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
                    cell.backgroundColor = UIColor.jamiBackgroundColor
                    cell.deviceIdLabel.text = device.deviceId
                    cell.deviceIdLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
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
                    cell.backgroundColor = UIColor.jamiBackgroundColor
                    cell.textLabel?.text = L10n.AccountPage.linkDeviceTitle
                    cell.textLabel?.textColor = UIColor.jamiMain
                    cell.textLabel?.textAlignment = .center
                    cell.selectionStyle = .none
                    cell.sizeToFit()
                    let button = UIButton.init(frame: cell.frame)
                    let size = CGSize(width: self.view.frame.width, height: button.frame.height)
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
                    cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                    cell.selectionStyle = .none
                    cell.sizeToFit()
                    let button = UIButton.init(frame: cell.frame)
                    cell.backgroundColor = UIColor.jamiBackgroundColor
                    let size = CGSize(width: self.view.frame.width, height: button.frame.height)
                    button.frame.size = size
                    cell.addSubview(button)
                    button.rx.tap
                        .subscribe(onNext: { [weak self] in
                            self?.openBlockedList()
                        })
                        .disposed(by: cell.disposeBag)
                    return cell

                case .sectionHeader(let title):
                    let cell = UITableViewCell()
                    cell.textLabel?.text = title
                    cell.backgroundColor = UIColor.jamiBackgroundSecondaryColor
                    cell.selectionStyle = .none
                    return cell

                case .removeAccount:
                    let cell = DisposableCell()
                    cell.backgroundColor = UIColor.jamiBackgroundColor
                    cell.textLabel?.text = L10n.AccountPage.removeAccountTitle
                    cell.textLabel?.textColor = UIColor.jamiMain
                    cell.textLabel?.textAlignment = .center
                    cell.selectionStyle = .none
                    cell.sizeToFit()
                    let button = UIButton.init(frame: cell.frame)
                    let size = CGSize(width: self.view.frame.width, height: button.frame.height)
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
                        return self.configureCellWithEnableTextCopy(text: L10n.AccountPage.username,
                                                                    secondaryText: label,
                                                                    style: .callout)
                    }
                    let cell = DisposableCell()
                    cell.textLabel?.text = L10n.AccountPage.registerNameTitle
                    cell.textLabel?.textColor = UIColor.jamiMain
                    cell.textLabel?.textAlignment = .center
                    cell.sizeToFit()
                    cell.selectionStyle = .none
                    let button = UIButton.init(frame: cell.frame)
                    let size = CGSize(width: self.view.frame.width, height: button.frame.height)
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
                                                                style: .footnote)
                case .ordinary(let label):
                    let cell = UITableViewCell()
                    cell.backgroundColor = UIColor.jamiBackgroundColor
                    cell.textLabel?.text = label
                    cell.selectionStyle = .none
                    return cell
                case .shareAccountDetails:
                    let cell = DisposableCell()
                    cell.backgroundColor = UIColor.jamiBackgroundColor
                    cell.textLabel?.text = L10n.AccountPage.shareAccountDetails
                    cell.textLabel?.textColor = UIColor.jamiMain
                    cell.textLabel?.textAlignment = .center
                    cell.sizeToFit()
                    cell.selectionStyle = .none
                    let button = UIButton.init(frame: cell.frame)
                    let size = CGSize(width: self.view.frame.width, height: button.frame.height)
                    button.frame.size = size
                    cell.addSubview(button)
                    button.rx.tap
                        .subscribe(onNext: { [weak self] in
                            self?.shareAccountInfo()
                        })
                        .disposed(by: cell.disposeBag)
                    return cell
                case .changePassword:
                    let cell = DisposableCell()
                    cell.backgroundColor = UIColor.jamiBackgroundColor
                    let title = self.viewModel.hasPassword() ?
                        L10n.AccountPage.changePassword : L10n.AccountPage.createPassword
                    cell.textLabel?.text = title
                    cell.textLabel?.textColor = UIColor.jamiMain
                    cell.textLabel?.textAlignment = .center
                    cell.sizeToFit()
                    cell.selectionStyle = .none
                    let button = UIButton.init(frame: cell.frame)
                    let size = CGSize(width: self.view.frame.width, height: button.frame.height)
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
                    cell.backgroundColor = UIColor.jamiBackgroundColor
                    cell.textLabel?.text = L10n.AccountPage.enableNotifications
                    let switchView = UISwitch()
                    cell.selectionStyle = .none
                    cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                    cell.accessoryView = switchView
                    self.viewModel.notificationsEnabledObservable
                        .observeOn(MainScheduler.instance)
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
                    cell.backgroundColor = UIColor.jamiBackgroundColor
                    cell.textLabel?.text = L10n.AccountPage.peerDiscovery
                    let switchView = UISwitch()
                    cell.selectionStyle = .none
                    cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                    cell.accessoryView = switchView
                    self.viewModel.peerDiscoveryEnabled
                        .asObservable()
                        .startWith(self.viewModel.peerDiscoveryEnabled.value)
                        .observeOn(MainScheduler.instance)
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
                    cell.backgroundColor = UIColor.jamiBackgroundColor

                    cell.textLabel?.text = L10n.Account.accountStatus
                    cell.selectionStyle = .none
                    cell.textLabel?.sizeToFit()
                    cell.detailTextLabel?.font = UIFont.preferredFont(forTextStyle: .callout)
                    cell.detailTextLabel?.text = state.value
                    state.asObservable()
                        .observeOn(MainScheduler.instance)
                        .subscribe(onNext: { (status) in
                            cell.detailTextLabel?.text = status
                        })
                        .disposed(by: cell.disposeBag)
                    return cell
                case .boothMode:
                    let cell = DisposableCell(style: .subtitle, reuseIdentifier: self.jamiIDCell)
                    cell.backgroundColor = UIColor.jamiBackgroundColor
                    cell.textLabel?.text = L10n.AccountPage.enableBoothMode
                    cell.textLabel?.sizeToFit()
                    let switchView = UISwitch()
                    cell.selectionStyle = .none
                    cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                    cell.accessoryView = switchView
                    cell.detailTextLabel?.text = self.viewModel.hasPassword() ?
                        L10n.AccountPage.boothModeExplanation : L10n.AccountPage.noBoothMode
                    cell.detailTextLabel?.lineBreakMode = .byWordWrapping
                    cell.detailTextLabel?.numberOfLines = 0
                    cell.detailTextLabel?.font = UIFont.preferredFont(forTextStyle: .footnote)
                    cell.sizeToFit()
                    cell.layoutIfNeeded()
                    self.viewModel.switchBoothModeState
                        .observeOn(MainScheduler.instance)
                        .bind(to: switchView.rx.value)
                        .disposed(by: self.disposeBag)
                    switchView.rx
                        .isOn.changed
                        .subscribe(onNext: {[weak self] enable in
                            if !enable {
                                return
                            }
                            self?.viewModel.switchBoothModeState.onNext(enable)
                            self?.confirmBoothModeAlert()
                        })
                        .disposed(by: self.disposeBag)
                    cell.isUserInteractionEnabled = self.viewModel.hasPassword()
                    cell.textLabel?.isEnabled = self.viewModel.hasPassword()
                    cell.detailTextLabel?.isEnabled = self.viewModel.hasPassword()
                    switchView.isEnabled = self.viewModel.hasPassword()
                    return cell
                case .enableAccount:
                    let cell = DisposableCell()
                    cell.backgroundColor = UIColor.jamiBackgroundColor
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
                }
        }

        let settingsItemDataSource = RxTableViewSectionedReloadDataSource<SettingsSection>(configureCell: configureCell)
        self.viewModel.settings
            .bind(to: self.settingsTable.rx.items(dataSource: settingsItemDataSource))
            .disposed(by: disposeBag)
    }

    func configureCellWithEnableTextCopy(text: String, secondaryText: String, style: UIFont.TextStyle) -> DisposableCell {
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
        textView.text = secondaryText
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

    func  configureSipCredentialsCell(cellType: SettingsSection.SectionRow,
                                      value: String) -> UITableViewCell {
        let cell = DisposableCell(style: .value1, reuseIdentifier: sipAccountCredentialsCell)
        cell.backgroundColor = UIColor.jamiBackgroundColor
        cell.selectionStyle = .none
        let text = UITextField()
        text.tag = self.sipCredentialsTAG
        text.font = UIFont.preferredFont(forTextStyle: .callout)
        text.returnKeyType = .done
        text.text = value
        text.sizeToFit()
        text.rx.controlEvent(.editingDidEndOnExit)
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in
                self?.viewModel.updateSipSettings()
            })
            .disposed(by: cell.disposeBag)
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
            let rightButton = UIButton(type: .custom)
            var insets = rightButton.contentEdgeInsets
            insets.right = 20.0
            rightButton.contentEdgeInsets = insets
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
                })
                .disposed(by: cell.disposeBag)
            rightButton.tintColor = UIColor.darkGray
            text.rightViewMode = .always
            text.rightView = rightButton
            rightButton.rx.tap
                .subscribe(onNext: { [weak self] _ in
                    self?.viewModel.secureTextEntry
                        .onNext(!text.isSecureTextEntry)
                })
                .disposed(by: cell.disposeBag)
            text.rx.text.orEmpty.distinctUntilChanged()
                .bind { [weak self, weak rightButton] newText in
                    self?.viewModel.sipPassword.accept(newText)
                    rightButton?.isHidden = newText.isEmpty
                    rightButton?.isEnabled = !newText.isEmpty
                }
                .disposed(by: cell.disposeBag)
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
            .findActiveTextField(in: settingsTable) else { return }
        activeField.resignFirstResponder()
        if activeField.tag != sipCredentialsTAG { return }
        self.viewModel.updateSipSettings()
    }

    let boothConfirmation = ConfirmationAlert()

    func confirmBoothModeAlert() {
        boothConfirmation.configure(title: L10n.AccountPage.enableBoothMode,
                                    msg: L10n.AccountPage.boothModeAlertMessage,
                                    enable: true, presenter: self,
                                    disposeBag: self.disposeBag)
    }

    func changePassword(title: String) {
        let controller = UIAlertController(title: title,
                                           message: nil,
                                           preferredStyle: .alert)
        let actionCancel = UIAlertAction(title: L10n.Actions.cancelAction,
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
            //remove border around text view
            controller.textFields?[1].superview?.backgroundColor = .clear
            controller.textFields?[1].superview?.superview?.subviews[0].removeFromSuperview()
        }
    }

    var nameRegistrationBag = DisposeBag()

    func registerUsername() {
        nameRegistrationBag = DisposeBag()
        let controller = UIAlertController(title: L10n.AccountPage.registerNameTitle,
                                           message: nil,
                                           preferredStyle: .alert)
        let actionCancel = UIAlertAction(title: L10n.Actions.cancelAction,
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
        //username textfield
        controller.addTextField {(textField) in
            textField.placeholder = L10n.AccountPage.usernamePlaceholder
        }
        //error rext field
        controller.addTextField {(textField) in
            textField.text = ""
            textField.isUserInteractionEnabled = false
            textField.textColor = UIColor.red
            textField.textAlignment = .center
            textField.borderStyle = .none
            textField.backgroundColor = UIColor.clear
            textField.font = UIFont.systemFont(ofSize: 11, weight: .thin)
        }
        //password text field
        if self.viewModel.hasPassword() {
            controller.addTextField {(textField) in
                textField.placeholder = L10n.AccountPage.passwordPlaceholder
                textField.isSecureTextEntry = true
            }
        }
        self.present(controller, animated: true, completion: nil)
        self.viewModel.subscribeForNameLokup(disposeBug: nameRegistrationBag)
        self.viewModel.usernameValidationState.asObservable()
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak controller] (state) in
                //update name lookup message
                guard let textFields = controller?.textFields,
                    textFields.count >= 2 else { return }
                if state.isAvailable {
                    textFields[1].text = ""
                } else {
                    textFields[1].text = state.message
                }
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
        //remove border around text view
        controller.textFields?[1].superview?.backgroundColor = .clear
        controller.textFields?[1].superview?.superview?.subviews[0].removeFromSuperview()
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
        guard let content = self.viewModel.accountInfoToShare else { return }
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

extension MeViewController: BoothModeConfirmationPresenter {
    func enableBoothMode(enable: Bool, password: String) -> Bool {
          return self.viewModel.enableBoothMode(enable: enable, password: password)
      }

      func switchBoothModeState(state: Bool) {
          self.viewModel.switchBoothModeState.onNext(state)
      }

      internal func stopLoadingView() {
          HUD.hide(animated: false)
      }

      internal func showLoadingViewWithoutText() {
          HUD.show(.labeledProgress(title: "", subtitle: nil))
      }
}
