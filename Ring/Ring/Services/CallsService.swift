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
import RxRelay
import SwiftyBeaver
import Contacts
import os

enum CallServiceError: Error {
    case acceptCallFailed
    case refuseCallFailed
    case hangUpCallFailed
    case holdCallFailed
    case unholdCallFailed
    case makeCallFailed
}

enum ConferenceState: String {
    case conferenceCreated
    case conferenceDestroyed
    case infoUpdated
}

enum MediaType: String, CustomStringConvertible {
    case audio = "MEDIA_TYPE_AUDIO"
    case video = "MEDIA_TYPE_VIDEO"

    var description: String {
        return self.rawValue
    }
}

typealias ConferenceUpdates = (conferenceID: String, state: String, calls: Set<String>)

// swiftlint:disable type_body_length
// swiftlint:disable file_length
class CallsService: CallsAdapterDelegate, VCardSender {
    private let disposeBag = DisposeBag()
    private let callsAdapter: CallsAdapter
    private let log = SwiftyBeaver.self

    var calls = BehaviorRelay<[String: CallModel]>(value: [String: CallModel]())
    var pendingConferences = [String: Set<String>]()
    var createdConferences = Set<String>() /// set of created conferences, waiting to calls to be attached

    private let ringVCardMIMEType = "x-ring/ring.profile.vcard;"

    let currentCallsEvents = ReplaySubject<CallModel>.create(bufferSize: 1)
    let newCall = BehaviorRelay<CallModel>(value: CallModel(withCallId: "", callDetails: [:], withMedia: [[:]]))
    private let responseStream = PublishSubject<ServiceEvent>()
    var sharedResponseStream: Observable<ServiceEvent>
    private let newMessagesStream = PublishSubject<ServiceEvent>()
    var newMessage: Observable<ServiceEvent>
    let dbManager: DBManager

    let currentConferenceEvent: BehaviorRelay<ConferenceUpdates> = BehaviorRelay<ConferenceUpdates>(value: ConferenceUpdates("", "", Set<String>()))
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
        self.calls.asObservable()
            .subscribe(onNext: { calls in
                if calls.isEmpty {
                    NotificationCenter.default.post(name: NSNotification.Name(NotificationName.restoreDefaultVideoDevice.rawValue), object: nil, userInfo: nil)
                }
            })
            .disposed(by: self.disposeBag)
    }

    func currentCall(callId: String) -> Observable<CallModel> {
        return self.currentCallsEvents
            .share()
            .filter { (call) -> Bool in
                call.callId == callId
            }
            .asObservable()
    }

    @objc
    func refuseUnansweredCall(_ notification: NSNotification) {
        guard let callId = notification.userInfo?[Constants.NotificationUserInfoKeys.callID.rawValue] as? String else {
            return
        }
        guard let call = self.call(callID: callId) else {
            return
        }

        if call.state == .incoming {
            self.refuse(callId: callId)
                .subscribe({_ in
                    print("Call ignored")
                })
                .disposed(by: self.disposeBag)
        }
    }

    func call(callID: String) -> CallModel? {
        return self.calls.value[callID]
    }

    func callByUUID(UUID: String) -> CallModel? {
        return self.calls.value.values.filter { call in
            call.callUUID.uuidString == UUID
        }.first
    }

    func getVideoCodec(call: CallModel) -> String? {
        let callDetails = self.callsAdapter.callDetails(withCallId: call.callId, accountId: call.accountId)
        return callDetails?[CallDetailKey.videoCodec.rawValue]
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
            let success = self.callsAdapter.acceptCall(withId: callId, accountId: call?.accountId, withMedia: call?.mediaList)
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
        guard let firstConf = self.call(callID: confID) else { return }
        if let pending = self.pendingConferences[confID], !pending.isEmpty {
            self.pendingConferences[confID]!.insert(callID)
        } else {
            self.pendingConferences[confID] = [callID]
        }
        if secondConf.participantsCallId.count == 1 {
            self.callsAdapter.joinConference(confID, call: callID, accountId: firstConf.accountId, account2Id: secondConf.accountId)
        } else {
            self.callsAdapter.joinConferences(confID, secondConference: callID, accountId: firstConf.accountId, account2Id: secondConf.accountId)
        }
    }

    func joinCall(firstCallId: String, secondCallId: String) {
        guard let firstCall = self.call(callID: firstCallId) else { return }
        guard let secondCall = self.call(callID: secondCallId) else { return }
        if let pending = self.pendingConferences[firstCallId], !pending.isEmpty {
            self.pendingConferences[firstCallId]!.insert(secondCallId)
        } else {
            self.pendingConferences[firstCallId] = [secondCallId]
        }
        self.callsAdapter.joinCall(firstCallId, second: secondCallId, accountId: firstCall.accountId, account2Id: secondCall.accountId)
    }

    func isParticipant(participantURI: String?, activeIn conferenceId: String, accountId: String) -> Bool? {
        guard let uri = participantURI,
              let participantsArray = self.callsAdapter.getConferenceInfo(conferenceId, accountId: accountId) as? [[String: String]] else { return nil }
        let participants = self.arrayToConferenceParticipants(participants: participantsArray, onlyURIAndActive: true)
        for participant in participants where participant.uri?.filterOutHost() == uri.filterOutHost() {
            return participant.isActive
        }
        return nil
    }

    private func arrayToConferenceParticipants(participants: [[String: String]], onlyURIAndActive: Bool) -> [ConferenceParticipant] {
        var conferenceParticipants = [ConferenceParticipant]()
        for participant in participants {
            conferenceParticipants.append(ConferenceParticipant(info: participant, onlyURIAndActive: onlyURIAndActive))
        }
        return conferenceParticipants
    }

    var conferenceInfos = [String: [ConferenceParticipant]]()

    func conferenceInfoUpdated(conference conferenceID: String, info: [[String: String]]) {
        let participants = self.arrayToConferenceParticipants(participants: info, onlyURIAndActive: false)
        self.conferenceInfos[conferenceID] = participants
        currentConferenceEvent.accept(ConferenceUpdates(conferenceID, ConferenceState.infoUpdated.rawValue, [""]))
    }

    func isModerator(participantId: String, inConference confId: String) -> Bool {
        let participants = self.conferenceInfos[confId]
        let participant = participants?.filter({ confParticipant in
            return confParticipant.uri?.filterOutHost() == participantId.filterOutHost()
        }).first
        return participant?.isModerator ?? false
    }

    func getConferenceParticipants(for conferenceId: String) -> [ConferenceParticipant]? {
        return conferenceInfos[conferenceId]
    }

    func setActiveParticipant(conferenceId: String, maximixe: Bool, jamiId: String) {
        guard let conference = self.call(callID: conferenceId),
              let isActive = self.isParticipant(participantURI: jamiId, activeIn: conferenceId, accountId: conference.accountId) else { return }
        let newLayout = isActive ? self.getNewLayoutForActiveParticipant(currentLayout: conference.layout, maximixe: maximixe) : .oneWithSmal
        conference.layout = newLayout
        self.callsAdapter.setActiveParticipant(jamiId, forConference: conferenceId, accountId: conference.accountId)
        self.callsAdapter.setConferenceLayout(newLayout.rawValue, forConference: conferenceId, accountId: conference.accountId)
    }

    private func getNewLayoutForActiveParticipant(currentLayout: CallLayout, maximixe: Bool) -> CallLayout {
        var newLayout = CallLayout.grid
        switch currentLayout {
        case .grid:
            newLayout = .oneWithSmal
        case .oneWithSmal:
            newLayout = maximixe ? .one : .grid
        case .one:
            newLayout = .oneWithSmal
        }
        return newLayout
    }

    func callAndAddParticipant(participant contactId: String,
                               toCall callId: String,
                               withAccount account: AccountModel,
                               userName: String,
                               videSource: String,
                               isAudioOnly: Bool = false) -> Observable<CallModel> {
        let call = self.calls.value[callId]
        let makeCall = self.makeCall(withAccount: account,
                                       toParticipantId: contactId,
                                       userName: userName,
                                       videoSource: videSource,
                                       isAudioOnly: isAudioOnly,
                                       withMedia: call?.mediaList ?? [[String: String]]())
            .asObservable()
            .publish()
        makeCall
            .subscribe(onNext: { (callModel) in
                self.inConferenceCalls.onNext(callModel)
                if let pending = self.pendingConferences[callId], !pending.isEmpty {
                    self.pendingConferences[callId]!.insert(callModel.callId)
                } else {
                    self.pendingConferences[callId] = [callModel.callId]
                }
            })
            .disposed(by: self.disposeBag)
        makeCall.connect().disposed(by: self.disposeBag)
        return makeCall
    }

    func refuse(callId: String) -> Completable {
        return Completable.create(subscribe: { completable in
            guard let call = self.call(callID: callId) else {
                completable(.error(CallServiceError.hangUpCallFailed))
                return Disposables.create { }
            }
            let success = self.callsAdapter.refuseCall(withId: callId, accountId: call.accountId)
            if success {
                completable(.completed)
            } else {
                completable(.error(CallServiceError.refuseCallFailed))
            }
            return Disposables.create { }
        })
    }

    func stopCall(call: CallModel) {
        self.callsAdapter.hangUpCall(call.callId, accountId: call.accountId)
    }

    func stopPendingCall(callId: String) {
        guard let call = self.call(callID: callId) else { return }
        self.stopCall(call: call)
    }
    func answerCall(call: CallModel) -> Bool {
        NSLog("call service answerCall %@", call.callId)
        return self.callsAdapter.acceptCall(withId: call.callId, accountId: call.accountId, withMedia: call.mediaList)
    }

    func hangUp(callId: String) -> Completable {
        return Completable.create(subscribe: { completable in
            var success: Bool
            guard let call = self.call(callID: callId) else {
                completable(.error(CallServiceError.hangUpCallFailed))
                return Disposables.create { }
            }
            success = self.callsAdapter.hangUpCall(callId, accountId: call.accountId)
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
                success = self.callsAdapter.hangUpCall(callId, accountId: call.accountId)
            } else {
                success = self.callsAdapter.hangUpConference(callId, accountId: call.accountId)
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
            guard let call = self.call(callID: callId) else {
                completable(.error(CallServiceError.hangUpCallFailed))
                return Disposables.create { }
            }
            let success = self.callsAdapter.holdCall(withId: callId, accountId: call.accountId)
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
            guard let call = self.call(callID: callId) else {
                completable(.error(CallServiceError.hangUpCallFailed))
                return Disposables.create { }
            }
            let success = self.callsAdapter.unholdCall(withId: callId, accountId: call.accountId)
            if success {
                completable(.completed)
            } else {
                completable(.error(CallServiceError.unholdCallFailed))
            }
            return Disposables.create { }
        })
    }

    func makeCall(withAccount account: AccountModel,
                   toParticipantId participantId: String,
                   userName: String,
                   videoSource: String,
                   isAudioOnly: Bool = false,
                   withMedia: [[String: String]] = [[String: String]]()) -> Single<CallModel> {

        // Create and emit the call
        var callDetails = [String: String]()
        callDetails[CallDetailKey.callTypeKey.rawValue] = String(describing: CallType.outgoing)
        callDetails[CallDetailKey.displayNameKey.rawValue] = userName
        callDetails[CallDetailKey.accountIdKey.rawValue] = account.id
        callDetails[CallDetailKey.audioOnlyKey.rawValue] = isAudioOnly.toString()
        callDetails[CallDetailKey.timeStampStartKey.rawValue] = ""

        var mediaList = withMedia
        if mediaList.isEmpty {
            var mediaAttribute = [String: String]()
            mediaAttribute[MediaAttributeKey.mediaType.rawValue] = MediaAttributeValue.audio.rawValue
            mediaAttribute[MediaAttributeKey.label.rawValue] = "audio_0"
            mediaAttribute[MediaAttributeKey.enabled.rawValue] = "true"
            mediaAttribute[MediaAttributeKey.muted.rawValue] = "false"
            mediaList.append(mediaAttribute)
            if !isAudioOnly {
                mediaAttribute[MediaAttributeKey.mediaType.rawValue] = MediaAttributeValue.video.rawValue
                mediaAttribute[MediaAttributeKey.label.rawValue] = "video_0"
                mediaAttribute[MediaAttributeKey.source.rawValue] = videoSource
                mediaList.append(mediaAttribute)
            }
        }

        let call = CallModel(withCallId: participantId, callDetails: callDetails, withMedia: mediaList)
        call.state = .unknown
        call.callType = .outgoing
        call.participantUri = participantId
        return Single<CallModel>.create(subscribe: { [weak self] single in
            if let self = self, let callId = self.callsAdapter.makeCall(withAccountId: account.id,
                                                                         toParticipantId: participantId,
                                                                         withMedia: mediaList), !callId.isEmpty,
               let callDictionary = self.callsAdapter.callDetails(withCallId: callId, accountId: account.id) {
                call.update(withDictionary: callDictionary, withMedia: mediaList)
                call.participantUri = participantId
                call.callId = callId
                call.participantsCallId.removeAll()
                call.participantsCallId.insert(callId)
                self.currentCallsEvents.onNext(call)
                var values = self.calls.value
                values[callId] = call
                self.calls.accept(values)
                single(.success(call))
            } else {
                single(.failure(CallServiceError.makeCallFailed))
            }
            return Disposables.create { }
        })
    }

    func playDTMF(code: String) {
        self.callsAdapter.playDTMF(code)
    }

    func sendVCard(callID: String, accountID: String) {
        if accountID.isEmpty || callID.isEmpty {
            return
        }
        guard let profile = self.dbManager.accountVCard(for: accountID) else { return }
        let jamiId = profile.uri
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            VCardUtils.sendVCard(card: profile,
                                 callID: callID,
                                 accountID: accountID,
                                 sender: self, from: jamiId)
        }
    }

    func sendTextMessage(callID: String, message: String, accountId: AccountModel) {
        guard let call = self.call(callID: callID) else { return }
        let messageDictionary = ["text/plain": message]
        self.callsAdapter.sendTextMessage(withCallID: callID,
                                          accountId: accountId.id,
                                          message: messageDictionary,
                                          from: call.paricipantHash(),
                                          isMixed: true)
        let accountHelper = AccountModelHelper(withAccount: accountId)
        let type = accountHelper.isAccountSip() ? URIType.sip : URIType.ring
        let contactUri = JamiURI.init(schema: type, infoHash: call.participantUri, account: accountId)
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

    func sendChunk(callID: String, message: [String: String], accountId: String, from: String) {
        self.callsAdapter.sendTextMessage(withCallID: callID,
                                          accountId: accountId,
                                          message: message,
                                          from: from,
                                          isMixed: true)
    }

    func updateCallUUID(callId: String, callUUID: String) {
        if let call = self.call(callID: callId), let uuid = UUID(uuidString: callUUID) {
            call.callUUID = uuid
        }
    }

    // MARK: CallsAdapterDelegate
    // swiftlint:disable cyclomatic_complexity
    func didChangeCallState(withCallId callId: String, state: String, accountId: String, stateCode: NSInteger) {
        if let callDictionary = self.callsAdapter.callDetails(withCallId: callId, accountId: accountId) {
            // Add or update new call
            var call = self.calls.value[callId]
            var callState = CallState(rawValue: state) ?? CallState.unknown
            call?.state = callState
            // Remove from the cache if the call is over and save message to history
            if call?.state == .over || call?.state == .failure {
                guard let finishedCall = call else { return }
                var time = 0
                if let startTime = finishedCall.dateReceived {
                    time = Int(Date().timeIntervalSince1970 - startTime.timeIntervalSince1970)
                }
                var event = ServiceEvent(withEventType: .callEnded)
                event.addEventInput(.peerUri, value: finishedCall.participantUri)
                event.addEventInput(.callUUID, value: finishedCall.callUUID.uuidString)
                event.addEventInput(.accountId, value: finishedCall.accountId)
                event.addEventInput(.callType, value: finishedCall.callType.rawValue)
                event.addEventInput(.callTime, value: time)
                self.responseStream.onNext(event)
                self.currentCallsEvents.onNext(finishedCall)
                var values = self.calls.value
                values[callId] = nil
                self.calls.accept(values)
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
            let mediaList = [[String: String]]()
            if call == nil {
                if !callState.isActive() {
                    return
                }
                call = CallModel(withCallId: callId, callDetails: callDictionary, withMedia: mediaList)
                var values = self.calls.value
                values[callId] = call
                self.calls.accept(values)
            } else {
                call?.update(withDictionary: callDictionary, withMedia: mediaList)
            }
            guard let newCall = call else { return }
            // send vCard
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
                                self.callsAdapter.joinCall(confId, second: callId, accountId: pendingCall.accountId, account2Id: accountId)
                            } else {
                                self.callsAdapter.joinConference(confId, call: callId, accountId: pendingCall.accountId, account2Id: accountId)
                            }
                        }
                    }
                }
            }

            // Emit the call to the observers
            self.currentCallsEvents.onNext(newCall)
        }
    }

    func didChangeMediaNegotiationStatus(withCallId callId: String, event: String, withMedia: [[String: String]]) {
        guard let call = self.calls.value[callId],
              let callDictionary = self.callsAdapter.callDetails(withCallId: callId, accountId: call.accountId) else { return }
        call.update(withDictionary: callDictionary, withMedia: withMedia)
        self.currentCallsEvents.onNext(call)
    }

    func didReceiveMediaChangeRequest(withAccountId accountId: String, callId: String, withMedia: [[String: String]]) {
        guard let call = self.calls.value[callId] else { return }
        var currentMediaLabels = [String]()
        for media in call.mediaList where media[MediaAttributeKey.label.rawValue] != nil {
            currentMediaLabels.append(media[MediaAttributeKey.label.rawValue]!)
        }

        var answerMedias = [[String: String]]()
        for media in withMedia {
            let label = media[MediaAttributeKey.label.rawValue] ?? ""
            let index = currentMediaLabels.firstIndex(of: label ) ?? -1
            if index >= 0 {
                var answerMedia = media
                answerMedia[MediaAttributeKey.muted.rawValue] = call.mediaList[index][MediaAttributeKey.muted.rawValue]
                answerMedia[MediaAttributeKey.enabled.rawValue] = call.mediaList[index][MediaAttributeKey.enabled.rawValue]
                answerMedias.append(answerMedia)
            } else {
                var answerMedia = media
                answerMedia[MediaAttributeKey.muted.rawValue] = "true"
                answerMedia[MediaAttributeKey.enabled.rawValue] = "true"
                answerMedias.append(answerMedia)
            }
        }
        self.callsAdapter.answerMediaChangeResquest(callId, accountId: accountId, withMedia: answerMedias)
    }

    func shouldCallBeAddedToConference(callId: String) -> String? {
        var confId: String?
        self.pendingConferences.keys.forEach { [weak self] (initialCall) in
            guard let self = self, let pendigs = self.pendingConferences[initialCall], !pendigs.isEmpty
            else { return }
            if pendigs.contains(callId) {
                confId = initialCall
            }
        }
        return confId
    }

    func didReceiveMessage(withCallId callId: String, fromURI uri: String, message: [String: String]) {
        guard let call = self.call(callID: callId) else { return }
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
        event.addEventInput(.peerUri, value: uri.filterOutHost())
        event.addEventInput(.name, value: name)
        event.addEventInput(.accountId, value: accountId)
        self.newMessagesStream.onNext(event)
    }
    // swiftlint:enable cyclomatic_complexity

    func receivingCall(withAccountId accountId: String, callId: String, fromURI uri: String, withMedia mediaList: [[String: String]]) {
        os_log("incoming call call service")
        if let callDictionary = self.callsAdapter.callDetails(withCallId: callId, accountId: accountId) {
            var call = self.calls.value[callId]
            if call == nil {
                call = CallModel(withCallId: callId, callDetails: callDictionary, withMedia: mediaList)
            } else {
                call?.update(withDictionary: callDictionary, withMedia: mediaList)
            }
            // Emit the call to the observers
            guard let newCall = call else { return }
            self.newCall.accept(newCall)
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
    func remoteRecordingChanged(call callId: String, record: Bool) {
        guard let call = self.calls.value[callId] else {
            return
        }
        call.callRecorded = record
        self.currentCallsEvents.onNext(call)
    }

    func videoMuted(call callId: String, mute: Bool) {
        guard let call = self.calls.value[callId] else {
            return
        }
        call.videoMuted = mute
        self.currentCallsEvents.onNext(call)
    }

    func callMediaUpdated(call: CallModel) {
        var mediaList = call.mediaList
        if mediaList.isEmpty {
            guard let attributes = self.callsAdapter.currentMediaList(withCallId: call.callId, accountId: call.accountId) else { return }
            call.update(withDictionary: [:], withMedia: attributes)
            mediaList = call.mediaList
        }
        if let callDictionary = self.callsAdapter.callDetails(withCallId: call.callId, accountId: call.accountId) {
            call.update(withDictionary: callDictionary, withMedia: mediaList)
            self.currentCallsEvents.onNext(call)
        }
    }

    func updateCallMediaIfNeeded(call: CallModel) {
        var mediaList = call.mediaList
        if mediaList.isEmpty {
            guard let attributes = self.callsAdapter.currentMediaList(withCallId: call.callId, accountId: call.accountId) else { return }
            call.update(withDictionary: [:], withMedia: attributes)
            mediaList = call.mediaList
        }
        call.mediaList = mediaList
    }

    func conferenceCreated(conference conferenceID: String, accountId: String) {
        let conferenceCalls = Set(self.callsAdapter
                                    .getConferenceCalls(conferenceID, accountId: accountId))
        if conferenceCalls.isEmpty {
            // no calls attached to a conference. Wait until conference changed to check the calls.
            createdConferences.insert(conferenceID)
            return
        }
        createdConferences.remove(conferenceID)
        self.pendingConferences.forEach { pending in
            if !conferenceCalls.contains(pending.key) ||
                conferenceCalls.isDisjoint(with: pending.value) {
                return
            }
            let callId = pending.key
            var values = pending.value
            // update pending conferences
            // replace callID by new Conference ID, and remove calls that was already added to onference
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
            guard var callDetails = self.callsAdapter.getConferenceDetails(conferenceID, accountId: accountId) else { return }
            callDetails[CallDetailKey.accountIdKey.rawValue] = self.call(callID: callId)?.accountId
            callDetails[CallDetailKey.audioOnlyKey.rawValue] = self.call(callID: callId)?.isAudioOnly.toString()
            let mediaList = [[String: String]]()
            let conf = CallModel(withCallId: conferenceID, callDetails: callDetails, withMedia: mediaList)
            conf.participantsCallId = conferenceCalls
            var value = self.calls.value
            value[conferenceID] = conf
            self.calls.accept(value)
            currentConferenceEvent.accept(ConferenceUpdates(conferenceID, ConferenceState.conferenceCreated.rawValue, conferenceCalls))
        }
    }

    func conferenceChanged(conference conferenceID: String, accountId: String, state: String) {
        if createdConferences.contains(conferenceID) {
            // a conference was created but calls was not attached to a conference. In this case a conference should be added first.
            self.conferenceCreated(conference: conferenceID, accountId: accountId)
            return
        }
        guard let conference = self.call(callID: conferenceID) else { return }
        let conferenceCalls = Set(self.callsAdapter
                                    .getConferenceCalls(conferenceID, accountId: conference.accountId))
        conference.participantsCallId = conferenceCalls
        conferenceCalls.forEach { (callId) in
            guard let call = self.call(callID: callId) else { return }
            call.participantsCallId = conferenceCalls
            var values = self.calls.value
            values[callId] = call
            self.calls.accept(values)
        }
    }

    func conferenceRemoved(conference conferenceID: String) {
        guard let conference = self.call(callID: conferenceID) else { return }
        self.conferenceInfos[conferenceID] = nil
        self.currentConferenceEvent.accept(ConferenceUpdates(conferenceID, ConferenceState.infoUpdated.rawValue, [""]))
        self.currentConferenceEvent.accept(ConferenceUpdates(conferenceID, ConferenceState.conferenceDestroyed.rawValue, conference.participantsCallId))
        var values = self.calls.value
        values[conferenceID] = nil
        self.calls.accept(values)
    }

    func updateConferences(callId: String) {
        let conferences = self.calls.value.keys.filter { (callID) -> Bool in
            guard let callModel = self.calls.value[callID] else { return false }
            return callModel.participantsCallId.count > 1 && callModel.participantsCallId.contains(callId)
        }

        guard let conferenceID = conferences.first, let conference = call(callID: conferenceID) else { return }
        let conferenceCalls = Set(self.callsAdapter
                                    .getConferenceCalls(conferenceID, accountId: conference.accountId))
        conference.participantsCallId = conferenceCalls
        conferenceCalls.forEach { (callID) in
            self.call(callID: callID)?.participantsCallId = conferenceCalls
        }
    }

    func setModeratorParticipant(confId: String, participantId: String, active: Bool) {
        guard let conference = call(callID: confId) else { return }
        self.callsAdapter.setConferenceModerator(participantId, forConference: confId, accountId: conference.accountId, active: active)
    }

    func hangupParticipant(confId: String, participantId: String, device: String) {
        guard let conference = call(callID: confId) else { return }
        self.callsAdapter.hangupConferenceParticipant(participantId, forConference: confId, accountId: conference.accountId, deviceId: device)
    }

    func muteStream(confId: String, participantId: String, device: String, accountId: String, streamId: String, state: Bool) {
        self.callsAdapter.muteStream(participantId, forConference: confId, accountId: accountId, deviceId: device, streamId: streamId, state: state)
    }

    func setRaiseHand(confId: String, participantId: String, state: Bool, accountId: String, deviceId: String) {
        guard let conference = call(callID: confId) else { return }
        self.callsAdapter.raiseHand(participantId, forConference: confId, accountId: accountId, deviceId: deviceId, state: state)
    }

}
