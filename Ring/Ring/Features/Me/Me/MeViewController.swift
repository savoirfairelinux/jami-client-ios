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
        self.setupUI()
    }

    override func setupUI() {
        self.viewModel.userName
            .bind(to: self.nameLabel.rx.text)
            .disposed(by: disposeBag)

        self.viewModel.ringId.asObservable()
            .bind(to: self.ringIdLabel.rx.text)
            .disposed(by: disposeBag)

        super.setupUI()

        //setup Table
        self.settingsTable.estimatedRowHeight = 50
        self.settingsTable.rowHeight = UITableViewAutomaticDimension
        self.settingsTable.separatorStyle = .none

        //Register cell
        self.setUpDataSource()
        self.settingsTable.register(cellType: DeviceCell.self)
        self.settingsTable.register(cellType: LinkNewDeviceCell.self)
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
