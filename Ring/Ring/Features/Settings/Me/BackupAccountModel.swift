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

enum ExportError: Error {
    case invalidFilePath
    case unableToAccessFile
    case exportFailed

    var userFriendlyMessage: String {
        switch self {
            case .invalidFilePath:
                return "The selected file path is invalid. Please choose a different location."
            case .unableToAccessFile:
                return "Access to the selected location was denied."
            case .exportFailed:
                return "The export operation failed."
        }
    }
}

class BackupAccountModel: ObservableObject {
    @Published var errorMessage: String? =  nil
    @Published var successMessage: String? = nil

    let account: AccountModel
    let accountService: AccountsService

    init(account: AccountModel, accountService: AccountsService) {
        self.account = account
        self.accountService = accountService
    }

    func exportToFile(filePath: URL?,
                      fileName: String,
                      password: String) {
        guard let filePath = filePath, !filePath.absoluteURL.path.isEmpty else {
            handleError(.invalidFilePath)
            return
        }

        // Access the security-scoped resource
        guard filePath.startAccessingSecurityScopedResource() else {
            handleError(.unableToAccessFile)
            return
        }

        defer {
            filePath.stopAccessingSecurityScopedResource()
        }

        let finalUrl = filePath.appendingPathComponent(fileName)

        let exportSuccess = accountService.exportToFileWithPassword(accountId: account.id, destinationPath: finalUrl.absoluteURL.path, password: password)

        if !exportSuccess {
            handleError(.exportFailed)
        } else {
            withAnimation {
                successMessage = "Backup created"
            }
        }
    }

    private func handleError(_ error: ExportError) {
        withAnimation {
            errorMessage = error.userFriendlyMessage
        }
    }

    func hasPassword() -> Bool {
        return AccountModelHelper(withAccount: account).hasPassword
    }

}
