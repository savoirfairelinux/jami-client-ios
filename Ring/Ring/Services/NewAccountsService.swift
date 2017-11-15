/*
 *  Copyright (C) 2017 Savoir-faire Linux Inc.
 *
 *  Authors: Romain Bertozzi <romain.bertozzi@savoirfairelinux.com>
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

import RxSwift
import SwiftyBeaver

enum AccountError: Error {
    case noAccountFound
    case unknownError
}

final class NewAccountsService {

    fileprivate let log = SwiftyBeaver.self
    fileprivate let accountAdapter: AccountAdapter
    fileprivate let daemonSignals = PublishSubject<ServiceEvent>()

    lazy var daemonSignalsObservable: Observable<ServiceEvent> = {
        return self.daemonSignals.asObservable()
    }()

    init(withAccountAdapter accountAdapter: AccountAdapter) {
        self.accountAdapter = accountAdapter
        //~ Registering to the accountAdatpter with self as delegate in order to receive delegation
        //~ callbacks.
        AccountAdapter.delegate = self
    }

    func currentAccount() -> Single<AccountModel> {
        return self.loadAccounts().map({ (accountsModel) -> AccountModel in
            guard let account = accountsModel.first else {
                throw AccountError.noAccountFound
            }
            return account
        })
    }

    func getAccount(fromAccountId id: String) -> Single<AccountModel> {
        return self.loadAccounts().map({ (accountModels) -> AccountModel in
            guard let account = accountModels.filter({ (accountModel) -> Bool in
                return id == accountModel.id
            }).first else {
                throw AccountError.noAccountFound
            }
            return account
        })
    }

    func loadAccounts() -> Single<[AccountModel]> {
        return Single.create(subscribe: { (single) -> Disposable in
            do {
                let accounts = try self.loadAccountsIdsFromDaemon().map({ (accountId) -> AccountModel in
                    return try self.buildAccountFromDaemon(accountId: accountId)
                })
                single(.success(accounts))
            } catch {
                single(.error(error))
            }
            return Disposables.create {
            }
        })
    }

    func addRingAccount(username: String?, password: String) -> Observable<AccountModel> {
        let single: Single<AccountModel> = Single.create(subscribe: { (single) -> Disposable in
            do {
                var ringDetails = try self.loadInitialAccountDetailsFromDaemon()
                if let username = username {
                    ringDetails.updateValue(username, forKey: ConfigKey.accountRegisteredName.rawValue)
                }
                ringDetails.updateValue(password, forKey: ConfigKey.archivePassword.rawValue)

                guard let accountId = self.accountAdapter.addAccount(ringDetails) else {
                    throw AddAccountError.unknownError
                }
                let account = try self.buildAccountFromDaemon(accountId: accountId)
                single(.success(account))
            } catch {
                single(.error(error))
            }
            return Disposables.create {
            }
        })

        let filteredDaemonSignals = self.daemonSignals.filter { (serviceEvent) -> Bool in
            return serviceEvent.eventType == ServiceEventType.accountsChanged
        }

        return Observable.combineLatest(single.asObservable(), filteredDaemonSignals.asObservable()) { (accountModel, _) -> AccountModel in
            return accountModel
        }.flatMap({ [unowned self] (accountModel) -> Observable<AccountModel> in
            return self.getAccount(fromAccountId: accountModel.id).asObservable()
        }).retry(3)
    }

    func linkToRingAccount(withPin pin: String, password: String) -> Observable<AccountModel> {
        let single = Single<AccountModel>.create(subscribe: { (single) -> Disposable in
            do {
                var ringDetails = try self.loadInitialAccountDetailsFromDaemon()
                ringDetails.updateValue(password, forKey: ConfigKey.archivePassword.rawValue)
                ringDetails.updateValue(pin, forKey: ConfigKey.archivePIN.rawValue)

                guard let accountId = self.accountAdapter.addAccount(ringDetails) else {
                    throw AddAccountError.unknownError
                }
                let account = try self.buildAccountFromDaemon(accountId: accountId)
                single(.success(account))
            } catch {
                single(.error(error))
            }
            return Disposables.create {
            }
        })

        let filteredDaemonSignals = self.daemonSignals.filter { (serviceEvent) -> Bool in
            return serviceEvent.eventType == ServiceEventType.accountsChanged
        }

        return Observable.combineLatest(single.asObservable(), filteredDaemonSignals.asObservable()) { (accountModel, _) -> AccountModel in
            return accountModel
        }.flatMap({ [unowned self] (accountModel) -> Observable<AccountModel> in
                return self.getAccount(fromAccountId: accountModel.id).asObservable()
        }).retry(3)
    }

}

extension NewAccountsService {

    fileprivate func loadAccountsIdsFromDaemon() -> [String] {
        return self.accountAdapter.getAccountList() as? [String] ?? []
    }

    fileprivate func loadAccountDetailsFromDaemon(accountId id: String) -> AccountConfigModel {
        let details: NSDictionary = self.accountAdapter.getAccountDetails(id) as NSDictionary
        let accountDetailsDict = details as NSDictionary? as? [String: String] ?? nil
        let accountDetails = AccountConfigModel(withDetails: accountDetailsDict)
        return accountDetails
    }

    fileprivate func loadVolatileAccountDetailsFromDaemon(accountId id: String) -> AccountConfigModel {
        let details: NSDictionary = self.accountAdapter.getVolatileAccountDetails(id) as NSDictionary
        let accountDetailsDict = details as NSDictionary? as? [String: String] ?? nil
        let accountDetails = AccountConfigModel(withDetails: accountDetailsDict)
        return accountDetails
    }

    fileprivate func loadAccountCredentialsFromDaemon(accountId id: String) throws -> [AccountCredentialsModel] {
        let creds: NSArray = self.accountAdapter.getCredentials(id) as NSArray
        let rawCredentials = creds as NSArray? as? [[String: String]] ?? nil

        if let rawCredentials = rawCredentials {
            var credentialsList = [AccountCredentialsModel]()
            for rawCredentials in rawCredentials {
                do {
                    let credentials = try AccountCredentialsModel(withRawaData: rawCredentials)
                    credentialsList.append(credentials)
                } catch CredentialsError.notEnoughData {
                    log.error("Not enough data to build a credential object.")
                    throw CredentialsError.notEnoughData
                } catch {
                    log.error("Unexpected error.")
                    throw AccountModelError.unexpectedError
                }
            }
            return credentialsList
        } else {
            throw AccountModelError.unexpectedError
        }
    }

    fileprivate func loadKnownRingDevicesFromDaemon(accountId id: String) -> [DeviceModel] {
        let knownRingDevices = self.accountAdapter.getKnownRingDevices(id)! as NSDictionary

        var devices = [DeviceModel]()
        for key in knownRingDevices.allKeys {
            if let key = key as? String {
                devices.append(DeviceModel(withDeviceId: key,
                                           deviceName: knownRingDevices.value(forKey: key) as? String))
            }
        }
        return devices
    }

    fileprivate func loadInitialAccountDetailsFromDaemon() throws -> [String: String] {
        let details: NSMutableDictionary = self.accountAdapter.getAccountTemplate(AccountType.ring.rawValue)
        var accountDetails = details as NSDictionary? as? [String: String] ?? nil
        if accountDetails == nil {
            throw AddAccountError.templateNotConform
        }
        accountDetails!.updateValue("false", forKey: ConfigKey.videoEnabled.rawValue)
        accountDetails!.updateValue("sipinfo", forKey: ConfigKey.accountDTMFType.rawValue)
        return accountDetails!
    }

    fileprivate func buildAccountFromDaemon(accountId id: String) throws -> AccountModel {
        let accountModel = AccountModel(withAccountId: id)
        accountModel.details = self.loadAccountDetailsFromDaemon(accountId: id)
        accountModel.volatileDetails = self.loadVolatileAccountDetailsFromDaemon(accountId: id)
        accountModel.devices = self.loadKnownRingDevicesFromDaemon(accountId: id)
        do {
            let credentialDetails = try self.loadAccountCredentialsFromDaemon(accountId: id)
            accountModel.credentialDetails.removeAll()
            accountModel.credentialDetails.append(contentsOf: credentialDetails)
        } catch {
            log.error("\(error)")
            throw error
        }
        return accountModel
    }

}

extension NewAccountsService: AccountAdapterDelegate {

    func accountsChanged() {
        log.debug("Accounts changed.")

        let event = ServiceEvent(withEventType: .accountsChanged)
        self.daemonSignals.onNext(event)
    }

    func registrationStateChanged(with response: RegistrationResponse) {
        log.debug("RegistrationStateChanged.")

        var event = ServiceEvent(withEventType: .registrationStateChanged)
        event.addEventInput(.registrationState, value: response.state)
        self.daemonSignals.onNext(event)
    }

    func knownDevicesChanged(for account: String, devices: [String: String]) {
//        let changedAccount = self.getAccount(fromAccountId: account)
//        if let changedAccount = changedAccount {
//            let accountHelper = AccountModelHelper(withAccount: changedAccount)
//            if let  uri = accountHelper.ringId {
//                var event = ServiceEvent(withEventType: .knownDevicesChanged)
//                event.addEventInput(.uri, value: uri)
//                self.responseStream.onNext(event)
//            }
//        }
//        let changedAccount = self.getAccount(fromAccountId: account).subscribe(onSuccess: { [unowned self] account in
//            let accountHelper = AccountModelHelper(withAccount: changedAccount)
//            if let uri = accountHelper.ringId {
//                var event = ServiceEvent(withEventType: .knownDevicesChanged)
//                event.addEventInput(.uri, value: uri)
//                self.daemonSignals.onNext(event)
//            }
//        }, onError: { error in
//
//        })
    }

    func exportOnRingEndeded(forAccout account: String, state: Int, pin: String) {
//        let changedAccount = getAccount(fromAccountId: account)
//        if let changedAccount = changedAccount {
//            let accountHelper = AccountModelHelper(withAccount: changedAccount)
//            if let  uri = accountHelper.ringId {
//                var event = ServiceEvent(withEventType: .exportOnRingEnded)
//                event.addEventInput(.uri, value: uri)
//                event.addEventInput(.state, value: state)
//                event.addEventInput(.pin, value: pin)
//                self.responseStream.onNext(event)
//            }
//        }
    }

}
