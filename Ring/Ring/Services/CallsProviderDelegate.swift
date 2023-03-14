/*
 *  Copyright (C) 2019-2023 Savoir-faire Linux Inc.
 *
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

import AVFoundation
import CallKit
import RxSwift

enum UnhandeledCallState {
    case answered
    case declined
    case awaiting
}

class UnhandeledCall: Equatable, Hashable {
    let uuid = UUID()
    let peerId: String
    var state: UnhandeledCallState = .awaiting

    init (peerId: String) {
        self.peerId = peerId
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(uuid)
    }

    static func == (lhs: UnhandeledCall, rhs: UnhandeledCall) -> Bool {
        return lhs.uuid == rhs.uuid
    }
}

class CallsProviderDelegate: NSObject {
    private lazy var provider: CXProvider? = nil
    private lazy var callController = CXCallController()
    private let disposeBag = DisposeBag()
    // Calls that were created from notification extension and waiting for daemon to connect.
    var unhandeledCalls = Set<UnhandeledCall>()
    // Timer to stop pending unhandeled call if no information about call received from the daemon.
    private weak var timer: Timer?
    // Timeout in seconds to wait until unhandeled call should be stopped.
    private let pendingCallTimeout = 15.0

    private let responseStream = PublishSubject<ServiceEvent>()
    var sharedResponseStream: Observable<ServiceEvent>

    override init() {
        self.sharedResponseStream = responseStream.share()
        super.init()
        let providerConfiguration = CXProviderConfiguration()
        providerConfiguration.supportsVideo = true
        providerConfiguration.supportedHandleTypes = [.generic, .phoneNumber]
        providerConfiguration.ringtoneSound = "default.wav"
        providerConfiguration.iconTemplateImageData = UIImage(asset: Asset.jamiLogo)?.pngData()
        providerConfiguration.maximumCallGroups = 1
        providerConfiguration.maximumCallsPerCallGroup = 1

        provider = CXProvider(configuration: providerConfiguration)
        provider?.setDelegate(self, queue: nil)
        self.responseStream.disposed(by: disposeBag)
    }
}

extension CallsProviderDelegate {
    func stopCall(callUUID: UUID, participant: String) {
        // Send request end call to CallKit.
        let endCallAction = CXEndCallAction(call: callUUID)
        let transaction = CXTransaction(action: endCallAction)
        self.requestTransaction(transaction)
        // Remove call from pending unhandeled calls. Get pending call by jamiId, because uuid could be different for unhandeled call and for incoming call.
        if let call = getUnhandeledCall(peerId: participant) {
            // If unhandeled calls uuid is different from requested callUUID stop it.
            if call.uuid != callUUID {
                let endCallAction = CXEndCallAction(call: call.uuid)
                let transaction = CXTransaction(action: endCallAction)
                self.requestTransaction(transaction)
            }
            unhandeledCalls.remove(call)
        }
    }

    func hasPendingTransactions() -> Bool {
        return !self.callController.callObserver.calls.isEmpty
    }

    func handleIncomingCall(account: AccountModel, call: CallModel) {
        if let unhandeledCall = getUnhandeledCall(peerId: call.paricipantHash()) {
            defer {
                unhandeledCalls.remove(unhandeledCall)
            }
            call.callUUID = unhandeledCall.uuid
            if unhandeledCall.state != .awaiting {
                // CallKit already received user action before call received from the daemon. Notify call view about the action
                let serviceEventType: ServiceEventType = unhandeledCall.state == .answered ? .callProviderAnswerCall : .callProviderCancelCall
                var serviceEvent = ServiceEvent(withEventType: serviceEventType)
                serviceEvent.addEventInput(.callUUID, value: call.callUUID.uuidString)
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
        self.provider?.reportNewIncomingCall(with: call.callUUID,
                                             update: update) { error in
            if error == nil {
                return
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
        self.provider?.reportCall(with: call.callUUID, updated: update)
    }

    func previewPendingCall(peerId: String, withVideo: Bool, displayName: String,
                            completion: ((Error?) -> Void)?) {
        let update = CXCallUpdate()
        let handleType = CXHandle.HandleType.phoneNumber
        update.remoteHandle = CXHandle(type: handleType, value: peerId)
        self.setUpCallUpdate(update: update, localizedCallerName: displayName, videoFlag: withVideo)

        // Stop existing unhandeled call for jamiId
        if let existingUnhandeledCall = self.getUnhandeledCall(peerId: peerId) {
            self.stopCall(callUUID: existingUnhandeledCall.uuid, participant: existingUnhandeledCall.peerId)
        }
        let unhandeledCall = UnhandeledCall(peerId: peerId)
        unhandeledCalls.insert(unhandeledCall)
        self.provider?.reportNewIncomingCall(with: unhandeledCall.uuid,
                                             update: update) { error in
            if error == nil {
                return
            }
            completion?(error)
        }
        let serviceEventType: ServiceEventType = .callProviderPreviewPendingCall
        var serviceEvent = ServiceEvent(withEventType: serviceEventType)
        serviceEvent.addEventInput(.callUUID, value: unhandeledCall.uuid.uuidString)
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
        unhandeledCalls.forEach { call in
            stopCall(callUUID: call.uuid, participant: call.peerId)
        }
    }

    func getHandleInfo(account: AccountModel, call: CallModel) -> (displayName: String, handle: String)? {
        let type = account.type == AccountType.ring ? URIType.ring : URIType.sip
        let uri = JamiURI.init(schema: type, infoHash: call.participantUri, account: account)
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

    func getUnhandeledCall(UUID: UUID) -> UnhandeledCall? {
        return self.unhandeledCalls.filter { call in
            call.uuid == UUID
        }.first
    }

    func getUnhandeledCall(peerId: String) -> UnhandeledCall? {
        return self.unhandeledCalls.filter { call in
            call.peerId == peerId
        }.first
    }

    private func requestTransaction(_ transaction: CXTransaction) {
        callController.request(transaction) { error in
            if let error = error {
                print("Error requesting transaction: \(error)")
            } else {
                print("Requested transaction successfully")
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
extension CallsProviderDelegate: CXProviderDelegate {
    func providerDidReset(_ provider: CXProvider) {
    }

    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        defer {
            action.fulfill()
        }
        if let call = getUnhandeledCall(UUID: action.callUUID) {
            call.state = .answered
            return
        }
        let serviceEventType: ServiceEventType = .callProviderAnswerCall
        var serviceEvent = ServiceEvent(withEventType: serviceEventType)
        serviceEvent.addEventInput(.callUUID, value: action.callUUID.uuidString)
        self.responseStream.onNext(serviceEvent)
    }

    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        defer {
            action.fulfill()
        }
        if let call = getUnhandeledCall(UUID: action.callUUID) {
            call.state = .declined
            return
        }
        let serviceEventType: ServiceEventType = .callProviderCancelCall
        var serviceEvent = ServiceEvent(withEventType: serviceEventType)
        serviceEvent.addEventInput(.callUUID, value: action.callUUID.uuidString)
        self.responseStream.onNext(serviceEvent)
    }

    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        defer {
            action.fulfill()
        }
        let update = CXCallUpdate()
        update.remoteHandle = action.handle
        update.localizedCallerName = action.contactIdentifier
        update.hasVideo = action.isVideo
        self.provider?.reportCall(with: action.callUUID, updated: update)
    }

    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        let serviceEventType: ServiceEventType = .audioActivated
        let serviceEvent = ServiceEvent(withEventType: serviceEventType)
        self.responseStream.onNext(serviceEvent)
    }
}
