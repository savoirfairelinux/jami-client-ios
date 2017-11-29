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

import RxSwift
import SwiftyBeaver

/// GetAccountError
///
/// - noAccountFound: no account has been found
/// - templateNotConform: no account template could be built from the daemon
/// - unknownError: an unknown error occured
enum AccountError: Error {
    case noAccountFound
    case templateNotConform
    case unknownError
}

enum ExportAccountError: Error {
    case unknownError
}

enum PinError: Error {
    case passwordError
    case networkError
    case defaultError

    var description: String {
        switch self {
        case .passwordError:
            return L10n.Linkdevice.passwordError
        case .networkError:
            return L10n.Linkdevice.networkError
        case .defaultError:
            return L10n.Linkdevice.defaultError
        }
    }
}

/// The New Accounts Service, with no model duplication from the daemon.
final class NewAccountsService {

    // MARK: - Private members
    /// Logger
    fileprivate let log = SwiftyBeaver.self

    /// Bridged daemon account adapter
    fileprivate let accountAdapter: AccountAdapter

    /// Stream for daemon signal, inaccessible from the outside
    fileprivate let daemonSignals = PublishSubject<ServiceEvent>()

    fileprivate let disposeBag = DisposeBag()

    // MARK: - Members
    lazy var daemonSignalsObservable: Observable<ServiceEvent> = {
        return self.daemonSignals.asObservable()
    }()

    // MARK: - Public API
    /// Initializer
    ///
    /// - Parameter accountAdapter: the injected accountAdapter
    init(withAccountAdapter accountAdapter: AccountAdapter) {
        self.accountAdapter = accountAdapter
        //~ Registering to the accountAdatpter with self as delegate in order to receive delegation
        //~ callbacks.
        AccountAdapter.delegate = self
    }

    /// Gets the current account.
    ///
    /// - Remark: the daemon has no such notion of current account. For now, since this app is only
    /// designed for one account, we consider that the one we have is the current one.
    /// - Returns: a single of an AccountModel
    func currentAccount() -> Single<AccountModel> {
        return self.loadAccounts().map({ (accountsModel) -> AccountModel in
            guard let account = accountsModel.first else {
                throw AccountError.noAccountFound
            }
            return account
        })
    }

    /// Gets the account responding to the given id.
    ///
    /// - Parameter id: the id of the account to get.
    /// - Returns: a single of an AccountModel
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

    /// Loads all the accounts.
    ///
    /// - Returns: a single of all the AccountModel
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

    /// Adds a new Ring account.
    ///
    /// - Parameters:
    ///   - username: an optional username for the new account
    ///   - password: the required password for the new account
    /// - Returns: an observable of an AccountModel: the created one
    func addRingAccount(username: String?, password: String) -> Observable<AccountModel> {
        //~ Single asking the daemon to add a new account with the associated metadata
        let createAccountSingle: Single<AccountModel> = Single.create(subscribe: { (single) -> Disposable in
            do {
                var ringDetails = try self.loadRingInitialAccountDetailsFromDaemon()
                if let username = username {
                    ringDetails.updateValue(username, forKey: ConfigKey.accountRegisteredName.rawValue)
                }
                ringDetails.updateValue(password, forKey: ConfigKey.archivePassword.rawValue)

                guard let accountId = self.accountAdapter.addAccount(ringDetails) else {
                    throw AccountError.unknownError
                }
                let account = try self.buildAccountFromDaemon(accountId: accountId)
                single(.success(account))
            } catch {
                single(.error(error))
            }
            return Disposables.create {
            }
        })

        //~ Filter the daemon signals to isolate the "account created" one.
        let filteredDaemonSignals = self.daemonSignals.filter { (serviceEvent) -> Bool in
            if serviceEvent.getEventInput(ServiceEventInput.registrationState) == ErrorGeneric {
                throw AccountCreationError.generic
            } else if serviceEvent.getEventInput(ServiceEventInput.registrationState) == ErrorNetwork {
                throw AccountCreationError.network
            }

            let isRegistrationStateChanged = serviceEvent.eventType == ServiceEventType.registrationStateChanged
            let isRegistered = serviceEvent.getEventInput(ServiceEventInput.registrationState) == Registered
            return isRegistrationStateChanged && isRegistered
        }

        //~ Make sure that we have the correct account added in the daemon, and return it.
        return Observable
            .combineLatest(createAccountSingle.asObservable(), filteredDaemonSignals.asObservable()) { (accountModel, serviceEvent) -> AccountModel in
                guard accountModel.id == serviceEvent.getEventInput(ServiceEventInput.accountId) else {
                    throw AccountError.unknownError
                }
                return accountModel
            }
            .flatMap({ [unowned self] (accountModel) -> Observable<AccountModel> in
                return self.getAccount(fromAccountId: accountModel.id).asObservable()
            })
    }

    func linkToRingAccount(withPin pin: String, password: String) -> Observable<AccountModel> {
        //~ Single asking the daemon to add a new account with the associated metadata
        let createAccountSingle: Single<AccountModel> = Single.create(subscribe: { (single) -> Disposable in
            do {
                var ringDetails = try self.loadRingInitialAccountDetailsFromDaemon()
                ringDetails.updateValue(password, forKey: ConfigKey.archivePassword.rawValue)
                ringDetails.updateValue(pin, forKey: ConfigKey.archivePIN.rawValue)
                guard let accountId = self.accountAdapter.addAccount(ringDetails) else {
                    throw AccountError.unknownError
                }
                let account = try self.buildAccountFromDaemon(accountId: accountId)
                single(.success(account))
            } catch {
                single(.error(error))
            }
            return Disposables.create {
            }
        })

        //~ Filter the daemon signals to isolate the "account created" one.
        let filteredDaemonSignals = self.daemonSignals.filter { (serviceEvent) -> Bool in
            if serviceEvent.getEventInput(ServiceEventInput.registrationState) == ErrorGeneric {
                throw AccountCreationError.linkError
            } else if serviceEvent.getEventInput(ServiceEventInput.registrationState) == ErrorNetwork {
                throw AccountCreationError.network
            }

            let isRegistrationStateChanged = serviceEvent.eventType == ServiceEventType.registrationStateChanged
            let isRegistered = serviceEvent.getEventInput(ServiceEventInput.registrationState) == Registered
            return isRegistrationStateChanged && isRegistered
        }

        //~ Make sure that we have the correct account added in the daemon, and return it.
        return Observable
            .combineLatest(createAccountSingle.asObservable(), filteredDaemonSignals.asObservable()) { (accountModel, serviceEvent) -> AccountModel in
                guard accountModel.id == serviceEvent.getEventInput(ServiceEventInput.accountId) else {
                    throw AccountError.unknownError
                }
                return accountModel
            }
            .flatMap({ [unowned self] (accountModel) -> Observable<AccountModel> in
                return self.getAccount(fromAccountId: accountModel.id).asObservable()
            })
    }

    func exportAccountOnRing(_ account: AccountModel, withPassword password: String) -> Observable<String> {
        let export = self.exportAccount(account, withPassword: password)

        let filteredDaemonSignals = self.daemonSignals.filter { (serviceEvent) -> Bool in
            if serviceEvent.getEventInput(ServiceEventInput.state) == ErrorGeneric {
                throw AccountCreationError.linkError
            } else if serviceEvent.getEventInput(ServiceEventInput.state) == ErrorNetwork {
                throw AccountCreationError.network
            }

            return serviceEvent.eventType == ServiceEventType.exportOnRingEnded
        }.asObservable()

        return Observable
            .combineLatest(export, filteredDaemonSignals) { (_, serviceEvent) -> String in
                let accountModelHelper = AccountModelHelper(withAccount: account)
                guard let uri = accountModelHelper.ringId, uri == serviceEvent.getEventInput(.uri) else {
                    throw ExportAccountError.unknownError
                }
                if let state: Int = serviceEvent.getEventInput(.state) {
                    switch state {
                    case ExportAccountResponse.success.rawValue:
                        guard let pin: String = serviceEvent.getEventInput(.pin) else {
                            throw PinError.defaultError
                        }
                        return pin
                    case ExportAccountResponse.wrongPassword.rawValue:
                        throw PinError.passwordError
                    case ExportAccountResponse.networkProblem.rawValue:
                        throw PinError.networkError
                    default:
                        throw PinError.defaultError
                    }
                }
                throw PinError.defaultError
            }
    }

}

// MARK: - Private daemon wrappers
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

    fileprivate func loadRingInitialAccountDetailsFromDaemon() throws -> [String: String] {
        do {
            var defaultDetails = try loadInitialAccountDetailsFromDaemon()
            defaultDetails.updateValue("Ring", forKey: ConfigKey.accountAlias.rawValue)
            defaultDetails.updateValue("bootstrap.ring.cx", forKey: ConfigKey.accountHostname.rawValue)
            defaultDetails.updateValue("true", forKey: ConfigKey.accountUpnpEnabled.rawValue)
            return defaultDetails
        } catch {
            throw error
        }
    }

    fileprivate func loadInitialAccountDetailsFromDaemon() throws -> [String: String] {
        let details: NSMutableDictionary = self.accountAdapter.getAccountTemplate(AccountType.ring.rawValue)
        var accountDetails = details as NSDictionary? as? [String: String] ?? nil
        if accountDetails == nil {
            throw AccountError.templateNotConform
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
            throw error
        }
        return accountModel
    }

    fileprivate func exportAccount(_ account: AccountModel, withPassword password: String) -> Observable<Bool> {
        return Observable.create { [unowned self] observable in
            let export = self.accountAdapter.export(onRing: account.id, password: password)
            if export {
                observable.onNext(true)
                observable.onCompleted()
            } else {
                observable.onError(LinkNewDeviceError.unknownError)
            }
            return Disposables.create()
        }
    }

}

// MARK: - AccountAdapterDelegate
extension NewAccountsService: AccountAdapterDelegate {

    func accountsChanged() {
        log.debug("Accounts changed.")

        let event = ServiceEvent(withEventType: .accountsChanged)
        self.daemonSignals.onNext(event)
    }

    func registrationStateChanged(with response: RegistrationResponse) {
        log.debug("Registration state changed.")

        var event = ServiceEvent(withEventType: .registrationStateChanged)
        event.addEventInput(.registrationState, value: response.state)
        event.addEventInput(.accountId, value: response.accountId)
        self.daemonSignals.onNext(event)
    }

    func knownDevicesChanged(for account: String, devices: [String: String]) {
        log.debug("Known devices changed.")
    }

    func exportOnRingEnded(for account: String, state: Int, pin: String) {
        log.debug("Export on Ring ended.")

        self.getAccount(fromAccountId: account)
            .subscribe(onSuccess: { [unowned self] (account) in
                let accountHelper = AccountModelHelper(withAccount: account)
                if let uri = accountHelper.ringId {
                    var event = ServiceEvent(withEventType: .exportOnRingEnded)
                    event.addEventInput(.uri, value: uri)
                    event.addEventInput(.state, value: state)
                    event.addEventInput(.pin, value: pin)
                    self.daemonSignals.onNext(event)
                }
                }, onError: { [unowned self] (error) in
                    self.log.error("Account not found")
                    var event = ServiceEvent(withEventType: .exportOnRingEnded)
                    event.addEventInput(.state, value: state)
                    event.addEventInput(.pin, value: pin)
                    self.daemonSignals.onNext(event)
            })
            .disposed(by: self.disposeBag)
    }

}
