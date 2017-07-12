/*
 *  Copyright (C) 2016 Savoir-faire Linux Inc.
 *
 *  Author: Romain Bertozzi <romain.bertozzi@savoirfairelinux.com>
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
import RxCocoa
import RxSwift
import PKHUD
import SwiftyBeaver

fileprivate enum CreateRingAccountCellType {
    case registerPublicUsername
    case usernameField
    case passwordNotice
    case newPasswordField
    case repeatPasswordField
}

class CreateRingAccountViewController: UITableViewController {

    /**
     logguer
     */
    private let log = SwiftyBeaver.self

    var accountViewModel = CreateRingAccountViewModel(withAccountService: AppDelegate.accountService,
                                                       nameService: AppDelegate.nameService)

    @IBOutlet weak var createAccountButton: DesignableButton!
    @IBOutlet weak var createAccountTitleLabel: UILabel!

    var disposeBag = DisposeBag()

    override func viewDidLoad() {
        super.viewDidLoad()

        self.registerCells()

        self.bindViews()

        self.setupUI()
    }

    func registerCells() {
        self.tableView.register(cellType: SwitchCell.self)
        self.tableView.register(cellType: TextFieldCell.self)
        self.tableView.register(cellType: TextCell.self)
    }

    /**
     Bind all the necessary of this View to its ViewModel.
     That allows to build the binding part of the MVVM pattern.
     */
    fileprivate func bindViews() {

        //Add Account button action
        self.createAccountButton
            .rx
            .tap
            .takeUntil(self.rx.deallocated)
            .subscribe(onNext: {
                self.accountViewModel.createAccount()
            })
            .disposed(by: self.disposeBag)

        //Add Account Registration state
        self.accountViewModel.accountCreationState.observeOn(MainScheduler.instance).subscribe(
            onNext: { [unowned self] state in
                switch state {
                case .started:
                    self.setCreateAccountAsLoading()
                case .success:
                    self.setCreateAccountAsIdle()
                    self.showDeviceAddedAlert()
                    let storyboard = UIStoryboard(name: "Main", bundle: nil)
                    let vc = storyboard.instantiateViewController(withIdentifier: "MainStoryboard") as UIViewController
                    self.dismiss(animated: true, completion: nil)
                    self.present(vc, animated: true, completion: nil)
                default:
                    return
                }
            },
            onError: { [unowned self] error in
                if let error = error as? AccountCreationError {
                    self.showErrorAlert(error)
                }
                self.setCreateAccountAsIdle()
        }).disposed(by: disposeBag)

        //Show or hide user name field
        self.accountViewModel.registerUsername.asObservable()
            .subscribe(onNext: { [weak self] showUsernameField in
                self?.toggleRegisterSwitch(showUsernameField)
            }).disposed(by: disposeBag)

        //Enables create account button
        self.accountViewModel.canCreateAccount
            .bind(to: self.createAccountButton.rx.isEnabled)
            .disposed(by: disposeBag)
    }

    /**
     Customize the views
     */

    fileprivate func setupUI() {
        self.tableView.estimatedRowHeight = 44.0
        self.tableView.rowHeight = UITableViewAutomaticDimension
        self.createAccountTitleLabel.text = L10n.Createaccount.createAccountFormTitle.smartString
    }

    fileprivate func setCreateAccountAsLoading() {
        log.debug("Creating account...")
        self.createAccountButton.setTitle(L10n.Createaccount.loading.smartString, for: .normal)
        self.createAccountButton.isUserInteractionEnabled = false
        HUD.show(.labeledProgress(title: L10n.Createaccount.waitCreateAccountTitle.smartString, subtitle: nil))
    }

    fileprivate func setCreateAccountAsIdle() {
        self.createAccountButton.setTitle(L10n.Welcome.createAccount.smartString, for: .normal)
        self.createAccountButton.isUserInteractionEnabled = true
        HUD.hide()
    }

    fileprivate func showDeviceAddedAlert() {
        HUD.flash(.labeledSuccess(title: L10n.Alerts.accountAddedTitle.smartString, subtitle: nil), delay: Durations.alertFlashDuration.value)
    }

    fileprivate func showErrorAlert(_ error: AccountCreationError) {
        let alert = UIAlertController.init(title: error.title,
                                           message: error.message,
                                           preferredStyle: .alert)
        alert.addAction(UIAlertAction.init(title: L10n.Global.ok.smartString, style: .default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }

    /**
     Show or hide the username field cell in function of the switch state
     */

    func toggleRegisterSwitch(_ show: Bool) {

        let usernameFieldCellIndex = 1

        if show && !cells.contains(.usernameField) {
            self.cells.insert(.usernameField, at: usernameFieldCellIndex)
            self.tableView.insertRows(at: [IndexPath(row: usernameFieldCellIndex, section: 0)],
                                      with: .automatic)
        } else if !show && cells.contains(.usernameField) {
            self.cells.remove(at: usernameFieldCellIndex)
            self.tableView.deleteRows(at: [IndexPath(row: usernameFieldCellIndex, section: 0)],
                                      with: .automatic)
        }

    }

    // MARK: TableView datasource
    fileprivate var cells: [CreateRingAccountCellType] = [.registerPublicUsername,
                                                           .passwordNotice,
                                                           .newPasswordField,
                                                           .repeatPasswordField]

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return cells.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let currentCellType = cells[indexPath.row]

        if currentCellType == .registerPublicUsername {
            let cell = tableView.dequeueReusableCell(for: indexPath, cellType: SwitchCell.self)

            cell.titleLabel.text = L10n.Createaccount.registerPublicUsername.smartString
            cell.titleLabel.textColor = .white
            cell.registerSwitch.rx.value.bind(to: self.accountViewModel.registerUsername).disposed(by: disposeBag)
            return cell
        } else if currentCellType == .usernameField {
            let cell = tableView.dequeueReusableCell(for: indexPath, cellType: TextFieldCell.self)

            cell.textField.isSecureTextEntry = false
            cell.textField.placeholder = L10n.Createaccount.enterNewUsernamePlaceholder.smartString

            //Binds the username field value to the ViewModel
            cell.textField.rx.text.orEmpty
                .throttle(Durations.textFieldThrottlingDuration.value, scheduler: MainScheduler.instance)
                .distinctUntilChanged()
                .bind(to: self.accountViewModel.username)
                .disposed(by: disposeBag)

            //Switch to new password cell when return button is touched
            cell.textField.rx.controlEvent(.editingDidEndOnExit).subscribe(onNext: {
                self.switchToCell(withType: .newPasswordField)
            }).disposed(by: disposeBag)

            self.accountViewModel.usernameValidationMessage.bind(to: cell.errorMessageLabel.rx.text).disposed(by: disposeBag)
            return cell
        } else if currentCellType == .passwordNotice {
            let cell = tableView.dequeueReusableCell(for: indexPath, cellType: TextCell.self)
            cell.label.text = L10n.Createaccount.chooseStrongPassword.smartString
            return cell
        } else if currentCellType == .newPasswordField {
            let cell = tableView.dequeueReusableCell(for: indexPath, cellType: TextFieldCell.self)

            cell.textField.isSecureTextEntry = true
            cell.textField.placeholder = L10n.Createaccount.newPasswordPlaceholder.smartString
            cell.errorMessageLabel.text = L10n.Createaccount.passwordCharactersNumberError.smartString

            //Binds the password field value to the ViewModel
            cell.textField.rx.text.orEmpty.bind(to: self.accountViewModel.password).disposed(by: disposeBag)

            //Binds the observer to show the error label if the field is not empty
            self.accountViewModel.hidePasswordError.bind(to: cell.errorMessageLabel.rx.isHidden).disposed(by: disposeBag)

            //Switch to the repeat pasword cell when return button is touched
            cell.textField.rx.controlEvent(.editingDidEndOnExit)
                .subscribe(onNext: {
                    self.switchToCell(withType: .repeatPasswordField)
                }).disposed(by: disposeBag)

            return cell
        } else {
            let cell = tableView.dequeueReusableCell(for: indexPath, cellType: TextFieldCell.self)

            cell.textField.isSecureTextEntry = true
            cell.textField.placeholder = L10n.Createaccount.repeatPasswordPlaceholder.smartString
            cell.errorMessageLabel.text = L10n.Createaccount.passwordNotMatchingError.smartString

            //Binds the repeat password field value to the ViewModel
            cell.textField.rx.text.orEmpty.bind(to: self.accountViewModel.repeatPassword).disposed(by: disposeBag)

            //Binds the observer to the text field 'hidden' property
            self.accountViewModel.hideRepeatPasswordError.bind(to: cell.errorMessageLabel.rx.isHidden).disposed(by: disposeBag)

            return cell

        }
    }

    fileprivate func switchToCell(withType cellType: CreateRingAccountCellType) {
        if let cellIndex = self.cells.index(of: cellType) {
            if let cell = tableView.cellForRow(at: IndexPath(row: cellIndex, section: 0))
                as? TextFieldCell {
                cell.textField.becomeFirstResponder()
            }
            self.tableView.scrollToRow(at: IndexPath(row: cellIndex, section: 0),
                                       at: .bottom, animated: false)
        }
    }
}
