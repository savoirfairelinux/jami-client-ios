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

class LinkedDevicesVM: ObservableObject {

    @Published var devices = [DeviceModel]()
    @Published var revocationError: String?
    @Published var revocationSuccess: String?
    @Published var generatingState = GeneratingPinState.initial
    @Published var PINImage: UIImage?
    @Published var showLinkDeviceAlert: Bool = false
    let account: AccountModel
    let accountService: AccountsService

    let disposeBag = DisposeBag()

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
                    deviceEvent.getEventInput(.id) == self.account.id
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
}
