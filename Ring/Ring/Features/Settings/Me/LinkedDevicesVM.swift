/*
 *  Copyright (C) 2024 Savoir-faire Linux Inc.
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

import SwiftUI
import RxSwift

enum ExportAccountResponse: Int {
    case success = 0
    case wrongPassword = 1
    case networkProblem = 2
}

enum PinError {
    case passwordError
    case networkError
    case defaultError

    var description: String {
        switch self {
        case .passwordError:
            return L10n.LinkDevice.passwordError
        case .networkError:
            return L10n.LinkDevice.networkError
        case .defaultError:
            return L10n.LinkDevice.defaultError
        }
    }
}

enum GeneratingPinState {

    case initial
    case generatingPin
    case success(pin: String)
    case error(error: PinError)

    var rawValue: String {
        switch self {
        case .initial:
            return "INITIAL"
        case .generatingPin:
            return "GENERATING_PIN"
        case .success:
            return "SUCCESS"
        case .error:
            return "ERROR"
        }
    }

    func isStateOfType(type: String) -> Bool {

        return self.rawValue == type
    }
}

enum ActionsState {
    case deviceRevokedWithSuccess(deviceId: String)
    case deviceRevocationError(deviceId: String, errorMessage: String)
    case showLoading
    case hideLoading
    case usernameRegistered
    case usernameRegistrationFailed(errorMessage: String)
    case noAction
}

// enum AuthState {
//    case initial
//    case connecting
//    case authenticating
//    case inProgress
//    case done
// }

enum AddDeviceExportState {
    case initial(error: AuthError? = nil)
    case connecting
    case authenticating(peerAddress: String?)
    case inProgress
    case done(error: AuthError?)
}

class LinkedDevicesVM: ObservableObject {

    @Published var devices = [DeviceModel]()
    @Published var revocationError: String?
    @Published var revocationSuccess: String?
    @Published var generatingState = GeneratingPinState.initial
    @Published var PINImage: UIImage?
    @Published var showLinkDeviceAlert: Bool = false
    @Published var exportState: AddDeviceExportState = .initial()
    let account: AccountModel
    let accountService: AccountsService

    let disposeBag = DisposeBag()

    private var operationId: UInt32 = 0

    init(account: AccountModel, accountService: AccountsService) {
        self.account = account
        self.accountService = accountService
        self.subscribeDevices()
    }

    func subscribeDevices() {
        self.accountService.devicesObservable(account: account)
            .subscribe(onNext: { [weak self] device in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.devices = device
                }
            })
            .disposed(by: self.disposeBag)
    }

    func editDeviceName(name: String) {
        self.accountService.setDeviceName(accountId: self.account.id, deviceName: name)
    }

    func hasPassword() -> Bool {
        return AccountModelHelper(withAccount: account).hasPassword
    }

    func revokeDevice(deviceId: String, accountPassword password: String) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            self.subscribeToDeviceRevocationEvents(for: deviceId)

            self.accountService.revokeDevice(for: self.account.id, withPassword: password, deviceId: deviceId)
        }
    }

    func showLinkDevice() {
        showLinkDeviceAlert = true
        if !self.hasPassword() {
            self.linkDevice(with: "")
        }
    }

    func linkDevice(with password: String) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            self.updateStateOnMainThread(GeneratingPinState.generatingPin)

            if self.hasPassword() && password.isEmpty {
                updateStateOnMainThread(.error(error: PinError.passwordError))
                return
            }

            self.accountService.sharedResponseStream
                .filter({ [weak self] exportCompletedEvent in
                    guard let self = self else { return false }
                    return exportCompletedEvent.eventType == ServiceEventType.exportOnRingEnded &&
                        exportCompletedEvent.getEventInput(.id) == self.accountService.currentAccount?.id
                })
                .subscribe(onNext: { [weak self] exportCompletedEvent in
                    guard let self = self else { return }
                    if let state: Int = exportCompletedEvent.getEventInput(.state) {
                        self.handleExportCompletedEvent(with: state, event: exportCompletedEvent)
                    }
                })
                .disposed(by: self.disposeBag)

            self.accountService.exportOnRing(withPassword: password)
                .subscribe(onCompleted: {
                }, onError: { [weak self] _ in
                    guard let self = self else { return }
                    self.updateStateOnMainThread(.error(error: PinError.passwordError))
                })
                .disposed(by: self.disposeBag)
        }
    }

    func cleanInfoMessages() {
        revocationError = nil
        revocationSuccess = nil
        updateStateOnMainThread(.initial)
    }

    private func subscribeToDeviceRevocationEvents(for deviceId: String) {
        self.accountService.sharedResponseStream
            .filter { [weak self] deviceEvent in
                guard let self = self else { return false }
                return deviceEvent.eventType == ServiceEventType.deviceRevocationEnded &&
                    deviceEvent.getEventInput(.accountId) == self.account.id
            }
            .subscribe(onNext: { [weak self] deviceEvent in
                guard let self = self else { return }
                self.handleDeviceRevocationEvent(deviceEvent, for: deviceId)
            })
            .disposed(by: self.disposeBag)
    }

    private func handleDeviceRevocationEvent(_ deviceEvent: ServiceEvent, for deviceId: String) {
        if let state: Int = deviceEvent.getEventInput(.state),
           let eventDeviceId: String = deviceEvent.getEventInput(.deviceId),
           deviceId == eventDeviceId {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.devices = self.account.devices
                self.handleRevocationState(state)
            }
        }
    }

    private func handleRevocationState(_ state: Int) {
        switch state {
        case DeviceRevocationState.success.rawValue:
            self.revocationSuccess = L10n.AccountPage.deviceRevocationSuccess
        case DeviceRevocationState.wrongPassword.rawValue:
            self.revocationError = L10n.AccountPage.deviceRevocationWrongPassword
        case DeviceRevocationState.unknownDevice.rawValue:
            self.revocationError = L10n.AccountPage.deviceRevocationUnknownDevice
        default:
            self.revocationError = L10n.AccountPage.deviceRevocationError
        }
    }

    private func updateStateOnMainThread(_ state: GeneratingPinState) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.generatingState = state
        }
    }

    private func handleExportCompletedEvent(with state: Int, event: ServiceEvent) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            switch state {
            case ExportAccountResponse.success.rawValue:
                if let pin: String = event.getEventInput(.pin) {
                    self.PINImage = pin.generateQRCode()
                    updateStateOnMainThread(.success(pin: pin))
                } else {
                    updateStateOnMainThread(.error(error: PinError.defaultError))
                }
            case ExportAccountResponse.wrongPassword.rawValue:
                updateStateOnMainThread(.error(error: PinError.passwordError))
            case ExportAccountResponse.networkProblem.rawValue:
                updateStateOnMainThread(.error(error: PinError.networkError))
            default:
                updateStateOnMainThread(.error(error: PinError.defaultError))
            }
        }
    }

    func handleAuthenticationUri(_ jamiAuthentication: String) {
        guard !jamiAuthentication.isEmpty,
              jamiAuthentication.hasPrefix("jami-auth://"),
              jamiAuthentication.count == 59 else {
            print("Invalid input: \(jamiAuthentication)")
            updateStateOnMainThread(.error(error: .defaultError))
            return
        }

        self.accountService.authStateSubject
            .filter { [weak self] authResult in
                guard let self = self else { return false }
                return authResult.accountId == self.account.id &&
                    authResult.operationId == self.operationId
            }
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] authResult in
                self?.handleAuthResult(authResult)
            })
            .disposed(by: disposeBag)

        operationId = self.accountService.addDevice(accountId: account.id, token: jamiAuthentication)

        //        self.accountService.authStateSubject
        //            .filter { [weak self] authResult in
        //                guard let self = self else { return false }
        //                return authResult.accountId == self.account.id &&
        //                       authResult.operationId == self.operationId
        //            }
        //            .observe(on: MainScheduler.instance)
        //            .subscribe(onNext: { [weak self] authResult in
        //                self?.handleAuthResult(authResult)
        //            })
        //            .disposed(by: disposeBag)
    }

    private func handleAuthResult(_ result: AuthResult) {
        guard checkNewStateValidity(result.state) else {
            print("Invalid state transition: \(exportState) -> \(result.state)")
            return
        }

        print("Processing signal: \(result.accountId):\(result.operationId):\(result.state) \(result.details)")

        switch result.state {
        case .initializing:
            break // Handle initial state if needed
        case .connecting:
            handleConnectingSignal()
        case .authenticating:
            handleAuthenticatingSignal(result.details)
        case .inProgress:
            handleInProgressSignal()
        case .done:
            handleDoneSignal(result.details)
        case .tokenAvailable:
            break
        }
    }

    private func checkNewStateValidity(_ newState: AuthState) -> Bool {
        return true
        //        switch exportState {
        //        case .initial:
        //            return [.connecting, .done].contains(newState)
        //        case .connecting:
        //            return [.authenticating, .done].contains(newState)
        //        case .authenticating:
        //            return [.inProgress, .done].contains(newState)
        //        case .inProgress:
        //            return [.done].contains(newState)
        //        case .done:
        //            return [.done].contains(newState)
        //        }
    }

    private func handleConnectingSignal() {
        DispatchQueue.main.async {
            self.exportState = .connecting
        }
    }

    private func handleAuthenticatingSignal(_ details: [String: String]) {
        DispatchQueue.main.async {
            let peerAddress = details["exportPeerAddress"]
            self.exportState = .authenticating(peerAddress: peerAddress)
        }
    }

    private func handleInProgressSignal() {
        DispatchQueue.main.async {
            self.exportState = .inProgress
        }
    }

    private func handleDoneSignal(_ details: [String: String]) {
        DispatchQueue.main.async {
            let errorString = details["error"]
            let error = errorString.flatMap { $0.isEmpty || $0 == "none" ? nil : AuthError(rawValue: $0) }
            self.exportState = .done(error: error)
        }
    }

    func confirmAddDevice() {
        accountService.confirmAddDevice(accountId: account.id, operationId: operationId)
    }

    func cancelAddDevice() {
        accountService.cancelAddDevice(accountId: account.id, operationId: operationId)
    }

    deinit {
        if case .done = exportState {} else {
            cancelAddDevice()
        }
    }
}
