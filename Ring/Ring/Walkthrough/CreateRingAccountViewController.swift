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

fileprivate enum CreateRingAccountCellType {
    case registerPublicUsername
    case usernameField
    case passwordNotice
    case newPasswordField
    case repeatPasswordField
}

class CreateRingAccountViewController: UITableViewController {

    var mAccountViewModel = CreateRingAccountViewModel()

    @IBOutlet weak var mCreateAccountButton: RoundedButton!
    @IBOutlet weak var mCreateAccountTitleLabel: UILabel!

    /**
     Cell identifiers
     */

    let switchCellId = "SwitchCellId"
    let textFieldCellId = "TextFieldCellId"
    let tableViewCellId = "TableViewCellId"

    var disposeBag = DisposeBag()

    let walkthroughTableName = "Walkthrough"

    override func viewDidLoad() {
        super.viewDidLoad()

        self.bindViews()

        self.setupUI()
    }

    /**
     Bind all the necessary of this View to its ViewModel.
     That allows to build the binding part of the MVVM pattern.
     */
    fileprivate func bindViews() {
        //~ Create the stream. Won't start until an observer subscribes to it.
        let createAccountObservable:Observable<Void> = self.mCreateAccountButton
            .rx
            .tap
            .takeUntil(self.rx.deallocated)

        mAccountViewModel.configureAddAccountObservers(
            observable: createAccountObservable,
            onStartCallback: { [weak self] in
                self?.setCreateAccountAsLoading()
            },
            onSuccessCallback: { [weak self] in
                print("Account created.")
                self?.setCreateAccountAsIdle()
            },
            onErrorCallback:  { [weak self] (error) in
                print("Error creating account...")
                if error != nil {
                    print(error!)
                }
                self?.setCreateAccountAsIdle()
        })

        _ = self.mAccountViewModel.showUsernameField.asObservable()
            .subscribe(onNext: { [weak self] showUsernameField in
                self?.toggleRegisterSwitch(showUsernameField)
        }).addDisposableTo(disposeBag)
    }

    /**
     Customize the views
     */

    fileprivate func setupUI() {
        self.tableView.estimatedRowHeight = 44.0
        self.tableView.rowHeight = UITableViewAutomaticDimension

        self.mCreateAccountTitleLabel.text = NSLocalizedString("CreateAccountFormTitle",
                                                              tableName: walkthroughTableName,
                                                              comment: "")
    }

    fileprivate func setCreateAccountAsLoading() {
        print("Creating account...")
        self.mCreateAccountButton.setTitle("Loading...", for: .normal)
        self.mCreateAccountButton.isUserInteractionEnabled = false
    }

    fileprivate func setCreateAccountAsIdle() {
        self.mCreateAccountButton.setTitle("Create a Ring account", for: .normal)
        self.mCreateAccountButton.isUserInteractionEnabled = true
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

    //MARK: TableView datasource
    fileprivate var cells :[CreateRingAccountCellType] = [.registerPublicUsername,
                                                          .passwordNotice,
                                                          .newPasswordField,
                                                          .repeatPasswordField]

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView,
                            numberOfRowsInSection section: Int) -> Int {
        return cells.count
    }

    override func tableView(_ tableView: UITableView,
                            cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let currentCellType = cells[indexPath.row]

        if currentCellType == .registerPublicUsername {
            let cell = tableView.dequeueReusableCell(withIdentifier: switchCellId,
                                                     for: indexPath) as! SwitchCell
            cell.titleLabel.text = NSLocalizedString("RegisterPublicUsername",
                                                     tableName: walkthroughTableName,
                                                     comment: "")
            cell.titleLabel.textColor = .white

            _ = cell.registerSwitch.rx.isOn.bindTo(self.mAccountViewModel.showUsernameField)
                .addDisposableTo(disposeBag)
            return cell
        } else if currentCellType == .usernameField {
            let cell = tableView.dequeueReusableCell(withIdentifier: textFieldCellId,
                                                     for: indexPath) as! TextFieldCell
            cell.textField.isSecureTextEntry = false
            cell.textField.placeholder = NSLocalizedString("EnterNewUsernamePlaceholder",
                                                           tableName: walkthroughTableName,
                                                           comment: "")
            return cell
        } else if currentCellType == .passwordNotice {
            let cell = tableView.dequeueReusableCell(withIdentifier: tableViewCellId,
                                                     for: indexPath) as! TextCell
            cell.label.text = NSLocalizedString("ChooseStrongPassword",
                                                tableName: walkthroughTableName,
                                                comment: "")
            return cell
        } else if currentCellType == .newPasswordField {
            let cell = tableView.dequeueReusableCell(withIdentifier: textFieldCellId,
                                                     for: indexPath) as! TextFieldCell
            cell.textField.isSecureTextEntry = true
            cell.textField.placeholder = NSLocalizedString("NewPasswordPlaceholder",
                                                           tableName: walkthroughTableName,
                                                           comment: "")
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: textFieldCellId,
                                                     for: indexPath) as! TextFieldCell
            cell.textField.isSecureTextEntry = true
            cell.textField.placeholder = NSLocalizedString("RepeatPasswordPlaceholder",
                                                           tableName: walkthroughTableName,
                                                           comment: "")
            return cell
        }
    }

}
