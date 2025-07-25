/*
 *  Copyright (C) 2017-2020 Savoir-faire Linux Inc.
 *
 *  Author: Silbino Gonçalves Matado <silbino.gmatado@savoirfairelinux.com>
 *  Author: Raphaël Brulé <raphael.brule@savoirfairelinux.com>
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

let registeredNamesKey = "REGISTERED_NAMES_KEY"

class NameService {

    /// Logger
    private let log = SwiftyBeaver.self

    private let disposeBag = DisposeBag()

    /// Used to make lookup name request to the daemon
    private let nameRegistrationAdapter: NameRegistrationAdapter

    private var delayedLookupNameCall: DispatchWorkItem?

    private let lookupNameCallDelay = 0.5

    /// Status of the current username validation request
    var usernameValidationStatus = PublishSubject<UsernameValidationStatus>()
    private let registrationStatus = PublishSubject<ServiceEvent>()
    var sharedRegistrationStatus: Observable<ServiceEvent>

    /// Status of the current username lookup request
    var usernameLookupStatus = PublishSubject<LookupNameResponse>()

    private let userSearchResponseStream = PublishSubject<UserSearchResponse>()
    /// Triggered when we receive a UserSearchResponse from the daemon
    let userSearchResponseShared: Observable<UserSearchResponse>

    init(withNameRegistrationAdapter nameRegistrationAdapter: NameRegistrationAdapter) {
        self.nameRegistrationAdapter = nameRegistrationAdapter
        self.sharedRegistrationStatus = registrationStatus.share()

        self.userSearchResponseStream.disposed(by: self.disposeBag)
        self.userSearchResponseShared = self.userSearchResponseStream.share()

        NameRegistrationAdapter.delegate = self
    }

    /// Make a username lookup request to the daemon
    func lookupName(withAccount account: String, nameserver: String, name: String) {

        let testServer: String = TestEnvironment.shared.nameServerURI ?? ""

        let nameserver = nameserver.isEmpty ? testServer : nameserver

        // Cancel previous lookups...
        delayedLookupNameCall?.cancel()

        if name.isEmpty {
            usernameValidationStatus.onNext(.empty)
        } else {
            usernameValidationStatus.onNext(.lookingUp)

            // Fire a delayed lookup...
            delayedLookupNameCall = DispatchWorkItem {
                self.nameRegistrationAdapter.lookupName(withAccount: account, nameserver: nameserver, name: name)
            }

            if let lookup = delayedLookupNameCall {

                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + lookupNameCallDelay, execute: lookup)
            }
        }
    }

    /// Make an address lookup request to the daemon
    func lookupAddress(withAccount account: String, nameserver: String, address: String) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.nameRegistrationAdapter.lookupAddress(withAccount: account, nameserver: nameserver, address: address)
        }
    }

    /// Register the username into the the blockchain
    func registerName(withAccount account: String, password: String, name: String) {
        self.nameRegistrationAdapter.registerName(withAccount: account, password: password, name: name)
    }

    func registerNameObservable(accountId: String, password: String, name: String) -> Observable<Bool> {
        let registerName: Single<Bool> =
            Single.create(subscribe: { (single) -> Disposable in
                self.nameRegistrationAdapter
                    .registerName(withAccount: accountId,
                                  password: password,
                                  name: name)
                single(.success(true))
                return Disposables.create { }
            })
            .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))

        let filteredDaemonSignals = self.sharedRegistrationStatus
            .filter({ (serviceEvent) -> Bool in
                return serviceEvent.getEventInput(ServiceEventInput.accountId) == accountId &&
                    serviceEvent.eventType == .nameRegistrationEnded
            })
        return Observable
            .combineLatest(registerName.asObservable(), filteredDaemonSignals.asObservable()) { (_, serviceEvent) -> Bool in
                guard let status: NameRegistrationState = serviceEvent.getEventInput(ServiceEventInput.state)
                else { return false }
                switch status {
                case .success:
                    return true
                default:
                    return false
                }
            }
    }

    /// Make a user search request to the daemon
    func searchUser(withAccount account: String, query: String) {
        self.nameRegistrationAdapter.searchUser(withAccount: account, query: query)
    }
}

// MARK: NameRegistrationAdapterDelegate
extension NameService: NameRegistrationAdapterDelegate {

    internal func registeredNameFound(with response: LookupNameResponse) {

        if response.state == .notFound {
            usernameValidationStatus.onNext(.valid)
        } else if response.state == .found {
            usernameValidationStatus.onNext(.alreadyTaken)
        } else if response.state == .invalidName || response.state == .error {
            usernameValidationStatus.onNext(.invalid)
        } else {
            log.error("Lookup name error")
        }

        usernameLookupStatus.onNext(response)
    }

    internal func nameRegistrationEnded(with response: NameRegistrationResponse) {
        if response.state == .success {
            var registeredNames = [String: String]()
            if let userNameData = UserDefaults.standard.dictionary(forKey: registeredNamesKey) as? [String: String] {
                registeredNames = userNameData
            }
            registeredNames[response.accountId] = response.name
            UserDefaults.standard.set(registeredNames, forKey: registeredNamesKey)
            log.debug("Registered name: \(response.name ?? "no name")")
        } else {
            log.debug("Name Registration failed. State = \(response.state.rawValue)")
        }
        var event = ServiceEvent(withEventType: .nameRegistrationEnded)
        event.addEventInput(.state, value: response.state)
        event.addEventInput(.accountId, value: response.accountId)
        self.registrationStatus.onNext(event)
    }

    internal func userSearchEnded(with response: UserSearchResponse) {
        switch response.state {
        case .found:
            self.userSearchResponseStream.onNext(response)
        case .invalidName:
            self.userSearchResponseStream.onNext(response)
            self.log.warning("User search invalid name")
        case.notFound:
            self.userSearchResponseStream.onNext(response)
            self.log.warning("User search not found")
        case .error:
            self.userSearchResponseStream.onNext(response)
            self.log.error("User search error")
        @unknown default:
            self.log.error("User search unknown default")
        }
    }
}
