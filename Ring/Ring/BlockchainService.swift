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

class BlockchainService: BlockchainAdapterDelegate {

    init(withBlockchainAdapter blockchainAdapter: BlockchainAdapter) {
        self.blockchainAdapter = blockchainAdapter
        BlockchainAdapter.delegate = self
    }

    fileprivate let disposebag = DisposeBag()

    /**
     Used to make lookup name request to the daemon
    */
    fileprivate let blockchainAdapter :BlockchainAdapter

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
            self.blockchainAdapter.lookupName(withAccount: account, nameserver: nameserver, name: name)
        }
    }

    /**
     Register the username into the the blockchain
     */
    func registerName(withAccount account: String, password: String, name: String) {
        self.blockchainAdapter.registerName(withAccount: account, password: password, name: name)
    }

    //MARK: BlockchainService delegate

    internal func registeredNameFoundWithResponse(_ response: BlockchainResponse) {

        /* If the username is available, the daemon returns an error
         to indicate that the name is not found in the blockchain
         */

        if response.state == .error {
            usernameValidationStatus.onNext(.valid)
        } else if response.state == .found {
            usernameValidationStatus.onNext(.alreadyTaken)
        } else {
            usernameValidationStatus.onNext(.invalid)
        }
    }

    internal func nameRegistrationEndedWithResponse(_ response: BlockchainResponse) {
        print("Name Registration ended. State = \(response.state.rawValue)")
    }
}
