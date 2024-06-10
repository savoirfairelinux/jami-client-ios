/*
 *  Copyright (C) 2024 Savoir-faire Linux Inc.
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

import SwiftUI
import UIKit
import RxSwift

class SipAccountDetailModel: ObservableObject {
    @Published var username = ""
    @Published var server = ""
    @Published var password = ""
    @Published var proxy = ""
    @Published var port = ""

    let account: AccountModel
    let accountService: AccountsService

    init(account: AccountModel, injectionBag: InjectionBag) {
        self.account = account
        self.accountService = injectionBag.accountService
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            guard let details = account.details, let credentials = account.credentialDetails.first else { return }
            self.username = credentials.username
            self.password = credentials.password
            self.server = details.get(withConfigKeyModel: ConfigKeyModel.init(withKey: .accountHostname))
            self.port = details.get(withConfigKeyModel:
                                        ConfigKeyModel.init(withKey: .localPort))
            self.proxy = details.get(withConfigKeyModel: ConfigKeyModel.init(withKey: .accountRouteSet))
        }
    }

    func updateSipSettings() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            guard let details = self.account.details, let credentials = self.account.credentialDetails.first else { return }
            let username = credentials.username
            let password = credentials.password
            let server = details.get(withConfigKeyModel: ConfigKeyModel.init(withKey: .accountHostname))
            let port = details.get(withConfigKeyModel:
                                    ConfigKeyModel.init(withKey: .localPort))
            let proxy = details.get(withConfigKeyModel: ConfigKeyModel.init(withKey: .accountRouteSet))
            if username == self.username
                && password == self.password
                && server == self.server
                && port == self.port
                && proxy == self.proxy {
                return
            }
            if username != self.username || password != self.password {
                credentials.username = self.username
                credentials.password = self.password
                self.account.credentialDetails = [credentials]
                let dict = credentials.toDictionary()
                self.accountService.setAccountCrdentials(forAccountId: self.account.id, crdentials: [dict])
            }
            if server != self.server ||
                port != self.port ||
                username != self.username ||
                proxy != self.proxy {
                details.set(withConfigKeyModel: ConfigKeyModel(withKey: ConfigKey.accountHostname), withValue: self.server)
                details.set(withConfigKeyModel: ConfigKeyModel(withKey: ConfigKey.localPort), withValue: self.port)
                details.set(withConfigKeyModel: ConfigKeyModel(withKey: ConfigKey.accountUsername), withValue: self.username)
                details.set(withConfigKeyModel: ConfigKeyModel(withKey: ConfigKey.accountRouteSet), withValue: self.proxy)
                account.details = details
                self.accountService.setAccountDetails(forAccountId: self.account.id, withDetails: details)
            }
        }
    }
}
