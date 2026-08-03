/*
 * Copyright (C) 2017-2026 Savoir-faire Linux Inc.
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

import Foundation

enum CallSystemEvent: Sendable {
    case callAdded(CallState)
    case callUpdated(CallState)
    case callMatched(CallId, CallState)
    case callEnded(CallState, durationSeconds: Int)
    case conferenceUpdated(ConferenceState)
    case conferenceEnded(ConfId, remainingCallId: CallId?)
    case incomingMessage(callId: CallId, fromUri: String, message: [String: String])
    case activeCallsChanged([String: AccountCallTracker])
}

enum CallStoreError: Error, Equatable {
    case placeCallFailed
    case callNotFound
    case notAuthorized
    case swarmCallTimedOut
}

/// The single source of truth for calls and conferences. Signals and user
/// intents are both actor methods, so they serialize against each other
actor CallStore { // swiftlint:disable:this type_body_length

    private let callAPI: LibJamiCallAPI
    /// `placeCall` is the sole intent that calls `callAPI` directly; every
    /// other command is sent off the actor through this queue.
    private let commandQueue: DispatchQueue
    private let callEvents: AsyncStream<LibJamiCallEvent>
    private let broadcaster = EventBroadcaster<CallSystemEvent>()

    private var state = CallSystemState()
    private var activeCallsTracker = ActiveCallsTracker()
    private var endedCalls = EndedCallLog()

    /// Sub-call → host call: joins deferred until the sub-call is current.
    private var pendingJoins: [CallId: CallId] = [:]
    /// Swarm placements waiting for their ConferenceCreated. Hosting a new
    /// swarm intentionally returns no call id, so the request metadata has to
    /// survive for a bounded interval while the conference signal may still
    /// supply the session id.
    private struct PendingSwarmCall {
        let requestId: UUID
        var continuation: CheckedContinuation<ConfId, Error>?
        let accountId: String
        let media: [MediaItem]
        let isAudioOnly: Bool
        let lateConferenceRetention: TimeInterval
        var callId: CallId?
    }
    private var pendingSwarmCalls: [String: PendingSwarmCall] = [:]
    /// Locally-created calls waiting for the libjami call that replaces them,
    /// keyed by account + peer hash.
    private var awaitingMatch: [PendingCallKey: CallId] = [:]
    private var pendingConferenceParticipants: [ConfId: [ConferenceParticipantInfo]] = [:]

    private var consumerTask: Task<Void, Never>?

    init(callAPI: LibJamiCallAPI,
         callEvents: AsyncStream<LibJamiCallEvent>,
         commandQueue: DispatchQueue = DispatchQueue(
            label: "com.savoirfairelinux.jami.calls.commands", qos: .userInitiated)) {
        self.callAPI = callAPI
        self.callEvents = callEvents
        self.commandQueue = commandQueue
    }

    private func send(_ command: @escaping @Sendable (LibJamiCallAPI) -> Void) {
        commandQueue.async { [callAPI] in
            command(callAPI)
        }
    }

    private func send(_ name: StaticString = #function,
                      reporting command: @escaping @Sendable (LibJamiCallAPI) -> Bool) {
        commandQueue.async { [callAPI] in
            if !command(callAPI) {
                NSLog("CallStore: libjami rejected %s", String(describing: name))
            }
        }
    }

    deinit {
        consumerTask?.cancel()
    }

    private static func waitForTimeout(_ timeout: TimeInterval) async -> Bool {
        do {
            try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            return true
        } catch {
            return false
        }
    }

    func start() {
        guard consumerTask == nil else { return }
        consumerTask = Task { [weak self] in
            guard let events = self?.callEvents else { return }
            for await event in events {
                guard let self = self else { return }
                await self.apply(event)
            }
        }
    }

    // MARK: - Reads

    func events() -> AsyncStream<CallSystemEvent> {
        return broadcaster.subscribe()
    }

    func events(for callId: CallId,
                fallback: CallState? = nil) -> AsyncStream<CallSystemEvent> {
        let observedCall: CallState?
        let lifecycleEvent: CallSystemEvent?
        if let call = state.calls[callId] {
            observedCall = call
            lifecycleEvent = .callUpdated(call)
        } else if let ended = endedCalls[callId] {
            observedCall = ended.call
            lifecycleEvent = .callEnded(ended.call,
                                        durationSeconds: ended.durationSeconds)
        } else if let call = fallback, call.id == callId {
            let ended = terminating(call)
            observedCall = ended
            lifecycleEvent = .callEnded(ended, durationSeconds: callDuration(ended))
        } else {
            observedCall = nil
            lifecycleEvent = nil
        }

        var replay: [CallSystemEvent] = []
        if let confId = observedCall?.conferenceId,
           let conference = state.conferences[confId] {
            // The conference must be known before a replayed subcall end so
            // the screen can follow a surviving member instead of dismissing.
            replay.append(.conferenceUpdated(conference))
        }
        if let lifecycleEvent = lifecycleEvent {
            replay.append(lifecycleEvent)
        }

        return broadcaster.subscribe(replaying: replay) { event in
            switch event {
            case let .callAdded(call), let .callUpdated(call):
                return call.id == callId
            case let .callEnded(call, _):
                return call.id == callId
            case let .callMatched(replaced, _):
                return replaced == callId
            case .conferenceUpdated, .conferenceEnded:
                return true
            case let .incomingMessage(messageCallId, _, _):
                return messageCallId == callId
            case .activeCallsChanged:
                return false
            }
        }
    }

    func snapshot() -> CallSystemState {
        return state
    }

    // MARK: - Call intents

    /// Places a call. `to` may be a peer URI, or a swarm:/rdv: URI, which
    /// always gets the complete audio+video media list (libjami contract).
    func placeCall(accountId: String, to peerUri: String,
                   audioOnly: Bool, videoSource: String) throws -> CallState {
        let isSwarmStyle = peerUri.hasPrefix("swarm:") || peerUri.hasPrefix("rdv:")
        let media = isSwarmStyle
            ? MediaNegotiator.completeMediaList(videoMuted: audioOnly, videoSource: videoSource)
            : MediaNegotiator.defaultMediaList(audioOnly: audioOnly, videoSource: videoSource)
        return try placeCall(accountId: accountId, to: peerUri, media: media,
                             isAudioOnly: audioOnly)
    }

    private func placeCall(accountId: String, to peerUri: String,
                           media: [MediaItem], isAudioOnly: Bool,
                           joinsExistingCall: Bool = false) throws -> CallState {
        guard let rawId = callAPI.placeCall(accountId: accountId, to: peerUri, media: media) else {
            throw CallStoreError.placeCallFailed
        }
        return registerPlacedCall(rawId: rawId, accountId: accountId, peerUri: peerUri,
                                  media: media, isAudioOnly: isAudioOnly,
                                  joinsExistingCall: joinsExistingCall)
    }

    private func registerPlacedCall(rawId: String, accountId: String, peerUri: String,
                                    media: [MediaItem], isAudioOnly: Bool,
                                    joinsExistingCall: Bool = false) -> CallState {
        var call = CallState(id: CallId(raw: rawId),
                             accountId: accountId,
                             direction: .outgoing,
                             peerUri: peerUri,
                             status: .connecting,
                             media: media,
                             isAudioOnly: isAudioOnly)
        call.joinsExistingCall = joinsExistingCall
        if peerUri.hasPrefix("swarm:") {
            call.conversationId = String(peerUri.dropFirst("swarm:".count))
        } else if let joined = ActiveCall(peerUri), peerUri.hasPrefix("rdv:") {
            // Joining an ongoing swarm call: mark it accepted everywhere
            // so banners dismiss and sibling accounts don't re-prompt.
            call.conversationId = joined.conversationId
            activeCallsTracker.acceptCall(uri: peerUri)
            broadcaster.send(.activeCallsChanged(activeCallsTracker.trackers))
        }
        endedCalls.forget(call.id)
        state.calls[call.id] = call
        broadcaster.send(.callAdded(call))
        return call
    }

    /// Hosts a swarm call: places `swarm:<conversationId>` and waits for
    /// libjami's ConferenceCreated.
    func placeSwarmCall(accountId: String, conversationId: String,
                        audioOnly: Bool, videoSource: String,
                        timeout: TimeInterval = 30,
                        lateConferenceRetention: TimeInterval = 30) async throws -> ConfId {
        guard pendingSwarmCalls[conversationId] == nil else {
            throw CallStoreError.placeCallFailed
        }
        let uri = "swarm:" + conversationId
        let media = MediaNegotiator.completeMediaList(videoMuted: audioOnly,
                                                       videoSource: videoSource)
        return try await withCheckedThrowingContinuation { continuation in
            pendingSwarmCalls[conversationId] = PendingSwarmCall(
                requestId: UUID(),
                continuation: continuation,
                accountId: accountId,
                media: media,
                isAudioOnly: audioOnly,
                lateConferenceRetention: lateConferenceRetention,
                callId: nil)
            scheduleSwarmCallExpiration(conversationId: conversationId, timeout: timeout)

            // A nil id is the normal libjami result when this device hosts a
            // new swarm. ConferenceCreated completes that path. If libjami
            // returns a sub-call id, retain the ordinary outgoing-call flow.
            guard let rawId = callAPI.placeCall(accountId: accountId, to: uri, media: media) else {
                return
            }
            let call = registerPlacedCall(rawId: rawId, accountId: accountId,
                                          peerUri: uri, media: media,
                                          isAudioOnly: audioOnly)
            pendingSwarmCalls[conversationId]?.callId = call.id
        }
    }

    private func scheduleSwarmCallExpiration(conversationId: String, timeout: TimeInterval) {
        Task { [weak self] in
            guard await Self.waitForTimeout(timeout) else { return }
            await self?.expireSwarmCall(conversationId: conversationId)
        }
    }

    private func expireSwarmCall(conversationId: String) {
        guard var pending = pendingSwarmCalls[conversationId],
              let continuation = pending.continuation else {
            return
        }
        pending.continuation = nil
        if pending.callId == nil {
            // Retain host placement metadata after resuming the caller. A
            // delayed ConferenceCreated still represents a live daemon
            // session and must produce a controllable call screen.
            pendingSwarmCalls[conversationId] = pending
            scheduleLateConferenceMetadataCleanup(
                conversationId: conversationId,
                requestId: pending.requestId,
                retention: pending.lateConferenceRetention)
        } else {
            pendingSwarmCalls[conversationId] = nil
        }
        continuation.resume(throwing: CallStoreError.swarmCallTimedOut)
    }

    private func scheduleLateConferenceMetadataCleanup(
        conversationId: String,
        requestId: UUID,
        retention: TimeInterval
    ) {
        Task { [weak self] in
            guard await Self.waitForTimeout(retention) else { return }
            await self?.removeExpiredSwarmPlacement(conversationId: conversationId,
                                                    requestId: requestId)
        }
    }

    private func removeExpiredSwarmPlacement(conversationId: String, requestId: UUID) {
        guard let pending = pendingSwarmCalls[conversationId],
              pending.requestId == requestId,
              pending.continuation == nil else { return }
        pendingSwarmCalls[conversationId] = nil
    }

    struct PendingCallKey: Hashable, Sendable {
        let accountId: String
        let peerHash: String
    }

    /// Answers a call the user accepted on the CallKit screen before libjami
    /// reported it: the call exists from the user's action, and the libjami
    /// call replaces it on arrival.
    @discardableResult
    func acceptPendingCall(peerId: String, accountId: String, withVideo: Bool,
                           timeout: TimeInterval = 15) -> CallState {
        let key = PendingCallKey(accountId: accountId, peerHash: peerId.filterOutHost())
        if let existing = awaitingMatch[key], let call = state.calls[existing] {
            return call
        }
        let call = CallState(id: .local(),
                             accountId: accountId,
                             direction: .incoming,
                             peerUri: peerId,
                             status: .connecting,
                             media: MediaNegotiator.defaultMediaList(audioOnly: !withVideo,
                                                                     videoSource: ""),
                             isAudioOnly: !withVideo)
        awaitingMatch[key] = call.id
        state.calls[call.id] = call
        broadcaster.send(.callAdded(call))

        scheduleUnmatchedCallExpiration(for: call.id, timeout: timeout)
        return call
    }

    private func scheduleUnmatchedCallExpiration(for id: CallId, timeout: TimeInterval) {
        Task { [weak self] in
            guard await Self.waitForTimeout(timeout) else { return }
            await self?.expireUnmatchedCall(id)
        }
    }

    private func expireUnmatchedCall(_ id: CallId) {
        guard var call = state.calls[id], id.isLocal else { return }
        awaitingMatch = awaitingMatch.filter { $0.value != id }
        call.status = .terminated(.failure)
        finishCall(call)
    }

    private func matchPendingCall(_ placeholderId: CallId, with call: CallState) {
        var matched = call
        if let placeholder = state.calls[placeholderId] {
            matched.callKitUUID = placeholder.callKitUUID
            matched.conversationId = matched.conversationId ?? placeholder.conversationId
        }
        state.calls[placeholderId] = nil
        awaitingMatch = awaitingMatch.filter { $0.value != placeholderId }
        state.calls[matched.id] = matched
        broadcaster.send(.callMatched(placeholderId, matched))
        applyPendingConferenceInfos(for: matched.id)
    }

    func accept(_ id: CallId, withVideo: Bool) {
        guard var call = state.calls[id], call.status.allows(.accept) else { return }
        var media = call.media.isEmpty ? [.audio()] : call.media
        if !withVideo {
            for index in media.indices where media[index].type == .video {
                media[index].muted = true
            }
        }
        let accountId = call.accountId
        let raw = id.raw
        let requested = media
        send(reporting: { $0.accept(callId: raw, accountId: accountId,
                                    media: requested) })
        call.media = media
        state.calls[id] = call
        broadcaster.send(.callUpdated(call))
    }

    func refuse(_ id: CallId) {
        guard var call = state.calls[id], call.status.allows(.refuse) else { return }
        let accountId = call.accountId
        let raw = id.raw
        send(reporting: { $0.refuse(callId: raw, accountId: accountId) })
        call.status = .terminated(.endedLocally)
        finishCall(call)
    }

    func hangUp(_ id: CallId) {
        guard var call = state.calls[id], call.status.allows(.hangUp) else { return }
        if let confId = call.conferenceId,
           confId.raw == id.raw,
           state.conferences[confId]?.isHost == true {
            hangUpConference(confId)
            return
        }
        let accountId = call.accountId
        let raw = id.raw
        if !id.isLocal {
            send(reporting: { $0.hangUp(callId: raw, accountId: accountId) })
        }
        awaitingMatch = awaitingMatch.filter { $0.value != id }
        call.status = .terminated(.endedLocally)
        finishCall(call)
    }

    func hangUpConference(_ id: ConfId) {
        guard let conference = state.conferences[id] else { return }
        let accountId = conference.accountId
        let raw = id.raw
        send(reporting: { $0.hangUpConference(conferenceId: raw,
                                              accountId: accountId) })
        // Drop the conference before its members: a member finished while the
        // conference still listed the others would look like a session that
        // lives on, and the screen would retarget onto a call about to end too.
        state.conferences[id] = nil
        for memberId in conference.memberCallIds {
            updateCall(memberId, emit: false) { $0.conferenceId = nil }
        }
        broadcaster.send(.conferenceEnded(id, remainingCallId: nil))
        for memberId in conference.memberCallIds {
            guard var call = state.calls[memberId] else { continue }
            call.status = .terminated(.endedLocally)
            finishCall(call)
        }
        finishHostedConferenceCall(id, status: .terminated(.endedLocally))
    }

    func hold(_ id: CallId, _ hold: Bool) {
        guard let call = state.calls[id],
              call.conferenceId == nil,
              call.status.allows(hold ? .hold : .resume) else { return }
        let accountId = call.accountId
        let raw = id.raw
        send { api in
            _ = hold ? api.hold(callId: raw, accountId: accountId)
                : api.resume(callId: raw, accountId: accountId)
        }
    }

    func holdConference(_ id: ConfId, _ hold: Bool) {
        guard let conference = state.conferences[id], conference.isHost else { return }
        let allowed = hold
            ? conference.lifecycle == .activeAttached
            : conference.lifecycle == .activeDetached || conference.lifecycle == .hold
        guard allowed else { return }
        let accountId = conference.accountId
        let raw = id.raw
        send { api in
            _ = hold ? api.holdConference(conferenceId: raw, accountId: accountId)
                : api.resumeConference(conferenceId: raw, accountId: accountId)
        }
    }

    /// Sends the re-invite that toggles `label`'s mute state. UI state
    /// flips only when libjami confirms via MediaNegotiationStatus.
    func toggleMute(_ id: CallId, label: MediaLabel, cameraSource: String) {
        guard var call = state.calls[id], call.status.allows(.changeMedia) else { return }
        if requestHostedConferenceMediaChange(for: call, transform: {
            MediaNegotiator.togglingMute(in: $0, label: label, cameraSource: cameraSource)
        }) { return }
        let newList = MediaNegotiator.togglingMute(in: call.media, label: label,
                                                   cameraSource: cameraSource)
        guard newList != call.media else { return }
        let accountId = call.accountId
        let raw = id.raw
        send(reporting: { $0.requestMediaChange(callId: raw, accountId: accountId,
                                                media: newList) })
        call.pendingMediaRequest = newList
        state.calls[id] = call
    }

    /// Re-invites with a new camera source. libjami cannot hot-swap the
    /// capture device, so a capture-quality change has to travel as a
    /// media change on every unmuted video stream.
    func updateVideoSource(_ id: CallId, source: String) {
        guard var call = state.calls[id], call.status.allows(.changeMedia) else { return }
        if requestHostedConferenceMediaChange(for: call, transform: { media in
            var media = media
            for index in media.indices where media[index].type == .video && !media[index].muted {
                media[index].source = source
            }
            return media
        }) { return }
        var newList = call.media
        for index in newList.indices where newList[index].type == .video && !newList[index].muted {
            newList[index].source = source
        }
        guard newList != call.media else { return }
        let accountId = call.accountId
        let raw = id.raw
        let requested = newList
        send(reporting: { $0.requestMediaChange(callId: raw, accountId: accountId,
                                                media: requested) })
        call.pendingMediaRequest = requested
        state.calls[id] = call
    }

    func sendInCallMessage(_ id: CallId, message: [String: String],
                           from jamiId: String, isMixed: Bool) {
        guard let call = state.calls[id] else { return }
        let accountId = call.accountId
        let raw = id.raw
        send { $0.sendInCallMessage(callId: raw, accountId: accountId,
                                    message: message, from: jamiId,
                                    isMixed: isMixed)
        }
    }

    func playDTMF(code: String) {
        send { $0.playDTMF(code: code) }
    }

    // MARK: - Conference intents

    /// Calls a new participant; the actual join runs when their call
    /// becomes current.
    func addParticipant(peerUri: String, toCall hostId: CallId,
                        requestedBy localJamiId: String,
                        videoSource: String) throws {
        guard let host = state.calls[hostId], host.status.isOngoing else {
            throw CallStoreError.callNotFound
        }
        if let conferenceId = host.conferenceId,
           let conference = state.conferences[conferenceId],
           !conference.isHost {
            let isLocalModerator = conference.participants.contains {
                $0.isModerator && $0.isLocalParticipant(
                    localJamiId: localJamiId, isHostedLocally: conference.isHost)
            }
            guard isLocalModerator else { throw CallStoreError.notAuthorized }
        }
        let conference = host.conferenceId.flatMap { state.conferences[$0] }
        let effectiveMedia = host.effectiveMedia(in: conference)
        let media = effectiveMedia.hasNegotiatedVideo
            ? MediaNegotiator.completeMediaList(videoMuted: effectiveMedia.isVideoMuted,
                                                videoSource: videoSource)
            : MediaNegotiator.defaultMediaList(audioOnly: true, videoSource: videoSource)
        let sub = try placeCall(accountId: host.accountId, to: peerUri, media: media,
                                isAudioOnly: !effectiveMedia.hasNegotiatedVideo,
                                joinsExistingCall: true)
        pendingJoins[sub.id] = hostId
        refreshPendingInvites(of: hostId)
    }

    /// Handles media owned by the local conference host.
    private func requestHostedConferenceMediaChange(
        for call: CallState,
        transform: ([MediaItem]) -> [MediaItem]
    ) -> Bool {
        guard let confId = call.conferenceId,
              var conference = state.conferences[confId],
              conference.id == call.conferenceId,
              conference.isHost else { return false }
        guard conference.hasAttachedHost else { return true }

        guard !conference.media.isEmpty else { return true }
        guard conference.pendingMediaRequest == nil else { return true }
        let requested = transform(conference.media)
        guard requested != conference.media else { return true }
        let accountId = conference.accountId
        send(reporting: { $0.requestMediaChange(callId: confId.raw, accountId: accountId,
                                                media: requested) })
        conference.pendingMediaRequest = requested
        state.conferences[confId] = conference
        broadcaster.send(.conferenceUpdated(conference))
        return true
    }

    private func refreshPendingInvites(of hostId: CallId) {
        let invites = pendingJoins
            .filter { $0.value == hostId }
            .compactMap { subId, _ -> PendingConferenceInvite? in
                guard let sub = state.calls[subId] else { return nil }
                return PendingConferenceInvite(callId: subId, peerUri: sub.peerUri,
                                               status: sub.status)
            }
            .sorted { $0.callId.raw < $1.callId.raw }
        guard state.calls[hostId]?.pendingInvites != invites else { return }
        updateCall(hostId) { $0.pendingInvites = invites }
    }

    func setActiveParticipant(_ participantId: String, in confId: ConfId) {
        guard let conference = state.conferences[confId] else { return }
        let accountId = conference.accountId
        let raw = confId.raw
        send { $0.setActiveParticipant(participantId, conferenceId: raw,
                                       accountId: accountId)
        }
    }

    func setLayout(_ layout: ConferenceLayoutMode, in confId: ConfId) {
        guard var conference = state.conferences[confId] else { return }
        let accountId = conference.accountId
        let raw = confId.raw
        send { $0.setConferenceLayout(layout.rawValue, conferenceId: raw,
                                      accountId: accountId)
        }
        conference.layout = layout
        state.conferences[confId] = conference
        broadcaster.send(.conferenceUpdated(conference))
    }

    func setModerator(_ participantId: String, in confId: ConfId, active: Bool) {
        guard let conference = state.conferences[confId] else { return }
        let accountId = conference.accountId
        let raw = confId.raw
        send { $0.setModerator(participantId, conferenceId: raw,
                               accountId: accountId, active: active)
        }
    }

    func hangUpParticipant(_ participantId: String, in confId: ConfId, deviceId: String) {
        guard let conference = state.conferences[confId] else { return }
        let accountId = conference.accountId
        let raw = confId.raw
        send { $0.hangUpParticipant(participantId, conferenceId: raw,
                                    accountId: accountId, deviceId: deviceId)
        }
    }

    func muteStream(_ participantId: String, in confId: ConfId,
                    deviceId: String, streamId: String, muted: Bool) {
        guard let conference = state.conferences[confId] else { return }
        let accountId = conference.accountId
        let raw = confId.raw
        send { $0.muteStream(participantId, conferenceId: raw,
                             accountId: accountId, deviceId: deviceId,
                             streamId: streamId, muted: muted)
        }
    }

    func raiseHand(_ participantId: String, in confId: ConfId,
                   deviceId: String, raised: Bool) {
        guard let conference = state.conferences[confId] else { return }
        let accountId = conference.accountId
        let raw = confId.raw
        send { $0.raiseHand(participantId, conferenceId: raw,
                            accountId: accountId, deviceId: deviceId,
                            raised: raised)
        }
    }

    // MARK: - Active swarm calls

    func updateActiveCalls(conversationId: String, calls: [[String: String]],
                           account: ActiveCallsTracker.AccountRef) {
        activeCallsTracker.updateActiveCalls(conversationId: conversationId,
                                             calls: calls, account: account)
        broadcaster.send(.activeCallsChanged(activeCallsTracker.trackers))
    }

    func ignoreActiveCall(_ call: ActiveCall) {
        activeCallsTracker.ignoreCall(call)
        broadcaster.send(.activeCallsChanged(activeCallsTracker.trackers))
    }

    func activeCall(conversationId: String, accountId: String) -> ActiveCall? {
        return activeCallsTracker.activeCall(conversationId: conversationId,
                                             accountId: accountId)
    }

    // MARK: - libjami event application

    private func apply(_ event: LibJamiCallEvent) {
        switch event {
        case let .incomingCall(accountId, callId, peerUri, media, details):
            applyIncomingCall(accountId: accountId, callId: callId,
                              peerUri: peerUri, media: media, details: details)
        case let .callStateChanged(callId, libJamiState, rawState, _, _,
                                   negotiatedMedia, videoCodec):
            applyStateChange(callId: CallId(raw: callId),
                             libJamiState: libJamiState, rawState: rawState,
                             negotiatedMedia: negotiatedMedia,
                             videoCodec: videoCodec)
        case let .mediaChangeRequested(accountId, callId, media):
            applyMediaChangeRequest(accountId: accountId,
                                    callId: CallId(raw: callId), requested: media)
        case let .mediaNegotiationStatus(callId, _, media):
            applyMediaNegotiation(callId: CallId(raw: callId), media: media)
        case let .peerHold(callId, hold):
            applyPeerHold(callId: CallId(raw: callId), hold: hold)
        case let .audioMuted(callId, muted):
            applyMuteSignal(callId: CallId(raw: callId), type: .audio, muted: muted)
        case let .videoMuted(callId, muted):
            applyMuteSignal(callId: CallId(raw: callId), type: .video, muted: muted)
        case let .remoteRecordingChanged(callId, recording):
            updateCall(CallId(raw: callId)) { $0.peerIsRecording = recording }
        case let .incomingMessage(callId, fromUri, message):
            broadcaster.send(.incomingMessage(callId: CallId(raw: callId),
                                              fromUri: fromUri,
                                              message: message))
        case let .conferenceCreated(conferenceId, conversationId, accountId, lifecycle,
                                    memberCallIds, participants, media):
            applyConferenceCreated(confId: ConfId(raw: conferenceId),
                                   conversationId: conversationId, accountId: accountId,
                                   lifecycle: lifecycle, memberCallIds: memberCallIds,
                                   participants: participants, media: media)
        case let .conferenceChanged(conferenceId, accountId, lifecycle, memberCallIds):
            applyConferenceChanged(confId: ConfId(raw: conferenceId), accountId: accountId,
                                   lifecycle: lifecycle, memberCallIds: memberCallIds)
        case let .conferenceRemoved(conferenceId):
            applyConferenceRemoved(confId: ConfId(raw: conferenceId))
        case let .conferenceInfosUpdated(conferenceId, participants):
            applyConferenceInfos(confId: ConfId(raw: conferenceId),
                                 participants: participants)
        }
    }

    private func applyIncomingCall(accountId: String, callId: String,
                                   peerUri: String, media: [MediaItem],
                                   details: CallDetails?) {
        let id = CallId(raw: callId)
        guard state.calls[id] == nil else { return }
        let call = CallState(id: id,
                             accountId: accountId,
                             direction: .incoming,
                             peerUri: peerUri,
                             displayName: details?.displayName ?? "",
                             registeredName: details?.registeredName,
                             status: .incoming,
                             media: media,
                             isAudioOnly: details?.isAudioOnly
                                ?? !media.contains { $0.type == .video && !$0.muted })
        endedCalls.forget(call.id)
        let key = PendingCallKey(accountId: accountId, peerHash: call.peerHash)
        if let pendingId = awaitingMatch[key] {
            matchPendingCall(pendingId, with: call)
            return
        }
        state.calls[id] = call
        broadcaster.send(.callAdded(call))
        applyPendingConferenceInfos(for: id)
    }

    private func applyStateChange(callId: CallId, libJamiState: LibJamiCallState?,
                                  rawState: String, negotiatedMedia: [MediaItem],
                                  videoCodec: String?) {
        guard var call = state.calls[callId] else { return }
        guard let libJamiState = libJamiState else {
            NSLog("CallStore: unknown call state '%@' for %@", rawState, callId.raw)
            return
        }

        var newStatus = CallStatus(libJami: libJamiState)
        // Merge libjami's hold notion with the separately-signalled peer hold.
        switch newStatus {
        case .held:
            newStatus = .held(side: call.peerHolding ? .both : .local)
        case .current where call.peerHolding:
            newStatus = .held(side: .peer)
        default:
            break
        }

        if !call.status.canTransition(to: newStatus) {
            NSLog("CallStore: unexpected transition %@ -> %@ for %@ (libjami is authoritative)",
                  String(describing: call.status), String(describing: newStatus), callId.raw)
        }

        if case .terminated = newStatus {
            call.status = newStatus
            finishCall(call)
            return
        }

        if newStatus == .current {
            if call.startedAt == nil {
                call.startedAt = Date()
                if !negotiatedMedia.isEmpty {
                    call.media = negotiatedMedia
                }
            }
            if let videoCodec = videoCodec, !videoCodec.isEmpty {
                call.videoCodec = videoCodec
            }
        }
        call.status = newStatus
        state.calls[callId] = call
        broadcaster.send(.callUpdated(call))

        if newStatus == .current {
            performPendingJoinIfNeeded(subCallId: callId)
        } else if let hostId = pendingJoins[callId] {
            refreshPendingInvites(of: hostId)
        }
    }

    private func finishCall(_ call: CallState) {
        let duration = callDuration(call)
        state.calls[call.id] = nil
        pendingConferenceParticipants[ConfId(raw: call.id.raw)] = nil
        let inviteHost = pendingJoins.removeValue(forKey: call.id)
        if call.peerUri.hasPrefix("rdv:") {
            activeCallsTracker.activeCallHungUp(uri: call.peerUri)
            broadcaster.send(.activeCallsChanged(activeCallsTracker.trackers))
        }
        if let confId = call.conferenceId {
            let isPeerHostedConference = confId.raw == call.id.raw
            if isPeerHostedConference {
                state.conferences[confId] = nil
                broadcaster.send(.conferenceEnded(confId, remainingCallId: nil))
            } else {
                updateConference(confId) { $0.memberCallIds.remove(call.id) }
            }
        }
        endedCalls.record(call, durationSeconds: duration)
        broadcaster.send(.callEnded(call, durationSeconds: duration))
        if let inviteHost = inviteHost {
            refreshPendingInvites(of: inviteHost)
        }
        rehostPendingInvites(leftBy: call)
    }

    private func rehostPendingInvites(leftBy host: CallState) {
        let legs = pendingJoins.filter { $0.value == host.id }.map(\.key)
        guard !legs.isEmpty else { return }
        let successor = host.conferenceId
            .flatMap { state.conferences[$0] }?
            .memberCallIds
            .sorted { $0.raw < $1.raw }
            .first { state.calls[$0] != nil }
        for leg in legs {
            pendingJoins[leg] = successor
            if successor == nil {
                hangUp(leg)
            }
        }
        if let successor = successor {
            refreshPendingInvites(of: successor)
        }
    }

    private func callDuration(_ call: CallState) -> Int {
        return max(0, call.startedAt.map { Int(Date().timeIntervalSince($0)) } ?? 0)
    }

    private func terminating(_ call: CallState) -> CallState {
        guard !call.status.isTerminal else { return call }
        var ended = call
        ended.status = .terminated(.over)
        return ended
    }

    private func performPendingJoinIfNeeded(subCallId: CallId) {
        guard let hostId = pendingJoins.removeValue(forKey: subCallId) else { return }
        refreshPendingInvites(of: hostId)
        guard let host = state.calls[hostId],
              let sub = state.calls[subCallId] else { return }
        let hostAccountId = host.accountId
        let subAccountId = sub.accountId
        if let confId = host.conferenceId,
           state.conferences[confId]?.isHost == true {
            send { _ = $0.joinConference(confId.raw, callId: subCallId.raw,
                                         accountId: hostAccountId,
                                         account2Id: subAccountId)
            }
        } else {
            send { _ = $0.joinCalls(hostId.raw, second: subCallId.raw,
                                    accountId: hostAccountId,
                                    account2Id: subAccountId)
            }
        }
    }

    private func applyMediaChangeRequest(accountId: String, callId: CallId,
                                         requested: [MediaItem]) {
        guard let call = state.calls[callId] else { return }
        let answer = MediaNegotiator.answer(forRequest: requested, current: call.media)
        let raw = callId.raw
        send { $0.answerMediaChangeRequest(callId: raw, accountId: accountId,
                                           media: answer)
        }
    }

    private func applyMediaNegotiation(callId: CallId, media: [MediaItem]) {
        let confId = ConfId(raw: callId.raw)
        if isHostedConferenceAlias(callId, confId: confId) {
            updateConference(confId) { conference in
                if !media.isEmpty {
                    conference.media = media
                }
                conference.pendingMediaRequest = nil
            }
            return
        }
        if state.calls[callId] != nil {
            updateCall(callId) { call in
                if !media.isEmpty {
                    call.media = media
                }
                call.pendingMediaRequest = nil
            }
            return
        }
        updateConference(confId) { conference in
            if !media.isEmpty {
                conference.media = media
            }
            conference.pendingMediaRequest = nil
        }
    }

    private func applyPeerHold(callId: CallId, hold: Bool) {
        updateCall(callId) { call in
            call.peerHolding = hold
            switch call.status {
            case .current where hold:
                call.status = .held(side: .peer)
            case .held(side: .local) where hold, .held(side: .both) where hold:
                call.status = .held(side: .both)
            case .held(side: .peer) where !hold:
                call.status = .current
            case .held(side: .both) where !hold:
                call.status = .held(side: .local)
            default:
                break
            }
        }
    }

    private func applyMuteSignal(callId: CallId, type: MediaType, muted: Bool) {
        let confId = ConfId(raw: callId.raw)
        if isHostedConferenceAlias(callId, confId: confId) {
            updateConference(confId) { conference in
                for index in conference.media.indices where conference.media[index].type == type {
                    conference.media[index].muted = muted
                }
            }
            return
        }
        if state.calls[callId] != nil {
            updateCall(callId) { call in
                for index in call.media.indices where call.media[index].type == type {
                    call.media[index].muted = muted
                }
            }
            return
        }
        updateConference(confId) { conference in
            for index in conference.media.indices where conference.media[index].type == type {
                conference.media[index].muted = muted
            }
        }
    }

    private func isHostedConferenceAlias(_ callId: CallId, confId: ConfId) -> Bool {
        return state.calls[callId]?.conferenceId == confId
            && state.conferences[confId]?.isHost == true
    }

    private func applyConferenceCreated(confId: ConfId, conversationId: String,
                                        accountId: String, lifecycle: String,
                                        memberCallIds: [String],
                                        participants: [ConferenceParticipantInfo],
                                        media: [MediaItem]) {
        let memberIds = Set(memberCallIds.map { CallId(raw: $0) })
        let participants = ConferenceParticipantInfo.latestPerStream(participants)

        var conference = state.conferences[confId]
            ?? ConferenceState(id: confId, accountId: accountId)
        conference.memberCallIds = memberIds
        conference.lifecycle = ConferenceLifecycle(libJamiState: lifecycle)
        if !media.isEmpty {
            conference.media = media
        }
        if !participants.isEmpty {
            conference.participants = participants
        }
        if let participants = pendingConferenceParticipants.removeValue(forKey: confId) {
            conference.participants = participants
        }
        if !conversationId.isEmpty {
            conference.conversationId = conversationId
        }

        for memberId in memberIds {
            updateCall(memberId, emit: false) { $0.conferenceId = confId }
        }

        conference.isHost = true
        state.conferences[confId] = conference

        if let pending = pendingSwarmCalls.removeValue(forKey: conversationId) {
            if let callId = pending.callId {
                updateCall(callId, emit: false) { $0.conferenceId = confId }
            } else {
                addHostedConferenceCall(confId: confId,
                                        conversationId: conversationId,
                                        pending: pending,
                                        conferenceMedia: conference.media)
            }
            pending.continuation?.resume(returning: confId)
        }

        broadcaster.send(.conferenceUpdated(conference))
    }

    private func addHostedConferenceCall(confId: ConfId, conversationId: String,
                                         pending: PendingSwarmCall,
                                         conferenceMedia: [MediaItem]) {
        let callId = CallId(raw: confId.raw)
        let media = conferenceMedia.isEmpty ? pending.media : conferenceMedia
        var call = CallState(id: callId,
                             accountId: pending.accountId,
                             direction: .outgoing,
                             peerUri: "swarm:" + conversationId,
                             status: .connecting,
                             media: media,
                             isAudioOnly: pending.isAudioOnly)
        call.conversationId = conversationId
        call.conferenceId = confId
        endedCalls.forget(callId)
        state.calls[callId] = call
        broadcaster.send(.callAdded(call))

        call.status = .current
        call.startedAt = Date()
        state.calls[callId] = call
        broadcaster.send(.callUpdated(call))
    }
    private func applyConferenceChanged(confId: ConfId, accountId: String,
                                        lifecycle: String,
                                        memberCallIds: [String]) {
        var conference = state.conferences[confId]
            ?? ConferenceState(id: confId, accountId: accountId)
        let previousMembers = conference.memberCallIds
        let memberIds = Set(memberCallIds.map { CallId(raw: $0) })
        conference.memberCallIds = memberIds
        conference.lifecycle = ConferenceLifecycle(libJamiState: lifecycle)
        if let participants = pendingConferenceParticipants.removeValue(forKey: confId) {
            conference.participants = participants
        }
        for memberId in memberIds {
            updateCall(memberId, emit: false) { $0.conferenceId = confId }
        }
        // Detach calls that left the conference so they don't carry a stale
        // parent id after they continue (or end) on their own.
        for departed in previousMembers.subtracting(memberIds) {
            updateCall(departed, emit: false) { $0.conferenceId = nil }
        }
        state.conferences[confId] = conference
        broadcaster.send(.conferenceUpdated(conference))
    }
    private func applyConferenceRemoved(confId: ConfId) {
        pendingConferenceParticipants[confId] = nil
        guard let conference = state.conferences.removeValue(forKey: confId) else { return }
        // The subcall the session should fall back to once the conference is
        // gone — the last participant still in a live call with us.
        let remainingCallId = conference.memberCallIds
            .sorted { $0.raw < $1.raw }
            .first { state.calls[$0] != nil }
        for memberId in conference.memberCallIds {
            updateCall(memberId, emit: false) { $0.conferenceId = nil }
        }
        broadcaster.send(.conferenceEnded(confId, remainingCallId: remainingCallId))
        if conference.isHost {
            finishHostedConferenceCall(confId, status: .terminated(.over))
        }
    }

    private func finishHostedConferenceCall(_ confId: ConfId, status: CallStatus) {
        let callId = CallId(raw: confId.raw)
        guard var call = state.calls[callId], call.conferenceId == confId else { return }
        call.conferenceId = nil
        call.status = status
        finishCall(call)
    }

    private func applyConferenceInfos(confId: ConfId,
                                      participants: [ConferenceParticipantInfo]) {
        let participants = ConferenceParticipantInfo.latestPerStream(participants)
        if var conference = state.conferences[confId] {
            if participants.isEmpty {
                let peerHostedCallId = CallId(raw: confId.raw)
                let isPeerHostedConference = conference.memberCallIds == [peerHostedCallId]
                if isPeerHostedConference {
                    collapsePeerHostedConference(confId, into: peerHostedCallId)
                    return
                }
                guard conference.memberCallIds.isEmpty else { return }
            }
            conference.participants = participants
            state.conferences[confId] = conference
            broadcaster.send(.conferenceUpdated(conference))
            return
        }

        guard !participants.isEmpty else { return }
        let callId = CallId(raw: confId.raw)
        guard let call = state.calls[callId] else {
            pendingConferenceParticipants[confId] = participants
            return
        }

        var conference = ConferenceState(id: confId, accountId: call.accountId)
        conference.participants = participants
        conference.memberCallIds = [callId]
        state.conferences[confId] = conference
        updateCall(callId, emit: false) { $0.conferenceId = confId }
        broadcaster.send(.conferenceUpdated(conference))
    }

    private func collapsePeerHostedConference(_ confId: ConfId, into callId: CallId) {
        state.conferences[confId] = nil
        updateCall(callId, emit: false) { $0.conferenceId = nil }
        let remaining = state.calls[callId] != nil ? callId : nil
        broadcaster.send(.conferenceEnded(confId, remainingCallId: remaining))
    }

    private func applyPendingConferenceInfos(for callId: CallId) {
        let confId = ConfId(raw: callId.raw)
        guard let participants = pendingConferenceParticipants.removeValue(forKey: confId) else {
            return
        }
        applyConferenceInfos(confId: confId, participants: participants)
    }

    // MARK: - State helpers

    private func updateCall(_ id: CallId, emit: Bool = true,
                            _ mutate: (inout CallState) -> Void) {
        guard var call = state.calls[id] else { return }
        mutate(&call)
        state.calls[id] = call
        if emit {
            broadcaster.send(.callUpdated(call))
        }
    }

    private func updateConference(_ id: ConfId, emit: Bool = true,
                                  _ mutate: (inout ConferenceState) -> Void) {
        guard var conference = state.conferences[id] else { return }
        mutate(&conference)
        state.conferences[id] = conference
        if emit {
            broadcaster.send(.conferenceUpdated(conference))
        }
    }

}

struct EndedCall: Sendable {
    let call: CallState
    let durationSeconds: Int
}

struct EndedCallLog: Sendable {

    static let limit = 32

    private var calls: [CallId: EndedCall] = [:]
    private var order: [CallId] = []

    subscript(id: CallId) -> EndedCall? {
        return calls[id]
    }

    mutating func record(_ call: CallState, durationSeconds: Int) {
        if calls[call.id] == nil {
            order.append(call.id)
        }
        calls[call.id] = EndedCall(call: call, durationSeconds: durationSeconds)
        while order.count > Self.limit {
            calls[order.removeFirst()] = nil
        }
    }

    mutating func forget(_ id: CallId) {
        guard calls.removeValue(forKey: id) != nil else { return }
        order.removeAll { $0 == id }
    }
}
