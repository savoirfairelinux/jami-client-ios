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

enum ErrorMessages {
    static let wrongPassword = "Wrong password"
    static let networkError = "Network error message"
    static let failedToGeneratePin = "Error when generating PIN"
    static let jamiIdNotFound = "Error when Jami ID is missing"
}

enum AuthSchemes {
    static let password = "password"
}

enum AuthenticationKeys {
    static let importAuthScheme = "auth_scheme"
    static let importAuthError = "auth_error"
    static let importPeerId = "peer_id"
    static let peerAddress = "peer_address"
    static let token = "token"
    static let error = "error"
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

    @Published var username: String?
    @Published var token: String = ""
    @Published var password: String = ""
    @Published var hasPassword: Bool = false
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
        return "Your code is: \(self.token)"
    }

    private func setupDeviceAuthObserver() {
        accountsService.authStateSubject
            .filter { $0.accountId == self.tempAccount }
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
        case .authenticating, .inProgress: validStates = [.inProgress, .done]
        case .error, .success: validStates = [.done]
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
        if let token = details[AuthenticationKeys.token] {
            self.token = token
            withAnimation { uiState = .displayingToken(pin: token) }
        } else {
            withAnimation { uiState = .error(message: ErrorMessages.failedToGeneratePin) }
        }
    }

    private func handleConnecting() {
        withAnimation { uiState = .connecting }
    }

    private func handleAuthenticating(details: [String: String]) {
        hasPassword = details[AuthenticationKeys.importAuthScheme] == AuthSchemes.password
        let authError = details[AuthenticationKeys.importAuthError].flatMap { AuthError.fromString($0) }
        if let errorMessage = authError?.rawValue {
            withAnimation { uiState = .error(message: errorMessage) }
            return
        }

        guard let jamiId = details[AuthenticationKeys.importPeerId] else {
            withAnimation { uiState = .error(message: ErrorMessages.jamiIdNotFound) }
            return
        }
        self.jamiId = jamiId
        self.lookupUserName(jamiId: jamiId)
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
        if let error = details[AuthenticationKeys.error].flatMap(AuthError.fromString) {
            withAnimation { uiState = .error(message: error.rawValue) }
        } else {
            withAnimation { uiState = .success }
        }
    }

    func onCancel() {
        // Remove temporary account if it exists
        if let tempAccountId = tempAccount {
            accountsService.removeAccount(id: tempAccountId)
        }
    }

    func start() {
        uiState = .initial
        setupDeviceAuthObserver()
        Task {
            tempAccount = try await accountsService.createTemplateAccount()
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
}
