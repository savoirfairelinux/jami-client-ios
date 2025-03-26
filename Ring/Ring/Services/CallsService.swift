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

// MARK: - Error definitions
enum CallServiceError: Error {
    case acceptCallFailed
    case refuseCallFailed
    case hangUpCallFailed
    case holdCallFailed
    case unholdCallFailed
    case placeCallFailed
}

// MARK: - Enums
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

// MARK: - Protocols

// Interface for call management
protocol CallManaging {
    func call(callID: String) -> CallModel?
    func callByUUID(UUID: String) -> CallModel?
    func accept(call: CallModel?) -> Completable
    func refuse(callId: String) -> Completable
    func hangUp(callId: String) -> Completable
    func hold(callId: String) -> Completable
    func unhold(callId: String) -> Completable
    func placeCall(withAccount account: AccountModel,
                   toParticipantId participantId: String,
                   userName: String,
                   videoSource: String,
                   isAudioOnly: Bool,
                   withMedia: [[String: String]]) -> Single<CallModel>
    func answerCall(call: CallModel) -> Bool
    func stopCall(call: CallModel)
    func stopPendingCall(callId: String)
    func playDTMF(code: String)
    func isCurrentCall() -> Bool
}

// Interface for conference management
protocol ConferenceManaging {
    func joinConference(confID: String, callID: String)
    func joinCall(firstCallId: String, secondCallId: String)
    func callAndAddParticipant(participant contactId: String,
                               toCall callId: String,
                               withAccount account: AccountModel,
                               userName: String,
                               videSource: String,
                               isAudioOnly: Bool) -> Observable<CallModel>
    func hangUpCallOrConference(callId: String) -> Completable
    func isParticipant(participantURI: String?, activeIn conferenceId: String, accountId: String) -> Bool?
    func isModerator(participantId: String, inConference confId: String) -> Bool
    func getConferenceParticipants(for conferenceId: String) -> [ConferenceParticipant]?
    func setActiveParticipant(conferenceId: String, maximixe: Bool, jamiId: String)
    func setModeratorParticipant(confId: String, participantId: String, active: Bool)
    func hangupParticipant(confId: String, participantId: String, device: String)
    func muteStream(confId: String, participantId: String, device: String, accountId: String, streamId: String, state: Bool)
    func setRaiseHand(confId: String, participantId: String, state: Bool, accountId: String, deviceId: String)
}

// Interface for message handling
protocol MessageHandling: VCardSender {
    func sendTextMessage(callID: String, message: String, accountId: AccountModel)
    func sendChunk(callID: String, message: [String: String], accountId: String, from: String)
}

// Interface for media management
protocol MediaManaging {
    func getVideoCodec(call: CallModel) -> String?
    func audioMuted(call callId: String, mute: Bool)
    func videoMuted(call callId: String, mute: Bool)
    func callMediaUpdated(call: CallModel)
    func updateCallMediaIfNeeded(call: CallModel)
}

// Interface for call adapter observations
protocol CallsAdapterObserving {
    func didChangeCallState(withCallId callId: String, state: String, accountId: String, stateCode: NSInteger)
    func didChangeMediaNegotiationStatus(withCallId callId: String, event: String, withMedia: [[String: String]])
    func didReceiveMediaChangeRequest(withAccountId accountId: String, callId: String, withMedia: [[String: String]])
    func didReceiveMessage(withCallId callId: String, fromURI uri: String, message: [String: String])
    func receivingCall(withAccountId accountId: String, callId: String, fromURI uri: String, withMedia mediaList: [[String: String]])
    func callPlacedOnHold(withCallId callId: String, holding: Bool)
    func conferenceCreated(conference conferenceID: String, accountId: String)
    func conferenceChanged(conference conferenceID: String, accountId: String, state: String)
    func conferenceRemoved(conference conferenceID: String)
    func remoteRecordingChanged(call callId: String, record: Bool)
    func conferenceInfoUpdated(conference conferenceID: String, info: [[String: String]])
}

// MARK: - Core Services

/// The CallsCoordinator acts as a facade for all call-related services
class CallsCoordinator: CallsAdapterDelegate {
    private let callManagementService: CallManagementService
    private let conferenceManagementService: ConferenceManagementService
    private let mediaManagementService: MediaManagementService
    private let messageHandlingService: MessageHandlingService
    private let callsAdapterObserver: CallsAdapterObservingService

    private let callsAdapter: CallsAdapter
    private let dbManager: DBManager
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
            coordinator: nil, // We'll set this after initialization
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
        self.callsAdapterObserver.setCoordinator(self)

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

    // MARK: - All CallsAdapterDelegate methods

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
}

// MARK: - Extension for CallsCoordinator to implement conference management protocol

extension CallsCoordinator: ConferenceManaging {
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
        //        guard let callManagementService = self.callManagementService,
        //              let inConferenceCalls = self.inConferenceCalls else {
        //            return Observable.error(CallServiceError.placeCallFailed)
        //        }

        let callManagementService = self.callManagementService
        let inConferenceCalls = self.inConferenceCalls

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
}

// MARK: - Extension for CallsCoordinator to implement media management protocol

extension CallsCoordinator: MediaManaging {
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
}

// MARK: - Extension for CallsCoordinator to implement message handling protocol

extension CallsCoordinator: MessageHandling {
    func sendVCard(callID: String, accountID: String) {
        messageHandlingService.sendVCard(callID: callID, accountID: accountID)
    }

    func sendTextMessage(callID: String, message: String, accountId: AccountModel) {
        messageHandlingService.sendTextMessage(callID: callID, message: message, accountId: accountId)
    }

    func sendChunk(callID: String, message: [String: String], accountId: String, from: String) {
        messageHandlingService.sendChunk(callID: callID, message: message, accountId: accountId, from: from)
    }
}

// MARK: - Public API for backwards compatibility (keeping references to original CallsService)

/**
 * This class is provided for backward compatibility with the original CallsService.
 * It maintains the same interface while delegating to the new coordinator-based implementation.
 */
class CallsService: CallManaging, ConferenceManaging, MessageHandling, MediaManaging, CallsAdapterObserving {
    private let coordinator: CallsCoordinator

    // Forward access to original properties
    var calls: BehaviorRelay<[String: CallModel]> { return coordinator.calls }
    var pendingConferences: [String: Set<String>] { return coordinator.pendingConferences }
    var createdConferences: Set<String> { return coordinator.createdConferences }
    var currentCallsEvents: ReplaySubject<CallModel> { return coordinator.currentCallsEvents }
    var newCall: BehaviorRelay<CallModel> { return coordinator.newCall }
    var sharedResponseStream: Observable<ServiceEvent> { return coordinator.sharedResponseStream }
    var newMessage: Observable<ServiceEvent> { return coordinator.newMessage }
    let dbManager: DBManager
    var currentConferenceEvent: BehaviorRelay<ConferenceUpdates> { return coordinator.currentConferenceEvent }
    var inConferenceCalls: PublishSubject<CallModel> { return coordinator.inConferenceCalls }
    var conferenceInfos: [String: [ConferenceParticipant]] { return coordinator.conferenceInfos }

    init(withCallsAdapter callsAdapter: CallsAdapter, dbManager: DBManager) {
        self.coordinator = CallsCoordinator(withCallsAdapter: callsAdapter, dbManager: dbManager)
        self.dbManager = dbManager
    }

    // MARK: - CallManaging

    func call(callID: String) -> CallModel? {
        return coordinator.call(callID: callID)
    }

    func callByUUID(UUID: String) -> CallModel? {
        return coordinator.callByUUID(UUID: UUID)
    }

    func accept(call: CallModel?) -> Completable {
        return coordinator.accept(call: call)
    }

    func refuse(callId: String) -> Completable {
        return coordinator.refuse(callId: callId)
    }

    func hangUp(callId: String) -> Completable {
        return coordinator.hangUp(callId: callId)
    }

    func hold(callId: String) -> Completable {
        return coordinator.hold(callId: callId)
    }

    func unhold(callId: String) -> Completable {
        return coordinator.unhold(callId: callId)
    }

    func placeCall(withAccount account: AccountModel, toParticipantId participantId: String, userName: String, videoSource: String, isAudioOnly: Bool, withMedia: [[String: String]]) -> Single<CallModel> {
        return coordinator.placeCall(withAccount: account, toParticipantId: participantId, userName: userName, videoSource: videoSource, isAudioOnly: isAudioOnly, withMedia: withMedia)
    }

    func answerCall(call: CallModel) -> Bool {
        return coordinator.answerCall(call: call)
    }

    func stopCall(call: CallModel) {
        coordinator.stopCall(call: call)
    }

    func stopPendingCall(callId: String) {
        coordinator.stopPendingCall(callId: callId)
    }

    func playDTMF(code: String) {
        coordinator.playDTMF(code: code)
    }

    func isCurrentCall() -> Bool {
        return coordinator.isCurrentCall()
    }

    // MARK: - ConferenceManaging

    func joinConference(confID: String, callID: String) {
        coordinator.joinConference(confID: confID, callID: callID)
    }

    func joinCall(firstCallId: String, secondCallId: String) {
        coordinator.joinCall(firstCallId: firstCallId, secondCallId: secondCallId)
    }

    func callAndAddParticipant(participant contactId: String, toCall callId: String, withAccount account: AccountModel, userName: String, videSource: String, isAudioOnly: Bool) -> Observable<CallModel> {
        return coordinator.callAndAddParticipant(participant: contactId, toCall: callId, withAccount: account, userName: userName, videSource: videSource, isAudioOnly: isAudioOnly)
    }

    func hangUpCallOrConference(callId: String) -> Completable {
        return coordinator.hangUpCallOrConference(callId: callId)
    }

    func isParticipant(participantURI: String?, activeIn conferenceId: String, accountId: String) -> Bool? {
        return coordinator.isParticipant(participantURI: participantURI, activeIn: conferenceId, accountId: accountId)
    }

    func isModerator(participantId: String, inConference confId: String) -> Bool {
        return coordinator.isModerator(participantId: participantId, inConference: confId)
    }

    func getConferenceParticipants(for conferenceId: String) -> [ConferenceParticipant]? {
        return coordinator.getConferenceParticipants(for: conferenceId)
    }

    func setActiveParticipant(conferenceId: String, maximixe: Bool, jamiId: String) {
        coordinator.setActiveParticipant(conferenceId: conferenceId, maximixe: maximixe, jamiId: jamiId)
    }

    func setModeratorParticipant(confId: String, participantId: String, active: Bool) {
        coordinator.setModeratorParticipant(confId: confId, participantId: participantId, active: active)
    }

    func hangupParticipant(confId: String, participantId: String, device: String) {
        coordinator.hangupParticipant(confId: confId, participantId: participantId, device: device)
    }

    func muteStream(confId: String, participantId: String, device: String, accountId: String, streamId: String, state: Bool) {
        coordinator.muteStream(confId: confId, participantId: participantId, device: device, accountId: accountId, streamId: streamId, state: state)
    }

    func setRaiseHand(confId: String, participantId: String, state: Bool, accountId: String, deviceId: String) {
        coordinator.setRaiseHand(confId: confId, participantId: participantId, state: state, accountId: accountId, deviceId: deviceId)
    }

    // MARK: - MessageHandling

    func sendVCard(callID: String, accountID: String) {
        coordinator.sendVCard(callID: callID, accountID: accountID)
    }

    func sendTextMessage(callID: String, message: String, accountId: AccountModel) {
        coordinator.sendTextMessage(callID: callID, message: message, accountId: accountId)
    }

    func sendChunk(callID: String, message: [String: String], accountId: String, from: String) {
        coordinator.sendChunk(callID: callID, message: message, accountId: accountId, from: from)
    }

    // MARK: - MediaManaging

    func getVideoCodec(call: CallModel) -> String? {
        return coordinator.getVideoCodec(call: call)
    }

    func audioMuted(call callId: String, mute: Bool) {
        coordinator.audioMuted(call: callId, mute: mute)
    }

    func videoMuted(call callId: String, mute: Bool) {
        coordinator.videoMuted(call: callId, mute: mute)
    }

    func callMediaUpdated(call: CallModel) {
        coordinator.callMediaUpdated(call: call)
    }

    func updateCallMediaIfNeeded(call: CallModel) {
        coordinator.updateCallMediaIfNeeded(call: call)
    }

    // MARK: - CallsAdapterObserving

    func didChangeCallState(withCallId callId: String, state: String, accountId: String, stateCode: NSInteger) {
        coordinator.didChangeCallState(withCallId: callId, state: state, accountId: accountId, stateCode: stateCode)
    }

    func didChangeMediaNegotiationStatus(withCallId callId: String, event: String, withMedia: [[String: String]]) {
        coordinator.didChangeMediaNegotiationStatus(withCallId: callId, event: event, withMedia: withMedia)
    }

    func didReceiveMediaChangeRequest(withAccountId accountId: String, callId: String, withMedia: [[String: String]]) {
        coordinator.didReceiveMediaChangeRequest(withAccountId: accountId, callId: callId, withMedia: withMedia)
    }

    func didReceiveMessage(withCallId callId: String, fromURI uri: String, message: [String: String]) {
        coordinator.didReceiveMessage(withCallId: callId, fromURI: uri, message: message)
    }

    func receivingCall(withAccountId accountId: String, callId: String, fromURI uri: String, withMedia mediaList: [[String: String]]) {
        coordinator.receivingCall(withAccountId: accountId, callId: callId, fromURI: uri, withMedia: mediaList)
    }

    func callPlacedOnHold(withCallId callId: String, holding: Bool) {
        coordinator.callPlacedOnHold(withCallId: callId, holding: holding)
    }

    func conferenceCreated(conference conferenceID: String, accountId: String) {
        coordinator.conferenceCreated(conference: conferenceID, accountId: accountId)
    }

    func conferenceChanged(conference conferenceID: String, accountId: String, state: String) {
        coordinator.conferenceChanged(conference: conferenceID, accountId: accountId, state: state)
    }

    func conferenceRemoved(conference conferenceID: String) {
        coordinator.conferenceRemoved(conference: conferenceID)
    }

    func remoteRecordingChanged(call callId: String, record: Bool) {
        coordinator.remoteRecordingChanged(call: callId, record: record)
    }

    func conferenceInfoUpdated(conference conferenceID: String, info: [[String: String]]) {
        coordinator.conferenceInfoUpdated(conference: conferenceID, info: info)
    }

    // MARK: - Additional utility methods

    func updateCallUUID(callId: String, callUUID: String) {
        coordinator.updateCallUUID(callId: callId, callUUID: callUUID)
    }

    // For backwards compatibility with existing references
    @objc
    func refuseUnansweredCall(_ notification: NSNotification) {
        coordinator.refuseUnansweredCall(notification)
    }
}

// MARK: - Factory classes

/// Factory for creating a call model
/// Follows the Factory Method pattern to create CallModel instances
class CallModelFactory {
    static func createCall(withId callId: String, callDetails: [String: String], withMedia mediaList: [[String: String]]) -> CallModel {
        return CallModel(withCallId: callId, callDetails: callDetails, withMedia: mediaList)
    }

    static func createOutgoingCall(participantId: String,
                                   accountId: String,
                                   userName: String,
                                   isAudioOnly: Bool,
                                   withMedia mediaList: [[String: String]]) -> CallModel {
        var callDetails = [String: String]()
        callDetails[CallDetailKey.callTypeKey.rawValue] = String(describing: CallType.outgoing)
        callDetails[CallDetailKey.displayNameKey.rawValue] = userName
        callDetails[CallDetailKey.accountIdKey.rawValue] = accountId
        callDetails[CallDetailKey.audioOnlyKey.rawValue] = isAudioOnly.toString()
        callDetails[CallDetailKey.timeStampStartKey.rawValue] = ""

        let call = CallModel(withCallId: participantId, callDetails: callDetails, withMedia: mediaList)
        call.state = .unknown
        call.callType = .outgoing
        call.participantUri = participantId
        return call
    }
}

/// Factory for creating media attributes
/// Follows the Factory Method pattern to create media attributes
class MediaAttributeFactory {
    static func createAudioMedia() -> [String: String] {
        var mediaAttribute = [String: String]()
        mediaAttribute[MediaAttributeKey.mediaType.rawValue] = MediaAttributeValue.audio.rawValue
        mediaAttribute[MediaAttributeKey.label.rawValue] = "audio_0"
        mediaAttribute[MediaAttributeKey.enabled.rawValue] = "true"
        mediaAttribute[MediaAttributeKey.muted.rawValue] = "false"
        return mediaAttribute
    }

    static func createVideoMedia(source: String) -> [String: String] {
        var mediaAttribute = [String: String]()
        mediaAttribute[MediaAttributeKey.mediaType.rawValue] = MediaAttributeValue.video.rawValue
        mediaAttribute[MediaAttributeKey.label.rawValue] = "video_0"
        mediaAttribute[MediaAttributeKey.source.rawValue] = source
        mediaAttribute[MediaAttributeKey.enabled.rawValue] = "true"
        mediaAttribute[MediaAttributeKey.muted.rawValue] = "false"
        return mediaAttribute
    }

    static func createDefaultMediaList(isAudioOnly: Bool, videoSource: String) -> [[String: String]] {
        var mediaList = [[String: String]]()
        mediaList.append(createAudioMedia())

        if !isAudioOnly {
            mediaList.append(createVideoMedia(source: videoSource))
        }

        return mediaList
    }
}

// MARK: - Extension for refactored call handling

extension CallsService {
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

        // This is a simplified version that delegates to the coordinator's placeCall method
        return coordinator.placeCall(withAccount: account,
                                     toParticipantId: participantId,
                                     userName: userName,
                                     videoSource: videoSource,
                                     isAudioOnly: isAudioOnly,
                                     withMedia: mediaList)
    }
}
/// Handles conference-related operations
class ConferenceManagementService: ConferenceManaging {
    private let callsAdapter: CallsAdapter
    private let calls: BehaviorRelay<[String: CallModel]>
    private var pendingConferences: [String: Set<String>]
    private var createdConferences: Set<String>
    private let currentCallsEvents: ReplaySubject<CallModel>
    private let currentConferenceEvent: BehaviorRelay<ConferenceUpdates>
    private var conferenceInfos: [String: [ConferenceParticipant]]
    private let disposeBag = DisposeBag()

    // Add reference to the CallManagementService
    private weak var callManagementService: CallManagementService?
    // Add reference to inConferenceCalls
    private weak var inConferenceCalls: PublishSubject<CallModel>?

    init(
        callsAdapter: CallsAdapter,
        calls: BehaviorRelay<[String: CallModel]>,
        pendingConferences: [String: Set<String>],
        createdConferences: Set<String>,
        currentCallsEvents: ReplaySubject<CallModel>,
        currentConferenceEvent: BehaviorRelay<ConferenceUpdates>,
        conferenceInfos: [String: [ConferenceParticipant]]
    ) {
        self.callsAdapter = callsAdapter
        self.calls = calls
        self.pendingConferences = pendingConferences
        self.createdConferences = createdConferences
        self.currentCallsEvents = currentCallsEvents
        self.currentConferenceEvent = currentConferenceEvent
        self.conferenceInfos = conferenceInfos
    }

    // Function to set callManagementService and inConferenceCalls
    func setupServices(callManagementService: CallManagementService, inConferenceCalls: PublishSubject<CallModel>) {
        self.callManagementService = callManagementService
        self.inConferenceCalls = inConferenceCalls
    }

    func joinConference(confID: String, callID: String) {
        guard let secondConf = self.calls.value[callID] else { return }
        guard let firstConf = self.calls.value[confID] else { return }
        if var pending = self.pendingConferences[confID] {
            pending.insert(callID)
            self.pendingConferences[confID] = pending
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
        guard let firstCall = self.calls.value[firstCallId] else { return }
        guard let secondCall = self.calls.value[secondCallId] else { return }
        if var pending = self.pendingConferences[firstCallId] {
            pending.insert(secondCallId)
            self.pendingConferences[firstCallId] = pending
        } else {
            self.pendingConferences[firstCallId] = [secondCallId]
        }
        self.callsAdapter.joinCall(firstCallId, second: secondCallId, accountId: firstCall.accountId, account2Id: secondCall.accountId)
    }

    func callAndAddParticipant(participant contactId: String,
                               toCall callId: String,
                               withAccount account: AccountModel,
                               userName: String,
                               videSource: String,
                               isAudioOnly: Bool = false) -> Observable<CallModel> {
        guard let callManagementService = self.callManagementService,
              let inConferenceCalls = self.inConferenceCalls else {
            return Observable.error(CallServiceError.placeCallFailed)
        }

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
        return Completable.create(subscribe: { completable in
            guard let call = self.calls.value[callId] else {
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

    func isParticipant(participantURI: String?, activeIn conferenceId: String, accountId: String) -> Bool? {
        guard let uri = participantURI,
              let participantsArray = self.callsAdapter.getConferenceInfo(conferenceId, accountId: accountId) as? [[String: String]] else { return nil }
        let participants = self.arrayToConferenceParticipants(participants: participantsArray, onlyURIAndActive: true)
        for participant in participants where participant.uri?.filterOutHost() == uri.filterOutHost() {
            return participant.isActive
        }
        return nil
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
        guard let conference = self.calls.value[conferenceId],
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

    func setModeratorParticipant(confId: String, participantId: String, active: Bool) {
        guard let conference = calls.value[confId] else { return }
        self.callsAdapter.setConferenceModerator(participantId, forConference: confId, accountId: conference.accountId, active: active)
    }

    func hangupParticipant(confId: String, participantId: String, device: String) {
        guard let conference = calls.value[confId] else { return }
        self.callsAdapter.hangupConferenceParticipant(participantId, forConference: confId, accountId: conference.accountId, deviceId: device)
    }

    func muteStream(confId: String, participantId: String, device: String, accountId: String, streamId: String, state: Bool) {
        self.callsAdapter.muteStream(participantId, forConference: confId, accountId: accountId, deviceId: device, streamId: streamId, state: state)
    }

    func setRaiseHand(confId: String, participantId: String, state: Bool, accountId: String, deviceId: String) {
        self.callsAdapter.raiseHand(participantId, forConference: confId, accountId: accountId, deviceId: deviceId, state: state)
    }

    private func arrayToConferenceParticipants(participants: [[String: String]], onlyURIAndActive: Bool) -> [ConferenceParticipant] {
        var conferenceParticipants = [ConferenceParticipant]()
        for participant in participants {
            conferenceParticipants.append(ConferenceParticipant(info: participant, onlyURIAndActive: onlyURIAndActive))
        }
        return conferenceParticipants
    }

    func updateConferences(callId: String) {
        let conferences = self.calls.value.keys.filter { (callID) -> Bool in
            guard let callModel = self.calls.value[callID] else { return false }
            return callModel.participantsCallId.count > 1 && callModel.participantsCallId.contains(callId)
        }

        guard let conferenceID = conferences.first, let conference = calls.value[conferenceID] else { return }
        let conferenceCalls = Set(self.callsAdapter
                                    .getConferenceCalls(conferenceID, accountId: conference.accountId))
        conference.participantsCallId = conferenceCalls
        conferenceCalls.forEach { (callID) in
            self.calls.value[callID]?.participantsCallId = conferenceCalls
        }
    }

    func handleConferenceCreated(conference conferenceID: String, accountId: String) {
        let conferenceCalls = Set(self.callsAdapter
                                    .getConferenceCalls(conferenceID, accountId: accountId))
        if conferenceCalls.isEmpty {
            // no calls attached to a conference. Wait until conference changed to check the calls.
            createdConferences.insert(conferenceID)
            return
        }
        createdConferences.remove(conferenceID)
        for (callId, pendingSet) in pendingConferences {
            if !conferenceCalls.contains(callId) ||
                conferenceCalls.isDisjoint(with: pendingSet) {
                continue
            }
            var values = pendingSet
            // update pending conferences
            // replace callID by new Conference ID, and remove calls that was already added to conference
            values.subtract(conferenceCalls)
            self.pendingConferences[callId] = nil
            if !values.isEmpty {
                self.pendingConferences[conferenceID] = values
            }
            // update calls and add conference
            self.calls.value[callId]?.participantsCallId = conferenceCalls
            values.forEach { (call) in
                self.calls.value[call]?.participantsCallId = conferenceCalls
            }
            guard var callDetails = self.callsAdapter.getConferenceDetails(conferenceID, accountId: accountId) else { return }
            callDetails[CallDetailKey.accountIdKey.rawValue] = self.calls.value[callId]?.accountId
            callDetails[CallDetailKey.audioOnlyKey.rawValue] = self.calls.value[callId]?.isAudioOnly.toString()
            let mediaList = [[String: String]]()
            let conf = CallModel(withCallId: conferenceID, callDetails: callDetails, withMedia: mediaList)
            conf.participantsCallId = conferenceCalls
            var value = self.calls.value
            value[conferenceID] = conf
            self.calls.accept(value)
            currentConferenceEvent.accept(ConferenceUpdates(conferenceID, ConferenceState.conferenceCreated.rawValue, conferenceCalls))
        }
    }

    func handleConferenceChanged(conference conferenceID: String, accountId: String, state: String) {
        if createdConferences.contains(conferenceID) {
            // a conference was created but calls was not attached to a conference. In this case a conference should be added first.
            self.handleConferenceCreated(conference: conferenceID, accountId: accountId)
            return
        }
        guard let conference = self.calls.value[conferenceID] else { return }
        let conferenceCalls = Set(self.callsAdapter
                                    .getConferenceCalls(conferenceID, accountId: conference.accountId))
        conference.participantsCallId = conferenceCalls
        conferenceCalls.forEach { (callId) in
            guard let call = self.calls.value[callId] else { return }
            call.participantsCallId = conferenceCalls
            var values = self.calls.value
            values[callId] = call
            self.calls.accept(values)
        }
    }

    func handleConferenceRemoved(conference conferenceID: String) {
        guard let conference = self.calls.value[conferenceID] else { return }
        self.conferenceInfos[conferenceID] = nil
        self.currentConferenceEvent.accept(ConferenceUpdates(conferenceID, ConferenceState.infoUpdated.rawValue, [""]))
        self.currentConferenceEvent.accept(ConferenceUpdates(conferenceID, ConferenceState.conferenceDestroyed.rawValue, conference.participantsCallId))
        var values = self.calls.value
        values[conferenceID] = nil
        self.calls.accept(values)
    }

    func handleConferenceInfoUpdated(conference conferenceID: String, info: [[String: String]]) {
        let participants = self.arrayToConferenceParticipants(participants: info, onlyURIAndActive: false)
        self.conferenceInfos[conferenceID] = participants
        currentConferenceEvent.accept(ConferenceUpdates(conferenceID, ConferenceState.infoUpdated.rawValue, [""]))
    }

    func clearPendingConferences(callId: String) {
        // clear pending conferences if need
        if self.pendingConferences.keys.contains(callId) {
            self.pendingConferences[callId] = nil
        }

        for (confId, pendingCalls) in pendingConferences {
            if let index = pendingCalls.firstIndex(of: callId) {
                var updatedCalls = pendingCalls
                updatedCalls.remove(at: index)
                if updatedCalls.isEmpty {
                    self.pendingConferences[confId] = nil
                } else {
                    self.pendingConferences[confId] = updatedCalls
                }
            }
        }
    }

    func shouldCallBeAddedToConference(callId: String) -> String? {
        var confId: String?
        self.pendingConferences.keys.forEach { [weak self] (initialCall) in
            guard let self = self,
                  let pendigs = self.pendingConferences[initialCall],
                  !pendigs.isEmpty
            else { return }
            if pendigs.contains(callId) {
                confId = initialCall
            }
        }
        return confId
    }
}

/// Handles media-related operations
class MediaManagementService: MediaManaging {
    private let callsAdapter: CallsAdapter
    private let calls: BehaviorRelay<[String: CallModel]>
    private let currentCallsEvents: ReplaySubject<CallModel>

    init(
        callsAdapter: CallsAdapter,
        calls: BehaviorRelay<[String: CallModel]>,
        currentCallsEvents: ReplaySubject<CallModel>
    ) {
        self.callsAdapter = callsAdapter
        self.calls = calls
        self.currentCallsEvents = currentCallsEvents
    }

    func getVideoCodec(call: CallModel) -> String? {
        let callDetails = self.callsAdapter.callDetails(withCallId: call.callId, accountId: call.accountId)
        return callDetails?[CallDetailKey.videoCodec.rawValue]
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

    /// Handles a change in the remote recording state
    func handleRemoteRecordingChanged(callId: String, record: Bool) {
        guard let call = self.calls.value[callId] else {
            return
        }
        call.callRecorded = record
        self.currentCallsEvents.onNext(call)
    }

    /// Handles when a call is placed on hold
    func handleCallPlacedOnHold(callId: String, holding: Bool) {
        guard let call = self.calls.value[callId] else {
            return
        }
        call.peerHolding = holding
        self.currentCallsEvents.onNext(call)
    }

    /// Updates media negotiation status based on an event
    func handleMediaNegotiationStatus(callId: String, event: String, media: [[String: String]]) {
        guard let call = self.calls.value[callId],
              let callDictionary = self.callsAdapter.callDetails(withCallId: callId, accountId: call.accountId) else { return }
        call.update(withDictionary: callDictionary, withMedia: media)
        self.currentCallsEvents.onNext(call)
    }

    /// Handles a request to change media
    func handleMediaChangeRequest(accountId: String, callId: String, media: [[String: String]]) {
        guard let call = self.calls.value[callId] else { return }
        var currentMediaLabels = [String]()
        for media in call.mediaList where media[MediaAttributeKey.label.rawValue] != nil {
            currentMediaLabels.append(media[MediaAttributeKey.label.rawValue]!)
        }

        var answerMedias = [[String: String]]()
        for media in media {
            let label = media[MediaAttributeKey.label.rawValue] ?? ""
            let index = currentMediaLabels.firstIndex(of: label) ?? -1
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
}

/// Handles call adapter observation events and delegates appropriately
class CallsAdapterObservingService: CallsAdapterObserving {
    private weak var coordinator: CallsCoordinator?
    private let callsAdapter: CallsAdapter
    private let calls: BehaviorRelay<[String: CallModel]>
    private let currentCallsEvents: ReplaySubject<CallModel>
    private let newCall: BehaviorRelay<CallModel>
    private let responseStream: PublishSubject<ServiceEvent>
    private let newMessagesStream: PublishSubject<ServiceEvent>
    private let ringVCardMIMEType = "x-ring/ring.profile.vcard;"

    init(
        coordinator: CallsCoordinator?,
        callsAdapter: CallsAdapter,
        calls: BehaviorRelay<[String: CallModel]>,
        currentCallsEvents: ReplaySubject<CallModel>,
        newCall: BehaviorRelay<CallModel>,
        responseStream: PublishSubject<ServiceEvent>,
        newMessagesStream: PublishSubject<ServiceEvent>
    ) {
        self.coordinator = coordinator
        self.callsAdapter = callsAdapter
        self.calls = calls
        self.currentCallsEvents = currentCallsEvents
        self.newCall = newCall
        self.responseStream = responseStream
        self.newMessagesStream = newMessagesStream
    }

    /// Set the coordinator after initialization to avoid circular reference issues
    func setCoordinator(_ coordinator: CallsCoordinator) {
        self.coordinator = coordinator
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
                self.coordinator?.clearPendingConferences(callId: callId)
                self.coordinator?.updateConferences(callId: callId)
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
                self.coordinator?.sendVCard(callID: callId, accountID: updatedCall.accountId)
            }

            // Handle current state changes
            if updatedCall.state == .current {
                self.coordinator?.handleCallBecomingCurrent(callId: callId, accountId: accountId)
            }

            // Emit the call to observers
            self.currentCallsEvents.onNext(updatedCall)
        }
    }

    func didChangeMediaNegotiationStatus(withCallId callId: String, event: String, withMedia: [[String: String]]) {
        // This is now handled directly in the coordinator and delegated to MediaManagementService
    }

    func didReceiveMediaChangeRequest(withAccountId accountId: String, callId: String, withMedia: [[String: String]]) {
        // This is now handled directly in the coordinator and delegated to MediaManagementService
    }

    func didReceiveMessage(withCallId callId: String, fromURI uri: String, message: [String: String]) {
        // This is now handled directly in the coordinator and delegated to MessageHandlingService
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
        // This is now handled directly in the coordinator and delegated to MediaManagementService
    }

    func conferenceCreated(conference conferenceID: String, accountId: String) {
        self.coordinator?.handleConferenceCreated(conference: conferenceID, accountId: accountId)
    }

    func conferenceChanged(conference conferenceID: String, accountId: String, state: String) {
        self.coordinator?.handleConferenceChanged(conference: conferenceID, accountId: accountId, state: state)
    }

    func conferenceRemoved(conference conferenceID: String) {
        self.coordinator?.handleConferenceRemoved(conference: conferenceID)
    }

    func remoteRecordingChanged(call callId: String, record: Bool) {
        // This is now handled directly in the coordinator and delegated to MediaManagementService
    }

    func conferenceInfoUpdated(conference conferenceID: String, info: [[String: String]]) {
        self.coordinator?.handleConferenceInfoUpdated(conference: conferenceID, info: info)
    }
}

/// Handles message-related operations
class MessageHandlingService: MessageHandling {
    private let callsAdapter: CallsAdapter
    private let dbManager: DBManager
    private let calls: BehaviorRelay<[String: CallModel]>
    private let newMessagesStream: PublishSubject<ServiceEvent>
    private let ringVCardMIMEType = "x-ring/ring.profile.vcard;"

    init(
        callsAdapter: CallsAdapter,
        dbManager: DBManager,
        calls: BehaviorRelay<[String: CallModel]>,
        newMessagesStream: PublishSubject<ServiceEvent>
    ) {
        self.callsAdapter = callsAdapter
        self.dbManager = dbManager
        self.calls = calls
        self.newMessagesStream = newMessagesStream
    }

    func sendVCard(callID: String, accountID: String) {
        if accountID.isEmpty || callID.isEmpty {
            return
        }
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            guard let profile = self.dbManager.accountVCard(for: accountID) else { return }
            let jamiId = profile.uri
            VCardUtils.sendVCard(card: profile,
                                 callID: callID,
                                 accountID: accountID,
                                 sender: self, from: jamiId)
        }
    }

    func sendTextMessage(callID: String, message: String, accountId: AccountModel) {
        guard let call = self.calls.value[callID] else { return }
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

    /// Handles an incoming message
    func handleIncomingMessage(callId: String, fromURI: String, message: [String: String]) {
        guard let call = self.calls.value[callId] else { return }
        if message.keys.filter({ $0.hasPrefix(self.ringVCardMIMEType) }).first != nil {
            var data = [String: Any]()
            data[ProfileNotificationsKeys.ringID.rawValue] = fromURI
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
        event.addEventInput(.peerUri, value: fromURI.filterOutHost())
        event.addEventInput(.name, value: name)
        event.addEventInput(.accountId, value: accountId)
        self.newMessagesStream.onNext(event)
    }
}

/// Handles call-related operations
class CallManagementService: CallManaging {
    private let callsAdapter: CallsAdapter
    private let calls: BehaviorRelay<[String: CallModel]>
    private let currentCallsEvents: ReplaySubject<CallModel>
    private let responseStream: PublishSubject<ServiceEvent>
    private let disposeBag = DisposeBag()

    init(
        callsAdapter: CallsAdapter,
        calls: BehaviorRelay<[String: CallModel]>,
        currentCallsEvents: ReplaySubject<CallModel>,
        responseStream: PublishSubject<ServiceEvent>
    ) {
        self.callsAdapter = callsAdapter
        self.calls = calls
        self.currentCallsEvents = currentCallsEvents
        self.responseStream = responseStream
    }

    func call(callID: String) -> CallModel? {
        return calls.value[callID]
    }

    func callByUUID(UUID: String) -> CallModel? {
        return calls.value.values.filter { call in
            call.callUUID.uuidString == UUID
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

    func placeCall(withAccount account: AccountModel,
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
            mediaList = MediaAttributeFactory.createDefaultMediaList(isAudioOnly: isAudioOnly, videoSource: videoSource)
        }

        let call = CallModelFactory.createOutgoingCall(
            participantId: participantId,
            accountId: account.id,
            userName: userName,
            isAudioOnly: isAudioOnly,
            withMedia: mediaList
        )

        return Single<CallModel>.create(subscribe: { [weak self] single in
            if let self = self, let callId = self.callsAdapter.placeCall(withAccountId: account.id,
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
                single(.failure(CallServiceError.placeCallFailed))
            }
            return Disposables.create { }
        })
    }

    func answerCall(call: CallModel) -> Bool {
        NSLog("call service answerCall %@", call.callId)
        return self.callsAdapter.acceptCall(withId: call.callId, accountId: call.accountId, withMedia: call.mediaList)
    }

    func stopCall(call: CallModel) {
        self.callsAdapter.hangUpCall(call.callId, accountId: call.accountId)
    }

    func stopPendingCall(callId: String) {
        guard let call = self.call(callID: callId) else { return }
        self.stopCall(call: call)
    }

    func playDTMF(code: String) {
        self.callsAdapter.playDTMF(code)
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

    /// Updates or adds a call in the calls map
    func updateCall(callId: String, callState: CallState, callDictionary: [String: String], mediaList: [[String: String]] = [[String: String]]()) -> CallModel? {
        var call = self.calls.value[callId]

        if call == nil {
            if !callState.isActive() {
                return nil
            }
            call = CallModel(withCallId: callId, callDetails: callDictionary, withMedia: mediaList)
            var values = self.calls.value
            values[callId] = call
            self.calls.accept(values)
        } else {
            call?.update(withDictionary: callDictionary, withMedia: mediaList)
        }

        return call
    }

    /// Removes a call from the calls map
    func removeCall(callId: String, callState: CallState) {
        guard let finishedCall = self.calls.value[callId],
              callState == .over || callState == .failure else { return }

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
    }

    /// Method to update a call's UUID
    func updateCallUUID(callId: String, callUUID: String) {
        if let call = self.call(callID: callId), let uuid = UUID(uuidString: callUUID) {
            call.callUUID = uuid
        }
    }
}
