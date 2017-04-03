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

class BlockchainService: BlockchainAdapterDelegate {

    static let sharedInstance = BlockchainService()

    fileprivate let blockchainAdapter = BlockchainAdapter.sharedManager()

    fileprivate let responseStream = PublishSubject<ServiceEvent>()

    let sharedResponseStream: Observable<ServiceEvent>

    init() {

        //self.responseStream.addDisposableTo(disposeBag)

        sharedResponseStream = responseStream.share()

        self.blockchainAdapter?.delegate = self
    }

    func lookupName(with account: String, nameserver: String, name: String) {
        blockchainAdapter?.lookupName(withAccount: account, nameserver: nameserver, name: name)
    }

    //MARK: BlockchainService delegate

    func registeredNameFound(with accountId: String,state: LookupNameState,address: String,name: String) {

        var event = ServiceEvent.init(withEventType: .RegisterNameFound)
        if state == .Found {
            event.addEventInput(.LookupNameState, value: LookupNameState.Found)
        } else if state == .InvalidName {
            event.addEventInput(.LookupNameState, value: LookupNameState.InvalidName)
        } else {
            event.addEventInput(.LookupNameState, value: LookupNameState.Error)
        }
        self.responseStream.onNext(event)
    }
}
