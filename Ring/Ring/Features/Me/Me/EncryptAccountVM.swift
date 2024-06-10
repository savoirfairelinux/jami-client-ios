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

import UIKit
import SwiftUI

class EncryptAccountVM: ObservableObject {

    @Published var newPassword: String = ""
    @Published var confirmPassword: String = ""
    @Published var currentPassword: String = ""
    @Published var validationError: String?
    @Published var encryptError: String?
    @Published var successMessage: String?
    @Published var savingPasswordInProgress: Bool = false
    @Published var buttonEnabled: Bool = true

    let account: AccountModel
    let accountService: AccountsService

    init(account: AccountModel, accountService: AccountsService) {
        self.account = account
        self.accountService = accountService
        self.updateButtonEnableState()
    }

    func validatePasswords() {
        self.successMessage = nil
        self.encryptError = nil
        if newPassword.isEmpty || confirmPassword.isEmpty {
            validationError = nil
        } else if newPassword != confirmPassword {
            validationError = L10n.AccountPage.passwordsDoNotMatch
        } else {
            validationError = nil
        }
        updateButtonEnableState()
    }

    private func updateButtonEnableState() {
        let currentPasswordValid = !hasPassword() || !currentPassword.isEmpty
        let newPasswordValid = !newPassword.isEmpty
        let confirmPasswordValid = !confirmPassword.isEmpty

        buttonEnabled = validationError == nil && newPasswordValid && confirmPasswordValid && currentPasswordValid
    }

    func changePassword() {
        let successMessage = hasPassword() ? L10n.AccountPage.passwordUpdated : L10n.AccountPage.passwordCreated
        let success = self.accountService
            .changePassword(forAccount: account.id, password: currentPassword, newPassword: newPassword)
        newPassword = ""
        confirmPassword = ""
        currentPassword = ""
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            self.savingPasswordInProgress = false
            self.encryptError = success ? nil : L10n.AccountPage.changePasswordError
            self.successMessage = success ? successMessage : nil
        }
    }

    func hasPassword() -> Bool {
        return AccountModelHelper(withAccount: account).hasPassword
    }
}
