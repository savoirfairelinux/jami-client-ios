/*
 * Copyright (C) 2014-2026 Savoir-faire Linux Inc.
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

/// Wires the call domain to the domains it needs but must not own: CallKit
/// reporting, camera capture, the audio session, and account/contact
/// lookups. Every rule that spans two services lives here; each service
/// stays independently constructible and testable.
final class CallsManager: CallCameraCoordinating {

    let callToPresent = PublishSubject<CallState>()

    private let callService: CallService
    private let videoService: VideoService
    private let audioService: AudioService
    private let callKit: CallKitService
    private let accountsService: AccountsService
    private let contactsService: ContactsService
    private let nameService: NameService
    private let disposeBag = DisposeBag()

    init(callService: CallService,
         videoService: VideoService,
         audioService: AudioService,
         callKit: CallKitService = CallKitService(),
         accountsService: AccountsService,
         contactsService: ContactsService,
         nameService: NameService) {
        self.callService = callService
        self.videoService = videoService
        self.audioService = audioService
        self.callKit = callKit
        self.accountsService = accountsService
        self.contactsService = contactsService
        self.nameService = nameService

        self.subscribeCallEvents()
        self.subscribeCallKitActions()
        self.subscribeCaptureQuality()
        // Last: the store only begins consuming once every domain above is
        // wired, so no call event can be handled unwired.
        callService.start()
    }

    private func subscribeCallEvents() {
        callService.camera = self
        callService.onSystemEvent = { [weak self] event in
            // CallKit reporting and capture teardown are main-thread work.
            DispatchQueue.main.async { self?.handle(event) }
        }
    }

    private func subscribeCallKitActions() {
        callKit.onAction = { [weak self] action in
            self?.handleCallKitAction(action)
        }
    }

    private func subscribeCaptureQuality() {
        videoService.onSourceDowngraded = { [weak self] sinkId, source in
            self?.reinviteWithDowngradedSource(sinkId: sinkId, source: source)
        }
    }

    // MARK: - Call events → CallKit, camera, contacts

    private func handle(_ event: CallSystemEvent) {
        switch event {
        case .callMatched(_, let call):
            reportIncoming(call)
        case let .callAdded(call):
            if call.id.isLocal {
                // Answered on the CallKit screen: CallKit already knows this
                // call, so only the screen is missing.
                callToPresent.onNext(call)
            } else if call.direction == .incoming {
                reportIncoming(call)
            } else if !call.joinsExistingCall {
                callKit.reportOutgoingCallStarted(call, handle: handle(for: call))
                callToPresent.onNext(call)
            }
        case let .callUpdated(call):
            videoService.setVideoCodec(call.videoCodec, forCallId: call.id.raw)
            guard call.direction == .outgoing else { return }
            switch call.status {
            case .ringing:
                callKit.reportOutgoingCallConnecting(call.id)
            case .current:
                callKit.reportOutgoingCallConnected(call.id)
            default:
                break
            }
        case let .callEnded(call, _):
            if !callService.stateMirror.calls.contains(where: { !$0.value.status.isTerminal }) {
                // No call left to take the capture over — stop a warm-up
                // libjami never claimed (normal ends go through
                // libjami's StopCapture signal as well; stop is idempotent).
                videoService.stopPreviewCapture()
                Task { await videoService.resetCameraPosition() }
            }
            callKit.reportCallEnded(call.id,
                                    isRemoteEnd: call.status != .terminated(.endedLocally))
            performBoothModeCleanup(accountId: call.accountId)
            videoService.restoreDefaultDevice()
        default:
            break
        }
    }

    private func reportIncoming(_ call: CallState) {
        callKit.reportIncomingCall(call, handle: handle(for: call)) { [weak self] error in
            if error != nil {
                // CallKit refused (e.g. DND restrictions misuse) — refuse.
                Task { await self?.callService.refuse(call.id) }
            }
        }
        resolveRegisteredName(for: call)
    }

    /// The CallKit label is reported from what libjami knew at call setup,
    /// which for an unknown peer is the bare hash. A registered name that
    /// resolves afterwards replaces it on the system call UI.
    private func resolveRegisteredName(for call: CallState) {
        guard call.bestName == call.peerHash,
              let account = accountsService.getAccount(fromAccountId: call.accountId),
              account.type == .ring else { return }
        let hash = call.peerHash
        nameService.usernameLookupStatus
            .filter { response in
                response.state == .found && !response.name.isEmpty
                    && (response.address == hash || response.requestedName == hash)
            }
            .take(1)
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] response in
                guard let self = self else { return }
                var named = call
                named.registeredName = response.name
                self.callKit.updateDisplayName(call.id, handle: self.handle(for: named),
                                               hasVideo: !call.isAudioOnly)
            })
            .disposed(by: disposeBag)
        nameService.lookupAddress(withAccount: call.accountId, nameserver: "", address: hash)
    }

    // MARK: - CallKit actions → calls, camera, audio

    private func handleCallKitAction(_ action: CallKitAction) {
        switch action {
        case let .answer(callId, withVideo):
            Task { [weak self] in
                guard let self = self else { return }
                await self.callService.accept(callId, withVideo: withVideo)
                if let call = await self.callService.snapshot().call(callId) {
                    self.callToPresent.onNext(call)
                }
            }
        case let .answerPending(peerId, accountId, hasVideo):
            // The decision replays on match; the call it creates presents
            // through `.callAdded` like any other.
            Task { [weak self] in
                await self?.callService.acceptPendingCall(
                    peerId: peerId, accountId: accountId, withVideo: hasVideo)
            }
        case let .end(callId):
            Task { await callService.hangUp(callId) }
        case .declinePending:
            break
        case let .setMuted(callId, muted):
            Task { [weak self] in
                guard let self = self else { return }
                guard let call = await self.callService.snapshot().call(callId),
                      call.isAudioMuted != muted else { return }
                await self.callService.toggleMute(callId, label: .defaultAudio)
            }
        case .audioSessionActivated:
            Task { [weak self] in
                guard let self = self else { return }
                let snapshot = await self.callService.snapshot()
                let call = snapshot.ongoingCalls.first
                    ?? snapshot.calls.values.first { !$0.status.isTerminal }
                self.audioService.callKitActivated(
                    callHasVideo: call.map { !$0.isAudioOnly || $0.hasVideo } ?? false,
                    direction: call?.direction ?? .outgoing)
            }
        case .audioSessionDeactivated:
            break
        }
    }

    // MARK: - Camera

    func currentCameraSource() -> String {
        return videoService.videoSource()
    }

    func prepareCameraForOutgoingCall(audioOnly: Bool) {
        guard !audioOnly else { return }
        videoService.startPreviewCapture()
    }

    func prepareCameraForAnswerWithVideo() {
        videoService.startPreviewCapture()
    }

    // MARK: - Capture quality

    /// Hardware acceleration only covers H264/H265; the pipeline drops to
    /// the medium camera for anything else, which needs the call's codec.

    /// libjami cannot hot-swap the capture device, so a downgraded call has
    /// to be re-invited with the new source.
    private func reinviteWithDowngradedSource(sinkId: SinkId, source: String) {
        let callId = CallId(raw: sinkId.raw)
        Task { [weak self] in
            await self?.callService.updateVideoSource(callId, source: source)
        }
    }

    // MARK: - Push placeholders

    func previewPendingCall(peerId: String,
                            withVideo: Bool,
                            displayName: String,
                            accountId: String,
                            pushNotificationPayload: [String: String],
                            completion: ((Error?) -> Void)?) {
        callKit.previewPendingCall(peerId: peerId, accountId: accountId,
                                   displayName: displayName, hasVideo: withVideo,
                                   completion: completion)
        callService.emitPendingCallPreview(pushNotificationPayload: pushNotificationPayload)
    }

    func stopAllUnhandeledCalls() {
        callKit.stopAllPendingCalls()
    }

    /// Ends every call reported to CallKit before the process goes away.
    func endAllCallsOnTermination() {
        callKit.endAllCallsOnTermination()
    }

    func hasActiveCalls() -> Bool {
        return callKit.hasActiveCalls() || callService.hasOngoingCalls
    }

    // MARK: - Boothmode

    private func performBoothModeCleanup(accountId: String) {
        guard accountsService.boothMode() else { return }
        contactsService.removeAllContacts(for: accountId)
    }

    // MARK: - CallKit handles

    /// SIP handles keep foreign hosts,
    /// registered names win for Jami accounts.
    private func handle(for call: CallState) -> CallKitHandle {
        guard let account = accountsService.getAccount(fromAccountId: call.accountId) else {
            return CallKitHandle(value: call.peerHash, displayName: call.bestName,
                                 isPhoneNumber: false)
        }
        let type: URIType = account.type == .ring ? .ring : .sip
        let uri = JamiURI(schema: type, infoHash: call.peerUri, account: account)
        var handle = uri.hash ?? call.peerHash
        if account.type == .sip {
            let accountHostname = account.details?
                .get(withConfigKeyModel: ConfigKeyModel(withKey: ConfigKey.accountHostname)) ?? ""
            if uri.hostname != accountHostname {
                handle = uri.userInfo + ":" + uri.hostname
            }
        }
        let registered = call.registeredName ?? ""
        let name = !call.displayName.isEmpty ? call.displayName
            : !registered.isEmpty ? registered : handle
        let contactHandle = (account.type == .sip || registered.isEmpty) ? handle : registered
        return CallKitHandle(value: contactHandle,
                             displayName: name == contactHandle ? "" : name,
                             isPhoneNumber: account.type == .sip && handle.isPhoneNumber)
    }
}
