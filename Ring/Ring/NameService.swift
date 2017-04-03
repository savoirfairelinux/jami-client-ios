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

import UIKit
import RxSwift

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

    init(withNameRegistrationAdapter nameRegistrationAdapter: NameRegistrationAdapter) {
        self.nameRegistrationAdapter = nameRegistrationAdapter
        NameRegistrationAdapter.delegate = self
    }

    /**
     Used to make lookup name request to the daemon
    */
    fileprivate let nameRegistrationAdapter :NameRegistrationAdapter

    /**
     Status of the current username lookup request
     */
    var usernameValidationStatus = PublishSubject<UsernameValidationStatus>()

    /**
    Make a username lookup request to the daemon
     */
    func lookupName(withAccount account: String, nameserver: String, name: String) {

        if name.isEmpty {
            usernameValidationStatus.onNext(.empty)
        } else {
            usernameValidationStatus.onNext(.lookingUp)
            self.nameRegistrationAdapter.lookupName(withAccount: account, nameserver: nameserver, name: name)
        }
    }

    /**
     Register the username into the the blockchain
     */
    func registerName(withAccount account: String, password: String, name: String) {
        self.nameRegistrationAdapter.registerName(withAccount: account, password: password, name: name)
    }

    //MARK: NameService delegate

    internal func registeredNameFound(with response: LookupNameResponse) {

        if response.state == .notFound {
            usernameValidationStatus.onNext(.valid)
        } else if response.state == .found {
            usernameValidationStatus.onNext(.alreadyTaken)
        } else if response.state == .invalidName {
            usernameValidationStatus.onNext(.invalid)
        } else {
            print("Lookup name error")
        }
    }

    internal func nameRegistrationEnded(with response: NameRegistrationResponse) {
        if response.state == .success {
            print("Registred name : \(response.name)")
        } else {
            print("Name Registration failed. State = \(response.state.rawValue)")
        }
    }
}
