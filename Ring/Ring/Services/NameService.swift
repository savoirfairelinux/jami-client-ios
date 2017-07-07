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

/**
 Represents the status of a username validation request when the user is typing his username
 */
enum UsernameValidationStatus {
    case empty
    case lookingUp
    case invalid
    case alreadyTaken
    case valid
}

class NameService: NameRegistrationAdapterDelegate {
    /**
     logguer
     */
    private let log = SwiftyBeaver.self

    /**
     Used to make lookup name request to the daemon
    */
    fileprivate let nameRegistrationAdapter: NameRegistrationAdapter

    fileprivate var delayedLookupNameCall: DispatchWorkItem?

    fileprivate let lookupNameCallDelay = 0.5

    /**
     Status of the current username validation request
     */
    var usernameValidationStatus = PublishSubject<UsernameValidationStatus>()

    init(withNameRegistrationAdapter nameRegistrationAdapter: NameRegistrationAdapter) {
        self.nameRegistrationAdapter = nameRegistrationAdapter
        NameRegistrationAdapter.delegate = self
    }

    /**
     Status of the current username lookup request
     */
    var usernameLookupStatus = PublishSubject<LookupNameResponse>()

    /**
    Make a username lookup request to the daemon
     */
    func lookupName(withAccount account: String, nameserver: String, name: String) {

        //Cancel previous lookups...
        delayedLookupNameCall?.cancel()

        if name.isEmpty {
            usernameValidationStatus.onNext(.empty)
        } else {
            usernameValidationStatus.onNext(.lookingUp)

            //Fire a delayed lookup...
            delayedLookupNameCall = DispatchWorkItem {
                self.nameRegistrationAdapter.lookupName(withAccount: account, nameserver: nameserver, name: name)
            }

            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + lookupNameCallDelay, execute: delayedLookupNameCall!)
        }
    }

    /**
     Make an address lookup request to the daemon
    */
    func lookupAddress(withAccount account: String, nameserver: String, address: String) {
        self.nameRegistrationAdapter.lookupAddress(withAccount: account, nameserver: nameserver, address: address)
    }

    /**
     Register the username into the the blockchain
     */
    func registerName(withAccount account: String, password: String, name: String) {
        self.nameRegistrationAdapter.registerName(withAccount: account, password: password, name: name)
    }

    // MARK: NameService delegate

    internal func registeredNameFound(with response: LookupNameResponse) {

        if response.state == .notFound {
            usernameValidationStatus.onNext(.valid)
        } else if response.state == .found {
            usernameValidationStatus.onNext(.alreadyTaken)
        } else if response.state == .invalidName {
            usernameValidationStatus.onNext(.invalid)
        } else {
            log.error("Lookup name error")
        }

        usernameLookupStatus.onNext(response)
    }

    internal func nameRegistrationEnded(with response: NameRegistrationResponse) {
        if response.state == .success {
            log.debug("Registred name : \(response.name)")
        } else {
            log.debug("Name Registration failed. State = \(response.state.rawValue)")
        }
    }
}
