/*
 *  Copyright (C) 2017-2025 Savoir-faire Linux Inc.
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

typealias CallsDictionary = [String: CallModel]
typealias PendingConferencesType = [String: Set<String>]
typealias ConferenceInfosType = [String: [ConferenceParticipant]]

/// Main service responsible for coordinating all call-related operations
class CallsService: CallsAdapterDelegate {
    // Service instances
    private let callManagementService: CallManagementService
    private let conferenceManagementService: ConferenceManagementService
    private let mediaManagementService: MediaManagementService
    private let messageHandlingService: MessageHandlingService
    private let activeCallsHelper = ActiveCallsHelper()

    private let callsAdapter: CallsAdapter
    let dbManager: DBManager
    private let disposeBag = DisposeBag()

    // Shared thread-safe queue helper for all call operations
    private let queueHelper: ThreadSafeQueueHelper

    var calls: SynchronizedRelay<CallsDictionary>
    let callUpdates = ReplaySubject<CallModel>.create(bufferSize: 1)

    // Public access to active calls
    var activeCalls: Observable<[String: AccountCalls]> {
        return activeCallsHelper.activeCalls.asObservable()
    }

    private let responseStream = PublishSubject<ServiceEvent>()
    var sharedResponseStream: Observable<ServiceEvent>
    private let newMessagesStream = PublishSubject<ServiceEvent>()
    var newMessage: Observable<ServiceEvent>

    var currentConferenceEvent: BehaviorRelay<ConferenceUpdates> {
        return conferenceManagementService.currentConferenceEvent
    }

    init(withCallsAdapter callsAdapter: CallsAdapter, dbManager: DBManager) {
        self.callsAdapter = callsAdapter
        self.dbManager = dbManager

        // Create a thread-safe queue helper for all call operations
        self.queueHelper = ThreadSafeQueueHelper(label: "com.ring.callsManagement", qos: .userInitiated)

        self.responseStream.disposed(by: disposeBag)
        self.sharedResponseStream = responseStream.share()
        newMessage = newMessagesStream.share()

        self.calls = SynchronizedRelay<CallsDictionary>(initialValue: [:], queueHelper: queueHelper)

        self.callManagementService = CallManagementService(
            callsAdapter: callsAdapter,
            calls: calls,
            callUpdates: callUpdates,
            responseStream: responseStream
        )

        self.conferenceManagementService = ConferenceManagementService(
            callsAdapter: callsAdapter,
            calls: calls,
            callUpdates: callUpdates
        )

        self.mediaManagementService = MediaManagementService(
            callsAdapter: callsAdapter,
            calls: calls,
            callUpdates: callUpdates,
            responseStream: responseStream
        )

        self.messageHandlingService = MessageHandlingService(
            callsAdapter: callsAdapter,
            dbManager: dbManager,
            calls: calls,
            newMessagesStream: newMessagesStream
        )

        CallsAdapter.delegate = self

        monitorCalls()
    }

    private func monitorCalls() {
        self.calls.observable
            .subscribe(onNext: { calls in
                if calls.isEmpty {
                    NotificationCenter.default.post(name: NSNotification.Name(NotificationName.restoreDefaultVideoDevice.rawValue), object: nil, userInfo: nil)
                }
            })
            .disposed(by: self.disposeBag)
    }

    // MARK: - CallsAdapterDelegate methods

    func didChangeCallState(withCallId callId: String, state: String, accountId: String, stateCode: NSInteger) {
        guard let callDictionary = self.callsAdapter.callDetails(withCallId: callId, accountId: accountId) else { return }

        let callState = CallState(rawValue: state) ?? CallState.unknown

        if callState.isFinished() {
            handleCallTermination(callId: callId, callState: callState)
            return
        }

        if let call = self.callManagementService.addOrUpdateCall(callId: callId, callState: callState, callDictionary: callDictionary) {
            processCallStateChange(call: call, callId: callId, accountId: accountId)
        }
    }

    private func handleCallTermination(callId: String, callState: CallState) {
        Task {
            await self.callManagementService.removeCall(callId: callId, callState: callState)
            await self.conferenceManagementService.clearPendingConferences(callId: callId)
            await self.conferenceManagementService.updateConferences(callId: callId)
        }
    }

    private func processCallStateChange(call: CallModel, callId: String, accountId: String) {
        if shouldSendVCard(for: call) {
            self.messageHandlingService.sendVCard(callID: callId, accountID: call.accountId)
        }

        if call.state == .current {
            self.joinConferenceIfNeeded(callId: callId, accountId: accountId)
        }
    }

    private func shouldSendVCard(for call: CallModel) -> Bool {
        return (call.state == .ringing && call.callType == .outgoing) ||
        (call.state == .current && call.callType == .incoming)
    }

    func didChangeMediaNegotiationStatus(withCallId callId: String, event: String, withMedia: [[String: String]]) {
        Task {
            await mediaManagementService.handleMediaNegotiationStatus(callId: callId, event: event, media: withMedia)
        }
    }

    func didReceiveMediaChangeRequest(withAccountId accountId: String, callId: String, withMedia: [[String: String]]) {
        Task {
            await mediaManagementService.handleMediaChangeRequest(accountId: accountId, callId: callId, media: withMedia)
        }
    }

    func getVideoCodec(call: CallModel) -> String? {
        return mediaManagementService.getVideoCodec(call: call)
    }

    func didReceiveMessage(withCallId callId: String, fromURI uri: String, message: [String: String]) {
        messageHandlingService.handleIncomingMessage(callId: callId, fromURI: uri, message: message)
    }

    func receivingCall(withAccountId accountId: String, callId: String, fromURI uri: String, withMedia: [[String: String]]) {
        guard let callDictionary = self.callsAdapter.callDetails(withCallId: callId, accountId: accountId) else { return }

        guard let call = self.callManagementService.addOrUpdateCall(callId: callId, callState: .incoming, callDictionary: callDictionary, mediaList: withMedia) else { return }

        notifyIncomingCall(call: call)
    }

    func callPlacedOnHold(withCallId callId: String, holding: Bool) {
        Task {
            await mediaManagementService.handleCallPlacedOnHold(callId: callId, holding: holding)
        }
    }

    func conferenceCreated(conferenceId: String, conversationId: String, accountId: String) {
        let waitForConference = self.waitForConference
        if !conversationId.isEmpty && waitForConference.contains(conversationId) {
            // For swarm calls, we provide the confId, conversationId, and accountId
            // to be picked up by the placeSwarmCall subscription
            relay.accept((confId: conferenceId, conversationId: conversationId, accountId: accountId))
        }

        Task {
            await conferenceManagementService.handleConferenceCreated(conferenceId: conferenceId, conversationId: conversationId, accountId: accountId)
        }
    }

    func conferenceChanged(conference conferenceID: String, accountId: String, state: String) {
        Task {
            await conferenceManagementService.handleConferenceChanged(conference: conferenceID, accountId: accountId, state: state)
        }
    }

    func conferenceRemoved(conference conferenceID: String) {
        Task {
            await conferenceManagementService.handleConferenceRemoved(conference: conferenceID)
        }
    }

    func remoteRecordingChanged(call callId: String, record: Bool) {
        Task {
            await mediaManagementService.handleRemoteRecordingChanged(callId: callId, record: record)
        }
    }

    func conferenceInfoUpdated(conference conferenceID: String, info: [[String: String]]) {
        Task {
            await conferenceManagementService.handleConferenceInfoUpdated(conference: conferenceID, info: info)
        }
    }

    func audioMuted(call callId: String, mute: Bool) {
        Task {
            await mediaManagementService.audioMuted(call: callId, mute: mute)
        }
    }

    func videoMuted(call callId: String, mute: Bool) {
        Task {
            await mediaManagementService.videoMuted(call: callId, mute: mute)
        }
    }

    func callMediaUpdated(call: CallModel) {
        Task {
            await mediaManagementService.callMediaUpdated(call: call)
        }
    }

    func updateCallMediaIfNeeded(call: CallModel) async {
        await mediaManagementService.updateCallMediaIfNeeded(call: call)
    }

    func handleRemoteRecordingChanged(call callId: String, record: Bool) {
        Task {
            await mediaManagementService.handleRemoteRecordingChanged(callId: callId, record: record)
        }
    }

    func handleCallPlacedOnHold(callId: String, holding: Bool) {
        Task {
            await mediaManagementService.handleCallPlacedOnHold(callId: callId, holding: holding)
        }
    }

    func handleMediaNegotiationStatus(callId: String, event: String, media: [[String: String]]) {
        Task {
            await mediaManagementService.handleMediaNegotiationStatus(callId: callId, event: event, media: media)
        }
    }

    func handleMediaChangeRequest(accountId: String, callId: String, media: [[String: String]]) {
        Task {
            await mediaManagementService.handleMediaChangeRequest(accountId: accountId, callId: callId, media: media)
        }
    }

    // MARK: - Event tracking

    private func notifyIncomingCall(call: CallModel) {
        var event = ServiceEvent(withEventType: .incomingCall)
        event.addEventInput(.peerUri, value: call.participantUri)
        event.addEventInput(.callUUID, value: call.callUUID.uuidString)
        event.addEventInput(.accountId, value: call.accountId)
        event.addEventInput(.callId, value: call.callId)
        self.responseStream.onNext(event)
    }

    // MARK: - CallManaging implementation

    func currentCall(callId: String) -> Observable<CallModel> {
        return self.callUpdates
            .share()
            .filter { (call) -> Bool in
                call.callId == callId
            }
            .asObservable()
    }

    func inConferenceCalls() -> PublishSubject<CallModel> {
        return self.conferenceManagementService.inConferenceCalls
    }

    func call(callID: String) -> CallModel? {
        return callManagementService.call(callId: callID)
    }

    func call(participantId: String, accountId: String) -> CallModel? {
        return callManagementService.call(participantId: participantId, accountId: accountId)
    }

    func callByUUID(UUID: String) -> CallModel? {
        return callManagementService.callByUUID(UUID: UUID)
    }

    func accept(callId: String) -> Completable {
        return callManagementService.accept(callId: callId)
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

    var waitForConference: String = ""
    var relay = BehaviorRelay<(confId: String, conversationId: String, accountId: String)>(value: (confId: "", conversationId: "", accountId: ""))

    func placeSwarmCall(withAccount account: AccountModel, uri: String, userName: String, videoSource: String, isAudioOnly: Bool) -> Single<CallModel> {
        waitForConference = uri
        // When conference is created, conferenceCreated will be called. We need to wait for that and create a call after that.
        return Single.create { [weak self] single in
            guard let self = self else {
                single(.failure(CallServiceError.placeCallFailed))
                return Disposables.create()
            }
            
            // Extract the conversation ID from the swarm URI
            let conversationId = uri.replacingOccurrences(of: "swarm:", with: "")
            
            // Create a cancellable work item for the timeout
            let timeoutWorkItem = DispatchWorkItem {
                single(.failure(CallServiceError.placeCallFailed))
            }
            
            // Schedule the timeout
            DispatchQueue.main.asyncAfter(deadline: .now() + 30.0, execute: timeoutWorkItem)
            
            // Create a subscription to monitor conference creation
            // This will be triggered by the conferenceCreated signal with matching conversationId
            let subscription = self.relay
                .subscribe(onNext: { conferences in
                    if conversationId == conferences.conversationId {
                        // Create a call model for the newly created conference
                        let call = CallModel()
                        call.state = .connecting
                        call.callType = .outgoing
                        call.accountId = conferences.accountId
                        call.callId = conferences.confId
                        call.conversationId = conferences.conversationId
                        
                        // Get call details if available
                        if let callDictionary = self.callManagementService.getCallDetails(callId: call.callId, accountId: conferences.accountId) {
                            call.update(withDictionary: callDictionary, withMedia: [])
                        }
                        
                        // Add the call to the calls dictionary
                        self.calls.update { calls in
                            calls[call.callId] = call
                        }
                        
                        // Cancel the timeout and return success
                        timeoutWorkItem.cancel()
                        single(.success(call))
                    }
                })
            
            // Just initiate the call process to trigger the conference creation
            // For swarm calls, this will return an empty string callId, but will trigger
            // the conferenceCreated signal with the swarm conversationId
            let callDisposable = self.callManagementService.placeCall(
                withAccount: account,
                toParticipantId: uri,
                userName: userName,
                videoSource: videoSource,
                isAudioOnly: isAudioOnly
            ).subscribe(
                onSuccess: { _ in 
                    // We don't expect this to succeed with a call model for swarm calls
                    // The actual call will be obtained via conference events
                },
                onFailure: { error in
                    // Only report error if it's a complete failure, not just the expected
                    // empty string return for swarm calls
                    if error as? CallServiceError != CallServiceError.placeCallFailed {
                        timeoutWorkItem.cancel()
                        single(.failure(error))
                    }
                }
            )
            
            // Return a disposable that will clean up all resources
            return Disposables.create {
                timeoutWorkItem.cancel()
                subscription.dispose()
                callDisposable.dispose()
            }
        }
    }

    func placeCall(withAccount account: AccountModel, toParticipantId participantId: String, userName: String, videoSource: String, isAudioOnly: Bool) -> Single<CallModel> {
        return callManagementService.placeCall(withAccount: account, toParticipantId: participantId, userName: userName, videoSource: videoSource, isAudioOnly: isAudioOnly)
    }

    func answerCall(call: CallModel) -> Bool {
        return self.callsAdapter.acceptCall(withId: call.callId, accountId: call.accountId, withMedia: call.mediaList)
    }

    func stopCall(call: CallModel) {
        self.callsAdapter.hangUpCall(call.callId, accountId: call.accountId)
    }

    func playDTMF(code: String) {
        self.callsAdapter.playDTMF(code)
    }

    func isCurrentCall() -> Bool {
        return callManagementService.isCurrentCall()
    }

    func updateCallUUID(callId: String, callUUID: String) {
        Task {
            await callManagementService.updateCallUUID(callId: callId, callUUID: callUUID)
        }
    }

    // MARK: - Conference handling methods

    func joinConferenceIfNeeded(callId: String, accountId: String) {
        guard let confId = conferenceManagementService.shouldCallBeAddedToConference(callId: callId) else {
            return
        }
        
        guard let pendingCall = self.call(callID: callId) else {
            return
        }

        // Using a delay to ensure call is fully established before joining to a conference
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            Task {
                await self.addCallToConference(
                    pendingCall: pendingCall,
                    callToAdd: callId,
                    confId: confId,
                    callAccountId: accountId
                )
            }
        }
    }

    func addCallToConference(pendingCall: CallModel, callToAdd: String, confId: String, callAccountId: String) async {
        if pendingCall.participantsCallId.count == 1 {
            self.callsAdapter.joinCall(confId, second: callToAdd, accountId: pendingCall.accountId, account2Id: callAccountId)
        } else {
            self.callsAdapter.joinConference(confId, call: callToAdd, accountId: pendingCall.accountId, account2Id: callAccountId)
        }
    }

    func joinConference(confID: String, callID: String) {
        Task {
            await conferenceManagementService.joinConference(confID: confID, callID: callID)
        }
    }

    func joinCall(firstCallId: String, secondCallId: String) {
        Task {
            await conferenceManagementService.joinCall(firstCallId: firstCallId, secondCallId: secondCallId)
        }
    }

    func callAndAddParticipant(participant contactId: String, toCall callId: String, withAccount account: AccountModel, userName: String, videSource: String, isAudioOnly: Bool = false) {
        guard let call = self.call(callID: callId) else { return }

        self.placeCall(withAccount: account,
                       toParticipantId: contactId,
                       userName: userName,
                       videoSource: videSource,
                       isAudioOnly: isAudioOnly)
            .subscribe { [weak self] callModel in
                guard let self = self else { return }
                Task {
                    await self.conferenceManagementService.addCall(call: callModel, to: callId)
                }
            }
            .disposed(by: self.disposeBag)
    }

    func hangUpCallOrConference(callId: String, isSwarm: Bool) -> Completable {
        return conferenceManagementService.hangUpCallOrConference(callId: callId, isSwarm: isSwarm)
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
        Task {
            await conferenceManagementService.setActiveParticipant(conferenceId: conferenceId, maximixe: maximixe, jamiId: jamiId)
        }
    }

    func setModeratorParticipant(confId: String, participantId: String, active: Bool) {
        Task {
            await conferenceManagementService.setModeratorParticipant(confId: confId, participantId: participantId, active: active)
        }
    }

    func hangupParticipant(confId: String, participantId: String, device: String) {
        Task {
            await conferenceManagementService.hangupParticipant(confId: confId, participantId: participantId, device: device)
        }
    }

    func muteStream(confId: String, participantId: String, device: String, accountId: String, streamId: String, state: Bool) {
        Task {
            await conferenceManagementService.muteStream(confId: confId, participantId: participantId, device: device, accountId: accountId, streamId: streamId, state: state)
        }
    }

    func setRaiseHand(confId: String, participantId: String, state: Bool, accountId: String, deviceId: String) {
        Task {
            await conferenceManagementService.setRaiseHand(confId: confId, participantId: participantId, state: state, accountId: accountId, deviceId: deviceId)
        }
    }

    func clearPendingConferences(callId: String) {
        Task {
            await conferenceManagementService.clearPendingConferences(callId: callId)
        }
    }

    func updateConferences(callId: String) {
        Task {
            await conferenceManagementService.updateConferences(callId: callId)
        }
    }

    func shouldCallBeAddedToConference(callId: String) -> String? {
        return conferenceManagementService.shouldCallBeAddedToConference(callId: callId)
    }

    // MARK: - MessageHandling implementation (delegating to MessageHandlingService)

    func sendVCard(callID: String, accountID: String) {
        messageHandlingService.sendVCard(callID: callID, accountID: accountID)
    }

    func sendInCallMessage(callID: String, message: String, accountId: AccountModel) {
        messageHandlingService.sendInCallMessage(callID: callID, message: message, accountId: accountId)
    }

    func sendChunk(callID: String, message: [String: String], accountId: String, from: String) {
        messageHandlingService.sendChunk(callID: callID, message: message, accountId: accountId, from: from)
    }

    func activeCallsChanged(conversationId: String, accountId: String, calls: [[String: String]], account: AccountModel) {
        activeCallsHelper.activeCallsChanged(conversationId: conversationId, accountId: accountId, calls: calls, account: account)
    }

    func joinCall(conversationId: String, uri: String, deviceId: String, confId: String, isAudioOnly: Bool, account: AccountModel) {
        let uri = "rdv:" + conversationId + "/" + uri + "/" + deviceId
                   + "/" + confId
        self.placeCall(withAccount: account, toParticipantId: uri, userName: "", videoSource: "", isAudioOnly: isAudioOnly)
            .subscribe { [weak self] callModel in
            }
            .disposed(by: self.disposeBag)

    }

    func ignoreCall(call: ActiveCall) {
        self.activeCallsHelper.ignoreCall(call)
    }
}

