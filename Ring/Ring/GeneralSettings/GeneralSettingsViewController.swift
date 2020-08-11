/*
 *  Copyright (C) 2019 Savoir-faire Linux Inc.
 *
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

import Reusable
import UIKit
import RxSwift
import RxCocoa
import RxDataSources

class GeneralSettingsViewController: UIViewController, StoryboardBased, ViewModelBased {
    var viewModel: GeneralSettingsViewModel!
    let disposeBag = DisposeBag()

    @IBOutlet weak var doneButton: UIButton!
    @IBOutlet weak var tilteLabel: UILabel!

    @IBOutlet weak var settingsTable: UITableView!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.jamiBackgroundColor
        settingsTable.backgroundColor = UIColor.jamiBackgroundColor
        self.applyL10n()
        self.setUpTable()
        doneButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.dismiss(animated: true, completion: nil)
            })
            .disposed(by: self.disposeBag)
    }

    func setUpTable() {
        self.settingsTable.estimatedRowHeight = 35
        self.settingsTable.rowHeight = UITableView.automaticDimension
        self.settingsTable.tableFooterView = UIView()
        self.setUpDataSource()
    }

    func applyL10n() {
        tilteLabel.text = L10n.GeneralSettings.title
    }

    private func setUpDataSource() {
        let configureCell: (TableViewSectionedDataSource, UITableView, IndexPath, GeneralSettingsSection.Item)
            -> UITableViewCell = {
                ( dataSource: TableViewSectionedDataSource<GeneralSettingsSection>,
                tableView: UITableView,
                indexPath: IndexPath,
                item: GeneralSettingsSection.Item) in
                switch dataSource[indexPath] {

                case .hardwareAcceleration:
                    let cell = DisposableCell()
                    cell.textLabel?.text = L10n.GeneralSettings.videoAcceleration
                    let switchView = UISwitch()
                    cell.selectionStyle = .none
                    cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                    cell.accessoryView = switchView
                    switchView.setOn(self.viewModel.hardwareAccelerationEnabled.value,
                                     animated: false)
                    self.viewModel.hardwareAccelerationEnabled
                        .asObservable()
                        .observeOn(MainScheduler.instance)
                        .bind(to: switchView.rx.value)
                        .disposed(by: cell.disposeBag)
                    switchView.rx.value
                        .observeOn(MainScheduler.instance)
                        .subscribe(onNext: { [weak self] (enable) in
                            self?.viewModel.togleHardwareAcceleration(enable: enable)
                        })
                        .disposed(by: cell.disposeBag)
                    return cell

                case .sectionHeader(let title):
                    let cell = UITableViewCell()
                    cell.textLabel?.text = title
                    cell.backgroundColor = UIColor.jamiBackgroundSecondaryColor
                    cell.selectionStyle = .none
                    cell.heightAnchor.constraint(equalToConstant: 35).isActive = true
                    return cell
                }
        }
        let settingsItemDataSource = RxTableViewSectionedReloadDataSource<GeneralSettingsSection>(configureCell: configureCell)
        self.viewModel.generalSettings
            .bind(to: settingsTable.rx.items(dataSource: settingsItemDataSource))
            .disposed(by: disposeBag)
    }
}
