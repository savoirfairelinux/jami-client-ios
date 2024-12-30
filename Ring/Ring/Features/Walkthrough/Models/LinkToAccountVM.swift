/*
 *  Copyright (C) 2024 Savoir-faire Linux Inc.
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

import Foundation
import RxSwift
import SwiftUI

private enum AuthenticationKeys {
    static let importAuthScheme = "import_auth_scheme"
    static let importAuthError = "import_auth_error"
    static let importPeerId = "import_peer_id"
}

enum InputError: String {
    case wrongPassword = "wrong_password"
    case networkError = "network_error"

    static func fromString(_ string: String) -> InputError? {
        return InputError(rawValue: string)
    }
}

enum AuthError: String {
    case wrongPassword = "wrong_password"
    case unknown = "network_error"

    static func fromString(_ string: String) -> AuthError? {
        return AuthError(rawValue: string)
    }
}

class LinkToAccountVM: ObservableObject, AvatarViewDataModel {
    var profileImage: UIImage?

    var profileName: String = ""

    @Published var username: String? = "test"
    var jamiId: String = ""

    @Published var pin: String = ""
    @Published var password: String = ""
    @Published var scannedCode: String?
    @Published var animatableScanSwitch: Bool = true
    @Published var notAnimatableScanSwitch: Bool = true
    @Published var showQRCode: Bool = false
    @Published var hasPassword: Bool = false

    private var tempAccount: String?
    private var accountsService: AccountsService
    private var nameService: NameService
    private let disposeBag = DisposeBag()
    
    @Published private(set) var uiState: LinkDeviceUIState = .initial

    var linkAction: ((_ pin: String, _ password: String) -> Void)

    var isLinkButtonEnabled: Bool {
        return !pin.isEmpty
    }

    var linkButtonColor: Color {
        return pin.isEmpty ? Color(UIColor.secondaryLabel) : .jamiColor
    }

    init(with injectionBag: InjectionBag, linkAction: @escaping ((_ pin: String, _ password: String) -> Void)) {
        self.linkAction = linkAction
        self.accountsService = injectionBag.accountService
        self.nameService = injectionBag.nameService
        self.retryConnection()
        setupDeviceAuthObserver()
    }

    func switchToQRCode() {
        withAnimation {
            showQRCode = true
        }
    }

    func switchToPin() {
        withAnimation {
            showQRCode = false
        }
    }

    func didScanQRCode(_ code: String) {
        self.pin = code
        self.scannedCode = code
    }

    private func setupDeviceAuthObserver() {
        accountsService.authStateSubject
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] result in
                self?.updateDeviceAuthState(result: result)
            })
            .disposed(by: disposeBag)
    }

    private func updateDeviceAuthState(result: AuthResult) {
        switch result.state {
            case .initializing:
                self.onInitSignal()
            case .tokenAvailable:
                self.onTokenAvailableSignal(details: result.details)
            case .connecting:
                self.onConnectingSignal()
            case .authenticating:
                self.onAuthenticatingSignal(details: result.details)
            case .inProgress:
                self.onInProgressSignal()
            case .done:
                self.onDoneSignal(details: result.details)
        }
    }
    
    private func onInitSignal() {
    }
    
    private func onTokenAvailableSignal(details: [String: String]) {
        if let pin = details["token"] {
            self.pin = pin
            uiState = .displayingPin(pin: pin)
        }
    }
    
    private func onConnectingSignal() {
        uiState = .connecting
    }
    
    private func onAuthenticatingSignal(details: [String: String]) {
        hasPassword = details[AuthenticationKeys.importAuthScheme] == "password"
        let authError = details[AuthenticationKeys.importAuthError].flatMap { InputError.fromString($0) }

        guard let jamiId = details[AuthenticationKeys.importPeerId] else {
            assertionFailure("Jami ID not found")
            return
        }
        self.jamiId = jamiId
        self.lookupUserName(jamiId: jamiId)
    }

    private func lookupUserName(jamiId: String) {
        guard let tempAccount = self.tempAccount else { return }
        self.nameService.usernameLookupStatus.asObservable()
            .filter({ lookupNameResponse in
                return lookupNameResponse.address == jamiId
            })
            .subscribe(onNext: { lookupNameResponse in
                if lookupNameResponse.state == .found && !lookupNameResponse.name.isEmpty {
                    self.username = lookupNameResponse.name
                }
            })
            .disposed(by: self.disposeBag)

        self.nameService.lookupAddress(withAccount: tempAccount,
                                       nameserver: "",
                                       address: jamiId)
    }

    func connect() {
        if let tempAccountId = tempAccount {
            self.accountsService.provideAccountAuthentication(accountId: tempAccountId, password: password)
        }
    }

    private func onInProgressSignal() {
        uiState = .inProgress
    }
    
    private func onDoneSignal(details: [String: String]) {
        let authError = details["error"].flatMap { AuthError.fromString($0) }
        if authError == nil {
            uiState = .success
        } else {
            uiState = .error(message: authError?.rawValue ?? "error")
        }
    }

    func onCancel() {
        // Remove temporary account if it exists
        if let tempAccountId = tempAccount {
            accountsService.removeAccount(id: tempAccountId)
        }
    }

    func retryConnection() {
        // Reset the state
        uiState = .initial
        // Attempt to recreate the temporary account and restart the process
        Task {
            tempAccount = try await accountsService.createTemplateAccount()
        }
    }
}

// Define UI states
enum LinkDeviceUIState: Equatable {
    case initial
    case displayingPin(pin: String)
    case connecting
    case authenticating
    case inProgress
    case success
    case error(message: String)
    
    static func == (lhs: LinkDeviceUIState, rhs: LinkDeviceUIState) -> Bool {
        switch (lhs, rhs) {
        case (.initial, .initial),
             (.connecting, .connecting),
             (.authenticating, .authenticating),
             (.inProgress, .inProgress),
             (.success, .success):
            return true
        case let (.displayingPin(pin1), .displayingPin(pin2)):
            return pin1 == pin2
        case let (.error(message1), .error(message2)):
            return message1 == message2
        default:
            return false
        }
    }
}
