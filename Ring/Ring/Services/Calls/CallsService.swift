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

// swiftlint:disable file_length
/**
 * The CallsService implements several protocols to handle different aspects of call management.
 * It directly manages all call-related services and acts as the main facade for call operations.
 */
class CallsService: CallManaging, ConferenceManaging, MessageHandling, MediaManaging, CallsAdapterDelegate {
    // Service instances
    private let callManagementService: CallManagementService
    private let conferenceManagementService: ConferenceManagementService
    private let mediaManagementService: MediaManagementService
    private let messageHandlingService: MessageHandlingService
    private let callsAdapterObserver: CallsAdapterObservingService

    private let callsAdapter: CallsAdapter
    let dbManager: DBManager
    private let disposeBag = DisposeBag()

    // Shared properties from original service
    var calls = BehaviorRelay<[String: CallModel]>(value: [String: CallModel]())
    var pendingConferences = [String: Set<String>]()
    var createdConferences = Set<String>()
    let currentCallsEvents = ReplaySubject<CallModel>.create(bufferSize: 1)
    let newCall = BehaviorRelay<CallModel>(value: CallModel(withCallId: "", callDetails: [:], withMedia: [[:]]))
    let currentConferenceEvent: BehaviorRelay<ConferenceUpdates> = BehaviorRelay<ConferenceUpdates>(value: ConferenceUpdates("", "", Set<String>()))
    let inConferenceCalls = PublishSubject<CallModel>()
    var conferenceInfos = [String: [ConferenceParticipant]]()

    private let responseStream = PublishSubject<ServiceEvent>()
    var sharedResponseStream: Observable<ServiceEvent>
    private let newMessagesStream = PublishSubject<ServiceEvent>()
    var newMessage: Observable<ServiceEvent>

    init(withCallsAdapter callsAdapter: CallsAdapter, dbManager: DBManager) {
        self.callsAdapter = callsAdapter
        self.dbManager = dbManager

        self.responseStream.disposed(by: disposeBag)
        self.sharedResponseStream = responseStream.share()
        newMessage = newMessagesStream.share()

        // Initialize core services first
        self.callManagementService = CallManagementService(
            callsAdapter: callsAdapter,
            calls: calls,
            currentCallsEvents: currentCallsEvents,
            responseStream: responseStream
        )

        self.conferenceManagementService = ConferenceManagementService(
            callsAdapter: callsAdapter,
            calls: calls,
            pendingConferences: pendingConferences,
            createdConferences: createdConferences,
            currentCallsEvents: currentCallsEvents,
            currentConferenceEvent: currentConferenceEvent,
            conferenceInfos: conferenceInfos
        )

        self.mediaManagementService = MediaManagementService(
            callsAdapter: callsAdapter,
            calls: calls,
            currentCallsEvents: currentCallsEvents
        )

        self.messageHandlingService = MessageHandlingService(
            callsAdapter: callsAdapter,
            dbManager: dbManager,
            calls: calls,
            newMessagesStream: newMessagesStream
        )

        // Initialize the adapter observer separately, after all other properties are initialized
        self.callsAdapterObserver = CallsAdapterObservingService(
            service: nil, // We'll set this after initialization
            callsAdapter: callsAdapter,
            calls: calls,
            currentCallsEvents: currentCallsEvents,
            newCall: newCall,
            responseStream: responseStream,
            newMessagesStream: newMessagesStream
        )

        // Setup connections between services
        self.conferenceManagementService.setupServices(
            callManagementService: callManagementService,
            inConferenceCalls: inConferenceCalls
        )

        // All properties are now initialized, we can now set the circular reference
        self.callsAdapterObserver.setService(self)

        // Set this class as the CallsAdapter delegate
        CallsAdapter.delegate = self

        // Setup notifications
        setupNotifications()

        // Monitor calls
        monitorCalls()
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(self.refuseUnansweredCall(_:)),
                                               name: NSNotification.Name(rawValue: NotificationName.refuseCallFromNotifications.rawValue),
                                               object: nil)
    }

    private func monitorCalls() {
        self.calls.asObservable()
            .subscribe(onNext: { calls in
                if calls.isEmpty {
                    NotificationCenter.default.post(name: NSNotification.Name(NotificationName.restoreDefaultVideoDevice.rawValue), object: nil, userInfo: nil)
                }
            })
            .disposed(by: self.disposeBag)
    }

    @objc
    func refuseUnansweredCall(_ notification: NSNotification) {
        guard let callId = notification.userInfo?[Constants.NotificationUserInfoKeys.callID.rawValue] as? String else {
            return
        }
        guard let call = self.calls.value[callId] else {
            return
        }

        if call.state == .incoming {
            self.callManagementService.refuse(callId: callId)
                .subscribe({_ in
                    print("Call ignored")
                })
                .disposed(by: self.disposeBag)
        }
    }

    // MARK: - CallsAdapterDelegate methods

    func didChangeCallState(withCallId callId: String, state: String, accountId: String, stateCode: NSInteger) {
        callsAdapterObserver.didChangeCallState(withCallId: callId, state: state, accountId: accountId, stateCode: stateCode)
    }

    func didChangeMediaNegotiationStatus(withCallId callId: String, event: String, withMedia: [[String: String]]) {
        mediaManagementService.handleMediaNegotiationStatus(callId: callId, event: event, media: withMedia)
        callsAdapterObserver.didChangeMediaNegotiationStatus(withCallId: callId, event: event, withMedia: withMedia)
    }

    func didReceiveMediaChangeRequest(withAccountId accountId: String, callId: String, withMedia: [[String: String]]) {
        mediaManagementService.handleMediaChangeRequest(accountId: accountId, callId: callId, media: withMedia)
        callsAdapterObserver.didReceiveMediaChangeRequest(withAccountId: accountId, callId: callId, withMedia: withMedia)
    }

    func didReceiveMessage(withCallId callId: String, fromURI uri: String, message: [String: String]) {
        messageHandlingService.handleIncomingMessage(callId: callId, fromURI: uri, message: message)
        callsAdapterObserver.didReceiveMessage(withCallId: callId, fromURI: uri, message: message)
    }

    func receivingCall(withAccountId accountId: String, callId: String, fromURI uri: String, withMedia mediaList: [[String: String]]) {
        callsAdapterObserver.receivingCall(withAccountId: accountId, callId: callId, fromURI: uri, withMedia: mediaList)
    }

    func callPlacedOnHold(withCallId callId: String, holding: Bool) {
        mediaManagementService.handleCallPlacedOnHold(callId: callId, holding: holding)
        callsAdapterObserver.callPlacedOnHold(withCallId: callId, holding: holding)
    }

    func conferenceCreated(conference conferenceID: String, accountId: String) {
        callsAdapterObserver.conferenceCreated(conference: conferenceID, accountId: accountId)
    }

    func conferenceChanged(conference conferenceID: String, accountId: String, state: String) {
        callsAdapterObserver.conferenceChanged(conference: conferenceID, accountId: accountId, state: state)
    }

    func conferenceRemoved(conference conferenceID: String) {
        callsAdapterObserver.conferenceRemoved(conference: conferenceID)
    }

    func remoteRecordingChanged(call callId: String, record: Bool) {
        mediaManagementService.handleRemoteRecordingChanged(callId: callId, record: record)
        callsAdapterObserver.remoteRecordingChanged(call: callId, record: record)
    }

    func conferenceInfoUpdated(conference conferenceID: String, info: [[String: String]]) {
        callsAdapterObserver.conferenceInfoUpdated(conference: conferenceID, info: info)
    }

    // MARK: - Utility Methods

    func updateCallUUID(callId: String, callUUID: String) {
        callManagementService.updateCallUUID(callId: callId, callUUID: callUUID)
    }

    // MARK: - Conference handling methods

    func handleConferenceCreated(conference conferenceID: String, accountId: String) {
        conferenceManagementService.handleConferenceCreated(conference: conferenceID, accountId: accountId)
    }

    func handleConferenceChanged(conference conferenceID: String, accountId: String, state: String) {
        conferenceManagementService.handleConferenceChanged(conference: conferenceID, accountId: accountId, state: state)
    }

    func handleConferenceRemoved(conference conferenceID: String) {
        conferenceManagementService.handleConferenceRemoved(conference: conferenceID)
    }

    func handleConferenceInfoUpdated(conference conferenceID: String, info: [[String: String]]) {
        conferenceManagementService.handleConferenceInfoUpdated(conference: conferenceID, info: info)
    }

    private func arrayToConferenceParticipants(participants: [[String: String]], onlyURIAndActive: Bool) -> [ConferenceParticipant] {
        var conferenceParticipants = [ConferenceParticipant]()
        for participant in participants {
            conferenceParticipants.append(ConferenceParticipant(info: participant, onlyURIAndActive: onlyURIAndActive))
        }
        return conferenceParticipants
    }

    func clearPendingConferences(callId: String) {
        conferenceManagementService.clearPendingConferences(callId: callId)
    }

    func updateConferences(callId: String) {
        conferenceManagementService.updateConferences(callId: callId)
    }

    func handleCallBecomingCurrent(callId: String, accountId: String) {
        if let confId = conferenceManagementService.shouldCallBeAddedToConference(callId: callId) {
            let seconds = 1.0
            if let pendingCall = callManagementService.call(callID: confId) {
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

    func shouldCallBeAddedToConference(callId: String) -> String? {
        return conferenceManagementService.shouldCallBeAddedToConference(callId: callId)
    }

    // MARK: - CallManaging implementation

    func call(callID: String) -> CallModel? {
        return callManagementService.call(callID: callID)
    }

    func callByUUID(UUID: String) -> CallModel? {
        return callManagementService.callByUUID(UUID: UUID)
    }

    func accept(call: CallModel?) -> Completable {
        return callManagementService.accept(call: call)
    }

    func refuse(callId: String) -> Completable {
        return callManagementService.refuse(callId: callId)
    }

    func hangUp(callId: String) -> Completable {
        return callManagementService.hangUp(callId: callId)
    }

    func hold(callId: String) -> Completable {
        return callManagementService.hold(callId: callId)
    }

    func unhold(callId: String) -> Completable {
        return callManagementService.unhold(callId: callId)
    }

    func placeCall(withAccount account: AccountModel,
                   toParticipantId participantId: String,
                   userName: String,
                   videoSource: String,
                   isAudioOnly: Bool,
                   withMedia: [[String: String]]) -> Single<CallModel> {
        return callManagementService.placeCall(withAccount: account,
                                               toParticipantId: participantId,
                                               userName: userName,
                                               videoSource: videoSource,
                                               isAudioOnly: isAudioOnly,
                                               withMedia: withMedia)
    }

    func answerCall(call: CallModel) -> Bool {
        return callManagementService.answerCall(call: call)
    }

    func stopCall(call: CallModel) {
        callManagementService.stopCall(call: call)
    }

    func stopPendingCall(callId: String) {
        callManagementService.stopPendingCall(callId: callId)
    }

    func playDTMF(code: String) {
        callManagementService.playDTMF(code: code)
    }

    func isCurrentCall() -> Bool {
        return callManagementService.isCurrentCall()
    }

    // MARK: - ConferenceManaging implementation

    func joinConference(confID: String, callID: String) {
        conferenceManagementService.joinConference(confID: confID, callID: callID)
    }

    func joinCall(firstCallId: String, secondCallId: String) {
        conferenceManagementService.joinCall(firstCallId: firstCallId, secondCallId: secondCallId)
    }

    func callAndAddParticipant(participant contactId: String,
                               toCall callId: String,
                               withAccount account: AccountModel,
                               userName: String,
                               videSource: String,
                               isAudioOnly: Bool = false) -> Observable<CallModel> {
        let call = self.calls.value[callId]
        let placeCall = callManagementService.placeCall(withAccount: account,
                                       toParticipantId: contactId,
                                       userName: userName,
                                       videoSource: videSource,
                                       isAudioOnly: isAudioOnly,
                                       withMedia: call?.mediaList ?? [[String: String]]())
            .asObservable()
            .publish()
        placeCall
            .subscribe(onNext: { [weak self] (callModel) in
                guard let self = self else { return }
                inConferenceCalls.onNext(callModel)
                if var pending = self.pendingConferences[callId] {
                    pending.insert(callModel.callId)
                    self.pendingConferences[callId] = pending
                } else {
                    self.pendingConferences[callId] = [callModel.callId]
                }
            })
            .disposed(by: self.disposeBag)
        placeCall.connect().disposed(by: self.disposeBag)
        return placeCall
    }

    func hangUpCallOrConference(callId: String) -> Completable {
        return conferenceManagementService.hangUpCallOrConference(callId: callId)
    }

    func isParticipant(participantURI: String?, activeIn conferenceId: String, accountId: String) -> Bool? {
        return conferenceManagementService.isParticipant(participantURI: participantURI, activeIn: conferenceId, accountId: accountId)
    }

    func isModerator(participantId: String, inConference confId: String) -> Bool {
        return conferenceManagementService.isModerator(participantId: participantId, inConference: confId)
    }

    func getConferenceParticipants(for conferenceId: String) -> [ConferenceParticipant]? {
        return conferenceManagementService.getConferenceParticipants(for: conferenceId)
    }

    func setActiveParticipant(conferenceId: String, maximixe: Bool, jamiId: String) {
        conferenceManagementService.setActiveParticipant(conferenceId: conferenceId, maximixe: maximixe, jamiId: jamiId)
    }

    func setModeratorParticipant(confId: String, participantId: String, active: Bool) {
        conferenceManagementService.setModeratorParticipant(confId: confId, participantId: participantId, active: active)
    }

    func hangupParticipant(confId: String, participantId: String, device: String) {
        conferenceManagementService.hangupParticipant(confId: confId, participantId: participantId, device: device)
    }

    func muteStream(confId: String, participantId: String, device: String, accountId: String, streamId: String, state: Bool) {
        conferenceManagementService.muteStream(confId: confId, participantId: participantId, device: device, accountId: accountId, streamId: streamId, state: state)
    }

    func setRaiseHand(confId: String, participantId: String, state: Bool, accountId: String, deviceId: String) {
        conferenceManagementService.setRaiseHand(confId: confId, participantId: participantId, state: state, accountId: accountId, deviceId: deviceId)
    }

    // MARK: - MediaManaging implementation

    func getVideoCodec(call: CallModel) -> String? {
        return mediaManagementService.getVideoCodec(call: call)
    }

    func audioMuted(call callId: String, mute: Bool) {
        mediaManagementService.audioMuted(call: callId, mute: mute)
    }

    func videoMuted(call callId: String, mute: Bool) {
        mediaManagementService.videoMuted(call: callId, mute: mute)
    }

    func callMediaUpdated(call: CallModel) {
        mediaManagementService.callMediaUpdated(call: call)
    }

    func updateCallMediaIfNeeded(call: CallModel) {
        mediaManagementService.updateCallMediaIfNeeded(call: call)
    }

    // MARK: - MessageHandling implementation

    func sendVCard(callID: String, accountID: String) {
        messageHandlingService.sendVCard(callID: callID, accountID: accountID)
    }

    func sendTextMessage(callID: String, message: String, accountId: AccountModel) {
        messageHandlingService.sendTextMessage(callID: callID, message: message, accountId: accountId)
    }

    func sendChunk(callID: String, message: [String: String], accountId: String, from: String) {
        messageHandlingService.sendChunk(callID: callID, message: message, accountId: accountId, from: from)
    }
    
    // MARK: - CallsAdapterObserving implementation
    // These are already implemented via the CallsAdapterDelegate methods

    // MARK: - Additional refactored methods

    /// Refactored method to place a call, using factory classes
    func placeCallRefactored(withAccount account: AccountModel,
                             toParticipantId participantId: String,
                             userName: String,
                             videoSource: String,
                             isAudioOnly: Bool = false,
                             withMedia: [[String: String]] = [[String: String]]()) -> Single<CallModel> {

        let mediaList = withMedia.isEmpty ?
            MediaAttributeFactory.createDefaultMediaList(isAudioOnly: isAudioOnly, videoSource: videoSource) :
            withMedia

        // Direct implementation without delegating
        return placeCall(withAccount: account,
                         toParticipantId: participantId,
                         userName: userName,
                         videoSource: videoSource,
                         isAudioOnly: isAudioOnly,
                         withMedia: mediaList)
    }
}

class CallsAdapterObservingService: CallsAdapterDelegate {

    private weak var service: CallsService?
    private let callsAdapter: CallsAdapter
    private let calls: BehaviorRelay<[String: CallModel]>
    private let currentCallsEvents: ReplaySubject<CallModel>
    private let newCall: BehaviorRelay<CallModel>
    private let responseStream: PublishSubject<ServiceEvent>
    private let newMessagesStream: PublishSubject<ServiceEvent>
    private let ringVCardMIMEType = "x-ring/ring.profile.vcard;"

    init(
        service: CallsService?,
        callsAdapter: CallsAdapter,
        calls: BehaviorRelay<[String: CallModel]>,
        currentCallsEvents: ReplaySubject<CallModel>,
        newCall: BehaviorRelay<CallModel>,
        responseStream: PublishSubject<ServiceEvent>,
        newMessagesStream: PublishSubject<ServiceEvent>
    ) {
        self.service = service
        self.callsAdapter = callsAdapter
        self.calls = calls
        self.currentCallsEvents = currentCallsEvents
        self.newCall = newCall
        self.responseStream = responseStream
        self.newMessagesStream = newMessagesStream
    }

    /// Set the service after initialization to avoid circular reference issues
    func setService(_ service: CallsService) {
        self.service = service
    }

    func didChangeCallState(withCallId callId: String, state: String, accountId: String, stateCode: NSInteger) {
        if let callDictionary = self.callsAdapter.callDetails(withCallId: callId, accountId: accountId) {
            // Process the call state
            let callState = CallState(rawValue: state) ?? CallState.unknown

            // If call is over, remove it from the call map
            if callState == .over || callState == .failure {
                guard let call = self.calls.value[callId] else { return }
                // Track call ending
                var time = 0
                if let startTime = call.dateReceived {
                    time = Int(Date().timeIntervalSince1970 - startTime.timeIntervalSince1970)
                }
                var event = ServiceEvent(withEventType: .callEnded)
                event.addEventInput(.peerUri, value: call.participantUri)
                event.addEventInput(.callUUID, value: call.callUUID.uuidString)
                event.addEventInput(.accountId, value: call.accountId)
                event.addEventInput(.callType, value: call.callType.rawValue)
                event.addEventInput(.callTime, value: time)
                self.responseStream.onNext(event)
                self.currentCallsEvents.onNext(call)

                // Update the calls map
                var values = self.calls.value
                values[callId] = nil
                self.calls.accept(values)

                // Handle conference-related cleanup
                self.service?.clearPendingConferences(callId: callId)
                self.service?.updateConferences(callId: callId)
                return
            }

            // Update or add the call
            let mediaList = [[String: String]]()
            var call: CallModel?

            if !self.calls.value.keys.contains(callId) {
                if !callState.isActive() {
                    return
                }
                call = CallModel(withCallId: callId, callDetails: callDictionary, withMedia: mediaList)
                var values = self.calls.value
                values[callId] = call
                self.calls.accept(values)
            } else {
                call = self.calls.value[callId]
                call?.update(withDictionary: callDictionary, withMedia: mediaList)
                call?.state = callState
            }

            guard let updatedCall = call else { return }

            // Send vCard if needed
            if (updatedCall.state == .ringing && updatedCall.callType == .outgoing) ||
                (updatedCall.state == .current && updatedCall.callType == .incoming) {
                self.service?.sendVCard(callID: callId, accountID: updatedCall.accountId)
            }

            // Handle current state changes
            if updatedCall.state == .current {
                self.service?.handleCallBecomingCurrent(callId: callId, accountId: accountId)
            }

            // Emit the call to observers
            self.currentCallsEvents.onNext(updatedCall)
        }
    }

    func didChangeMediaNegotiationStatus(withCallId callId: String, event: String, withMedia: [[String: String]]) {
        // This is now handled directly by the service
    }

    func didReceiveMediaChangeRequest(withAccountId accountId: String, callId: String, withMedia: [[String: String]]) {
        // This is now handled directly by the service
    }

    func didReceiveMessage(withCallId callId: String, fromURI uri: String, message: [String: String]) {
        // This is now handled directly by the service
    }

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
            guard let newIncomingCall = call else { return }
            self.newCall.accept(newIncomingCall)
        }
    }

    func callPlacedOnHold(withCallId callId: String, holding: Bool) {
        // This is now handled directly by the service
    }

    func conferenceCreated(conference conferenceID: String, accountId: String) {
        self.service?.handleConferenceCreated(conference: conferenceID, accountId: accountId)
    }

    func conferenceChanged(conference conferenceID: String, accountId: String, state: String) {
        self.service?.handleConferenceChanged(conference: conferenceID, accountId: accountId, state: state)
    }

    func conferenceRemoved(conference conferenceID: String) {
        self.service?.handleConferenceRemoved(conference: conferenceID)
    }

    func remoteRecordingChanged(call callId: String, record: Bool) {
        // This is now handled directly by the service
    }

    func conferenceInfoUpdated(conference conferenceID: String, info: [[String: String]]) {
        self.service?.handleConferenceInfoUpdated(conference: conferenceID, info: info)
    }

    func audioMuted(call callId: String, mute: Bool) {
    }

    func videoMuted(call callId: String, mute: Bool) {
    }
}
