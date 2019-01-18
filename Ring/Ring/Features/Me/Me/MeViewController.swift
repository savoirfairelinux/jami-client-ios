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

class MeViewController: EditProfileViewController, StoryboardBased, ViewModelBased {

    // MARK: - outlets
    @IBOutlet private weak var settingsTable: SettingsTableView!

    // MARK: - members
    var viewModel: MeViewModel!
    fileprivate let disposeBag = DisposeBag()
    private var stretchyHeader: AccountHeader!

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .default
    }

    // MARK: - functions
    override func viewDidLoad() {
        super.viewDidLoad()
        self.addHeaderView()

        self.navigationItem.title = L10n.Global.meTabBarTitle
        self.configureBindings()
        self.configureRingNavigationBar()
        self.adaptTableToKeyboardState(for: self.settingsTable, with: self.disposeBag, topOffset: self.stretchyHeader.minimumContentHeight)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.navigationBar
            .titleTextAttributes = [NSAttributedStringKey.font: UIFont(name: "HelveticaNeue-Light", size: 25)!,
                                    NSAttributedStringKey.foregroundColor: UIColor.jamiMain]
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
        let qrCodeButton   = UIButton(type: UIButtonType.custom) as UIButton
        qrCodeButton.setImage(imageQrCode, for: .normal)
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
        self.settingsTable.estimatedRowHeight = 50
        self.settingsTable.rowHeight = UITableViewAutomaticDimension
        self.settingsTable.tableFooterView = UIView()

        //Register cell
        self.setUpDataSource()
        self.settingsTable.register(cellType: DeviceCell.self)
        self.settingsTable.register(cellType: LinkNewDeviceCell.self)
        self.settingsTable.register(cellType: ProxyCell.self)
        self.settingsTable.register(cellType: BlockContactsCell.self)
        self.settingsTable.register(cellType: NotificationCell.self)

        self.settingsTable.rx.itemSelected
            //.throttle(RxTimeInterval(2), scheduler: MainScheduler.instance)
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
        let alert = UIAlertController(title: "\nJami\nbuild: \(compileDate)\n\"Live Free or Die\"", message: "", preferredStyle: .alert)
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
                    return cell

                case .linkNew:
                    let cell = tableView.dequeueReusableCell(for: indexPath, cellType: LinkNewDeviceCell.self)

                    cell.addDeviceButton.rx.tap.subscribe(onNext: { [weak self] in
                        self?.viewModel.linkDevice()
                    }).disposed(by: cell.disposeBag)
                    cell.addDeviceTitle.rx.tap.subscribe(onNext: { [weak self] in
                        self?.viewModel.linkDevice()
                    }).disposed(by: cell.disposeBag)
                    cell.selectionStyle = .none
                    return cell

                case .proxy:
                    let cell = tableView.dequeueReusableCell(for: indexPath,
                                                             cellType: ProxyCell.self)
                    cell.proxyAddrsss.placeholder = L10n.AccountPage.proxyPaceholder
                    cell.enableProxyLabel.text = L10n.AccountPage.enableProxy
                    cell.proxyAddrsss.enablesReturnKeyAutomatically = true
                    self.viewModel.proxyEnabled.asDriver()
                        .drive(cell.switchProxy.rx.isOn)
                        .disposed(by: cell.disposeBag)
                    cell.switchProxy.rx.value.skip(1)
                        .observeOn(MainScheduler.instance)
                        .subscribe(onNext: { [weak self] (enable) in
                            if enable {
                                self?.askProxyAddressAlert()
                                return
                            }
                            self?.viewModel.changeProxyAvailability(enable: enable, proxyAddress: "")
                        }).disposed(by: cell.disposeBag)
                    cell.selectionStyle = .none
                    cell.proxyAddrsss.rx.controlEvent(.editingDidEndOnExit)
                        .observeOn(MainScheduler.instance)
                        .subscribe(onNext: { [weak self] _ in
                        if let text = cell.proxyAddrsss.text, !text.isEmpty {
                            self?.viewModel.changeProxyAddress(address: text)
                        } else {
                            cell.proxyAddrsss.text = self?.viewModel.proxyAddress.value
                        }
                    }).disposed(by: cell.disposeBag)
                    self.viewModel.proxyDisplaybele.asDriver(onErrorJustReturn: "")
                        .drive(cell.proxyAddrsss.rx.text)
                        .disposed(by: cell.disposeBag)
                    self.viewModel.proxyEnabled.asDriver()
                        .drive(cell.proxyAddrsss.rx.isEnabled)
                        .disposed(by: cell.disposeBag)
                    return cell

                case .blockedList:
                    let cell = tableView.dequeueReusableCell(for: indexPath,
                    cellType: BlockContactsCell.self)
                    cell.label.text = L10n.AccountPage.blockedContacts
                    return cell

                case .sectionHeader(let title):
                    let cell = UITableViewCell()
                    cell.textLabel?.text = title
                    cell.backgroundColor = UIColor.jamiNavigationBar.darken(byPercentage: 0.02)
                    cell.selectionStyle = .none
                    return cell

                case .ordinary(let label):
                    let cell = UITableViewCell()
                    cell.textLabel?.text = label
                    cell.selectionStyle = .none
                    return cell
                case .notifications:
                    let cell = tableView.dequeueReusableCell(for: indexPath,
                                                             cellType: NotificationCell.self)
                    cell.selectionStyle = .none
                    cell.enableNotificationsLabel.text = L10n.AccountPage.enableNotifications
                    self.viewModel.notificationsEnabled.asDriver()
                        .drive(cell.enableNotificationsSwitch.rx.value)
                        .disposed(by: cell.disposeBag)
                    cell.enableNotificationsSwitch.rx.value.skip(1)
                        .observeOn(MainScheduler.instance)
                        .subscribe(onNext: { [weak self] (enable) in
                            guard let proxyEnabled = self?.viewModel.proxyEnabled.value else {return}
                            if enable && !proxyEnabled {
                                self?.proxyDisabledAlert()
                                return
                            }
                            self?.viewModel.enablePushNotifications(enable: enable)
                        }).disposed(by: cell.disposeBag)
                    return cell
                }
        }

        let settingsItemDataSource = RxTableViewSectionedReloadDataSource<SettingsSection>(configureCell: configureCell)
        self.viewModel.settings
            .bind(to: self.settingsTable.rx.items(dataSource: settingsItemDataSource))
            .disposed(by: disposeBag)
    }

    func proxyDisabledAlert() {
        let alert = UIAlertController(title: L10n.AccountPage.proxyDisabledAlertTitle,
                                      message: L10n.AccountPage.proxyDisabledAlertBody,
                                      preferredStyle: .alert)
        let actionCancel = UIAlertAction(title: L10n.Global.ok, style: .cancel) { [weak self]_ in
            self?.viewModel.notificationsEnabled.value = false
            self?.dismiss(animated: true, completion: nil)
        }
        alert.addAction(actionCancel)
        self.present(alert, animated: true, completion: nil)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        resetProfileName()
        self.profileName.resignFirstResponder()
        if let activeField = self.findActiveTextField(in: settingsTable) {
            activeField.resignFirstResponder()
            // now the only possible active text field is proxy address, ensure it is not empty
            if let text = activeField.text, text.isEmpty {
                self.viewModel.proxyAddress.value =  self.viewModel.proxyAddress.value
            }
        }
    }

    func askProxyAddressAlert() {
        let alert = UIAlertController(title: L10n.AccountPage.proxyAddressAlert,
                                      message: nil,
                                      preferredStyle: .alert)
        let actionCancel = UIAlertAction(title: L10n.Actions.cancelAction,
                                         style: .cancel) { [weak self] _ in
            self?.viewModel.proxyEnabled.value = false
            alert.dismiss(animated: true, completion: nil)
        }
        let actionConfirm = UIAlertAction(title: L10n.AccountPage.saveProxyAddress,
                                          style: .default) { [weak self] _ in
            if let textFields = alert.textFields, let text = textFields[0].text, !text.isEmpty {
                self?.viewModel.changeProxyAvailability(enable: true, proxyAddress: text)
            }
            alert.dismiss(animated: false, completion: nil)
        }
        alert.addAction(actionCancel)
        alert.addAction(actionConfirm)

        alert.addTextField { [weak self] (textField) in
            textField.placeholder = L10n.AccountPage.proxyPaceholder
            textField.text = self?.viewModel.proxyAddress.value
        }

        if let textFields = alert.textFields {
            textFields[0].rx.text.map({text in
                if let text = text {
                    return !text.isEmpty
                }
                return false
            }).bind(to: actionConfirm.rx.isEnabled).disposed(by: self.disposeBag)
        }
        self.present(alert, animated: true, completion: nil)
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
