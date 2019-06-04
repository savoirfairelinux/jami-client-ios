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
        self.applyL10n()
        self.setUpTable()
        doneButton.rx.tap
            .subscribe(onNext: { [unowned self] in
                self.dismiss(animated: true, completion: nil)
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
                    //L10n.CreateProfile.title
                    //"generalSettings.title" = "General settings";
                    //"generalSettings.videoAcceleration" = "Enable video acceleration";
                    cell.textLabel?.text = L10n.GeneralSettings.videoAcceleration
                    let switchView = UISwitch()
                    cell.selectionStyle = .none
                    switchView.frame = CGRect(x: self.view.frame.size.width - 63,
                                              y: cell.frame.size.height * 0.5 - 15,
                                              width: 49, height: 30)
                    cell.contentView
                        .addSubview(switchView)
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
                        }).disposed(by: cell.disposeBag)
                    return cell

                case .sectionHeader(let title):
                    let cell = UITableViewCell()
                    cell.textLabel?.text = title
                    cell.backgroundColor = UIColor.jamiNavigationBar
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
