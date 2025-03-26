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

// Type aliases to improve readability
typealias CallsDictionary = [String: CallModel]
typealias PendingConferencesType = [String: Set<String>]
typealias ConferenceInfosType = [String: [ConferenceParticipant]]

class CallsService: CallsAdapterDelegate {
    // Service instances
    private let callManagementService: CallManagementService
    private let conferenceManagementService: ConferenceManagementService
    private let mediaManagementService: MediaManagementService
    private let messageHandlingService: MessageHandlingService
    
    private let callsAdapter: CallsAdapter
    let dbManager: DBManager
    private let disposeBag = DisposeBag()

    // Shared properties from original service
    var calls = BehaviorRelay<CallsDictionary>(value: [:])
    var pendingConferences: PendingConferencesType = [:]
    var createdConferences = Set<String>()
    let currentCallsEvents = ReplaySubject<CallModel>.create(bufferSize: 1)
    let newCall = BehaviorRelay<CallModel>(value: CallModel(withCallId: "", callDetails: [:], withMedia: [[:]]))
    let currentConferenceEvent: BehaviorRelay<ConferenceUpdates> = BehaviorRelay<ConferenceUpdates>(value: ConferenceUpdates("", "", Set<String>()))
    let inConferenceCalls = PublishSubject<CallModel>()
    var conferenceInfos: ConferenceInfosType = [:]

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

        // Initialize core services
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

        // Setup services after full initialization
        self.setupServices()
        
        // Set this class as the CallsAdapter delegate
        CallsAdapter.delegate = self

        monitorCalls()
    }
    
    // MARK: - Setup methods
    
    func setupServices() {
        // Setup connections between services
        self.conferenceManagementService.setupServices(
            callManagementService: callManagementService,
            inConferenceCalls: inConferenceCalls
        )
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

    // MARK: - CallsAdapterDelegate methods

    func didChangeCallState(withCallId callId: String, state: String, accountId: String, stateCode: NSInteger) {
        // Process call state change through the CallManagementService
        if let callDictionary = self.callsAdapter.callDetails(withCallId: callId, accountId: accountId) {
            let callState = CallState(rawValue: state) ?? CallState.unknown
            
            // Handle call termination or update call based on state
            if callState == .over || callState == .failure {
                self.callManagementService.removeCall(callId: callId, callState: callState)
                self.conferenceManagementService.clearPendingConferences(callId: callId)
                self.conferenceManagementService.updateConferences(callId: callId)
            } else {
                if let updatedCall = self.callManagementService.updateCall(callId: callId, callState: callState, callDictionary: callDictionary) {
                    
                    // Send vCard if needed
                    if (updatedCall.state == .ringing && updatedCall.callType == .outgoing) ||
                       (updatedCall.state == .current && updatedCall.callType == .incoming) {
                        self.messageHandlingService.sendVCard(callID: callId, accountID: updatedCall.accountId)
                    }
                    
                    // Handle current state changes
                    if updatedCall.state == .current {
                        self.handleCallBecomingCurrent(callId: callId, accountId: accountId)
                    }
                }
            }
        }
    }

    func didChangeMediaNegotiationStatus(withCallId callId: String, event: String, withMedia: [[String: String]]) {
        // Update the call state through the media management service
        mediaManagementService.handleMediaNegotiationStatus(callId: callId, event: event, media: withMedia)
    }

    func didReceiveMediaChangeRequest(withAccountId accountId: String, callId: String, withMedia: [[String: String]]) {
        // Handle the media change request through the media management service
        mediaManagementService.handleMediaChangeRequest(accountId: accountId, callId: callId, media: withMedia)
    }

    func didReceiveMessage(withCallId callId: String, fromURI uri: String, message: [String: String]) {
        messageHandlingService.handleIncomingMessage(callId: callId, fromURI: uri, message: message)
    }

    func receivingCall(withAccountId accountId: String, callId: String, fromURI uri: String, withMedia mediaList: [[String: String]]) {
        os_log("incoming call call service")
        
        // Handle incoming call
        if let callDictionary = self.callsAdapter.callDetails(withCallId: callId, accountId: accountId) {
            var call = self.calls.value[callId]
            if call == nil {
                call = CallModel(withCallId: callId, callDetails: callDictionary, withMedia: mediaList)
            } else {
                call?.update(withDictionary: callDictionary, withMedia: mediaList)
            }
            
            // Emit the call to the observers
            if let newIncomingCall = call {
                // Track the incoming call
                trackIncomingCall(call: newIncomingCall)
                
                // Update the call model
                self.newCall.accept(newIncomingCall)
            }
        }
    }

    func callPlacedOnHold(withCallId callId: String, holding: Bool) {
        // Handle the hold state through the media management service
        mediaManagementService.handleCallPlacedOnHold(callId: callId, holding: holding)
    }

    func conferenceCreated(conference conferenceID: String, accountId: String) {
        conferenceManagementService.handleConferenceCreated(conference: conferenceID, accountId: accountId)
    }

    func conferenceChanged(conference conferenceID: String, accountId: String, state: String) {
        conferenceManagementService.handleConferenceChanged(conference: conferenceID, accountId: accountId, state: state)
    }

    func conferenceRemoved(conference conferenceID: String) {
        conferenceManagementService.handleConferenceRemoved(conference: conferenceID)
    }

    func remoteRecordingChanged(call callId: String, record: Bool) {
        mediaManagementService.handleRemoteRecordingChanged(callId: callId, record: record)
    }

    func conferenceInfoUpdated(conference conferenceID: String, info: [[String: String]]) {
        conferenceManagementService.handleConferenceInfoUpdated(conference: conferenceID, info: info)
    }

    // Implement required delegate methods
    func audioMuted(call callId: String, mute: Bool) {
        guard let call = self.calls.value[callId] else { return }
        
        // Handle through the media management service
        mediaManagementService.audioMuted(call: callId, mute: mute)
        
        // Track the media state change
        trackMediaStateChanged(call: call, mediaType: "audio", muted: mute)
    }

    func videoMuted(call callId: String, mute: Bool) {
        guard let call = self.calls.value[callId] else { return }
        
        // Handle through the media management service
        mediaManagementService.videoMuted(call: callId, mute: mute)
        
        // Track the media state change
        trackMediaStateChanged(call: call, mediaType: "video", muted: mute)
    }
    
    // MARK: - Event tracking
    
    /// Tracks an incoming call event
    /// - Parameter call: The incoming call model
    private func trackIncomingCall(call: CallModel) {
        var event = ServiceEvent(withEventType: .incomingCall)
        event.addEventInput(.peerUri, value: call.participantUri)
        event.addEventInput(.callUUID, value: call.callUUID.uuidString)
        event.addEventInput(.accountId, value: call.accountId)
        self.responseStream.onNext(event)
    }
    
    /// Tracks a media state change event
    /// - Parameters:
    ///   - call: The call whose media state changed
    ///   - mediaType: The type of media (audio or video)
    ///   - muted: Whether the media is muted
    private func trackMediaStateChanged(call: CallModel, mediaType: String, muted: Bool) {
        var event = ServiceEvent(withEventType: .mediaStateChanged)
        event.addEventInput(.peerUri, value: call.participantUri)
        event.addEventInput(.callUUID, value: call.callUUID.uuidString)
        event.addEventInput(.accountId, value: call.accountId)
        event.addEventInput(.mediaType, value: mediaType)
        event.addEventInput(.mediaState, value: muted ? "muted" : "unmuted")
        self.responseStream.onNext(event)
    }

    // MARK: - CallManaging implementation (delegating to CallManagementService)
    
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
    
    func placeCall(withAccount account: AccountModel, toParticipantId participantId: String, userName: String, videoSource: String, isAudioOnly: Bool, withMedia: [[String: String]]) -> Single<CallModel> {
        return callManagementService.placeCall(withAccount: account, toParticipantId: participantId, userName: userName, videoSource: videoSource, isAudioOnly: isAudioOnly, withMedia: withMedia)
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
    
    func updateCallUUID(callId: String, callUUID: String) {
        callManagementService.updateCallUUID(callId: callId, callUUID: callUUID)
    }

    // MARK: - Conference handling methods
    
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

    // MARK: - ConferenceManaging implementation (delegating to ConferenceManagementService)
    
    func joinConference(confID: String, callID: String) {
        conferenceManagementService.joinConference(confID: confID, callID: callID)
    }
    
    func joinCall(firstCallId: String, secondCallId: String) {
        conferenceManagementService.joinCall(firstCallId: firstCallId, secondCallId: secondCallId)
    }
    
    func callAndAddParticipant(participant contactId: String, toCall callId: String, withAccount account: AccountModel, userName: String, videSource: String, isAudioOnly: Bool = false) -> Observable<CallModel> {
        return conferenceManagementService.callAndAddParticipant(participant: contactId, toCall: callId, withAccount: account, userName: userName, videSource: videSource, isAudioOnly: isAudioOnly)
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

    // MARK: - MediaManaging implementation (delegating to MediaManagementService)

    func getVideoCodec(call: CallModel) -> String? {
        return mediaManagementService.getVideoCodec(call: call)
    }

    func callMediaUpdated(call: CallModel) {
        mediaManagementService.callMediaUpdated(call: call)
    }

    func updateCallMediaIfNeeded(call: CallModel) {
        mediaManagementService.updateCallMediaIfNeeded(call: call)
    }

    // MARK: - MessageHandling implementation (delegating to MessageHandlingService)

    func sendVCard(callID: String, accountID: String) {
        messageHandlingService.sendVCard(callID: callID, accountID: accountID)
    }

    func sendTextMessage(callID: String, message: String, accountId: AccountModel) {
        messageHandlingService.sendTextMessage(callID: callID, message: message, accountId: accountId)
    }

    func sendChunk(callID: String, message: [String: String], accountId: String, from: String) {
        messageHandlingService.sendChunk(callID: callID, message: message, accountId: accountId, from: from)
    }
    
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

        return placeCall(withAccount: account,
                         toParticipantId: participantId,
                         userName: userName,
                         videoSource: videoSource,
                         isAudioOnly: isAudioOnly,
                         withMedia: mediaList)
    }
    
    /// Creates a call to a participant and adds them to a conference
    /// - Parameters:
    ///   - contactId: The contact ID to call
    ///   - callId: The call ID to add the participant to
    ///   - account: The account to use for the call
    ///   - userName: The user name for the call
    ///   - videSource: The video source to use
    ///   - isAudioOnly: Flag indicating if call is audio only
    /// - Returns: Observable emitting the created call model
    func callParticipantAndAddToConference(
        participant contactId: String,
        toCall callId: String,
        withAccount account: AccountModel,
        userName: String,
        videSource: String,
        isAudioOnly: Bool = false
    ) -> Observable<CallModel> {
        let call = self.calls.value[callId]
        let mediaToUse = call?.mediaList ?? MediaAttributeFactory.createDefaultMediaList(
            isAudioOnly: isAudioOnly,
            videoSource: videSource
        )
        
        return callAndAddParticipant(
            participant: contactId,
            toCall: callId,
            withAccount: account,
            userName: userName,
            videSource: videSource,
            isAudioOnly: isAudioOnly
        )
    }
}
