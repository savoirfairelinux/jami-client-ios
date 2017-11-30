/*
 *  Copyright (C) 2017 Savoir-faire Linux Inc.
 *
 *  Author: Silbino Gonçalves Matado <silbino.gmatado@savoirfairelinux.com>
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

/// Represents the status of a username validation request when the user is typing his username
///
/// - empty: entered username is empty
/// - lookingUp: lookup is being done
/// - invalid: name does not match blockchain requirements
/// - exists: name is already reserved in the blockchain
/// - valid: name can be reserved
enum UsernameValidationStatus {
    case empty
    case lookingUp
    case invalid
    case exists (name: String, address: String)
    case valid
}

/// Represents the status of a username registration request
///
/// - empty: entered username is empty
/// - registering: username is being registered on the blockchain
/// - alreadyTaken: name is already reserved
/// - valid: name can be reserved
enum UsernameRegistrationStatus {
    case empty
    case registering
    case registered
    case notRegistered
}

/// Service related to blockchain registreation
final class NameService {

    fileprivate let log = SwiftyBeaver.self
    private let nameRegistrationAdapter: NameRegistrationAdapter

    init(withNameRegistrationAdapter nameRegistrationAdapter: NameRegistrationAdapter) {
        self.nameRegistrationAdapter = nameRegistrationAdapter
        NameRegistrationAdapter.delegate = self
    }

    fileprivate var usernameLookupStatus = PublishSubject<LookupNameResponse>()
    fileprivate var usernameRegistrationStatus = PublishSubject<NameRegistrationResponse>()

    /// Make a username lookup request to the daemon / blockchain
    ///
    /// - Parameters:
    ///   - account: account id
    ///   - nameserver: lookup server address
    ///   - name: the name we are resolving
    /// - Returns: the status of the request
    func lookupName(withAccountId accountId: String, nameserver: String, name: String) -> Observable<UsernameValidationStatus> {

        if name.isEmpty {
            return Observable.just(.empty)
        }

        // the subscription to this observable triggers the lookup on the blockchain
        let lookupNameObservable = Observable<Void>.create { [unowned self] (observer) -> Disposable in
            self.nameRegistrationAdapter.lookupName(withAccount: accountId, nameserver: nameserver, name: name)
            observer.onNext(Void())
            return Disposables.create()
        }

        // the subscription to this observable allows to parse the lookup response and filter it per accountId/name
        let lookupStatusObservable = self.usernameLookupStatus.filter { $0.accountId == accountId && $0.name == name }

        // the combination of the observables makes the operation atomic and consistant
        return Observable.combineLatest(lookupStatusObservable, lookupNameObservable) { (lookupResponse, _) -> UsernameValidationStatus in
            switch lookupResponse.state {
            case .notFound:
                return .valid
            case .found:
                return .exists(name: lookupResponse.name, address: lookupResponse.address)
            case .invalidName:
                return .invalid
            case .error:
                return .invalid
            }
            }.startWith(.lookingUp)
    }

    /// Make an address lookup request to the daemon
    ///
    /// - Parameters:
    ///   - account: account id
    ///   - nameserver: lookup server address
    ///   - name: the name we are resolving
    /// - Returns: the lookup response
    func lookupAddress(withAccountId accountId: String, nameserver: String, address: String) -> Single<LookupNameResponse> {

        // the subscription to this observable triggers the lookup on the blockchain
        let lookupAddressObservable = Observable<Void>.create { [unowned self] (observer) -> Disposable in
            self.nameRegistrationAdapter.lookupAddress(withAccount: accountId, nameserver: nameserver, address: address)
            observer.onNext(Void())
            return Disposables.create()
        }

        // the subscription to this observable allows to parse the lookup response and filter it per address
        let lookupStatusObservable = self.usernameLookupStatus.filter { $0.address == address }

        return Observable.combineLatest(lookupStatusObservable, lookupAddressObservable, resultSelector: { (lookupResponse, _) -> LookupNameResponse in
            return lookupResponse
        })
            .take(1)
            .asSingle()
    }

    /// Register the username into the the blockchain
    ///
    /// - Parameters:
    ///   - account: account id
    ///   - nameserver: lookup server address
    ///   - name: the name we are resolving
    /// - Returns: the status of the registration
    @discardableResult func registerName(withAccountId accountId: String, password: String, name: String) -> Observable<UsernameRegistrationStatus> {

        if name.isEmpty {
            return Observable.just(.empty)
        }

        // the subscription to this observable triggers the registration on the blockchain
        let registerNameObservable = Observable<Void>.create { [unowned self] (observer) -> Disposable in
            self.nameRegistrationAdapter.registerName(withAccount: accountId, password: password, name: name)
            observer.onNext(Void())
            return Disposables.create()
        }

        // the subscription to this observable allows to parse the registration response and filter it per accountId/name
        let registrationStatusObservable = self.usernameRegistrationStatus.filter { $0.accountId == accountId && $0.name == name }

        // the combination of the observables makes the operation atomic and consistant
        return Observable.combineLatest(registrationStatusObservable, registerNameObservable) { (registrationResponse, _) -> UsernameRegistrationStatus in
            switch registrationResponse.state {
            case .success:
                return .registered
            default:
                return .notRegistered
            }
            }.startWith(.registering)
    }
}

// MARK: NameService delegate
extension NameService: NameRegistrationAdapterDelegate {

    internal func registeredNameFound(with response: LookupNameResponse) {
        log.debug("lookup response: \(response.name) - \(response.state)")
        self.usernameLookupStatus.onNext(response)
    }

    internal func nameRegistrationEnded(with response: NameRegistrationResponse) {
        log.debug("name registration status: \(response)")
        self.usernameRegistrationStatus.onNext(response)
    }
}
