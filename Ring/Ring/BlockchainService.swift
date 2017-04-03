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

    fileprivate let disposebag = DisposeBag()

    /** 
     Used to make lookup name request to the daemon
    */
    fileprivate let blockchainAdapter = BlockchainAdapter.sharedManager()

    /**
     Used to observe the lookup name response from the daemon
     */
    fileprivate let lookupNameState = PublishSubject<LookupNameState>()

    init() {
        self.blockchainAdapter?.delegate = self
    }

    /**
    Make a username lookup request to the daemon
     */

    func lookupName(with account: String, nameserver: String, name: String) {
        blockchainAdapter?.lookupName(withAccount: account, nameserver: nameserver, name: name)
    }

    /**
     Returns an Observable that send the state of the username validation request to the user
     or just an empty string if the field is empty or the username is valid
     */

    func usernameValidation(username: String) -> Observable<UsernameValidationStatus> {

        if username.isEmpty {
            return Observable.just(.empty)
        }

        //Observes the request to the BlockchainService
        let blockchainRequest = Observable<UsernameValidationStatus>.create({ [unowned self] observer in
            self.lookupNameState.subscribe(onNext: { state in
                if state == .found {
                    observer.onNext(.alreadyTaken)
                } else if state == .invalidName {
                    observer.onNext(.invalid)
                } else {
                    observer.onNext(.valid)
                }
                observer.onCompleted()
            }).addDisposableTo(self.disposebag)

            //Request the blockchain with username
            self.blockchainAdapter?.lookupName(withAccount: "", nameserver: "", name: username)
            observer.onNext(.lookingUp)

            return Disposables.create()
        })

        return blockchainRequest
    }


    //MARK: BlockchainService delegate

    func registeredNameFound(with accountId: String, state: LookupNameState ,address: String,name: String) {
        if state == .found {
            self.lookupNameState.onNext(.found)
        } else if state == .invalidName {
            self.lookupNameState.onNext(.invalidName)
        } else {
            self.lookupNameState.onNext(.error)
        }
    }
}
