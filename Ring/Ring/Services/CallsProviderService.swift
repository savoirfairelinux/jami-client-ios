/*
 * Copyright (C) 2019-2025 Savoir-faire Linux Inc.
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

import AVFoundation
import CallKit
import RxSwift

enum UnhandeledCallState {
    case accepted
    case declined
    case awaiting
}

class UnhandeledCall: Equatable, Hashable {
    let uuid = UUID()
    let peerId: String
    let accountId: String
    var state: UnhandeledCallState = .awaiting

    init (peerId: String, accountId: String) {
        self.peerId = peerId
        self.accountId = accountId
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(uuid)
    }

    static func == (lhs: UnhandeledCall, rhs: UnhandeledCall) -> Bool {
        return lhs.uuid == rhs.uuid
    }
}

class CallsProviderService: NSObject {
    private let provider: CXProvider
    private var callController: CXCallController
    private let disposeBag = DisposeBag()
    // Calls that were created from notification extension and waiting for daemon to connect.
    private var unhandeledCalls = Set<UnhandeledCall>()
    private let unhandeledCallsLock = NSLock()
    // Timer to stop pending unhandeled call if no information about call received from the daemon.
    private weak var timer: Timer?
    // Timeout in seconds to wait until unhandeled call should be stopped.
    private let pendingCallTimeout = 15.0

    private let responseStream = PublishSubject<ServiceEvent>()
    var sharedResponseStream: Observable<ServiceEvent>
    private var jamiCallUUIDs = Set<UUID>()
    private let jamiCallUUIDsLock = NSLock()

    init(provider: CXProvider, controller: CXCallController) {
        self.sharedResponseStream = responseStream.share()
        self.provider = provider
        self.callController = controller
        super.init()
        self.provider.setDelegate(self, queue: nil)
        self.responseStream.disposed(by: disposeBag)
    }

    private func insertUnhandeledCall(_ call: UnhandeledCall) {
        unhandeledCallsLock.lock()
        defer { unhandeledCallsLock.unlock() }
        unhandeledCalls.insert(call)
    }

    private func removeUnhandeledCall(_ call: UnhandeledCall) {
        unhandeledCallsLock.lock()
        defer { unhandeledCallsLock.unlock() }
        unhandeledCalls.remove(call)
    }

    private func getUnhandeledCall(UUID: UUID) -> UnhandeledCall? {
        unhandeledCallsLock.lock()
        defer { unhandeledCallsLock.unlock() }
        return unhandeledCalls.first { $0.uuid == UUID }
    }

    internal func getUnhandeledCall(peerId: String) -> UnhandeledCall? {
        unhandeledCallsLock.lock()
        defer { unhandeledCallsLock.unlock() }
        return unhandeledCalls.first { $0.peerId == peerId }
    }

    internal func getUnhandeledCalls(peerId: String) -> [UnhandeledCall] {
        unhandeledCallsLock.lock()
        defer { unhandeledCallsLock.unlock() }
        return unhandeledCalls.filter { $0.peerId == peerId }
    }

    private func forEachUnhandeledCall(_ body: (UnhandeledCall) -> Void) {
        unhandeledCallsLock.lock()
        let calls = unhandeledCalls
        unhandeledCallsLock.unlock()
        calls.forEach(body)
    }

    private func insertJamiCallUUID(_ uuid: UUID) {
        jamiCallUUIDsLock.lock()
        defer { jamiCallUUIDsLock.unlock() }
        jamiCallUUIDs.insert(uuid)
    }

    private func removeJamiCallUUID(_ uuid: UUID) {
        jamiCallUUIDsLock.lock()
        defer { jamiCallUUIDsLock.unlock() }
        jamiCallUUIDs.remove(uuid)
    }

    private func containsJamiCallUUID(_ uuid: UUID) -> Bool {
        jamiCallUUIDsLock.lock()
        defer { jamiCallUUIDsLock.unlock() }
        return jamiCallUUIDs.contains(uuid)
    }
}

extension CallsProviderService {
    func stopCall(callUUID: UUID, participant: String) {
        // Remove call from pending unhandeled calls. Get pending call by jamiId, because uuid could be different for unhandeled call and for incoming call.
        if let call = getUnhandeledCall(peerId: participant) {
            let unhandeledCallUUID = call.uuid
            removeUnhandeledCall(call)
            // If unhandeled calls uuid is different from requested callUUID stop it.
            if unhandeledCallUUID != callUUID {
                let endCallAction = CXEndCallAction(call: unhandeledCallUUID)
                let transaction = CXTransaction(action: endCallAction)
                self.requestTransaction(transaction)
            }
        } else if let call = getUnhandeledCall(UUID: callUUID) {
            removeUnhandeledCall(call)
        }
        // Send request end call to CallKit.
        let endCallAction = CXEndCallAction(call: callUUID)
        let transaction = CXTransaction(action: endCallAction)
        self.requestTransaction(transaction)
    }

    func hasActiveCalls() -> Bool {
        let calls = self.callController.callObserver.calls
        let jamiCalls = calls.filter { call in
            !call.hasEnded && isJamiCall(call)
        }
        return !jamiCalls.isEmpty
    }

    func isJamiCall(_ call: CXCall) -> Bool {
        return containsJamiCallUUID(call.uuid)
    }

    func handleIncomingCall(account: AccountModel, call: CallModel) {
        if let unhandeledCall = getUnhandeledCall(peerId: call.paricipantHash()) {
            defer {
                removeUnhandeledCall(unhandeledCall)
            }
            call.callUUID = unhandeledCall.uuid
            if unhandeledCall.state != .awaiting {
                // CallKit already received user action before call received from the daemon. Notify call view about the action
                let serviceEventType: ServiceEventType = unhandeledCall.state == .accepted ? .callProviderAcceptCall : .callProviderDeclineCall
                var serviceEvent = ServiceEvent(withEventType: serviceEventType)
                serviceEvent.addEventInput(.callUUID, value: call.callUUID.uuidString)
                serviceEvent.addEventInput(.callId, value: call.callUUID.uuidString)
                self.responseStream.onNext(serviceEvent)
            }
        } else {
            reportIncomingCall(account: account, call: call, completion: nil)
        }
    }

    private func reportIncomingCall(account: AccountModel, call: CallModel,
                                    completion: ((Error?) -> Void)?) {
        let update = CXCallUpdate()
        let isJamiAccount = account.type == AccountType.ring
        guard let handleInfo = self.getHandleInfo(account: account, call: call) else { return }
        let handleType = (isJamiAccount
                            || !handleInfo.handle.isPhoneNumber) ? CXHandle.HandleType.generic : CXHandle.HandleType.phoneNumber
        update.remoteHandle = CXHandle(type: handleType, value: handleInfo.handle)
        self.setUpCallUpdate(update: update, localizedCallerName: handleInfo.displayName, videoFlag: !call.isAudioOnly)
        self.provider.reportNewIncomingCall(with: call.callUUID,
                                            update: update) { [weak self] error in
            if error == nil {
                self?.insertJamiCallUUID(call.callUUID)
            }
            completion?(error)
        }
    }

    func updateRegisteredName(account: AccountModel, call: CallModel) {
        let update = CXCallUpdate()
        let isJamiAccount = account.type == AccountType.ring
        guard let handleInfo = self.getHandleInfo(account: account, call: call) else { return }
        let handleType = (isJamiAccount
                            || !handleInfo.handle.isPhoneNumber) ? CXHandle.HandleType.generic : CXHandle.HandleType.phoneNumber

        update.remoteHandle = CXHandle(type: handleType, value: handleInfo.handle)
        self.setUpCallUpdate(update: update, localizedCallerName: call.registeredName, videoFlag: !call.isAudioOnly)
        self.provider.reportCall(with: call.callUUID, updated: update)
    }

    func previewPendingCall(peerId: String, withVideo: Bool, displayName: String,
                            accountId: String,
                            pushNotificationPayload: [String: String]? = nil,
                            completion: ((Error?) -> Void)?) {
        let update = CXCallUpdate()
        let handleType = CXHandle.HandleType.phoneNumber
        update.remoteHandle = CXHandle(type: handleType, value: peerId)
        self.setUpCallUpdate(update: update, localizedCallerName: displayName, videoFlag: withVideo)

        // Stop existing unhandeled call for jamiId
        if let existingUnhandeledCall = self.getUnhandeledCall(peerId: peerId) {
            self.stopCall(callUUID: existingUnhandeledCall.uuid, participant: existingUnhandeledCall.peerId)
        }
        let unhandeledCall = UnhandeledCall(peerId: peerId, accountId: accountId)
        insertUnhandeledCall(unhandeledCall)
        self.provider.reportNewIncomingCall(with: unhandeledCall.uuid,
                                            update: update) { [weak self] error in
            if error == nil {
                self?.insertJamiCallUUID(unhandeledCall.uuid)
            }
            completion?(error)
        }
        let serviceEventType: ServiceEventType = .callProviderPreviewPendingCall
        var serviceEvent = ServiceEvent(withEventType: serviceEventType)
        serviceEvent.addEventInput(.callUUID, value: unhandeledCall.uuid.uuidString)
        if let payload = pushNotificationPayload {
            serviceEvent.addEventInput(.content, value: payload)
        }
        self.responseStream.onNext(serviceEvent)
        startTimer(callUUID: unhandeledCall.uuid)
    }
    func setUpCallUpdate(update: CXCallUpdate, localizedCallerName: String, videoFlag: Bool) {
        update.localizedCallerName = localizedCallerName
        update.hasVideo = videoFlag
        update.supportsGrouping = false
        update.supportsUngrouping = false
        update.supportsHolding = false
    }

    func startCall(account: AccountModel, call: CallModel) {
        let isJamiAccount = account.type == AccountType.ring
        guard let handleInfo = self.getHandleInfo(account: account, call: call) else { return }
        let handleType = (isJamiAccount
                            || !handleInfo.handle.isPhoneNumber) ? CXHandle.HandleType.generic : CXHandle.HandleType.phoneNumber
        let contactHandle = CXHandle(type: handleType, value: handleInfo.handle)
        let startCallAction = CXStartCallAction(call: call.callUUID, handle: contactHandle)
        startCallAction.isVideo = !call.isAudioOnly
        startCallAction.contactIdentifier = handleInfo.displayName
        let transaction = CXTransaction(action: startCallAction)
        requestTransaction(transaction)
    }

    func stopAllUnhandeledCalls() {
        forEachUnhandeledCall { call in
            stopCall(callUUID: call.uuid, participant: call.peerId)
        }
    }

    func getHandleInfo(account: AccountModel, call: CallModel) -> (displayName: String, handle: String)? {
        let type = account.type == AccountType.ring ? URIType.ring : URIType.sip
        let uri = JamiURI.init(schema: type, infoHash: call.callUri, account: account)
        guard var handle = uri.hash else { return nil }
        // for sip contact if account and contact have different host name add contact host name
        if account.type == AccountType.sip {
            let accountHostname = account.details?
                .get(withConfigKeyModel: ConfigKeyModel(withKey: ConfigKey.accountHostname)) ?? ""
            if uri.hostname != accountHostname {
                handle = uri.userInfo + ":" + uri.hostname
            }
        }
        let name = !call.displayName.isEmpty ? call.displayName : !call.registeredName.isEmpty ? call.registeredName : handle
        let contactHandle = (account.type == AccountType.sip
                                || call.registeredName.isEmpty) ? handle : call.registeredName
        if name == contactHandle {
            return ("", contactHandle)
        }
        return (name, contactHandle)
    }

    private func requestTransaction(_ transaction: CXTransaction) {
        callController.request(transaction) { error in
            if let error = error {
                print("An error occurred while requesting transaction: \(error)")
            } else {
                print("Transaction requested successfully.")
            }
        }
    }
    // MARK: - Timer
    @objc
    func timerHandler(_ timer: Timer) {
        defer {
            stopTimer()
        }
        guard let uuid = timer.userInfo as? UUID else { return }
        // did not receive incoming call from daemon
        if getUnhandeledCall(UUID: uuid) != nil {
            stopCall(callUUID: uuid, participant: "")
        }
    }

    func startTimer(callUUID: UUID) {
        stopTimer()
        timer = Timer.scheduledTimer(timeInterval: pendingCallTimeout, target: self, selector: #selector(timerHandler(_:)), userInfo: callUUID, repeats: false)
    }

    func stopTimer() {
        timer?.invalidate()
    }
}
// MARK: - CXProviderDelegate
extension CallsProviderService: CXProviderDelegate {
    func providerDidReset(_ provider: CXProvider) {
    }

    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        defer {
            action.fulfill()
        }
        if let call = getUnhandeledCall(UUID: action.callUUID) {
            call.state = .accepted
            // Emit event to show connecting screen for unhandled call
            let serviceEventType: ServiceEventType = .callProviderAcceptUnhandeledCall
            var serviceEvent = ServiceEvent(withEventType: serviceEventType)
            serviceEvent.addEventInput(.callUUID, value: action.callUUID.uuidString)
            serviceEvent.addEventInput(.peerUri, value: call.peerId)
            serviceEvent.addEventInput(.accountId, value: call.accountId)
            self.responseStream.onNext(serviceEvent)
            return
        }
        let serviceEventType: ServiceEventType = .callProviderAcceptCall
        var serviceEvent = ServiceEvent(withEventType: serviceEventType)
        serviceEvent.addEventInput(.callUUID, value: action.callUUID.uuidString)
        self.responseStream.onNext(serviceEvent)
    }

    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        defer {
            action.fulfill()
        }
        removeJamiCallUUID(action.callUUID)
        if let call = getUnhandeledCall(UUID: action.callUUID) {
            call.state = .declined
            return
        }
        let serviceEventType: ServiceEventType = .callProviderDeclineCall
        var serviceEvent = ServiceEvent(withEventType: serviceEventType)
        serviceEvent.addEventInput(.callUUID, value: action.callUUID.uuidString)
        self.responseStream.onNext(serviceEvent)
    }

    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        defer {
            action.fulfill()
        }
        insertJamiCallUUID(action.callUUID)
        /*
         To display correct name in call history create an update and report
         it to the provider.
         */
        let update = CXCallUpdate()
        update.remoteHandle = action.handle
        update.localizedCallerName = action.contactIdentifier
        update.hasVideo = action.isVideo
        self.provider.reportCall(with: action.callUUID, updated: update)
    }

    func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        defer {
            action.fulfill()
        }
        let serviceEventType: ServiceEventType = .callProviderSetMuted
        var serviceEvent = ServiceEvent(withEventType: serviceEventType)
        serviceEvent.addEventInput(.callUUID, value: action.callUUID.uuidString)
        serviceEvent.addEventInput(.muted, value: action.isMuted)
        self.responseStream.onNext(serviceEvent)
    }

    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        let serviceEventType: ServiceEventType = .audioActivated
        let serviceEvent = ServiceEvent(withEventType: serviceEventType)
        self.responseStream.onNext(serviceEvent)
    }
}
