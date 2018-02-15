/*
 *  Copyright (C) 2017 Savoir-faire Linux Inc.
 *
 *  Author: Edric Ladent-Milaret <edric.ladent-milaret@savoirfairelinux.com>
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
import Reusable
import RxSwift
import RxCocoa
import RxDataSources

class MeViewController: EditProfileViewController, StoryboardBased, ViewModelBased {

    // MARK: - outlets
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var ringIdLabel: UILabel!
    @IBOutlet weak var settingsTable: UITableView!

    // MARK: - members
    var viewModel: MeViewModel!
    fileprivate let disposeBag = DisposeBag()

    // MARK: - functions
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.title = L10n.Global.meTabBarTitle
        self.configureBindings()
    }

    func configureBindings() {
        self.viewModel.userName
            .bind(to: self.nameLabel.rx.text)
            .disposed(by: disposeBag)

        self.viewModel.ringId.asObservable()
            .bind(to: self.ringIdLabel.rx.text)
            .disposed(by: disposeBag)

        let infoButton = UIButton(type: .infoLight)
        let infoItem = UIBarButtonItem(customView: infoButton)
        infoButton.rx.tap.throttle(0.5, scheduler: MainScheduler.instance)
            .subscribe(onNext: { [unowned self] in
                self.infoItemTapped()
            })
            .disposed(by: self.disposeBag)

        self.navigationItem.rightBarButtonItem = infoItem

        //setup Table
        self.settingsTable.estimatedRowHeight = 50
        self.settingsTable.rowHeight = UITableViewAutomaticDimension
        self.settingsTable.separatorStyle = .none

        //Register cell
        self.setUpDataSource()
        self.settingsTable.register(cellType: DeviceCell.self)
        self.settingsTable.register(cellType: LinkNewDeviceCell.self)
        self.settingsTable.register(cellType: ProxyCell.self)
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

    func openBlockedList() {
        self.viewModel.showBlockedContacts()
    }

    func infoItemTapped() {
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
        let alert = UIAlertController(title: "\nRing\nbuild: \(compileDate)\n\"In varietate concordia\"", message: "", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L10n.Global.ok, style: .default, handler: nil))
        let image = UIImageView(image: UIImage(asset: Asset.ringIcon))
        alert.view.addSubview(image)
        image.translatesAutoresizingMaskIntoConstraints = false
        alert.view.addConstraint(NSLayoutConstraint(item: image, attribute: .centerX, relatedBy: .equal, toItem: alert.view, attribute: .centerX, multiplier: 1, constant: 0))
        alert.view.addConstraint(NSLayoutConstraint(item: image, attribute: .centerY, relatedBy: .equal, toItem: alert.view, attribute: .top, multiplier: 1, constant: 0.0))
        alert.view.addConstraint(NSLayoutConstraint(item: image, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: 64.0))
        alert.view.addConstraint(NSLayoutConstraint(item: image, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: 64.0))
        self.present(alert, animated: true, completion: nil)
    }

    func setUpDataSource() {

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
                    return cell

                case .linkNew:
                    let cell = tableView.dequeueReusableCell(for: indexPath, cellType: LinkNewDeviceCell.self)

                    cell.addDeviceButton.rx.tap.subscribe(onNext: { [unowned self] in
                        self.viewModel.linkDevice()
                    }).disposed(by: cell.disposeBag)
                    cell.addDeviceTitle.rx.tap.subscribe(onNext: { [unowned self] in
                        self.viewModel.linkDevice()
                    }).disposed(by: cell.disposeBag)
                    cell.selectionStyle = .none
                    return cell

                case .proxy:
                    let cell = tableView.dequeueReusableCell(for: indexPath,
                                                             cellType: ProxyCell.self)
                    cell.enableProxyLabel.text = L10n.Accountpage.enableProxy
                    cell.switchProxy.isOn = self.viewModel.proxyInitialState
                    self.viewModel.proxyEnabled?
                        .observeOn(MainScheduler.instance)
                        .bind(to: cell.switchProxy.rx.isOn)
                        .disposed(by: cell.disposeBag)
                    cell.switchProxy.rx.isOn
                        .observeOn(MainScheduler.instance)
                        .subscribe(onNext: { [unowned self] (enable) in
                            self.viewModel.enableProxy(enable: enable)
                        }).disposed(by: cell.disposeBag)
                    cell.selectionStyle = .none
                    return cell

                case .blockedList:
                    let cell = tableView.dequeueReusableCell(for: indexPath,
                    cellType: BlockContactsCell.self)
                    cell.label.text = L10n.Accountpage.blockedContacts
                    return cell
                }
        }

        let settingsItemDataSource = RxTableViewSectionedReloadDataSource<SettingsSection>(configureCell: configureCell)
        self.viewModel.settings
            .bind(to: self.settingsTable.rx.items(dataSource: settingsItemDataSource))
            .disposed(by: disposeBag)

        //Set header titles
        settingsItemDataSource.titleForHeaderInSection = { dataSource, index in
            return dataSource.sectionModels[index].header
        }
    }
}
