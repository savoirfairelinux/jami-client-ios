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

enum ConferenceState: String {
    case conferenceCreated
    case conferenceDestroyed
    case infoUpdated
    case activeAttachd
}

typealias ConferenceUpdates = (conferenceID: String, state: String, calls: Set<String>)

class ConferenceManagementService {
    private let callsAdapter: CallsAdapter
    private let calls: SynchronizedRelay<[String: CallModel]>
    private let callUpdates: ReplaySubject<CallModel>

    private let pendingConferencesRelay = BehaviorRelay<PendingConferencesType>(value: [:])
    let createdConferencesRelay = BehaviorRelay<Set<String>>(value: [])
    private let conferenceInfosRelay = BehaviorRelay<ConferenceInfosType>(value: [:])

    private let disposeBag = DisposeBag()

    let inConferenceCalls = PublishSubject<CallModel>()
    let currentConferenceEvent: BehaviorRelay<ConferenceUpdates>

    init(
        callsAdapter: CallsAdapter,
        calls: SynchronizedRelay<[String: CallModel]>,
        callUpdates: ReplaySubject<CallModel>
    ) {
        self.callsAdapter = callsAdapter
        self.calls = calls
        self.callUpdates = callUpdates
        self.currentConferenceEvent = BehaviorRelay<ConferenceUpdates>(value: ("", "", Set<String>()))
    }

    // MARK: - Conference Management

    func joinConference(confID: String, callID: String) {
        guard let secondConf = calls.get()[callID],
              let firstConf = calls.get()[confID] else { return }

        updatePendingConferences(mainCallId: confID, callToAdd: callID)

        if secondConf.participantsCallId.count == 1 {
            callsAdapter.joinConference(confID, call: callID, accountId: firstConf.accountId, account2Id: secondConf.accountId)
        } else {
            callsAdapter.joinConferences(confID, secondConference: callID, accountId: firstConf.accountId, account2Id: secondConf.accountId)
        }
    }

    func joinCall(firstCallId: String, secondCallId: String) {
        guard let firstCall = calls.get()[firstCallId],
              let secondCall = calls.get()[secondCallId] else { return }

        updatePendingConferences(mainCallId: firstCallId, callToAdd: secondCallId)
        callsAdapter.joinCall(firstCallId, second: secondCallId, accountId: firstCall.accountId, account2Id: secondCall.accountId)
    }

    func addCall(call: CallModel, to callId: String) {
        updatePendingConferences(mainCallId: callId, callToAdd: call.callId)
        self.inConferenceCalls.onNext(call)
    }

    func endCallOrConference(callId: String, isSwarm: Bool) -> Completable {
        return Completable.create { [weak self] completable in
            guard let self = self,
                  let call = self.calls.get()[callId] else {
                completable(.error(CallServiceError.endCallFailed))
                return Disposables.create()
            }

            let success = self.endCall(callId: callId, call: call, isSwarm: isSwarm)

            if success {
                completable(.completed)
            } else {
                completable(.error(CallServiceError.endCallFailed))
            }

            return Disposables.create()
        }
    }

    private func endCall(callId: String, call: CallModel, isSwarm: Bool) -> Bool {
        if call.participantsCallId.count >= 2 || isSwarm {
            return callsAdapter.disconnectConference(callId, accountId: call.accountId) ||
                callsAdapter.endCall(callId, accountId: call.accountId)
        } else {
            return callsAdapter.endCall(callId, accountId: call.accountId)
        }
    }

    // MARK: - Participant Management

    /// Checks if a participant is active in a conference
    /// - Returns: true if the participant is active, false if not, nil if no participant
    func isParticipant(participantURI: String?, activeIn conferenceId: String, accountId: String) -> Bool? {
        guard let uri = participantURI else { return false }
        guard let participants = conferenceInfosRelay.value[conferenceId] else {
            guard let participantsArray = callsAdapter.getConferenceInfo(conferenceId, accountId: accountId) as? [[String: String]] else {
                return nil
            }

            let normalizedURI = uri.filterOutHost()
            for participant in participantsArray {
                if let participantURI = participant["uri"]?.filterOutHost(),
                   participantURI == normalizedURI {
                    return ConferenceParticipant(info: participant, onlyURIAndActive: true).isActive
                }
            }

            return nil
        }

        let normalizedURI = uri.filterOutHost()
        return participants.first(where: { $0.uri?.filterOutHost() == normalizedURI })?.isActive
    }

    func isModerator(participantId: String, inConference confId: String) -> Bool {
        guard let participants = conferenceInfosRelay.value[confId] else { return false }

        return participants.first(where: {
            $0.uri?.filterOutHost() == participantId.filterOutHost()
        })?.isModerator ?? false
    }

    func getConferenceParticipants(for conferenceId: String) -> [ConferenceParticipant]? {
        return conferenceInfosRelay.value[conferenceId]
    }

    func setActiveParticipant(conferenceId: String, maximixe: Bool, jamiId: String) {
        guard let conference = self.calls.get()[conferenceId],
              let isActive = self.isParticipant(participantURI: jamiId, activeIn: conferenceId, accountId: conference.accountId) else {
            return
        }

        let newLayout = isActive ? self.getNewLayoutForActiveParticipant(currentLayout: conference.layout, maximixe: maximixe) : .oneWithSmal
        conference.layout = newLayout

        self.callsAdapter.setActiveParticipant(jamiId, forConference: conferenceId, accountId: conference.accountId)
        self.callsAdapter.setConferenceLayout(newLayout.rawValue, forConference: conferenceId, accountId: conference.accountId)
    }

    func setModeratorParticipant(confId: String, participantId: String, active: Bool) {
        guard let conference = calls.get()[confId] else { return }
        callsAdapter.setConferenceModerator(participantId, forConference: confId, accountId: conference.accountId, active: active)
    }

    func disconnectParticipant(confId: String, participantId: String, device: String) {
        guard let conference = calls.get()[confId] else { return }
        callsAdapter.disconnectConferenceParticipant(participantId, forConference: confId, accountId: conference.accountId, deviceId: device)
    }

    func muteStream(confId: String, participantId: String, device: String, accountId: String, streamId: String, state: Bool) {
        callsAdapter.muteStream(participantId, forConference: confId, accountId: accountId, deviceId: device, streamId: streamId, state: state)
    }

    func setRaiseHand(confId: String, participantId: String, state: Bool, accountId: String, deviceId: String) {
        callsAdapter.raiseHand(participantId, forConference: confId, accountId: accountId, deviceId: deviceId, state: state)
    }

    // MARK: - Conference State Management

    func updateConferences(callId: String) async {
        calls.update { calls in
            let conferencesWithCall = calls.keys.filter { conferenceId -> Bool in
                guard let callModel = calls[conferenceId] else { return false }
                return callModel.participantsCallId.count > 1 && callModel.participantsCallId.contains(callId)
            }

            guard let conferenceId = conferencesWithCall.first,
                  let conference = calls[conferenceId] else { return }

            let conferenceCalls = Set(self.callsAdapter.getConferenceCalls(conferenceId, accountId: conference.accountId))

            conference.participantsCallId = conferenceCalls

            for callId in conferenceCalls {
                if let call = calls[callId] {
                    call.participantsCallId = conferenceCalls
                }
            }
        }
    }

    private func getConferenceParticipants(conferenceId: String, accountId: String) -> Set<String> {
        return Set(self.callsAdapter.getConferenceCalls(conferenceId, accountId: accountId))
    }

    private func registerEmptyConference(conferenceId: String) {
        var createdConferences = self.createdConferencesRelay.value
        createdConferences.insert(conferenceId)
        self.createdConferencesRelay.accept(createdConferences)
    }

    private func markConferenceAsProcessed(conferenceId: String) {
        var createdConferences = self.createdConferencesRelay.value
        createdConferences.remove(conferenceId)
        self.createdConferencesRelay.accept(createdConferences)
    }

    private func processPendingParticipants(
        conferenceId: String,
        conferenceCalls: Set<String>
    ) -> (sourceCallId: String?, updatedPendingConferences: [String: Set<String>]) {
        let pendingConferences = self.pendingConferencesRelay.value
        var updatedPendingConferences = pendingConferences
        var sourceCallId: String?

        for (callId, pendingSet) in pendingConferences {
            if conferenceCalls.contains(callId) && !conferenceCalls.isDisjoint(with: pendingSet) {
                sourceCallId = callId

                // Identify which invited participants haven't joined yet
                var waitingParticipants = pendingSet
                waitingParticipants.subtract(conferenceCalls)

                // Update pending conferences tracking
                updatedPendingConferences[callId] = nil
                if !waitingParticipants.isEmpty {
                    updatedPendingConferences[conferenceId] = waitingParticipants
                }
                break
            }
        }

        return (sourceCallId, updatedPendingConferences)
    }

    private func linkParticipantsToConference(conferenceCalls: Set<String>) {
        calls.update { calls in
            for callId in conferenceCalls {
                if let call = calls[callId] {
                    call.participantsCallId = conferenceCalls
                }
            }
        }
    }

    private func createConferenceObject(
        conferenceId: String,
        sourceCallId: String,
        conferenceCalls: Set<String>,
        accountId: String
    ) -> Bool {
        guard let sourceCall = calls.get()[sourceCallId],
              var callDetails = self.callsAdapter.getConferenceDetails(conferenceId, accountId: accountId) else {
            return false
        }

        callDetails[CallDetailKey.accountIdKey.rawValue] = sourceCall.accountId
        callDetails[CallDetailKey.audioOnlyKey.rawValue] = sourceCall.isAudioOnly.toString()

        let conferenceModel = CallModel(withCallId: conferenceId, callDetails: callDetails, withMedia: [[String: String]]())
        conferenceModel.participantsCallId = conferenceCalls

        calls.update { calls in
            calls[conferenceId] = conferenceModel
        }

        return true
    }

    private func notifyConferenceReady(conferenceId: String, conferenceCalls: Set<String>) {
        self.currentConferenceEvent.accept((conferenceId, ConferenceState.conferenceCreated.rawValue, conferenceCalls))
    }

    private func updatePendingParticipantsTracking(updatedPendingConferences: [String: Set<String>]) {
        let pendingConferences = self.pendingConferencesRelay.value
        if updatedPendingConferences != pendingConferences {
            self.pendingConferencesRelay.accept(updatedPendingConferences)
        }
    }

    func handleConferenceCreated(conferenceId: String, conversationId: String, accountId: String) {
        let conferenceCalls = self.getConferenceParticipants(conferenceId: conferenceId, accountId: accountId)

        if conferenceCalls.isEmpty {
            self.registerEmptyConference(conferenceId: conferenceId)
            return
        }

        self.markConferenceAsProcessed(conferenceId: conferenceId)

        let (sourceCallId, updatedPendingConferences) = self.processPendingParticipants(
            conferenceId: conferenceId,
            conferenceCalls: conferenceCalls
        )

        self.linkParticipantsToConference(conferenceCalls: conferenceCalls)

        var conferenceCreated = false
        if let sourceId = sourceCallId {
            conferenceCreated = self.createConferenceObject(
                conferenceId: conferenceId,
                sourceCallId: sourceId,
                conferenceCalls: conferenceCalls,
                accountId: accountId
            )
        }

        if conferenceCreated {
            self.notifyConferenceReady(conferenceId: conferenceId, conferenceCalls: conferenceCalls)
        }

        self.updatePendingParticipantsTracking(updatedPendingConferences: updatedPendingConferences)
    }

    func handleConferenceChanged(conference conferenceId: String, accountId: String, state: String) async {
        if state == "ACTIVE_ATTACHED" {
            if let call = calls.get()[conferenceId] {
                // For swarm calls, when a participant is attached, update the call state
                if call.state == .connecting {
                    call.state = .current
                    self.callUpdates.onNext(call)
                }
            }
            self.currentConferenceEvent.accept((conferenceId, state, [""]))
        }
        // Check if it's a newly created conference that needs processing
        let createdConferences = self.createdConferencesRelay.value
        if createdConferences.contains(conferenceId) {
            self.handleConferenceCreated(conferenceId: conferenceId, conversationId: "", accountId: accountId)
            return
        }

        calls.update { calls in
            guard let conference = calls[conferenceId] else { return }

            let conferenceCalls = Set(self.callsAdapter.getConferenceCalls(conferenceId, accountId: conference.accountId))

            conference.participantsCallId = conferenceCalls

            for callId in conferenceCalls {
                if let call = calls[callId] {
                    call.participantsCallId = conferenceCalls
                }
            }

            self.currentConferenceEvent.accept((conferenceId, state, conferenceCalls))
        }
    }

    func handleConferenceRemoved(conference conferenceId: String) async {
        guard let conference = calls.get()[conferenceId] else { return }

        let participantCallIds = conference.participantsCallId

        var conferenceInfos = self.conferenceInfosRelay.value
        conferenceInfos.removeValue(forKey: conferenceId)
        self.conferenceInfosRelay.accept(conferenceInfos)

        var pendingConferences = self.pendingConferencesRelay.value
        pendingConferences[conferenceId] = nil

        var updatedEntries = [String: Set<String>]()
        var keysToRemove = [String]()

        for (callId, pendingCalls) in pendingConferences {
            if pendingCalls.contains(conferenceId) {
                var updatedCalls = pendingCalls
                updatedCalls.remove(conferenceId)

                if updatedCalls.isEmpty {
                    keysToRemove.append(callId)
                } else {
                    updatedEntries[callId] = updatedCalls
                }
            }
        }

        for (callId, updatedCalls) in updatedEntries {
            pendingConferences[callId] = updatedCalls
        }

        for keyToRemove in keysToRemove {
            pendingConferences.removeValue(forKey: keyToRemove)
        }

        self.pendingConferencesRelay.accept(pendingConferences)

        var createdConferences = self.createdConferencesRelay.value
        createdConferences.remove(conferenceId)
        self.createdConferencesRelay.accept(createdConferences)

        self.currentConferenceEvent.accept((conferenceId, ConferenceState.infoUpdated.rawValue, [""]))
        self.currentConferenceEvent.accept((conferenceId, ConferenceState.conferenceDestroyed.rawValue, participantCallIds))

        calls.update { calls in
            calls[conferenceId] = nil
        }
    }

    func handleConferenceInfoUpdated(conference conferenceId: String, info: [[String: String]]) async {
        let participants = self.arrayToConferenceParticipants(participants: info, onlyURIAndActive: false)

        var conferenceInfos = self.conferenceInfosRelay.value
        let previousParticipants = conferenceInfos[conferenceId] ?? []
        conferenceInfos[conferenceId] = participants
        self.conferenceInfosRelay.accept(conferenceInfos)

        let participantAttached = previousParticipants.count < participants.count

        if participantAttached,
           let call = self.calls.get()[conferenceId],
           participants.count > 1 {
            if call.state == .connecting {
                call.state = .current
            }
        }

        self.currentConferenceEvent.accept((conferenceId, ConferenceState.infoUpdated.rawValue, [""]))
    }

    func clearPendingConferences(callId: String) {
        var pendingConferences = self.pendingConferencesRelay.value
        pendingConferences[callId] = nil

        var updatedEntries = [String: Set<String>]()
        var keysToRemove = [String]()

        for (conferenceId, pendingCalls) in pendingConferences {
            if pendingCalls.contains(callId) {
                var updatedCalls = pendingCalls
                updatedCalls.remove(callId)

                if updatedCalls.isEmpty {
                    keysToRemove.append(conferenceId)
                } else {
                    updatedEntries[conferenceId] = updatedCalls
                }
            }
        }

        for (conferenceId, updatedCalls) in updatedEntries {
            pendingConferences[conferenceId] = updatedCalls
        }

        for keyToRemove in keysToRemove {
            pendingConferences.removeValue(forKey: keyToRemove)
        }

        self.pendingConferencesRelay.accept(pendingConferences)
    }

    func shouldCallBeAddedToConference(callId: String) -> String? {
        let pendingConferences = pendingConferencesRelay.value

        for (conferenceId, pendingCalls) in pendingConferences {
            if !pendingCalls.isEmpty && pendingCalls.contains(callId) {
                return conferenceId
            }
        }

        return nil
    }

    private func updatePendingConferences(mainCallId: String, callToAdd: String) {
        var pendingConferences = self.pendingConferencesRelay.value

        if var pendingCalls = pendingConferences[mainCallId] {
            pendingCalls.insert(callToAdd)
            pendingConferences[mainCallId] = pendingCalls
        } else {
            pendingConferences[mainCallId] = [callToAdd]
        }

        self.pendingConferencesRelay.accept(pendingConferences)
    }

    private func getNewLayoutForActiveParticipant(currentLayout: CallLayout, maximixe: Bool) -> CallLayout {
        switch currentLayout {
        case .grid:
            return .oneWithSmal
        case .oneWithSmal:
            return maximixe ? .one : .grid
        case .one:
            return .oneWithSmal
        }
    }

    private func arrayToConferenceParticipants(participants: [[String: String]], onlyURIAndActive: Bool) -> [ConferenceParticipant] {
        return participants.map { ConferenceParticipant(info: $0, onlyURIAndActive: onlyURIAndActive) }
    }
}
