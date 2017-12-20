/*
 *  Copyright (C) 2017 Savoir-faire Linux Inc.
 *
 *  Author: Silbino Gonçalves Matado <silbino.gmatado@savoirfairelinux.com>
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
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
import Contacts

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
    fileprivate var base64VCard = [Int: String]() //The key is the vCard part number...
    fileprivate let ringVCardMIMEType = "x-ring/ring.profile.vcard"

    let currentCall = ReplaySubject<CallModel>.create(bufferSize: 1)
    let newIncomingCall = Variable<CallModel>(CallModel(withCallId: "", callDetails: [:]))
    let receivedVCard = PublishSubject<CNContact>()

    init(withCallsAdapter callsAdapter: CallsAdapter) {
        self.callsAdapter = callsAdapter
        CallsAdapter.delegate = self
    }

    func accept(callId: String) -> Completable {
        return Completable.create(subscribe: { completable in
            let success = self.callsAdapter.acceptCall(withId: callId)
            if success {
                completable(.completed)
            } else {
                completable(.error(CallServiceError.acceptCallFailed))
            }
            return Disposables.create { }
        })
    }

    func refuse(callId: String) -> Completable {
        return Completable.create(subscribe: { completable in
            let success = self.callsAdapter.refuseCall(withId: callId)
            if success {
                completable(.completed)
            } else {
                completable(.error(CallServiceError.refuseCallFailed))
            }
            return Disposables.create { }
        })
    }

    func hangUp(callId: String) -> Completable {
        return Completable.create(subscribe: { completable in
            let success = self.callsAdapter.hangUpCall(withId: callId)
            if success {
                completable(.completed)
            } else {
                completable(.error(CallServiceError.hangUpCallFailed))
            }
            return Disposables.create { }
        })
    }

    func hold(callId: String) -> Completable {
        return Completable.create(subscribe: { completable in
            let success = self.callsAdapter.holdCall(withId: callId)
            if success {
                completable(.completed)
            } else {
                completable(.error(CallServiceError.holdCallFailed))
            }
            return Disposables.create { }
        })
    }

    func unhold(callId: String) -> Completable {
        return Completable.create(subscribe: { completable in
            let success = self.callsAdapter.unholdCall(withId: callId)
            if success {
                completable(.completed)
            } else {
                completable(.error(CallServiceError.unholdCallFailed))
            }
            return Disposables.create { }
        })
    }

    func placeCall(withAccount account: AccountModel, toRingId ringId: String, userName: String) -> Single<CallModel> {

        //Create and emit the call
        let call = CallModel(withCallId: ringId, callDetails: [String: String]())
        call.state = .connecting
        call.registeredName = userName
        return Single<CallModel>.create(subscribe: { single in
            if let callId = self.callsAdapter.placeCall(withAccountId: account.id,
                                                        toRingId: "ring:\(ringId)"),
                let callDictionary = self.callsAdapter.callDetails(withCallId: callId) {
                call.update(withDictionary: callDictionary)
                call.callId = callId
                self.currentCall.onNext(call)
                self.calls[callId] = call
                single(.success(call))
            } else {
                single(.error(CallServiceError.placeCallFailed))
            }
            return Disposables.create { }
        })
    }

    // MARK: CallsAdapterDelegate

    func didChangeCallState(withCallId callId: String, state: String, stateCode: NSInteger) {

        if let callDictionary = self.callsAdapter.callDetails(withCallId: callId) {

            //Add or update new call
            var call = self.calls[callId]
            if call == nil {
                call = CallModel(withCallId: callId, callDetails: callDictionary)
                self.calls[callId] = call
            } else {
                call?.update(withDictionary: callDictionary)
            }

            //Update the call
            call?.state = CallState(rawValue: state)!

            //Emit the call to the observers
            self.currentCall.onNext(call!)

            //Remove from the cache if the call is over
            if call?.state == .over {
                // TODO save history
                self.calls[callId] = nil
            }
        }
    }

    func didReceiveMessage(withCallId callId: String, fromURI uri: String, message: [String: String]) {

        if let vCardKey = message.keys.filter({ $0.hasPrefix(self.ringVCardMIMEType) }).first {

            //Parse the key to get the number of parts and the current part number
            let components = vCardKey.components(separatedBy: ",")

            guard let partComponent = components.filter({$0.hasPrefix("part=")}).first else {
                return
            }

            guard let ofComponent = components.filter({$0.hasPrefix("of=")}).first else {
                return
            }

            let part = Int(partComponent.components(separatedBy: "=")[1])
            let of = Int(ofComponent.components(separatedBy: "=")[1])

            self.base64VCard[part!] = message[vCardKey]

            //Emit the vCard when all data are appended
            if of == part {

                //Append data from sorted part numbers
                var vCardData = Data()
                for currentPartNumber in self.base64VCard.keys.sorted() {
                    if let currentData = self.base64VCard[currentPartNumber]?.data(using: String.Encoding.utf8) {
                        vCardData.append(currentData)
                    }
                }

                //Create the vCard and emit it or throw an error
                do {
                    if let vCard = try CNContactVCardSerialization.contacts(with: vCardData).first {
                        self.receivedVCard.onNext(vCard)
                    }
                } catch {
                    self.receivedVCard.onError(error)
                }
            }
        }
    }

    func receivingCall(withAccountId accountId: String, callId: String, fromURI uri: String) {
        if let callDictionary = self.callsAdapter.callDetails(withCallId: callId) {

            //Add or update new call
            var call = self.calls[callId]
            if call == nil {
                call = CallModel(withCallId: callId, callDetails: callDictionary)
            } else {
                call?.update(withDictionary: callDictionary)
            }
            //Emit the call to the observers
            self.newIncomingCall.value = call!
        }

    }

    func newCallStarted(withAccountId accountId: String, callId: String, toURI uri: String) {

    }

    func callPlacedOnHold(withCallId callId: String, holding: Bool) {

    }

    func muteAudio(call callId: String, mute: Bool) {

    }

    func muteVideo(call callId: String, mute: Bool) {

    }
}
