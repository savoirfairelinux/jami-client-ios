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

enum MediaType: String, CustomStringConvertible {
    case audio = "MEDIA_TYPE_AUDIO"
    case video = "MEDIA_TYPE_VIDEO"

    var description: String {
        return self.rawValue
    }
}

struct Base64VCard {
    var data: [Int: String] //The key is the number of vCard part
    var partsReceived: Int
}

class CallsService: CallsAdapterDelegate {

    fileprivate let disposeBag = DisposeBag()
    fileprivate let callsAdapter: CallsAdapter
    fileprivate let log = SwiftyBeaver.self

    fileprivate var calls = [String: CallModel]()

    fileprivate var base64VCards = [Int: Base64VCard]() //The key is the vCard id
    fileprivate let ringVCardMIMEType = "x-ring/ring.profile.vcard;"

    let currentCall = ReplaySubject<CallModel>.create(bufferSize: 1)
    let newCall = Variable<CallModel>(CallModel(withCallId: "", callDetails: [:]))
    let dbManager = DBManager(profileHepler: ProfileDataHelper(), conversationHelper: ConversationDataHelper(), interactionHepler: InteractionDataHelper())
    fileprivate let responseStream = PublishSubject<ServiceEvent>()
    var sharedResponseStream: Observable<ServiceEvent>

    init(withCallsAdapter callsAdapter: CallsAdapter) {
        self.callsAdapter = callsAdapter
        self.responseStream.disposed(by: disposeBag)
        self.sharedResponseStream = responseStream.share()
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

    func placeCall(withAccount account: AccountModel,
                   toRingId ringId: String,
                   userName: String,
                   isAudioOnly: Bool = false) -> Single<CallModel> {

        //Create and emit the call
        var callDetails = [String: String]()
        callDetails[CallDetailKey.callTypeKey.rawValue] = String(describing: CallType.outgoing)
        callDetails[CallDetailKey.displayNameKey.rawValue] = userName
        callDetails[CallDetailKey.accountIdKey.rawValue] = account.id
        callDetails[CallDetailKey.audioOnlyKey.rawValue] = isAudioOnly.toString()
        let call = CallModel(withCallId: ringId, callDetails: callDetails)
        call.state = .connecting
        return Single<CallModel>.create(subscribe: { [unowned self] single in
            if let callId = self.callsAdapter.placeCall(withAccountId: account.id,
                                                        toRingId: "ring:\(ringId)",
                                                        details: callDetails),
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

    func muteAudio(call callId: String, mute: Bool) {
        self.callsAdapter
            .muteMedia(callId,
                       mediaType: String(describing: MediaType.audio),
                       muted: mute)
    }

    func muteVideo(call callId: String, mute: Bool) {
        self.callsAdapter
            .muteMedia(callId,
                       mediaType: String(describing: MediaType.video),
                       muted: mute)
    }

    func sendVCard(callID: String, accountID: String) {
        if accountID.isEmpty || callID.isEmpty {
            return
        }
        VCardUtils.loadVCard(named: VCardFiles.myProfile.rawValue,
                             inFolder: VCardFolders.profile.rawValue)
            .subscribe(onSuccess: { [unowned self] card in
                VCardUtils.sendVCard(card: card,
                                     callID: callID,
                                     accountID: accountID,
                                     sender: self)
            }).disposed(by: disposeBag)
    }

    func sendChunk(callID: String, message: [String: String], accountId: String) {
        self.callsAdapter.sendTextMessage(withCallID: callID,
                                          message: message,
                                          accountId: accountId,
                                          sMixed: true)
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

            //send vCard
            if (call?.state == .ringing && call?.callType == .outgoing) ||
                (call?.state == .current && call?.callType == .incoming) {
                let accountID = call?.accountId
                self.sendVCard(callID: callId, accountID: accountID!)
            }

            //Emit the call to the observers
            self.currentCall.onNext(call!)

            //Remove from the cache if the call is over
            if call?.state == .over {
                // TODO save history
                self.calls[callId] = nil
            }
        }
    }

    // swiftlint:disable cyclomatic_complexity
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

            guard let idComponent = components.filter({$0.hasPrefix("x-ring/ring.profile.vcard;id=")}).first else {
                return
            }

            guard let part = Int(partComponent.components(separatedBy: "=")[1]) else {
                return
            }

            guard let of = Int(ofComponent.components(separatedBy: "=")[1]) else {
                return
            }

            guard let id = Int(idComponent.components(separatedBy: "=")[1]) else {
                return
            }
            var numberOfReceivedChunk = 1
            if var chunk = self.base64VCards[id] {
                chunk.data[part] = message[vCardKey]
                chunk.partsReceived += 1
                numberOfReceivedChunk = chunk.partsReceived
                self.base64VCards[id] = chunk
            } else {
                let partMessage = message[vCardKey]
                let data: [Int: String] = [part: partMessage!]
                let chunk = Base64VCard(data: data, partsReceived: numberOfReceivedChunk)
                self.base64VCards[id] = chunk
            }

            //Emit the vCard when all data are appended
            if of == numberOfReceivedChunk {
                guard let vcard = self.base64VCards[id] else {
                    return
                }

                let vCardChunks = vcard.data

                //Append data from sorted part numbers
                var vCardData = Data()
                for currentPartNumber in vCardChunks.keys.sorted() {
                    if let currentData = vCardChunks[currentPartNumber]?.data(using: String.Encoding.utf8) {
                        vCardData.append(currentData)
                    }
                }

                //Create the vCard, save and db and emite an event
                do {
                    if let vCard = try CNContactVCardSerialization.contacts(with: vCardData).first {
                        let name = VCardUtils.getName(from: vCard)
                        var stringImage: String?
                        if let image = vCard.imageData {
                            stringImage = image.base64EncodedString()
                        }
                        let uri = uri.replacingOccurrences(of: "@ring.dht", with: "")
                        _ = self.dbManager
                            .createOrUpdateRingProfile(profileUri: uri,
                                                       alias: name,
                                                       image: stringImage,
                                                       status: ProfileStatus.untrasted)
                        var event = ServiceEvent(withEventType: .profileUpdated)
                        event.addEventInput(.uri, value: uri)
                        self.responseStream.onNext(event)
                    }
                } catch {
                   self.log.error(error)
                }
            }
        }
    }
    // swiftlint:enable cyclomatic_complexity

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
            self.newCall.value = call!
        }
    }

    func newCallStarted(withAccountId accountId: String, callId: String, toURI uri: String) {
    }

    func callPlacedOnHold(withCallId callId: String, holding: Bool) {
        guard let call = self.calls[callId] else {
            return
        }
        call.peerHolding = holding
        self.currentCall.onNext(call)
    }

    func audioMuted(call callId: String, mute: Bool) {
        guard let call = self.calls[callId] else {
            return
        }
        call.audioMuted = mute
        self.currentCall.onNext(call)
    }

    func videoMuted(call callId: String, mute: Bool) {
        guard let call = self.calls[callId] else {
            return
        }
        call.videoMuted = mute
        self.currentCall.onNext(call)
    }
}
