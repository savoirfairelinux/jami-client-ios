/*
 *  Copyright (C) 2017-2019 Savoir-faire Linux Inc.
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

class CallsService: CallsAdapterDelegate {

    fileprivate let disposeBag = DisposeBag()
    fileprivate let callsAdapter: CallsAdapter
    fileprivate let log = SwiftyBeaver.self

    fileprivate var calls = [String: CallModel]()

    fileprivate let ringVCardMIMEType = "x-ring/ring.profile.vcard;"

    let currentCall = ReplaySubject<CallModel>.create(bufferSize: 1)
    let newCall = Variable<CallModel>(CallModel(withCallId: "", callDetails: [:]))
    fileprivate let responseStream = PublishSubject<ServiceEvent>()
    var sharedResponseStream: Observable<ServiceEvent>
    fileprivate let newMessagesStream = PublishSubject<ServiceEvent>()
    var newMessage: Observable<ServiceEvent>
    let dbManager: DBManager

    init(withCallsAdapter callsAdapter: CallsAdapter, dbManager: DBManager) {
        self.callsAdapter = callsAdapter
        self.responseStream.disposed(by: disposeBag)
        self.sharedResponseStream = responseStream.share()
        self.dbManager = dbManager
        newMessage = newMessagesStream.share()
        CallsAdapter.delegate = self
        NotificationCenter.default.addObserver(self, selector: #selector(self.refuseUnansweredCall(_:)),
                                               name: NSNotification.Name(rawValue: NotificationName.refuseCallFromNotifications.rawValue),
                                               object: nil)
    }

    func checkForIncomingCall() {
        if let call = self.call(callID: self.newCall.value.callId), call.state == .incoming {
            self.newCall.value = call
        }
    }

    @objc func refuseUnansweredCall(_ notification: NSNotification) {
        guard let callid = notification.userInfo?[NotificationUserInfoKeys.callID.rawValue] as? String else {
            return
        }
        guard let call = self.call(callID: callid) else {
            return
        }

        if call.state == .incoming {
            self.refuse(callId: callid).subscribe({_ in
                print("Call ignored")
            }).disposed(by: self.disposeBag)
        }
    }

    func call(callID: String) -> CallModel? {
        return self.calls[callID]
    }

    func accept(call: CallModel?) -> Completable {
        return Completable.create(subscribe: { completable in
            guard let callId = call?.callId else {
                completable(.error(CallServiceError.acceptCallFailed))
                return Disposables.create { }
            }
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
        callDetails[CallDetailKey.timeStampStartKey.rawValue] = ""
        let call = CallModel(withCallId: ringId, callDetails: callDetails)
        call.state = .unknown
        call.callType = .outgoing
        return Single<CallModel>.create(subscribe: { [unowned self] single in
            if let callId = self.callsAdapter.placeCall(withAccountId: account.id,
                                                        toRingId: ringId,
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

    func muteCurrentCallVideoVideo(mute: Bool) {
        for call in self.calls.values where call.state == .current {
                self.callsAdapter
                    .muteMedia(call.callId,
                               mediaType: String(describing: MediaType.video),
                               muted: mute)
                return
        }
    }

    func playDTMF(code: String) {
        self.callsAdapter.playDTMF(code)
    }

    func sendVCard(callID: String, accountID: String) {
        if accountID.isEmpty || callID.isEmpty {
            return
        }
        guard let accountProfile = self.dbManager.accountProfile(for: accountID) else {return}
        let vCard = CNMutableContact()
        var cardChanged = false
        if let name = accountProfile.alias {
            vCard.familyName = name
            cardChanged = true
        }
        if let photo = accountProfile.photo {
            vCard.imageData = NSData(base64Encoded: photo,
                                     options: NSData.Base64DecodingOptions.ignoreUnknownCharacters) as Data?
            cardChanged = true
        }
        if cardChanged {
            DispatchQueue.main.async { [unowned self] in
                VCardUtils.sendVCard(card: vCard,
                                     callID: callID,
                                     accountID: accountID,
                                     sender: self)
            }
        }
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
            call?.state = CallState(rawValue: state) ?? CallState.unknown
            //Remove from the cache if the call is over and save message to history
            if call?.state == .over || call?.state == .failure {
                guard let finichedCall = call else { return }
                var time = 0
                if let startTime = finichedCall.dateReceived {
                    time = Int(Date().timeIntervalSince1970 - startTime.timeIntervalSince1970)
                }
                var event = ServiceEvent(withEventType: .callEnded)
                event.addEventInput(.uri, value: finichedCall.participantUri)
                event.addEventInput(.accountId, value: finichedCall.accountId)
                event.addEventInput(.callType, value: finichedCall.callType.rawValue)
                event.addEventInput(.callTime, value: time)
                self.responseStream.onNext(event)
                self.currentCall.onNext(finichedCall)
                self.calls[callId] = nil
                return
            }
            if call == nil {
                call = CallModel(withCallId: callId, callDetails: callDictionary)
                self.calls[callId] = call
            } else {
                call?.update(withDictionary: callDictionary)
            }
            guard let newCall = call else { return }
            //send vCard
            if (newCall.state == .ringing && newCall.callType == .outgoing) ||
                (newCall.state == .current && newCall.callType == .incoming) {
                self.sendVCard(callID: callId, accountID: newCall.accountId)
            }

            //Emit the call to the observers
            self.currentCall.onNext(newCall)
        }
    }

    func didReceiveMessage(withCallId callId: String, fromURI uri: String, message: [String: String]) {
        guard let call = self.call(callID: callId) else {return}
        if  message.keys.filter({ $0.hasPrefix(self.ringVCardMIMEType) }).first != nil {
            var data = [String: Any]()
            data[ProfileNotificationsKeys.ringID.rawValue] = uri
            data[ProfileNotificationsKeys.accountId.rawValue] = call.accountId
            data[ProfileNotificationsKeys.message.rawValue] = message
            NotificationCenter.default.post(name: NSNotification.Name(ProfileNotifications.messageReceived.rawValue), object: nil, userInfo: data)
            return
        }
        let accountId = call.accountId
        let displayName = call.displayName
        let registeredName = call.registeredName
        let name = !displayName.isEmpty ? displayName : registeredName
        var event = ServiceEvent(withEventType: .newIncomingMessage)
        event.addEventInput(.content, value: message.values.first)
        event.addEventInput(.peerUri, value: uri.replacingOccurrences(of: "@ring.dht", with: ""))
        event.addEventInput(.name, value: name)
        event.addEventInput(.accountId, value: accountId)
        self.newMessagesStream.onNext(event)
    }
    // swiftlint:enable cyclomatic_complexity

    func receivingCall(withAccountId accountId: String, callId: String, fromURI uri: String) {
        if let callDictionary = self.callsAdapter.callDetails(withCallId: callId) {

            if !isCurrentCall() {
                var call = self.calls[callId]
                if call == nil {
                    call = CallModel(withCallId: callId, callDetails: callDictionary)
                } else {
                    call?.update(withDictionary: callDictionary)
                }
                //Emit the call to the observers
                guard let newCall = call else { return }
                self.newCall.value = newCall
            } else {
                self.refuse(callId: callId).subscribe(onCompleted: { [weak self] in
                    self?.log.debug("call refused")
                }, onError: { [weak self] _ in
                    self?.log.debug("Could not to refuse a call")
                }).disposed(by: self.disposeBag)
            }
        }
    }

    func isCurrentCall() -> Bool {
        for call in self.calls.values {
            if call.state == .current || call.state == .hold ||
                call.state == .unhold || call.state == .ringing {
                return true
            }
        }
        return false
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
