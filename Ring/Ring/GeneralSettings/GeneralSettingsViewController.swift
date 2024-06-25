/*
 *  Copyright (C) 2019 Savoir-faire Linux Inc.
 *
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
 *  Author: Alireza Toghiani Khorasgani alireza.toghiani@savoirfairelinux.com *
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
import RxCocoa
import RxDataSources
import RxSwift
import UIKit

class GeneralSettingsViewController: UIViewController, StoryboardBased, ViewModelBased {
    var viewModel: GeneralSettingsViewModel!
    let disposeBag = DisposeBag()
    let defaultFont = UIFont.preferredFont(forTextStyle: .body)

    @IBOutlet var settingsTable: UITableView!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.jamiBackgroundColor
        settingsTable.backgroundColor = UIColor.jamiBackgroundColor
        applyL10n()
        setUpTable()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.layer.shadowColor = UIColor.clear.cgColor
        navigationController?.navigationBar
            .titleTextAttributes = [
                NSAttributedString.Key.font: UIFont.systemFont(ofSize: 18, weight: .medium),
                NSAttributedString.Key.foregroundColor: UIColor.jamiLabelColor
            ]
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.navigationBar.layer.shadowColor = UIColor.jamiNavigationBarShadow
            .cgColor
    }

    func setUpTable() {
        settingsTable.estimatedRowHeight = 50
        settingsTable.rowHeight = UITableView.automaticDimension
        settingsTable.tableFooterView = UIView()
        setUpDataSource()
    }

    func applyL10n() {
        navigationItem.title = L10n.Global.advancedSettings
    }

    private func setUpDataSource() {
        let configureCell: (
            TableViewSectionedDataSource,
            UITableView,
            IndexPath,
            GeneralSettingsSection.Item
        )
        -> UITableViewCell = { [weak self]
            (dataSource: TableViewSectionedDataSource<GeneralSettingsSection>,
             _: UITableView,
             indexPath: IndexPath,
             _: GeneralSettingsSection.Item) in
            guard let self = self else {
                return DisposableCell()
            }
            switch dataSource[indexPath] {
            case .hardwareAcceleration:
                let cell = DisposableCell()
                cell.textLabel?.text = L10n.GeneralSettings.videoAcceleration
                cell.textLabel?.font = self.defaultFont
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
                    .subscribe(onNext: { [weak self] enable in
                        self?.viewModel.togleHardwareAcceleration(enable: enable)
                    })
                    .disposed(by: cell.disposeBag)
                return cell
            case let .sectionHeader(title):
                let cell = UITableViewCell()
                cell.textLabel?.text = title.uppercased()
                cell.textLabel?.textColor = .secondaryLabel
                cell.backgroundColor = UIColor.jamiBackgroundSecondaryColor
                cell.selectionStyle = .none
                return cell
            case .acceptTransferLimit:
                return self.makeAcceptTransferLimitCell()
            case .automaticallyAcceptIncomingFiles:
                return self.makeAutoDownloadFilesCell()
            case .limitLocationSharingDuration:
                return self.makeLimitLocationSharingCell()
            case .locationSharingDuration:
                return self.makeLocationSharingDurationCell()
            case .donationCampaign:
                return self.makeDoantionCell()
            case .log:
                let cell = DisposableCell()
                cell.textLabel?.text = L10n.LogView.description
                cell.textLabel?.font = self.defaultFont
                cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                cell.selectionStyle = .none
                cell.sizeToFit()
                let button = UIButton(frame: cell.frame)
                cell.backgroundColor = UIColor.jamiBackgroundColor
                let size = CGSize(width: self.view.frame.width, height: button.frame.height)
                button.frame.size = size
                cell.addSubview(button)
                button.rx.tap
                    .subscribe(onNext: { [weak self] in
                        self?.viewModel.openLog()
                    })
                    .disposed(by: cell.disposeBag)
                return cell
            }
        }
        let settingsItemDataSource =
            RxTableViewSectionedReloadDataSource<GeneralSettingsSection>(
                configureCell: configureCell
            )
        viewModel.generalSettings
            .bind(to: settingsTable.rx.items(dataSource: settingsItemDataSource))
            .disposed(by: disposeBag)
    }

    func makeDoantionCell() -> DisposableCell {
        let cell = DisposableCell()
        cell.textLabel?.text = L10n.GeneralSettings.enableDonationCampaign
        cell.textLabel?.font = defaultFont
        let switchView = UISwitch()
        cell.selectionStyle = .none
        cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
        cell.accessoryView = switchView
        viewModel.enableDonationCampaign
            .asObservable()
            .observe(on: MainScheduler.instance)
            .startWith(viewModel.enableDonationCampaign.value)
            .bind(to: switchView.rx.value)
            .disposed(by: cell.disposeBag)
        switchView.rx.value
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] enabled in
                self?.viewModel.togleEnableDonationCampaign(enable: enabled)
            })
            .disposed(by: cell.disposeBag)
        return cell
    }

    func makeAutoDownloadFilesCell() -> DisposableCell {
        let cell = DisposableCell()
        cell.textLabel?.text = L10n.GeneralSettings.automaticAcceptIncomingFiles
        cell.textLabel?.font = defaultFont
        let switchView = UISwitch()
        cell.selectionStyle = .none
        cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
        cell.accessoryView = switchView
        switchView.setOn(viewModel.automaticAcceptIncomingFiles.value, animated: false)
        viewModel.automaticAcceptIncomingFiles
            .asObservable()
            .observe(on: MainScheduler.instance)
            .bind(to: switchView.rx.value)
            .disposed(by: cell.disposeBag)
        switchView.rx.value
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] enabled in
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

        let normalAttributes = [NSAttributedString.Key.font: defaultFont]
        let smallAttributes = [NSAttributedString.Key.font: titleLabel.font.withSize(10)]

        let partOne = NSMutableAttributedString(
            string: L10n.GeneralSettings.acceptTransferLimit,
            attributes: normalAttributes
        )
        let partTwo = NSMutableAttributedString(
            string: " " + L10n.GeneralSettings.acceptTransferLimitDescription,
            attributes: smallAttributes
        )

        partOne.append(partTwo)

        titleLabel.attributedText = partOne
        titleLabel.heightAnchor.constraint(equalToConstant: 45).isActive = true

        stackView.addArrangedSubview(titleLabel)

        let textField = PaddingTextField(frame: CGRect(x: 0, y: 0, width: 50, height: 40))
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.text = viewModel.acceptTransferLimit.value.description
        textField.cornerRadius = 5
        textField.borderColor = UIColor(red: 51, green: 51, blue: 51, alpha: 1)
        textField.borderWidth = 1
        textField.keyboardType = .numberPad
        textField.textAlignment = .left
        textField.setContentHuggingPriority(.fittingSizeLevel, for: .horizontal)
        textField.heightAnchor.constraint(equalToConstant: 45).isActive = true
        textField.addCloseToolbar()
        viewModel.automaticAcceptIncomingFiles
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak textField, weak titleLabel] enabled in
                textField?.isUserInteractionEnabled = enabled
                textField?.textColor = enabled ? UIColor.label : UIColor.tertiaryLabel
                titleLabel?.textColor = enabled ? UIColor.label : UIColor.tertiaryLabel
                textField?
                    .borderColor = enabled ? UIColor(red: 51, green: 51, blue: 51, alpha: 1) :
                    UIColor.tertiaryLabel
            })
            .disposed(by: cell.disposeBag)
        stackView.addArrangedSubview(textField)

        stackView.layoutSubviews()
        cell.selectionStyle = .none

        viewModel.acceptTransferLimit
            .asObservable()
            .observe(on: MainScheduler.instance)
            .map { intValue in
                String(intValue)
            }
            .bind(to: textField.rx.value)
            .disposed(by: cell.disposeBag)
        textField.rx.value
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] newValue in
                self?.viewModel.changeTransferLimit(value: newValue ?? "")
            })
            .disposed(by: cell.disposeBag)
        return cell
    }

    func makeLimitLocationSharingCell() -> DisposableCell {
        let cell = DisposableCell()
        cell.textLabel?.text = L10n.GeneralSettings.limitLocationSharingDuration
        cell.textLabel?.font = defaultFont
        let switchView = UISwitch()
        cell.selectionStyle = .none
        cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
        cell.accessoryView = switchView
        viewModel.limitLocationSharingDuration
            .asObservable()
            .observe(on: MainScheduler.instance)
            .bind(to: switchView.rx.value)
            .disposed(by: cell.disposeBag)
        switchView.rx.value
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] enabled in
                guard let self = self else { return }
                if enabled, !self.viewModel.limitLocationSharingDuration.value {
                    self.viewModel.changeLocationSharingDuration(value: 15)
                }
                self.viewModel.togleLimitLocationSharingDuration(enable: enabled)
            })
            .disposed(by: cell.disposeBag)
        switchView.setOn(viewModel.limitLocationSharingDuration.value, animated: false)
        return cell
    }

    func makeLocationSharingDurationCell() -> DisposableCell {
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
        titleLabel.font = defaultFont

        titleLabel.text = L10n.GeneralSettings.locationSharingDuration
        titleLabel.heightAnchor.constraint(equalToConstant: 45).isActive = true
        stackView.addArrangedSubview(titleLabel)

        let textField = PaddingTextField(frame: CGRect(x: 0, y: 0, width: 50, height: 40))
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.cornerRadius = 5
        textField.borderColor = UIColor(red: 51, green: 51, blue: 51, alpha: 1)
        textField.borderWidth = 1
        textField.keyboardType = .numberPad
        textField.textAlignment = .left
        textField.setContentHuggingPriority(.fittingSizeLevel, for: .horizontal)
        textField.heightAnchor.constraint(equalToConstant: 45).isActive = true
        textField.addCloseToolbar()

        let durationPicker = DurationPicker(
            maxHours: 10,
            duration: viewModel.locationSharingDuration.value
        )
        durationPicker.translatesAutoresizingMaskIntoConstraints = false
        durationPicker.viewModel = viewModel
        textField.inputView = durationPicker
        stackView.addArrangedSubview(textField)

        viewModel.locationSharingDuration
            .startWith(viewModel.locationSharingDuration.value)
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak textField, weak self] value in
                guard let self = self else { return }
                textField?.text = self.viewModel.locationSharingDurationText
                durationPicker.duration = value
            })
            .disposed(by: cell.disposeBag)

        cell.selectionStyle = .none

        viewModel.limitLocationSharingDuration
            .startWith(viewModel.limitLocationSharingDuration.value)
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak cell] enabled in
                cell?.isUserInteractionEnabled = enabled
                cell?.alpha = enabled ? 1 : 0.3
            })
            .disposed(by: cell.disposeBag)

        return cell
    }
}
