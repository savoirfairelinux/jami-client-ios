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

class CallsService: CallsAdapterDelegate {

    fileprivate let disposeBag = DisposeBag()
    fileprivate let callsAdapter: CallsAdapter
    fileprivate let log = SwiftyBeaver.self

    var currentAccount: AccountModel?
    var accounts: [AccountModel]?

    init(withCallsAdapter callsAdapter: CallsAdapter) {
        self.callsAdapter = callsAdapter
        CallsAdapter.delegate = self
    }

    func setCurrentAccount(currentAccount: AccountModel) {
        self.currentAccount = currentAccount
        self.loadCalls()
    }

    func setAccounts(accounts: [AccountModel]) {
        self.accounts = accounts
    }

    fileprivate func loadCalls() {
        //TODO: Implement

        //callDetailsWithCallId:(NSString*)callId;
        //calls;
    }

    func accept(call: CallModel) -> Observable<Void> {
        return Observable.just() //TODO: Implement
    }

    func refuse(call: CallModel) -> Observable<Void> {
        return Observable.just() //TODO: Implement
    }

    func hangUp(call: CallModel) -> Observable<Void> {
        return Observable.just() //TODO: Implement
    }

    func hold(call: CallModel) -> Observable<Void> {
        return Observable.just() //TODO: Implement
    }

    func unhold(call: CallModel) -> Observable<Void> {
        return Observable.just() //TODO: Implement
    }

    func placeCall(toContact contact: ContactModel) -> Observable<CallModel> {
         //TODO: Implement
        return Observable.just(CallModel(withCallId: "",
                                         dateReceived: Date(),
                                         duration: 0,
                                         from: ContactModel(withRingId: "")))
    }

    // MARK: CallsAdapterDelegate

    func didChangeCallState(withCallId callId: String, state: String, errorCode: NSInteger) {
        DispatchQueue.main.async {
            self.log.debug("didChangeCallState withCallId: \(callId) state: \(state) errorCode: \(errorCode)")
        }
    }

    func didReceiveMessage(withCallId callId: String, fromURI uri: String, message: [String : String]) {
        DispatchQueue.main.async {
            self.log.debug("didReceiveMessage withCallId: \(callId) fromURI: \(uri) message: \(message)")
        }
    }

    func receivingCall(withAccountId accountId: String, callId: String, fromURI uri: String) {
        DispatchQueue.main.async {
            self.log.debug("receivingCall withAccountId: \(accountId) callId: \(callId) fromURI: \(uri)")
        }
    }
}
