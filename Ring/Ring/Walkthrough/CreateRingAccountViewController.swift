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

    var mAccountViewModel: AccountViewModel = AccountViewModel()

    @IBOutlet weak var mCreateAccountButton: RoundedButton!
    
    @IBOutlet weak var createAccountTitleLabel: UILabel!
    

    /**
     Cell identifiers
     */
    
    let switchCellId = "SwitchCellId"
    let textFieldCellId = "TextFieldCellId"
    let tableViewCellId = "TableViewCellId"

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
            onStart: { [weak self] in
                self?.setCreateAccountAsLoading()
            },
            onSuccess: { [weak self] in
                print("Account created.")
                self?.setCreateAccountAsIdle()
            },
            onError:  { [weak self] (error) in
                print("Error creating account...")
                if error != nil {
                    print(error!)
                }
                self?.setCreateAccountAsIdle()
        })
    }
    
    /** 
     Customize the views
     */
    
    fileprivate func setupUI() {
        self.tableView.estimatedRowHeight = 44.0
        self.tableView.rowHeight = UITableViewAutomaticDimension
        
        self.createAccountTitleLabel.text = NSLocalizedString("CreateAccountFormTitle", comment: "")
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
    
    //MARK: TableView datasource
    
    fileprivate var cells :[CreateRingAccountCellType] = [.registerPublicUsername, .passwordNotice, .newPasswordField, .repeatPasswordField]
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return cells.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let currentCellType = cells[indexPath.row]
        
        if currentCellType == .registerPublicUsername {
            let cell = tableView.dequeueReusableCell(withIdentifier: switchCellId, for: indexPath) as! SwitchCell
            cell.titleLabel.text = NSLocalizedString("RegisterPublicUsername", comment: "")
            cell.titleLabel.textColor = .white
            cell.registerSwitch.isOn = false
            return cell
        } else if currentCellType == .usernameField {
            let cell = tableView.dequeueReusableCell(withIdentifier: textFieldCellId, for: indexPath) as! TextFieldCell
            cell.textField.placeholder = NSLocalizedString("EnterNewUsernamePlaceholder", comment: "")
            return cell
        } else if currentCellType == .passwordNotice {
            let cell = tableView.dequeueReusableCell(withIdentifier: tableViewCellId, for: indexPath) as! TextCell
            cell.label.text = NSLocalizedString("ChooseStrongPassword", comment: "")
            return cell
        } else if currentCellType == .newPasswordField {
            let cell = tableView.dequeueReusableCell(withIdentifier: textFieldCellId, for: indexPath) as! TextFieldCell
            cell.textField.placeholder = NSLocalizedString("NewPasswordPlaceholder", comment: "")
            return cell
        } else if currentCellType == .repeatPasswordField {
            let cell = tableView.dequeueReusableCell(withIdentifier: textFieldCellId, for: indexPath) as! TextFieldCell
            cell.textField.placeholder = NSLocalizedString("RepeatPasswordPlaceholder", comment: "")
            return cell
        } else {
            return UITableViewCell()
        }
    }
    
}
