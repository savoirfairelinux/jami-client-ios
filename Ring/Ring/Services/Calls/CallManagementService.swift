/*
 * Copyright (C) 2017-2025 Savoir-faire Linux Inc.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA.
 */

import RxSwift
import RxRelay

enum CallServiceError: Error, LocalizedError {
    case acceptCallFailed
    case declineCallFailed
    case hangUpCallFailed
    case holdCallFailed
    case unholdCallFailed
    case placeCallFailed
    case callNotFound
    case invalidUUID

    var errorDescription: String? {
        switch self {
        case .acceptCallFailed:
            return "Failed to accept call"
        case .declineCallFailed:
            return "Failed to decline call"
        case .hangUpCallFailed:
            return "Failed to hang up call"
        case .holdCallFailed:
            return "Failed to hold call"
        case .unholdCallFailed:
            return "Failed to unhold call"
        case .placeCallFailed:
            return "Failed to place call"
        case .callNotFound:
            return "Call not found"
        case .invalidUUID:
            return "Invalid call UUID"
        }
    }
}

class CallManagementService {
    // MARK: - Properties

    private let callsAdapter: CallsAdapter
    private let calls: SynchronizedRelay<[String: CallModel]>
    private let callUpdates: ReplaySubject<CallModel>
    private let responseStream: PublishSubject<ServiceEvent>
    private let disposeBag = DisposeBag()

    // MARK: - Initialization

    init(
        callsAdapter: CallsAdapter,
        calls: SynchronizedRelay<[String: CallModel]>,
        callUpdates: ReplaySubject<CallModel>,
        responseStream: PublishSubject<ServiceEvent>
    ) {
        self.callsAdapter = callsAdapter
        self.calls = calls
        self.callUpdates = callUpdates
        self.responseStream = responseStream
    }

    // MARK: - Call Access

    func call(callId: String) -> CallModel? {
        return calls.get()[callId]
    }

    func call(participantId: String, accountId: String) -> CallModel? {
        return calls.get().values.first(where: { $0.paricipantHash() == participantId && $0.accountId == accountId })
    }

    func callByUUID(UUID: String) -> CallModel? {
        return calls.get().values.first(where: { $0.callUUID.uuidString == UUID })
    }

    // MARK: - Call Management

    func accept(callId: String) -> Completable {
        return createObservableAction(callId: callId, error: .acceptCallFailed) { [weak self] call in
            guard let self = self else { return false }
            return self.callsAdapter.acceptCall(withId: call.callId, accountId: call.accountId, withMedia: call.mediaList)
        }
    }

    func decline(callId: String) -> Completable {
        return createObservableAction(callId: callId, error: .declineCallFailed) { [weak self] call in
            guard let self = self else { return false }
            return self.callsAdapter.declineCall(withId: callId, accountId: call.accountId)
        }
    }

    func hangUp(callId: String) -> Completable {
        return createObservableAction(callId: callId, error: .hangUpCallFailed) { [weak self] call in
            guard let self = self else { return false }
            return self.callsAdapter.hangUpCall(callId, accountId: call.accountId)
        }
    }

    func hold(callId: String) -> Completable {
        return createObservableAction(callId: callId, error: .holdCallFailed) { [weak self] call in
            guard let self = self else { return false }
            return self.callsAdapter.holdCall(withId: callId, accountId: call.accountId)
        }
    }

    func unhold(callId: String) -> Completable {
        return createObservableAction(callId: callId, error: .unholdCallFailed) { [weak self] call in
            guard let self = self else { return false }
            return self.callsAdapter.unholdCall(withId: callId, accountId: call.accountId)
        }
    }

    func placeCall(withAccount account: AccountModel,
                   toParticipantId participantId: String,
                   userName: String,
                   videoSource: String,
                   isAudioOnly: Bool = false,
                   withMedia: [[String: String]] = [[String: String]]()) -> Single<CallModel> {

        return prepareCallModel(
            account: account,
            participantId: participantId,
            userName: userName,
            videoSource: videoSource,
            isAudioOnly: isAudioOnly,
            withMedia: withMedia
        )
        .flatMap { [weak self] callModel -> Single<CallModel> in
            guard let self = self else {
                return Single.error(CallServiceError.placeCallFailed)
            }
            return self.executeCall(callModel: callModel, account: account, participantId: participantId)
        }
    }

    private func prepareCallModel(
        account: AccountModel,
        participantId: String,
        userName: String,
        videoSource: String,
        isAudioOnly: Bool,
        withMedia: [[String: String]]
    ) -> Single<CallModel> {

        var mediaList: [[String: String]] = []

        if participantId.contains("rdv:") || participantId.contains("swarm:") {
            // When joining a group conversation call, create both audio and video streams,
            // muting video if needed while still allowing incoming video to be received
            mediaList = MediaAttributeFactory.createCompleteMediaList(isVideoMuted: isAudioOnly, videoSource: videoSource)
        } else {
            mediaList = withMedia.isEmpty ?
                MediaAttributeFactory.createDefaultMediaList(isAudioOnly: isAudioOnly, videoSource: videoSource) :
                withMedia
        }

        let call = CallModelFactory.createOutgoingCall(
            participantId: participantId,
            accountId: account.id,
            userName: userName,
            isAudioOnly: isAudioOnly,
            withMedia: mediaList
        )

        return Single.just(call)
    }

    private func executeCall(
        callModel: CallModel,
        account: AccountModel,
        participantId: String
    ) -> Single<CallModel> {
        return Single<CallModel>.create { [weak self] single in
            guard let self = self else {
                single(.failure(CallServiceError.placeCallFailed))
                return Disposables.create()
            }

            let callId = self.initiateCall(account: account, participantId: participantId, mediaList: callModel.mediaList)
            if callId.isEmpty {
                single(.failure(CallServiceError.placeCallFailed))
                return Disposables.create()
            }

            guard let callDictionary = self.getCallDetails(callId: callId, accountId: account.id) else {
                single(.failure(CallServiceError.placeCallFailed))
                return Disposables.create()
            }

            callModel.updateWith(callId: callId, callDictionary: callDictionary, participantId: participantId)
            self.updateCallsStore(callModel, forId: callId)

            // self.emitCallStarted(call: callModel)
            single(.success(callModel))

            return Disposables.create()
        }
    }

    private func initiateCall(account: AccountModel, participantId: String, mediaList: [[String: String]]) -> String {
        guard let callId = self.callsAdapter.placeCall(
            withAccountId: account.id,
            toParticipantId: participantId,
            withMedia: mediaList
        ) else {
            return ""
        }
        return callId
    }

    func getCallDetails(callId: String, accountId: String) -> [String: String]? {
        return self.callsAdapter.callDetails(
            withCallId: callId,
            accountId: accountId
        )
    }

    func createSwarmCallModel(conference: (confId: String, conversationId: String, accountId: String), isAudioOnly: Bool) -> CallModel {
        let call = CallModel()
        call.state = .connecting
        call.callType = .outgoing
        call.accountId = conference.accountId
        call.callId = conference.confId
        call.conversationId = conference.conversationId
        call.isAudioOnly = isAudioOnly

        calls.update { calls in
            calls[call.callId] = call
        }

        return call
    }
    
    func createPlaceholderCallModel(callUUID: UUID, peerId: String, accountId: String) -> CallModel {
        let call = CallModel()
        call.callUUID = callUUID
        call.callUri = peerId
        call.displayName = peerId
        call.accountId = accountId
        call.state = .connecting
        call.callType = .incoming
        call.callId = callUUID.uuidString
        
        calls.update { calls in
            calls[call.callId] = call
        }
        
        return call
    }

    func isCurrentCall() -> Bool {
        return calls.get().values.contains { $0.isCurrent() }
    }

    // MARK: - Call State Management

    func addOrUpdateCall(callId: String, callState: CallState, callDictionary: [String: String], mediaList: [[String: String]] = [[String: String]](), notifyIncoming: Bool = false) -> CallModel? {
        var call = self.calls.get()[callId]

        if call == nil {
            if !callState.isActive() {
                return nil
            }
            
            // Check if there's a placeholder call that we should replace
            let peerUri = callDictionary[CallDetailKey.peerNumberKey.rawValue] ?? ""
            let peerHash = peerUri.filterOutHost()
            let existingPlaceholder = self.calls.get().values.first { existingCall in
                // A placeholder has callId == UUID string and callUri matching the peer
                existingCall.callId == existingCall.callUUID.uuidString &&
                existingCall.paricipantHash() == peerHash &&
                existingCall.state == .connecting
            }
            
            if let placeholder = existingPlaceholder {
                // Replace placeholder with real call, keeping the UUID
                call = CallModel(withCallId: callId, callDetails: callDictionary, withMedia: mediaList)
                call?.callUUID = placeholder.callUUID
                call?.state = callState
                calls.update { calls in
                    calls.removeValue(forKey: placeholder.callId)
                }
                updateCallsStore(call!, forId: callId)
            } else {
                call = CallModel(withCallId: callId, callDetails: callDictionary, withMedia: mediaList)
                call?.state = callState
                updateCallsStore(call!, forId: callId)
            }
        } else {
            call?.update(withDictionary: callDictionary, withMedia: mediaList)
            call?.state = callState
        }

        guard let updatedCall = call else { return nil }
        self.callUpdates.onNext(updatedCall)

        if notifyIncoming {
            notifyIncomingCall(call: updatedCall)
        }
        return updatedCall
    }

    private func notifyIncomingCall(call: CallModel) {
        var event = ServiceEvent(withEventType: .incomingCall)
        event.addEventInput(.peerUri, value: call.callUri)
        event.addEventInput(.callUUID, value: call.callUUID.uuidString)
        event.addEventInput(.accountId, value: call.accountId)
        event.addEventInput(.callId, value: call.callId)
        self.responseStream.onNext(event)
    }

    func removeCall(callId: String, callState: CallState) {
        guard let finishedCall = self.call(callId: callId) else {
            return
        }

        finishedCall.state = callState

        let callDuration = self.calculateCallDuration(finishedCall)
        self.emitCallEnded(call: finishedCall, duration: callDuration)

        self.callUpdates.onNext(finishedCall)

        self.calls.update { calls in
            calls[callId] = nil
        }
    }

    func updateCallUUID(callId: String, callUUID: String) {
        guard let call = self.call(callId: callId),
              let uuid = UUID(uuidString: callUUID) else {
            return
        }

        call.callUUID = uuid
    }

    // MARK: - Private Helpers

    private func createObservableAction(callId: String, error: CallServiceError, action: @escaping (CallModel) -> Bool) -> Completable {
        return Completable.create { [weak self] completable in
            guard let self = self else {
                completable(.error(CallServiceError.callNotFound))
                return Disposables.create()
            }

            guard let call = self.call(callId: callId) else {
                completable(.error(CallServiceError.callNotFound))
                return Disposables.create()
            }

            let success = action(call)
            if success {
                completable(.completed)
            } else {
                completable(.error(error))
            }

            return Disposables.create()
        }
    }

    private func updateCallsStore(_ call: CallModel, forId callId: String) {
        self.calls.update { calls in
            calls[callId] = call
        }
    }

    private func calculateCallDuration(_ call: CallModel) -> Int {
        guard let startTime = call.dateReceived else { return 0 }
        return Int(Date().timeIntervalSince1970 - startTime.timeIntervalSince1970)
    }

    // MARK: - Event Emission

    private func emitCallEnded(call: CallModel, duration: Int) {
        var event = ServiceEvent(withEventType: .callEnded)
        configureBasicCallEvent(&event, for: call)
        event.addEventInput(.callTime, value: duration)
        self.responseStream.onNext(event)
    }

    private func configureBasicCallEvent(_ event: inout ServiceEvent, for call: CallModel) {
        event.addEventInput(.peerUri, value: call.callUri)
        event.addEventInput(.callUUID, value: call.callUUID.uuidString)
        event.addEventInput(.accountId, value: call.accountId)
        event.addEventInput(.callId, value: call.callId)
        event.addEventInput(.callType, value: call.callType.rawValue)
    }
}

class CallModelFactory {
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
        call.callUri = participantId
        return call
    }
}
