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

enum CallServiceError: Error {
    case acceptCallFailed
    case refuseCallFailed
    case hangUpCallFailed
    case holdCallFailed
    case unholdCallFailed
    case placeCallFailed
}

class CallsService: CallsAdapterDelegate {

    fileprivate let disposeBag = DisposeBag()
    fileprivate let callsAdapter: CallsAdapter
    fileprivate let log = SwiftyBeaver.self
    fileprivate var calls = [String: CallModel]()
    //fileprivate var messages = [String: Data] //Serialized data from messages...

    var currentAccount: AccountModel?
    let incomingCall = ReplaySubject<CallModel>.create(bufferSize: 1)
    //let receivedMessage: Observable<CNContact>

    init(withCallsAdapter callsAdapter: CallsAdapter) {
        self.callsAdapter = callsAdapter
        CallsAdapter.delegate = self
    }

    func setCurrentAccount(currentAccount: AccountModel) {
        self.currentAccount = currentAccount
    }

    func accept(call: CallModel) -> Completable {
        return Completable.create(subscribe: { completable in
            let success = self.callsAdapter.acceptCall(withId: call.callId)
            if success {
                completable(.completed)
            } else {
                completable(.error(CallServiceError.acceptCallFailed))
            }
            return Disposables.create { }
        })
    }

    func refuse(call: CallModel) -> Completable {
        return Completable.create(subscribe: { completable in
            let success = self.callsAdapter.refuseCall(withId: call.callId)
            if success {
                completable(.completed)
            } else {
                completable(.error(CallServiceError.refuseCallFailed))
            }
            return Disposables.create { }
        })
    }

    func hangUp(call: CallModel) -> Completable {
        return Completable.create(subscribe: { completable in
            let success = self.callsAdapter.hangUpCall(withId: call.callId)
            if success {
                completable(.completed)
            } else {
                completable(.error(CallServiceError.hangUpCallFailed))
            }
            return Disposables.create { }
        })
    }

    func hold(call: CallModel) -> Completable {
        return Completable.create(subscribe: { completable in
            let success = self.callsAdapter.holdCall(withId: call.callId)
            if success {
                completable(.completed)
            } else {
                completable(.error(CallServiceError.holdCallFailed))
            }
            return Disposables.create { }
        })
    }

    func unhold(call: CallModel) -> Completable {
        return Completable.create(subscribe: { completable in
            let success = self.callsAdapter.unholdCall(withId: call.callId)
            if success {
                completable(.completed)
            } else {
                completable(.error(CallServiceError.unholdCallFailed))
            }
            return Disposables.create { }
        })
    }

    func placeCall(toContact contact: ContactModel) -> Single<CallModel> {
        return Single<CallModel>.create(subscribe: { single in
            if let currentAccount = self.currentAccount {
                if let callId = self.callsAdapter.placeCall(withAccountId: currentAccount.id,
                                                            toRingId: contact.ringId),
                    let callDictionary = self.callsAdapter.callDetails(withCallId: callId) {
                    let call = CallModel(withCallId: "", valuesFromDictionary: callDictionary)
                    single(.success(call))
                } else {
                    single(.error(CallServiceError.placeCallFailed))
                }
            } else {
                single(.error(CallServiceError.placeCallFailed))
            }
            return Disposables.create { }
        })
    }

    // MARK: CallsAdapterDelegate

    func didChangeCallState(withCallId callId: String, state: String, errorCode: NSInteger) {

        if errorCode != 0 {
            //TODO: throw error
        }

        if let callDictionary = self.callsAdapter.callDetails(withCallId: callId) {

            //Add or update new call
            var call = self.calls[callId]
            if call == nil {
                call = CallModel(withCallId: callId, valuesFromDictionary: callDictionary)
            } else {
                call?.update(withDictionary: callDictionary)
            }

            //Update the state
            call?.state = CallState(rawValue: state)!

            //Emit the call to the observers
            self.incomingCall.onNext(call!)

            //Remove from the cache if the call is over
            if call?.state == .over {
                self.calls[callId] = nil
            }
        }

        DispatchQueue.main.async {
            self.log.debug("didChangeCallState withCallId: \(callId) state: \(state) errorCode: \(errorCode)")
        }
    }

    func didReceiveMessage(withCallId callId: String, fromURI uri: String, message: [String : String]) {

        //TODO: Serialize the vCard...

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
