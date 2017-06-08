/*
 *  Copyright (C) 2017 Savoir-faire Linux Inc.
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

/**
 A structure exposing the fields and methods for an Account
 */
struct AccountModelHelper {
    fileprivate var account: AccountModel

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
        let sipString = AccountType.SIP.rawValue
        let accountType = self.account.details?
            .get(withConfigKeyModel: ConfigKeyModel.init(withKey: .AccountType))
        return sipString.compare(accountType!) == ComparisonResult.orderedSame
    }

    /**
     Getter exposing the type of the account.

     - Returns: true if the account is considered as a Ring account
     */
    func isAccountRing() -> Bool {
        let ringString = AccountType.Ring.rawValue
        let accountType = self.account.details?
            .get(withConfigKeyModel: ConfigKeyModel.init(withKey: .AccountType))
        return ringString.compare(accountType!) == ComparisonResult.orderedSame
    }

    /**
     Getter exposing the enable state of the account.

     - Returns: true if the account is enabled, false otherwise.
     */
    func isEnabled() -> Bool {
        return (self.account.details!
            .getBool(forConfigKeyModel: ConfigKeyModel.init(withKey: .AccountEnable)))
    }

    /**
     Getter exposing the registration state of the account.

     - Returns: the registration state of the account as a String.
     */
    func getRegistrationState() -> String {
        return (self.account.volatileDetails!
            .get(withConfigKeyModel: ConfigKeyModel.init(withKey: .AccountRegistrationStatus)))
    }

    /**
     Getter exposing the error state of the account.

     - Returns: true if the account is considered as being in error, false otherwise.
     */
    func isInError() -> Bool {
        let state = self.getRegistrationState()
        return (state.compare(AccountState.Error.rawValue) == ComparisonResult.orderedSame) ||
            (state.compare(AccountState.ErrorAuth.rawValue) == ComparisonResult.orderedSame) ||
            (state.compare(AccountState.ErrorConfStun.rawValue) == ComparisonResult.orderedSame) ||
            (state.compare(AccountState.ErrorExistStun.rawValue) == ComparisonResult.orderedSame) ||
            (state.compare(AccountState.ErrorGeneric.rawValue) == ComparisonResult.orderedSame) ||
            (state.compare(AccountState.ErrorHost.rawValue) == ComparisonResult.orderedSame) ||
            (state.compare(AccountState.ErrorNetwork.rawValue) == ComparisonResult.orderedSame) ||
            (state.compare(AccountState.ErrorNotAcceptable.rawValue) == ComparisonResult.orderedSame) ||
            (state.compare(AccountState.ErrorServiceUnavailable.rawValue) == ComparisonResult.orderedSame) ||
            (state.compare(AccountState.ErrorRequestTimeout.rawValue) == ComparisonResult.orderedSame)
    }

    /**
     Setter on the credentials of the account.

     - Parameter: a list of credentials to apply to the account. A nil parameter will clear the
     credentials of the account.
     */
    mutating func setCredentials(_ credentials: Array<Dictionary<String, String>>?) -> AccountModel {
        self.account.credentialDetails.removeAll()
        if credentials != nil {
            for (credential) in credentials! {
                do {
                    let accountCredentialModel = try AccountCredentialsModel(withRawaData: credential)
                    self.account.credentialDetails.append(accountCredentialModel)
                }
                catch CredentialsError.NotEnoughData {
                    print("Not enough data to create a credential")
                }
                catch {
                    print("Unexpected error")
                }
            }
        }
        return self.account
    }
}
