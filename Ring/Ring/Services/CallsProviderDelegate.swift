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
    @available(iOS 10.0, *)
    private lazy var provider: CXProvider? = nil
    @available(iOS 10.0, *)
    private lazy var callController = CXCallController()
    let responseStream = PublishSubject<ServiceEvent>()
    var sharedResponseStream: Observable<ServiceEvent>
    fileprivate let disposeBag = DisposeBag()

    override init() {
        self.sharedResponseStream = responseStream.share()
        super.init()
        if #available(iOS 10.0, *) {
            let providerConfiguration = CXProviderConfiguration(localizedName: "Jami")

            providerConfiguration.supportsVideo = true
            providerConfiguration.supportedHandleTypes = [.generic]
            providerConfiguration.ringtoneSound = "default.wav"

            provider = CXProvider(configuration: providerConfiguration)
            provider?.setDelegate(self, queue: nil)
        }
        self.responseStream.disposed(by: disposeBag)
    }
}

// MARK: - iOS 10
@available(iOS 10.0, *)
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

    func reportIncomingCall(uuid: UUID, name: String,
                            hasVideo: Bool, uri: String,
                            completion: ((Error?) -> Void)?) {
        let update = CXCallUpdate()
        update.localizedCallerName = uri
        update.remoteHandle = CXHandle(type: .generic, value: uri)
        update.hasVideo = hasVideo
        provider?.reportNewIncomingCall(with: uuid,
                                        update: update) { error in
                                            if error == nil {
                                                return
                                            }
                                            completion?(error)
        }
    }

    func startCall(handle: String, name: String, videoEnabled: Bool, callUUID: UUID) {
        let contactHandle = CXHandle(type: .generic, value: handle)
        let startCallAction = CXStartCallAction(call: callUUID, handle: contactHandle)
        startCallAction.isVideo = videoEnabled
        startCallAction.contactIdentifier = handle
        let transaction = CXTransaction(action: startCallAction)
        requestTransaction(transaction)
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
@available(iOS 10.0, *)
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
}
