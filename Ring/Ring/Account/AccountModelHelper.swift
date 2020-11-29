/*
 *  Copyright (C) 2017-2019 Savoir-faire Linux Inc.
 *
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

import SwiftyBeaver

/**
 A structure exposing the fields and methods for an Account
 */
struct AccountModelHelper {

    private static let ringIdPrefix = "ring:"
    private static let sipIdPrefix = "sip:"

    private var account: AccountModel

    /**
     logguer
     */
    private let log = SwiftyBeaver.self

    /**
     Constructor

     - Parameter account: the account to expose
     */
    init (withAccount account: AccountModel) {
        self.account = account
    }

    /**
     Getter exposing the type of the account.

     - Returns: true if the account is considered as a SIP account
     */
    func isAccountSip() -> Bool {
        let sipString = AccountType.sip.rawValue
        guard let accountType = self.account.details?
            .get(withConfigKeyModel: ConfigKeyModel.init(withKey: .accountType)) else {
                return false
        }
        return sipString.compare(accountType) == ComparisonResult.orderedSame
    }

    /**
     Getter exposing the type of the account.

     - Returns: true if the account is considered as a Ring account
     */
    func isAccountRing() -> Bool {
        let ringString = AccountType.ring.rawValue
        guard let accountType = self.account.details?
            .get(withConfigKeyModel: ConfigKeyModel.init(withKey: .accountType)) else {
                return false
        }
        return ringString.compare(accountType) == ComparisonResult.orderedSame
    }

    /**
     Getter exposing the enable state of the account.

     - Returns: true if the account is enabled, false otherwise.
     */
    func isEnabled() -> Bool {
        guard let details = self.account.details else { return false }
        return (details
            .getBool(forConfigKeyModel: ConfigKeyModel.init(withKey: .accountEnable)))
    }

    /**
     Getter exposing the registration state of the account.

     - Returns: the registration state of the account as a String.
     */
    func getRegistrationState() -> String {
        guard let details = self.account.volatileDetails else { return "" }
        return (details
            .get(withConfigKeyModel: ConfigKeyModel.init(withKey: .accountRegistrationStatus)))
    }

    /**
     Getter exposing the error state of the account.

     - Returns: true if the account is considered as being in error, false otherwise.
     */
    func isInError() -> Bool {
        let state = self.getRegistrationState()
        return (state.compare(AccountState.error.rawValue) == ComparisonResult.orderedSame) ||
            (state.compare(AccountState.errorAuth.rawValue) == ComparisonResult.orderedSame) ||
            (state.compare(AccountState.errorConfStun.rawValue) == ComparisonResult.orderedSame) ||
            (state.compare(AccountState.errorExistStun.rawValue) == ComparisonResult.orderedSame) ||
            (state.compare(AccountState.errorGeneric.rawValue) == ComparisonResult.orderedSame) ||
            (state.compare(AccountState.errorHost.rawValue) == ComparisonResult.orderedSame) ||
            (state.compare(AccountState.errorNetwork.rawValue) == ComparisonResult.orderedSame) ||
            (state.compare(AccountState.errorNotAcceptable.rawValue) == ComparisonResult.orderedSame) ||
            (state.compare(AccountState.errorServiceUnavailable.rawValue) == ComparisonResult.orderedSame) ||
            (state.compare(AccountState.errorRequestTimeout.rawValue) == ComparisonResult.orderedSame)
    }

    /**
     Setter on the credentials of the account.

     - Parameter: a list of credentials to apply to the account. A nil parameter will clear the
     credentials of the account.
     */
    mutating func setCredentials(_ credentials: [[String: String]]?) -> AccountModel {
        self.account.credentialDetails.removeAll()
        if credentials != nil {
            for (credential) in credentials! {
                do {
                    let accountCredentialModel = try AccountCredentialsModel(withRawaData: credential)
                    self.account.credentialDetails.append(accountCredentialModel)
                } catch CredentialsError.notEnoughData {
                    log.error("Not enough data to create a credential")
                } catch {
                    log.error("Unexpected error")
                }
            }
        }
        return self.account
    }

    var ringId: String? {

        let accountUsernameKey = ConfigKeyModel(withKey: ConfigKey.accountUsername)
        let accountUsername = self.account.details?.get(withConfigKeyModel: accountUsernameKey)
        guard let userName = accountUsername else {
            return nil
        }
        return userName.replacingOccurrences(of: AccountModelHelper.ringIdPrefix, with: "")
    }

    var uri: String? {
        guard let details = self.account.details else { return nil }
        if self.account.type == AccountType.sip {
            let name = details
                .get(withConfigKeyModel: ConfigKeyModel.init(withKey: .accountUsername))
            let server = details
                .get(withConfigKeyModel: ConfigKeyModel.init(withKey: .accountHostname))
            let port = details
                .get(withConfigKeyModel: ConfigKeyModel.init(withKey: .localPort))
            var uri: String
            if !name.isEmpty {
                uri = AccountModelHelper.sipIdPrefix + name
                if !server.isEmpty {
                    uri += "@" + server
                    if !port.isEmpty {
                        uri += ":" + port
                    }
                    return uri
                } else {
                    return uri
                }
            }
            return nil
        } else {
            guard let ringId = self.ringId else { return nil }
            return AccountModelHelper.ringIdPrefix.appending(ringId)
        }
    }

    var hasPassword: Bool {
        let noPassword: String = self.account.details?.get(withConfigKeyModel: ConfigKeyModel(withKey: ConfigKey.archiveHasPassword)) ?? "false"
        return noPassword == "true" ? true : false
    }

    static func uri(fromRingId ringId: String) -> String {
        return self.ringIdPrefix.appending(ringId)
    }
}
