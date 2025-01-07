/*
 *  Copyright (C) 2025 Savoir-faire Linux Inc.
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

enum AddDeviceExportState {
    case initial(error: AuthError? = nil)
    case connecting
    case authenticating(peerAddress: String?)
    case inProgress
    case success
    case error(error: String)

    func isCancelableState() -> Bool {
        switch self {
        case .initial, .success, .error:
            return true
        default:
            return false
        }
    }
}

class LinkDeviceVM: ObservableObject {
    static let schema = "jami-auth://"
    @Published var exportState: AddDeviceExportState = .initial()
    @Published var exportToken: String = "jami-auth://"
    @Published var entryError: String?
    let account: AccountModel
    let accountService: AccountsService

    let disposeBag = DisposeBag()
    var codeProvided = false

    private var operationId: UInt32 = 0

    init(account: AccountModel, accountService: AccountsService) {
        self.account = account
        self.accountService = accountService
    }

    func cleanState() {
        entryError = nil
        exportToken = LinkDeviceVM.schema
    }

    func handleAuthenticationUri(_ jamiAuthentication: String) {
        entryError = nil
        if codeProvided {
            return
        }
        guard !jamiAuthentication.isEmpty,
              jamiAuthentication.hasPrefix(LinkDeviceVM.schema),
              jamiAuthentication.count == 59 else {
            entryError = L10n.LinkDevice.wrongEntry
            return
        }

        codeProvided = true

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
    }

    private func handleAuthResult(_ result: AuthResult) {
        guard checkNewStateValidity(newState: result.state) else {
            print("Invalid state transition: \(exportState) -> \(result.state)")
            return
        }

        print("Processing signal: \(result.accountId):\(result.operationId):\(result.state) \(result.details)")

        switch result.state {
        case .initializing:
            break
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

    private func checkNewStateValidity(newState: AuthState) -> Bool {
        let validStates: [AuthState]

        switch exportState {
        case .initial: validStates = [.connecting, .done]
        case .connecting: validStates = [.authenticating, .done]
        case .authenticating: validStates = [.inProgress, .done]
        case .inProgress: validStates = [.inProgress, .done]
        case .error, .success: validStates = [.done]
        }

        return validStates.contains(newState)
    }

    private func handleConnectingSignal() {
        withAnimation { self.exportState = .connecting }
    }

    private func handleAuthenticatingSignal(_ details: [String: String]) {
        let peerAddress = details[LinkDeviceConstants.Keys.peerAddress]
        withAnimation { self.exportState = .authenticating(peerAddress: peerAddress) }
    }

    private func handleInProgressSignal() {
        withAnimation { self.exportState = .inProgress }
    }

    private func handleDoneSignal(_ details: [String: String]) {
        if let errorString = details[LinkDeviceConstants.Keys.error],
           !errorString.isEmpty,
           errorString != "none",
           let error = AuthError(rawValue: errorString) {
            withAnimation { self.exportState = .error(error: error.message()) }
        } else {
            withAnimation { self.exportState = .success }
        }
    }

    func confirmAddDevice() {
        self.handleInProgressSignal()
        accountService.confirmAddDevice(accountId: account.id, operationId: operationId)
    }

    func cancelAddDevice() {
        self.handleInProgressSignal()
        accountService.cancelAddDevice(accountId: account.id, operationId: operationId)
    }

    func shouldShowAlert() -> Bool {
        return !self.exportState.isCancelableState()
    }
}
