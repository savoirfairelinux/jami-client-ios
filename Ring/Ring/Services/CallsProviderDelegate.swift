/*
 *  Copyright (C) 2019 Savoir-faire Linux Inc.
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

class CallsProviderDelegate: NSObject {
    private lazy var provider: CXProvider? = nil
    private lazy var callController = CXCallController()
    let responseStream = PublishSubject<ServiceEvent>()
    var sharedResponseStream: Observable<ServiceEvent>
    private let disposeBag = DisposeBag()

    override init() {
        self.sharedResponseStream = responseStream.share()
        super.init()
        let providerConfiguration = CXProviderConfiguration(localizedName: "Jami")

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
    func stopCall(callUUID: UUID) {
        let callController = CXCallController()
        let endCallAction = CXEndCallAction(call: callUUID)
        let transaction = CXTransaction(action: endCallAction)
        callController.request(transaction) { error in
            if let error = error {
                print("Error requesting transaction: \(error)")
            } else {
                print("Requested transaction successfully")
            }
        }
    }

    func reportIncomingCall(account: AccountModel, call: CallModel,
                            completion: ((Error?) -> Void)?) {
        let update = CXCallUpdate()
        let isJamiAccount = account.type == AccountType.ring
        guard let handleInfo = self.getHandleInfo(account: account, call: call) else { return }
        let handleType = (isJamiAccount
            || !handleInfo.handle.isPhoneNumber) ? CXHandle.HandleType.generic : CXHandle.HandleType.phoneNumber
        update.localizedCallerName = handleInfo.displayName
        update.remoteHandle = CXHandle(type: handleType, value: handleInfo.handle)
        update.hasVideo = !call.isAudioOnly
        update.supportsGrouping = false
        update.supportsUngrouping = false
        update.supportsHolding = false
        self.provider?.reportNewIncomingCall(with: call.callUUID,
                                             update: update) { error in
                                                if error == nil {
                                                    return
                                                }
                                                completion?(error)
        }
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

    func getHandleInfo(account: AccountModel, call: CallModel) -> (displayName: String, handle: String)? {
        let type = account.type == AccountType.ring ? URIType.ring : URIType.sip
        let uri = JamiURI.init(schema: type, infoHach: call.participantUri, account: account)
        guard var handle = uri.hash else { return nil }
        //for sip contact if account and contact have different host name add contact host name
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
                print("Error requesting transaction: \(error)")
            } else {
                print("Requested transaction successfully")
            }
        }
    }
}
// MARK: - CXProviderDelegate
extension CallsProviderDelegate: CXProviderDelegate {
    func providerDidReset(_ provider: CXProvider) {
    }

    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        let serviceEventType: ServiceEventType = .callProviderAnswerCall
        var serviceEvent = ServiceEvent(withEventType: serviceEventType)
        serviceEvent.addEventInput(.callUUID, value: action.callUUID.uuidString)
        self.responseStream.onNext(serviceEvent)
        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        let serviceEventType: ServiceEventType = .callProviderCancellCall
        var serviceEvent = ServiceEvent(withEventType: serviceEventType)
        serviceEvent.addEventInput(.callUUID, value: action.callUUID.uuidString)
        self.responseStream.onNext(serviceEvent)
        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        let update = CXCallUpdate()
        update.remoteHandle = action.handle
        update.localizedCallerName = action.contactIdentifier
        update.hasVideo = action.isVideo
        self.provider?.reportCall(with: action.callUUID, updated: update)
        action.fulfill()
    }

    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        let serviceEventType: ServiceEventType = .audioActivated
        let serviceEvent = ServiceEvent(withEventType: serviceEventType)
        self.responseStream.onNext(serviceEvent)
    }
}
