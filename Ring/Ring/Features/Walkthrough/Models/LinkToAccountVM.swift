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

enum LinkDeviceError {
    static let wrongPassword = L10n.LinkDevice.errorWrongPassword
    static let networkError = L10n.LinkDevice.errorNetwork
    static let failedToGenerateToken = L10n.LinkDevice.errorToken
    static let jamiIdNotFound = L10n.LinkDevice.errorWrongData
}

enum LinkDeviceConstants {
    enum AuthScheme {
        static let password = "password"
    }

    enum Keys {
        static let importAuthScheme = "auth_scheme"
        static let importAuthError = "auth_error"
        static let importPeerId = "peer_id"
        static let peerAddress = "peer_address"
        static let token = "token"
        static let error = "error"
    }
}

enum AuthError: String {
    case wrongPassword = "auth_error"
    case credentials = "invalid_credentials"
    case network = "network"
    case timeout = "timeout"
    case state = "state"
    case canceled = "canceled"

    static func fromString(_ string: String) -> AuthError? {
        return AuthError(rawValue: string)
    }

    func message() -> String {
        switch self {
        case .wrongPassword, .credentials: return L10n.LinkDevice.errorWrongPassword
        case .network: return L10n.LinkDevice.errorNetwork
        case .timeout: return L10n.LinkDevice.errorTimeout
        case .state: return L10n.LinkDevice.errorWrongData
        case .canceled: return "canceled"
        }
    }
}

class LinkToAccountVM: ObservableObject, AvatarViewDataModel {
    var profileImage: UIImage?
    var profileName: String = ""

    @Published var username: String?
    @Published var token: String = ""
    @Published var password: String = ""
    @Published var hasPassword: Bool = true
    @Published var authError: String?
    @Published private(set) var uiState: LinkDeviceUIState = .initial

    var jamiId: String = ""

    private var tempAccount: String?

    private var accountsService: AccountsService
    private var nameService: NameService
    private let disposeBag = DisposeBag()

    private var linkAction: (() -> Void)

    init(with injectionBag: InjectionBag, linkAction: @escaping (() -> Void)) {
        self.linkAction = linkAction
        self.accountsService = injectionBag.accountService
        self.nameService = injectionBag.nameService
        self.start()
    }

    func linkCompleted() {
        if let accountId = tempAccount {
            guard let account = self.accountsService.getAccount(fromAccountId: accountId) else { return }
            self.accountsService.updateCurrentAccount(account: account)
            UserDefaults.standard.set(accountId, forKey: self.accountsService.selectedAccountID)
        }
        linkAction()
    }

    func getShareInfo() -> String {
        let info: String = self.token
        return L10n.LinkToAccount.shareMessage(info)
    }

    private func setupDeviceAuthObserver() {
        accountsService.authStateSubject
            .filter { [weak self] in $0.accountId == self?.tempAccount }
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] result in
                self?.updateDeviceAuthState(result: result)
            })
            .disposed(by: disposeBag)
    }

    private func checkNewStateValidity(newState: AuthState) -> Bool {
        let validStates: [AuthState]

        switch uiState {
        case .initial: validStates = [.tokenAvailable, .done]
        case .displayingToken: validStates = [.tokenAvailable, .connecting, .done]
        case .connecting: validStates = [.authenticating, .done]
        case .authenticating, .inProgress: validStates = [.inProgress, .done, .authenticating]
        case .error, .success: validStates = [.done, .authenticating, .inProgress]
        }

        return validStates.contains(newState)
    }

    private func updateDeviceAuthState(result: AuthResult) {
        guard checkNewStateValidity(newState: result.state) else { return }

        switch result.state {
        case .initializing: break
        case .tokenAvailable: handleTokenAvailable(details: result.details)
        case .connecting: handleConnecting()
        case .authenticating: handleAuthenticating(details: result.details)
        case .inProgress: handleInProgress()
        case .done: handleDone(details: result.details)
        }
    }

    private func handleTokenAvailable(details: [String: String]) {
        if let token = details[LinkDeviceConstants.Keys.token] {
            self.token = token
            withAnimation { uiState = .displayingToken(pin: token) }
        } else {
            withAnimation { uiState = .error(message: LinkDeviceError.failedToGenerateToken) }
        }
    }

    private func handleConnecting() {
        withAnimation { uiState = .connecting }
    }

    private func handleAuthenticating(details: [String: String]) {
        hasPassword = details[LinkDeviceConstants.Keys.importAuthScheme] == LinkDeviceConstants.AuthScheme.password
        let authError = details[LinkDeviceConstants.Keys.importAuthError].flatMap { AuthError.fromString($0) }
        if let errorMessage = authError?.message() {
            self.authError = errorMessage
        }

        guard let jamiId = details[LinkDeviceConstants.Keys.importPeerId] else {
            return
        }
        self.jamiId = jamiId
        if self.username == nil {
            self.lookupUserName(jamiId: jamiId)
        }
        withAnimation { uiState = .authenticating }
    }

    private func lookupUserName(jamiId: String) {
        guard let tempAccount = self.tempAccount else { return }
        self.nameService.usernameLookupStatus.asObservable()
            .filter({ response in
                return response.address == jamiId
            })
            .subscribe(onNext: { [weak self] response in
                if response.state == .found && !response.name.isEmpty {
                    DispatchQueue.main.async { self?.username = response.name }
                }
            })
            .disposed(by: self.disposeBag)

        self.nameService.lookupAddress(withAccount: tempAccount,
                                       nameserver: "",
                                       address: jamiId)
    }

    func connect() {
        handleInProgress()
        if let tempAccountId = tempAccount {
            accountsService.provideAccountAuthentication(accountId: tempAccountId, password: password)
        }
    }

    private func handleInProgress() {
        withAnimation { uiState = .inProgress }
    }

    private func handleDone(details: [String: String]) {
        if let errorString = details[LinkDeviceConstants.Keys.error],
           !errorString.isEmpty,
           errorString != "none",
           let error = AuthError(rawValue: errorString) {
            withAnimation { self.uiState = .error(message: error.message()) }
        } else {
            withAnimation { self.uiState = .success }
        }
    }

    func onCancel() {
        if let tempAccountId = tempAccount {
            accountsService.removeAccount(id: tempAccountId)
        }
    }

    func shouldShowAlert() -> Bool {
        return !self.uiState.isCancelableState()
    }

    func start() {
        uiState = .initial
        setupDeviceAuthObserver()
        Task {
            tempAccount = try await accountsService.createTemporaryAccount()
        }
    }
}

enum LinkDeviceUIState: Equatable {
    case initial
    case displayingToken(pin: String)
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
        case let (.displayingToken(token1), .displayingToken(token2)):
            return token1 == token2
        case let (.error(message1), .error(message2)):
            return message1 == message2
        default:
            return false
        }
    }

    func isCancelableState() -> Bool {
        switch self {
        case .initial, .displayingToken, .success, .error:
            return true
        default:
            return false
        }
    }
}
