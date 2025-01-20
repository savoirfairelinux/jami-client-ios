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

import SwiftUI

class BackupAccountModel: ObservableObject {
    enum ViewState {
        case loading
        case error(String)
        case success(String)
        case idle
    }

    enum ExportError: Error {
        case invalidFilePath
        case unableToAccessFile
        case exportFailed

        var displayMessage: String {
            switch self {
            case .invalidFilePath:
                return L10n.BackupAccount.errorWrongLocation
            case .unableToAccessFile:
                return L10n.BackupAccount.errorAccessDenied
            case .exportFailed:
                return L10n.BackupAccount.errorFailed
            }
        }
    }

    @Published private(set) var state: ViewState = .idle

    let account: AccountModel
    let accountService: AccountsService

    init(account: AccountModel, accountService: AccountsService) {
        self.account = account
        self.accountService = accountService
    }

    private func updateStateToLoading() {
        state = .loading
    }

    private func updateStateToError(_ message: String) {
        state = .error(message)
    }

    private func updateStateToSuccess(_ message: String) {
        state = .success(message)
    }

    func exportToFile(filePath: URL?,
                      fileName: String,
                      password: String) {
        updateStateToLoading()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            guard let filePath = filePath, !filePath.absoluteURL.path.isEmpty else {
                self.handleError(.invalidFilePath)
                return
            }

            guard filePath.startAccessingSecurityScopedResource() else {
                self.handleError(.unableToAccessFile)
                return
            }

            defer {
                filePath.stopAccessingSecurityScopedResource()
            }

            let archiveName = fileName + ".jac"
            let finalUrl = filePath.appendingPathComponent(archiveName)

            let exportSuccess = self.accountService.exportToFileWithPassword(
                accountId: self.account.id,
                destinationPath: finalUrl.absoluteURL.path,
                password: password
            )

            if !exportSuccess {
                self.handleError(.exportFailed)
            } else {
                self.handleSuccess()
            }
        }
    }

    private func handleError(_ error: ExportError) {
        DispatchQueue.main.async { [weak self] in
            withAnimation {
                guard let self = self else { return }
                self.updateStateToError(error.displayMessage)
            }
        }
    }

    private func handleSuccess() {
        DispatchQueue.main.async { [weak self] in
            withAnimation {
                guard let self = self else { return }
                self.updateStateToSuccess(L10n.BackupAccount.exportSuccess)
            }
        }
    }

    func hasPassword() -> Bool {
        return AccountModelHelper(withAccount: account).hasPassword
    }
}
