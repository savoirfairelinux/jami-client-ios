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

import Foundation

struct AccessibilityIdentifiers {
    static let joinJamiButton = "joinJamiButtonIdentifier"
    static let usernameTextField = "usernameTextField"
    static let joinButton = "joinButton"
    static let accountRegisteredName = "accountRegisteredName"
    static let accountJamiId = "accountJamiId"
    static let cancelCreatingAccount = "cancelCreatingAccount"
    static let createAccountView = "createAccountView"
    static let createAccountTitle = "createAccountTitle"
    static let createAccountUserNameLabel = "createAccountUserNameLabel"
    static let createAccountErrorLabel = "createAccountErrorLabel"
    static let welcomeWindow = "welcomeWindow"
}

struct SmartListAccessibilityIdentifiers {
    static let openAccountsButton = "accountsInformationIdentifier"
    static let addAccountButton = "addAccountButtonIdentifier"
    static let openMenuInSmartList = "openMenuInSmartList"
    static let conversationView = "conversationView"
    static let backgroundCover = "backgroundCover"
    static let accountListView = "accountListView"
    static let bookButton = "bookButtonIdentifier"
    static let searchBarTextField = "searchBarTextField"
    static let contactPicker = "contactPicker"
    static let accountsListTitle = "accountsListTitle"
    static let closeAccountsList = "closeAccountsList"
    static let closeAboutView = "closeAboutView"
    static let requestsCloseButton = "requestsCloseButton"

}
