/*
 * Copyright (C) 2019-2026 Savoir-faire Linux Inc.
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
import CallKit
import AVFoundation

struct CallKitHandle {
    let value: String
    let displayName: String
    let isPhoneNumber: Bool
}

enum CallKitAction {
    case answer(callId: CallId, withVideo: Bool)
    /// Accepted from the lock screen before libjami reported the call.
    case answerPending(peerId: String, accountId: String, hasVideo: Bool)
    case end(callId: CallId)
    case declinePending(peerId: String, accountId: String)
    case setMuted(callId: CallId, muted: Bool)
    case audioSessionActivated(AVAudioSession)
    case audioSessionDeactivated(AVAudioSession)
}

final class CallKitService: NSObject {

    private let provider: CXProvider
    private let callController: CXCallController
    private(set) var directory = CallKitDirectory()
    private let placeholderTimeout: TimeInterval

    /// Set by the facade; receives every CallKit-initiated action.
    var onAction: ((CallKitAction) -> Void)?

    /// CallKit callbacks and directory access are confined to the main queue.
    /// Injected providers/controllers must preserve the same callback contract.
    init(provider: CXProvider = CXProvider(configuration: CallsHelpers.providerConfiguration()),
         callController: CXCallController = CXCallController(queue: .main),
         placeholderTimeout: TimeInterval = 15) {
        self.provider = provider
        self.callController = callController
        self.placeholderTimeout = placeholderTimeout
        super.init()
        self.provider.setDelegate(self, queue: .main)
    }

    // MARK: - Push placeholder path

    /// Reports the CallKit call for a VoIP push before libjami knows
    /// about it. An existing placeholder for the peer is replaced.
    func previewPendingCall(peerId: String, accountId: String, displayName: String,
                            hasVideo: Bool, completion: ((Error?) -> Void)?) {
        assertMainQueue()
        let uuid = UUID()
        if let replaced = directory.addPlaceholder(uuid: uuid, peerId: peerId,
                                                   accountId: accountId,
                                                   displayName: displayName,
                                                   hasVideo: hasVideo) {
            endCallKitCall(uuid: replaced, isRemoteEnd: false)
        }

        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .phoneNumber, value: peerId)
        configure(update, callerName: displayName, hasVideo: hasVideo)
        provider.reportNewIncomingCall(with: uuid, update: update) { [weak self] error in
            self?.assertMainQueue()
            if error != nil {
                self?.directory.remove(uuid: uuid)
            }
            completion?(error)
        }

        scheduleExpiry(uuid: uuid)
    }

    private func scheduleExpiry(uuid: UUID) {
        let timeout = placeholderTimeout
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
            self?.assertMainQueue()
            guard let self = self, self.directory.expirePlaceholder(uuid: uuid) else { return }
            self.provider.reportCall(with: uuid, endedAt: Date(), reason: .failed)
        }
    }

    // MARK: - libjami-call reporting

    /// The libjami reported an incoming call: reuse the placeholder's
    /// CallKit call when there is one (replaying any user decision),
    /// otherwise report a fresh incoming call.
    func reportIncomingCall(_ call: CallState, handle: CallKitHandle,
                            completion: ((Error?) -> Void)? = nil) {
        assertMainQueue()
        if let (_, decision) = directory.match(peerId: call.peerHash,
                                               accountId: call.accountId,
                                               callId: call.id) {
            switch decision {
            case .accepted(let withVideo):
                onAction?(.answer(callId: call.id, withVideo: withVideo))
            case .declined:
                onAction?(.end(callId: call.id))
            case nil:
                break
            }
            completion?(nil)
            return
        }

        let uuid = UUID()
        directory.attach(uuid: uuid, to: call.id)
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: handle.isPhoneNumber ? .phoneNumber : .generic,
                                       value: handle.value)
        configure(update, callerName: handle.displayName, hasVideo: !call.isAudioOnly)
        provider.reportNewIncomingCall(with: uuid, update: update) { [weak self] error in
            self?.assertMainQueue()
            if error != nil {
                self?.directory.remove(uuid: uuid)
            }
            completion?(error)
        }
    }

    /// Registers an outgoing call with CallKit.
    func reportOutgoingCallStarted(_ call: CallState, handle: CallKitHandle) {
        assertMainQueue()
        let uuid = UUID()
        directory.attach(uuid: uuid, to: call.id)
        let cxHandle = CXHandle(type: handle.isPhoneNumber ? .phoneNumber : .generic,
                                value: handle.value)
        let action = CXStartCallAction(call: uuid, handle: cxHandle)
        action.isVideo = !call.isAudioOnly
        action.contactIdentifier = handle.displayName
        callController.request(CXTransaction(action: action)) { [weak self] error in
            self?.assertMainQueue()
            if let error = error {
                NSLog("CallKit start-call transaction failed: %@", error.localizedDescription)
                self?.directory.remove(uuid: uuid)
            } else {
                guard let self = self, self.directory.isTracked(uuid) else { return }
                self.provider.reportOutgoingCall(with: uuid, startedConnectingAt: Date())
            }
        }
    }

    func reportOutgoingCallConnecting(_ callId: CallId) {
        assertMainQueue()
        guard let uuid = directory.uuid(for: callId) else { return }
        provider.reportOutgoingCall(with: uuid, startedConnectingAt: Date())
    }

    func reportOutgoingCallConnected(_ callId: CallId) {
        assertMainQueue()
        guard let uuid = directory.uuid(for: callId) else { return }
        provider.reportOutgoingCall(with: uuid, connectedAt: Date())
    }

    /// The call ended (locally or remotely) — tear down its CallKit call.
    func reportCallEnded(_ callId: CallId, isRemoteEnd: Bool) {
        assertMainQueue()
        guard let uuid = directory.uuid(for: callId) else { return }
        directory.remove(uuid: uuid)
        endCallKitCall(uuid: uuid, isRemoteEnd: isRemoteEnd)
    }

    func updateDisplayName(_ callId: CallId, handle: CallKitHandle, hasVideo: Bool) {
        assertMainQueue()
        guard let uuid = directory.uuid(for: callId) else { return }
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: handle.isPhoneNumber ? .phoneNumber : .generic,
                                       value: handle.value)
        configure(update, callerName: handle.displayName, hasVideo: hasVideo)
        provider.reportCall(with: uuid, updated: update)
    }

    // MARK: - Queries

    func hasActiveCalls() -> Bool {
        assertMainQueue()
        return callController.callObserver.calls.contains {
            !$0.hasEnded && directory.isTracked($0.uuid)
        }
    }

    func stopAllPendingCalls() {
        assertMainQueue()
        for uuid in directory.allPlaceholderUUIDs() {
            directory.remove(uuid: uuid)
            endCallKitCall(uuid: uuid, isRemoteEnd: false)
        }
    }

    /*
     Ends every call reported to CallKit before the process goes away.

     stopAllPendingCalls() requests CXTransactions, which CallKit processes
     asynchronously. On the termination path the process is gone before they
     are delivered and the system call UI stays on screen, so invalidate the
     provider: it ends all of its calls right away.
     */
    func endAllCallsOnTermination() {
        stopAllPendingCalls()
        provider.invalidate()
    }

    // MARK: - Private

    private func assertMainQueue() {
#if DEBUG
        dispatchPrecondition(condition: .onQueue(.main))
#endif
    }

    private func configure(_ update: CXCallUpdate, callerName: String, hasVideo: Bool) {
        update.localizedCallerName = callerName
        update.hasVideo = hasVideo
        update.supportsGrouping = false
        update.supportsUngrouping = false
        update.supportsHolding = false
    }

    private func endCallKitCall(uuid: UUID, isRemoteEnd: Bool) {
        assertMainQueue()
        let isOutgoing = callController.callObserver.calls
            .first { $0.uuid == uuid }?.isOutgoing ?? false
        if isRemoteEnd && !isOutgoing {
            provider.reportCall(with: uuid, endedAt: Date(), reason: .remoteEnded)
        } else {
            callController.request(CXTransaction(action: CXEndCallAction(call: uuid))) { [weak self] error in
                self?.assertMainQueue()
                if let error = error {
                    NSLog("CallKit end-call transaction failed: %@", error.localizedDescription)
                }
            }
        }
    }
}

// MARK: - CXProviderDelegate

extension CallKitService: CXProviderDelegate {

    func providerDidReset(_ provider: CXProvider) {
        assertMainQueue()
    }

    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        assertMainQueue()
        defer { action.fulfill() }
        switch directory.recordCallAction(uuid: action.callUUID, .accepted(withVideo: true)) {
        case .applyToCall(let callId):
            onAction?(.answer(callId: callId, withVideo: true))
        case .storedOnPlaceholder:
            if let placeholder = directory.placeholder(uuid: action.callUUID) {
                onAction?(.answerPending(peerId: placeholder.peerId,
                                         accountId: placeholder.accountId,
                                         hasVideo: placeholder.hasVideo))
            }
        case .unknownCall:
            break
        }
    }

    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        assertMainQueue()
        defer { action.fulfill() }
        switch directory.recordCallAction(uuid: action.callUUID, .declined) {
        case .applyToCall(let callId):
            directory.remove(uuid: action.callUUID)
            onAction?(.end(callId: callId))
        case .storedOnPlaceholder:
            if let placeholder = directory.placeholder(uuid: action.callUUID) {
                onAction?(.declinePending(peerId: placeholder.peerId,
                                          accountId: placeholder.accountId))
            }
        case .unknownCall:
            break
        }
    }

    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        assertMainQueue()
        defer { action.fulfill() }
        // Report the display name so call history shows it correctly.
        let update = CXCallUpdate()
        update.remoteHandle = action.handle
        update.localizedCallerName = action.contactIdentifier
        update.hasVideo = action.isVideo
        provider.reportCall(with: action.callUUID, updated: update)
    }

    func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        assertMainQueue()
        defer { action.fulfill() }
        guard let callId = directory.callId(for: action.callUUID) else { return }
        onAction?(.setMuted(callId: callId, muted: action.isMuted))
    }

    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        assertMainQueue()
        onAction?(.audioSessionActivated(audioSession))
    }

    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        assertMainQueue()
        onAction?(.audioSessionDeactivated(audioSession))
        try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
    }
}
