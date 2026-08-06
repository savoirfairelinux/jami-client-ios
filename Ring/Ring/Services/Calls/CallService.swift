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
import RxSwift
import RxRelay

enum CallType: Int {
    case incoming = 0
    case outgoing
    case missed
}

protocol CallCameraCoordinating: AnyObject {
    func currentCameraSource() -> String
    func prepareCameraForOutgoingCall(audioOnly: Bool)
    func prepareCameraForAnswerWithVideo()
    func cancelCameraPreparation()
}

final class CallService {

    // MARK: - Core

    private let store: CallStore
    private let eventSource: CallEventSource?
    private let callClient: LibJamiCallAPI

    /// Written off the main thread, read from anywhere — hence `mirrorLock`.
    private(set) var stateMirror: CallSystemState {
        get {
            mirrorLock.lock()
            defer { mirrorLock.unlock() }
            return mirrorStorage
        }
        set {
            mirrorLock.lock()
            mirrorStorage = newValue
            mirrorLock.unlock()
        }
    }

    private let mirrorLock = NSLock()
    private var mirrorStorage = CallSystemState()

    // MARK: - Rx surface

    /// Ongoing swarm calls per account (banners, active-calls list).
    let activeCalls = BehaviorRelay<[String: AccountCallTracker]>(value: [:])

    let responseStream = PublishSubject<ServiceEvent>()
    var sharedResponseStream: Observable<ServiceEvent> {
        return responseStream.asObservable().share()
    }
    var newMessage: Observable<ServiceEvent> {
        return responseStream.asObservable().share()
    }

    let callsUpdated = PublishSubject<Void>()

    // MARK: - CallsManager wiring

    /// Every store event, after `stateMirror` has been updated.
    var onSystemEvent: ((CallSystemEvent) -> Void)?
    weak var camera: CallCameraCoordinating?

    // MARK: - Init / wiring

    convenience init(callsAdapter: CallsAdapter = CallsAdapter()) {
        let client = LibJamiCallClient(adapter: callsAdapter)
        let resolver = CallEventResolver(api: client)
        let source = CallEventSource { [resolver] signal in resolver.handle(signal) }
        self.init(callClient: client,
                  callEvents: resolver.events,
                  eventSource: source)
        source.attachToAdapter()
    }

    init(callClient: LibJamiCallAPI,
         callEvents: AsyncStream<LibJamiCallEvent>,
         eventSource: CallEventSource? = nil) {
        self.eventSource = eventSource
        self.callClient = callClient
        self.store = CallStore(callAPI: callClient, callEvents: callEvents)
    }

    func start() {
        Task { [weak self] in
            guard let self = self else { return }
            await self.store.start()
            await self.pumpStoreEvents()
        }
    }

    // MARK: - Store event pump

    private func pumpStoreEvents() async {
        let events = await store.events()
        for await event in events {
            handle(event)
        }
    }

    func handle(_ event: CallSystemEvent) {
        switch event {
        case let .callAdded(call):
            stateMirror.calls[call.id] = call
            callsUpdated.onNext(())
        case let .callUpdated(call):
            stateMirror.calls[call.id] = call
            callsUpdated.onNext(())
        case let .callMatched(replaced, call):
            stateMirror.calls[replaced] = nil
            stateMirror.calls[call.id] = call
            callsUpdated.onNext(())
        case let .callEnded(call, duration):
            stateMirror.calls[call.id] = nil
            callsUpdated.onNext(())
            emitCallEnded(call: call, duration: duration)
        case let .conferenceUpdated(conference):
            stateMirror.conferences[conference.id] = conference
        case let .conferenceEnded(confId, _):
            stateMirror.conferences[confId] = nil
        case let .incomingMessage(callId, fromUri, message):
            emitIncomingMessage(callId: callId, fromUri: fromUri, message: message)
        case let .activeCallsChanged(trackers):
            activeCalls.accept(trackers)
        }
        onSystemEvent?(event)
    }

    // MARK: - Outgoing calls

    func startOutgoingCall(uri: String, account: AccountModel, isAudioOnly: Bool) {
        camera?.prepareCameraForOutgoingCall(audioOnly: isAudioOnly)
        Task { [weak self] in
            guard let self = self else { return }
            do {
                let videoSource = self.camera?.currentCameraSource() ?? ""
                if uri.hasPrefix("swarm:") {
                    let conversationId = String(uri.dropFirst("swarm:".count))
                    _ = try await self.store.placeSwarmCall(
                        accountId: account.id,
                        conversationId: conversationId,
                        audioOnly: isAudioOnly,
                        videoSource: videoSource)
                } else {
                    _ = try await self.store.placeCall(accountId: account.id,
                                                       to: uri,
                                                       audioOnly: isAudioOnly,
                                                       videoSource: videoSource)
                }
            } catch {
                NSLog("CallService: placing call failed: %@", error.localizedDescription)
                self.camera?.cancelCameraPreparation()
            }
        }
    }

    func placeCall(accountId: String, to peerUri: String,
                   audioOnly: Bool) async throws -> CallState {
        return try await store.placeCall(accountId: accountId, to: peerUri,
                                         audioOnly: audioOnly,
                                         videoSource: camera?.currentCameraSource() ?? "")
    }

    // MARK: - Synchronous queries

    var hasOngoingCalls: Bool {
        return !stateMirror.ongoingCalls.isEmpty
    }

    func call(participantId: String, accountId: String) -> CallId? {
        return stateMirror.call(withPeer: participantId.filterOutHost(),
                                accountId: accountId)?.id
    }

    func getActiveCall(accountId: String, conversationId: String) -> ActiveCall? {
        return activeCalls.value[accountId]?.calls(for: conversationId).first
    }

    // MARK: - Intents from conversation features

    func sendInCallMessage(callId: CallId, message: String, accountId: AccountModel) {
        Task {
            await store.sendInCallMessage(callId,
                                          message: ["text/plain": message],
                                          from: accountId.jamiId,
                                          isMixed: accountId.type == .sip)
        }
    }

    /// Calls a new participant and joins them once their call connects.
    func addParticipant(uri: String, toCall callId: CallId,
                        requestedBy localJamiId: String) {
        Task { [weak self] in
            guard let self = self else { return }
            do {
                try await self.store.addParticipant(
                    peerUri: uri, toCall: callId, requestedBy: localJamiId,
                    videoSource: self.camera?.currentCameraSource() ?? "")
            } catch {
                NSLog("Failed to add call participant: %@", String(describing: error))
            }
        }
    }

    func ignoreCall(call: ActiveCall) {
        Task { await store.ignoreActiveCall(call) }
    }

    // MARK: - Active swarm-call discovery

    func updateActiveCalls(conversationId: String, account: AccountModel) {
        Task { [weak self] in
            guard let self = self else { return }
            let raw = self.callClient.activeCalls(conversationId: conversationId,
                                                  accountId: account.id)
            await self.store.updateActiveCalls(conversationId: conversationId,
                                               calls: raw,
                                               account: Self.accountRef(account))
        }
    }

    func activeCallsChanged(conversationId: String, calls: [[String: String]],
                            account: AccountModel) {
        Task {
            await store.updateActiveCalls(conversationId: conversationId,
                                          calls: calls,
                                          account: Self.accountRef(account))
        }
    }

    private static func accountRef(_ account: AccountModel) -> ActiveCallsTracker.AccountRef {
        let deviceId = account.devices.first(where: \.isCurrent)?.deviceId ?? ""
        return ActiveCallsTracker.AccountRef(id: account.id,
                                             jamiId: account.jamiId,
                                             currentDeviceId: deviceId)
    }

    // MARK: - Store forwarding (in-call screen)

    func snapshot() async -> CallSystemState {
        return await store.snapshot()
    }

    func events(for callId: CallId,
                fallback: CallState? = nil) async -> AsyncStream<CallSystemEvent> {
        return await store.events(for: callId, fallback: fallback)
    }

    /// Answers on the user's action, before libjami has reported the call.
    func acceptPendingCall(peerId: String, accountId: String,
                           withVideo: Bool) async -> CallState {
        if withVideo {
            camera?.prepareCameraForAnswerWithVideo()
        }
        return await store.acceptPendingCall(peerId: peerId, accountId: accountId,
                                             withVideo: withVideo)
    }

    func accept(_ id: CallId, withVideo: Bool) async {
        if withVideo {
            camera?.prepareCameraForAnswerWithVideo()
        }
        await store.accept(id, withVideo: withVideo)
    }

    func refuse(_ id: CallId) async {
        await store.refuse(id)
    }

    func hangUp(_ id: CallId) async {
        await store.hangUp(id)
    }

    func hangUpConference(_ id: ConfId) async {
        await store.hangUpConference(id)
    }

    func hold(_ id: CallId, _ hold: Bool) async {
        await store.hold(id, hold)
    }

    func holdConference(_ id: ConfId, _ hold: Bool) async {
        await store.holdConference(id, hold)
    }

    func toggleMute(_ id: CallId, label: MediaLabel) async {
        await store.toggleMute(id, label: label,
                               cameraSource: camera?.currentCameraSource() ?? "")
    }

    func playDTMF(code: String) {
        Task { await store.playDTMF(code: code) }
    }

    func updateVideoSource(_ id: CallId, source: String) async {
        await store.updateVideoSource(id, source: source)
    }

    func setLayout(_ layout: ConferenceLayoutMode, in confId: ConfId) async {
        await store.setLayout(layout, in: confId)
    }

    func setActiveParticipant(_ participantId: String, in confId: ConfId) async {
        await store.setActiveParticipant(participantId, in: confId)
    }

    func setModerator(_ participantId: String, in confId: ConfId, active: Bool) async {
        await store.setModerator(participantId, in: confId, active: active)
    }

    func hangUpParticipant(_ participantId: String, in confId: ConfId,
                           deviceId: String) async {
        await store.hangUpParticipant(participantId, in: confId, deviceId: deviceId)
    }

    func muteStream(_ participantId: String, in confId: ConfId,
                    deviceId: String, streamId: String, muted: Bool) async {
        await store.muteStream(participantId, in: confId, deviceId: deviceId,
                               streamId: streamId, muted: muted)
    }

    func raiseHand(_ participantId: String, in confId: ConfId,
                   deviceId: String, raised: Bool) async {
        await store.raiseHand(participantId, in: confId, deviceId: deviceId,
                              raised: raised)
    }

    private func emitCallEnded(call: CallState, duration: Int) {
        var event = ServiceEvent(withEventType: .callEnded)
        event.addEventInput(.peerUri, value: call.peerUri)
        event.addEventInput(.callUUID, value: call.callKitUUID?.uuidString ?? "")
        event.addEventInput(.accountId, value: call.accountId)
        event.addEventInput(.callId, value: call.id.raw)
        event.addEventInput(.callType,
                            value: (call.direction == .incoming
                                        ? CallType.incoming : CallType.outgoing).rawValue)
        event.addEventInput(.callTime, value: duration)
        responseStream.onNext(event)
    }

    private func emitIncomingMessage(callId: CallId, fromUri: String,
                                     message: [String: String]) {
        // Only plain text reaches conversations; vCard chunks and other
        // MIME payloads in call messages are intentionally ignored.
        guard let call = stateMirror.calls[callId] ?? nil,
              let content = message.first(where: { $0.key.contains("text/plain") })?.value else {
            return
        }
        var event = ServiceEvent(withEventType: .newIncomingMessage)
        event.addEventInput(.content, value: content)
        event.addEventInput(.peerUri, value: fromUri.filterOutHost())
        event.addEventInput(.accountId, value: call.accountId)
        event.addEventInput(.name, value: call.bestName)
        responseStream.onNext(event)
    }

    /// Emits the push-preview event conversations listen for.
    func emitPendingCallPreview(pushNotificationPayload: [String: String]) {
        var event = ServiceEvent(withEventType: .callProviderPreviewPendingCall)
        event.addEventInput(.content, value: pushNotificationPayload)
        responseStream.onNext(event)
    }
}
