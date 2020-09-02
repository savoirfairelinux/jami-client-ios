/*
 *  Copyright (C) 2017-2019 Savoir-faire Linux Inc.
 *
 *  Author: Edric Ladent-Milaret <edric.ladent-milaret@savoirfairelinux.com>
 *  Author: Romain Bertozzi <romain.bertozzi@savoirfairelinux.com>
 *  Author: Quentin Muret <quentin.muret@savoirfairelinux.com>
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

/**
 Errors that can be thrown when trying to build an AccountModel
 */
enum AccountModelError: Error {
    case unexpectedError
}

/**
 A class representing an account.
 */
class AccountModel: Equatable {
    // MARK: Public members
    var id: String = ""
    var protectedDetails: AccountConfigModel? {
        willSet {
            if let newDetails = newValue {
                if !newDetails
                    .get(withConfigKeyModel: ConfigKeyModel(withKey: .accountUsername))
                    .isEmpty {
                    self.username = newDetails
                        .get(withConfigKeyModel: ConfigKeyModel(withKey: .accountUsername))
                }
                let accountType = newDetails
                    .get(withConfigKeyModel: ConfigKeyModel.init(withKey: .accountType))
                if let type = AccountType(rawValue: accountType) {
                    self.type = type
                }
                self.enabled = newDetails
                    .get(withConfigKeyModel: ConfigKeyModel.init(withKey: .accountEnable))
                    .boolValue
            }
        }
    }

    let detailsQueue = DispatchQueue(label: "com.accountDetailsAccess", qos: .background, attributes: .concurrent)

    var details: AccountConfigModel? {
        get {
            return detailsQueue.sync { protectedDetails }
        }

        set(newValue) {
            detailsQueue.sync(flags: .barrier) {[weak self] in
                self?.protectedDetails = newValue
            }
        }
    }

    var volatileDetails: AccountConfigModel? {
        get {
            return volatileDetailsQueue.sync { protectedVolatileDetails }
        }

        set(newValue) {
            volatileDetailsQueue.sync(flags: .barrier) { [weak self] in
                self?.protectedVolatileDetails = newValue
            }
        }
    }

    let volatileDetailsQueue = DispatchQueue(label: "com.accountVolatileDetailsAccess", qos: .background, attributes: .concurrent)

    var protectedVolatileDetails: AccountConfigModel? {
        willSet {
            if let newDetails = newValue {
                if !newDetails
                    .get(withConfigKeyModel: ConfigKeyModel(withKey: .accountRegisteredName))
                    .isEmpty {
                    self.registeredName = newDetails.get(withConfigKeyModel: ConfigKeyModel(withKey: .accountRegisteredName))
                }
                if let status = AccountState(rawValue:
                    newDetails.get(withConfigKeyModel:
                        ConfigKeyModel(withKey: .accountRegistrationStatus))) {
                    self.status = status
                }

                let managerConfModel = ConfigKeyModel(withKey: .managerUri)
                self.isJams = !newDetails.get(withConfigKeyModel: managerConfModel).isEmpty
            }
        }
    }
    var credentialDetails = [AccountCredentialsModel]()
    var devices = [DeviceModel]()
    var registeredName = ""
    var username = ""
    var jamiId: String {
        return self.username.replacingOccurrences(of: "ring:", with: "")
    }
    var type = AccountType.ring
    var isJams = false
    var status = AccountState.unregistered
    var enabled = true

    // MARK: Init
    convenience init(withAccountId accountId: String) {
        self.init()
        self.id = accountId
    }

    convenience init(withAccountId accountId: String,
                     details: AccountConfigModel,
                     volatileDetails: AccountConfigModel,
                     credentials: [AccountCredentialsModel],
                     devices: [DeviceModel]) throws {
        self.init()
        self.id = accountId
        self.details = details
        self.volatileDetails = volatileDetails
        self.devices = devices
    }

    static func == (lhs: AccountModel, rhs: AccountModel) -> Bool {
        return lhs.id == rhs.id
    }

}
