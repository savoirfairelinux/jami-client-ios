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

    @IBOutlet weak var settingsTable: UITableView!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.jamiBackgroundColor
        settingsTable.backgroundColor = UIColor.jamiBackgroundColor
        self.applyL10n()
        self.setUpTable()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.navigationBar.layer.shadowColor = UIColor.jamiNavigationBarShadow.cgColor
        self.navigationController?.navigationBar
            .titleTextAttributes = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 18, weight: .medium),
                                    NSAttributedString.Key.foregroundColor: UIColor.jamiLabelColor]
    }

    func setUpTable() {
        self.settingsTable.estimatedRowHeight = 50
        self.settingsTable.rowHeight = UITableView.automaticDimension
        self.settingsTable.tableFooterView = UIView()
        self.setUpDataSource()
    }

    func applyL10n() {
        self.navigationItem.title = L10n.GeneralSettings.title
    }

    private func setUpDataSource() {
        let configureCell: (TableViewSectionedDataSource, UITableView, IndexPath, GeneralSettingsSection.Item)
            -> UITableViewCell = {
                ( dataSource: TableViewSectionedDataSource<GeneralSettingsSection>,
                  _: UITableView,
                  indexPath: IndexPath,
                  _: GeneralSettingsSection.Item) in
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
                        .observe(on: MainScheduler.instance)
                        .bind(to: switchView.rx.value)
                        .disposed(by: cell.disposeBag)
                    switchView.rx.value
                        .observe(on: MainScheduler.instance)
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
                case .acceptTransferLimit:
                    return self.makeAcceptTransferLimitCell()
                case .automaticallyAcceptIncomingFiles:
                    return self.makeAutoDownloadFilesCell()
                }
            }
        let settingsItemDataSource = RxTableViewSectionedReloadDataSource<GeneralSettingsSection>(configureCell: configureCell)
        self.viewModel.generalSettings
            .bind(to: settingsTable.rx.items(dataSource: settingsItemDataSource))
            .disposed(by: disposeBag)
    }

    func makeAutoDownloadFilesCell() -> DisposableCell {
        let cell = DisposableCell()
        cell.textLabel?.text = L10n.GeneralSettings.FileTransfer.automaticAcceptIncomingFiles
        let switchView = UISwitch()
        cell.selectionStyle = .none
        cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
        cell.accessoryView = switchView
        switchView.setOn(self.viewModel.automaticAcceptIncomingFiles.value, animated: false)
        self.viewModel.automaticAcceptIncomingFiles
            .asObservable()
            .observe(on: MainScheduler.instance)
            .bind(to: switchView.rx.value)
            .disposed(by: cell.disposeBag)
        switchView.rx.value
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] (enabled) in
                self?.viewModel.togleAcceptingUnkownIncomingFiles(enable: enabled)
            })
            .disposed(by: cell.disposeBag)
        return cell
    }

    func makeAcceptTransferLimitCell() -> DisposableCell {
        let cell = DisposableCell()
        let stackView = UIStackView()
        stackView.alignment = .fill
        stackView.distribution = .fill
        stackView.alignment = .leading
        stackView.spacing = 8
        cell.contentView.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.topAnchor.constraint(equalTo: cell.topAnchor, constant: 6).isActive = true
        stackView.bottomAnchor.constraint(equalTo: cell.bottomAnchor, constant: -6).isActive = true
        stackView.leftAnchor.constraint(equalTo: cell.leftAnchor, constant: 16).isActive = true
        stackView.rightAnchor.constraint(equalTo: cell.rightAnchor, constant: -16).isActive = true
        stackView.layoutSubviews()

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let normalAttributes = [NSAttributedString.Key.foregroundColor: UIColor.black, NSAttributedString.Key.font: titleLabel.font.withSize(17)]
        let smallAttributes = [NSAttributedString.Key.foregroundColor: UIColor.darkGray, NSAttributedString.Key.font: titleLabel.font.withSize(13)]

        let partOne = NSMutableAttributedString(string: L10n.GeneralSettings.FileTransfer.acceptTransferLimit, attributes: normalAttributes)
        let partTwo = NSMutableAttributedString(string: " " + L10n.GeneralSettings.FileTransfer.acceptTransferLimitDescription, attributes: smallAttributes)

        partOne.append(partTwo)

        titleLabel.attributedText = partOne
        titleLabel.heightAnchor.constraint(equalToConstant: 45).isActive = true

        stackView.addArrangedSubview(titleLabel)

        let textField = PaddingTextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.text = viewModel.acceptTransferLimit.value.description
        textField.backgroundColor = UIColor(red: 242, green: 242, blue: 242, alpha: 1)
        textField.cornerRadius = 5
        textField.borderColor = UIColor(red: 51, green: 51, blue: 51, alpha: 1)
        textField.borderWidth = 1
        textField.keyboardType = .numberPad
        textField.textAlignment = .left
        textField.setContentHuggingPriority(.fittingSizeLevel, for: .horizontal)
        textField.heightAnchor.constraint(equalToConstant: 45).isActive = true
        textField.addCloseToolbar()

        stackView.addArrangedSubview(textField)

        stackView.layoutSubviews()
        cell.selectionStyle = .none

        self.viewModel.acceptTransferLimit
            .asObservable()
            .observe(on: MainScheduler.instance)
            .map({ intValue in
                String(intValue)
            })
            .bind(to: textField.rx.value)
            .disposed(by: cell.disposeBag)
        textField.rx.value
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] (newValue) in
                self?.viewModel.changeTransferLimit(value: newValue ?? "")
            })
            .disposed(by: cell.disposeBag)
        return cell
    }

    @objc func closeButtonDidTap() {
        self.resignFirstResponder()
    }
}
