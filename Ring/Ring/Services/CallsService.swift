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

enum ConferenceState: String {
    case conferenceCreated
    case conferenceDestroyed
}

enum MediaType: String, CustomStringConvertible {
    case audio = "MEDIA_TYPE_AUDIO"
    case video = "MEDIA_TYPE_VIDEO"

    var description: String {
        return self.rawValue
    }
}
// swiftlint:disable type_body_length
// swiftlint:disable file_length
class CallsService: CallsAdapterDelegate {
    fileprivate let disposeBag = DisposeBag()
    fileprivate let callsAdapter: CallsAdapter
    fileprivate let log = SwiftyBeaver.self

    var calls = Variable<[String: CallModel]>([String: CallModel]())
    var pendingConferences = [String: Set<String>]()

    fileprivate let ringVCardMIMEType = "x-ring/ring.profile.vcard;"

    let currentCallsEvents = ReplaySubject<CallModel>.create(bufferSize: 1)
    let newCall = Variable<CallModel>(CallModel(withCallId: "", callDetails: [:]))
    fileprivate let responseStream = PublishSubject<ServiceEvent>()
    var sharedResponseStream: Observable<ServiceEvent>
    fileprivate let newMessagesStream = PublishSubject<ServiceEvent>()
    var newMessage: Observable<ServiceEvent>
    let dbManager: DBManager
    typealias ConferenceUpdates = (conferenceID: String, state: String, calls: Set<String>)
    let currentConferenceEvent: Variable<ConferenceUpdates> = Variable<ConferenceUpdates>(ConferenceUpdates("", "", Set<String>()))
    let inConferenceCalls = PublishSubject<CallModel>()

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

    func currentCall(callId: String) -> Observable<CallModel> {
        return self.currentCallsEvents
            .share()
            .filter { (call) -> Bool in
                call.callId == callId
        }.asObservable()
    }

    func currentConference(callId: String) -> Observable<ConferenceUpdates> {
        return self.currentConferenceEvent
        .asObservable()
            .share()
            .filter { (conference) -> Bool in
                guard let conf = self.calls.value[conference.conferenceID] else {return false}
                return conf.participantsCallId.contains(callId)
        }.asObservable()
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
        return self.calls.value[callID]
    }

    func call(participantHash: String, accountID: String) -> CallModel? {
        return self.calls
            .value.values
            .filter { (callModel) -> Bool in
                callModel.paricipantHash() == participantHash &&
                    callModel.accountId == accountID
        }.first
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

    func joinConference(confID: String, callID: String) {
        guard let secondConf = self.call(callID: callID) else { return }
        if let pending = self.pendingConferences[confID], !pending.isEmpty {
            self.pendingConferences[confID]!.insert(callID)
        } else {
            self.pendingConferences[confID] = [callID]
        }
        if secondConf.participantsCallId.count == 1 {
            self.callsAdapter.joinConference(confID, call: callID)
        } else {
            self.callsAdapter.joinConferences(confID, secondConference: callID)
        }
    }

    func joinCall(firstCall: String, secondCall: String) {
        if let pending = self.pendingConferences[firstCall], !pending.isEmpty {
            self.pendingConferences[firstCall]!.insert(secondCall)
        } else {
            self.pendingConferences[firstCall] = [secondCall]
        }
        self.callsAdapter.joinCall(firstCall, second: secondCall)
    }

    func callAndAddParticipant(participant contactId: String,
                               toCall callId: String,
                               withAccount account: AccountModel,
                               userName: String,
                               isAudioOnly: Bool = false) -> Observable<CallModel> {
        let palceCall = self.placeCall(withAccount: account, toRingId: contactId, userName: userName, isAudioOnly: isAudioOnly).asObservable().publish()
        palceCall
            .subscribe(onNext: { (callModel) in
                self.inConferenceCalls.onNext(callModel)
                if let pending = self.pendingConferences[callId], !pending.isEmpty {
                    self.pendingConferences[callId]!.insert(callModel.callId)
                } else {
                    self.pendingConferences[callId] = [callModel.callId]
                }
            })
            .disposed(by: self.disposeBag)
        palceCall.connect().disposed(by: self.disposeBag)
        return palceCall
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
            var success: Bool
                success = self.callsAdapter.hangUpCall(withId: callId)
            if success {
                completable(.completed)
            } else {
                completable(.error(CallServiceError.hangUpCallFailed))
            }
            return Disposables.create { }
        })
    }

    func hangUpCallOrConference(callId: String) -> Completable {
            return Completable.create(subscribe: { completable in
                guard let call = self.call(callID: callId) else {
                    completable(.error(CallServiceError.hangUpCallFailed))
                    return Disposables.create { }
                }
                var success: Bool
                if call.participantsCallId.count < 2 {
                    success = self.callsAdapter.hangUpCall(withId: callId)
                } else {
                    success =  self.callsAdapter.hangUpConference(callId)
                }
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
                call.participantsCallId.removeAll()
                call.participantsCallId.insert(callId)
                self.currentCallsEvents.onNext(call)
                self.calls.value[callId] = call
                self.calls.value = self.calls.value
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
        for call in self.calls.value.values where call.state == .current {
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

    func sendTextMessage(callID: String, message: String, accountId: AccountModel) {
        guard let call = self.call(callID: callID) else {return}
        let messageDictionary = ["text/plain": message]
        self.callsAdapter.sendTextMessage(withCallID: callID,
                                          message: messageDictionary,
                                          accountId: accountId.id,
                                          sMixed: true)
        let accountHelper = AccountModelHelper(withAccount: accountId)
        let type = accountHelper.isAccountSip() ? URIType.sip : URIType.ring
        let contactUri = JamiURI.init(schema: type, infoHach: call.participantUri, account: accountId)
        guard let stringUri = contactUri.uriString else {
            return
        }
        if let uri = accountHelper.uri {
            var event = ServiceEvent(withEventType: .newOutgoingMessage)
            event.addEventInput(.content, value: message)
            event.addEventInput(.peerUri, value: stringUri)
            event.addEventInput(.accountId, value: accountId.id)
            event.addEventInput(.accountUri, value: uri)

            self.newMessagesStream.onNext(event)
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
            var call = self.calls.value[callId]
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
                self.currentCallsEvents.onNext(finichedCall)
                self.calls.value[callId] = nil
                self.calls.value = self.calls.value
                // clear pending conferences if need
                if self.pendingConferences.keys.contains(callId) {
                    self.pendingConferences[callId] = nil
                }
                if let confId = shouldCallBeAddedToConference(callId: callId),
                    var pendingCalls = self.pendingConferences[confId],
                    let index = pendingCalls.firstIndex(of: callId) {
                    pendingCalls.remove(at: index)
                    if pendingCalls.isEmpty {
                        self.pendingConferences[confId] = nil
                    } else {
                        self.pendingConferences[confId] = pendingCalls
                    }
                }
                self.updateConferences(callId: callId)
                return
            }
            if call == nil {
                call = CallModel(withCallId: callId, callDetails: callDictionary)
                self.calls.value[callId] = call
                self.calls.value = self.calls.value
            } else {
                call?.update(withDictionary: callDictionary)
            }
            guard let newCall = call else { return }
            //send vCard
            if (newCall.state == .ringing && newCall.callType == .outgoing) ||
                (newCall.state == .current && newCall.callType == .incoming) {
                self.sendVCard(callID: callId, accountID: newCall.accountId)
            }

            if newCall.state == .current {
                if let confId = shouldCallBeAddedToConference(callId: callId) {
                    let seconds = 1.0
                    if let pendingCall = self.call(callID: confId) {
                        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
                            if pendingCall.participantsCallId.count == 1 {
                                self.callsAdapter.joinCall(confId, second: callId)
                            } else {
                                self.callsAdapter.joinConference(confId, call: callId)
                            }
                        }
                    }
                }
            }

            //Emit the call to the observers
            self.currentCallsEvents.onNext(newCall)
        }
    }

    func shouldCallBeAddedToConference(callId: String) -> String? {
        var confId: String?
        self.pendingConferences.keys.forEach { [unowned self] (initialCall) in
            guard let pendigs = self.pendingConferences[initialCall],
                !pendigs.isEmpty else {
                    return
            }
            if pendigs.contains(callId) {
                confId = initialCall
            }
        }
        return confId
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
                var call = self.calls.value[callId]
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
        for call in self.calls.value.values {
            if call.state == .current || call.state == .hold ||
                call.state == .unhold || call.state == .ringing {
                return true
            }
        }
        return false
    }

    func callPlacedOnHold(withCallId callId: String, holding: Bool) {
        guard let call = self.calls.value[callId] else {
            return
        }
        call.peerHolding = holding
        self.currentCallsEvents.onNext(call)
    }

    func audioMuted(call callId: String, mute: Bool) {
        guard let call = self.calls.value[callId] else {
            return
        }
        call.audioMuted = mute
        self.currentCallsEvents.onNext(call)
    }

    func videoMuted(call callId: String, mute: Bool) {
        guard let call = self.calls.value[callId] else {
            return
        }
        call.videoMuted = mute
        self.currentCallsEvents.onNext(call)
    }

    func conferenceCreated(conference conferenceID: String) {
        let conferenceCalls = Set(self.callsAdapter
            .getConferenceCalls(conferenceID))
        self.pendingConferences.forEach { pending in
            if !conferenceCalls.contains(pending.key) ||
                conferenceCalls.isDisjoint(with: pending.value) {
                return
            }
            let callId = pending.key
            var values = pending.value
            //update pending conferences
            //replace callID by new Conference ID, and remove calls that was already added to onference
            values.subtract(conferenceCalls)
            self.pendingConferences[callId] = nil
            if !values.isEmpty {
                self.pendingConferences[conferenceID] = values
            }
            // update calls and add conference
            self.call(callID: callId)?.participantsCallId = conferenceCalls
            values.forEach { (call) in
                self.call(callID: call)?.participantsCallId = conferenceCalls
            }
            guard var callDetails = self.callsAdapter.getConferenceDetails(conferenceID) else {return}
           // var callDetails = [String: String]()
            callDetails[CallDetailKey.accountIdKey.rawValue] = self.call(callID: callId)?.accountId
            callDetails[CallDetailKey.audioOnlyKey.rawValue] = self.call(callID: callId)?.isAudioOnly.toString()
            let conf = CallModel(withCallId: conferenceID, callDetails: callDetails)
            conf.participantsCallId = conferenceCalls
            self.calls.value[conferenceID] = conf
            self.calls.value = self.calls.value
            currentConferenceEvent.value = ConferenceUpdates(conferenceID, ConferenceState.conferenceCreated.rawValue, conferenceCalls)
        }
    }

    func conferenceChanged(conference conferenceID: String, state: String) {
        guard let conference = self.call(callID: conferenceID) else {return}
        let conferenceCalls = Set(self.callsAdapter
            .getConferenceCalls(conferenceID))
        conference.participantsCallId = conferenceCalls
        conferenceCalls.forEach { (callId) in
            guard let call = self.call(callID: callId) else { return }
            call.participantsCallId = conferenceCalls
            self.calls.value[callId] = call
        }
    }

    func conferenceRemoved(conference conferenceID: String) {
        guard let conference = self.call(callID: conferenceID) else {return}
        currentConferenceEvent.value = ConferenceUpdates(conferenceID, ConferenceState.conferenceDestroyed.rawValue, conference.participantsCallId)
        self.calls.value[conferenceID] = nil
     }

    func updateConferences(callId: String) {
        let conferences = self.calls.value.keys.filter { (callID) -> Bool in
            guard let callModel = self.calls.value[callID] else {return false}
            return callModel.participantsCallId.count > 1 && callModel.participantsCallId.contains(callId)
        }

        guard let conferenceID = conferences.first, let conference = call(callID: conferenceID) else {return}
        let conferenceCalls = Set(self.callsAdapter
                  .getConferenceCalls(conferenceID))
        conference.participantsCallId = conferenceCalls
        conferenceCalls.forEach { (callID) in
            self.call(callID: callID)?.participantsCallId = conferenceCalls
        }
    }
}
