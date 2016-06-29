/*
 *  Copyright (C) 2016 Savoir-faire Linux Inc.
 *
 *  Author: Edric Ladent-Milaret <edric.ladent-milaret@savoirfairelinux.com>
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

import Foundation

class AccountModel {

    //MARK: - Properties
    let confAdapt = ConfigurationManagerAdaptator.sharedManager()
    var accountList: Array<Account> = []
    
    //MARK: - Singleton
    static let sharedInstance = AccountModel()
    
    private init() {
        NSNotificationCenter.defaultCenter().addObserverForName("AccountsChanged", object: nil, queue: nil, usingBlock: {_ in
            self.reload()
        })
    }

    //MARK: - Methods
    func reload() {
        accountList.removeAll()
        for acc in confAdapt.getAccountList() {
            let accID = acc as! String
            accountList.append(Account(accID: accID))
        }
    }
    
    func addAccount() {
        
        //TODO: This need work for all account type
        let details = confAdapt.getAccountTemplate("RING")
        details.setValue("iOS", forKey: "Account.alias")
        details.setValue("iOS", forKey: "Account.displayName")
        confAdapt.addAccount(details! as [NSObject : AnyObject])
    }
    
    func removeAccount(row: Int) {
        if row < accountList.count {
            confAdapt.removeAccount(accountList[row].id)
        }
    }
    
}