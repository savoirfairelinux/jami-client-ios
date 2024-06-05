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

enum TestEnvironmentConst: String {
    case serverAddress
    case isRunningTest
    case createFirstAccount
    case createSecondAccount
}

class TestEnvironment {
    static let shared = TestEnvironment()

    var nameServerURI: String?

    var isRunningTest: Bool = false

    var createFirstAccount: Bool = false

    var createSecondAccount: Bool = false

    var firstAccountId: String?

    var secondAccountId: String?

    private init() {
        // For UI test we set local host as server address
        nameServerURI = ProcessInfo.processInfo.environment[TestEnvironmentConst.serverAddress.rawValue]

        if let isRunningTestString = ProcessInfo.processInfo.environment[TestEnvironmentConst.isRunningTest.rawValue],
           let isRunningTestBool = Bool(isRunningTestString), isRunningTestBool {
            isRunningTest = true

            // Check if we need to create account.
            if let createFirstAccountString = ProcessInfo.processInfo.environment[TestEnvironmentConst.createFirstAccount.rawValue],
               let createFirstAccountBool = Bool(createFirstAccountString), createFirstAccountBool {
                createFirstAccount = true
            }

            if let createSecondAccountString = ProcessInfo.processInfo.environment[TestEnvironmentConst.createSecondAccount.rawValue],
               let createSecondAccountBool = Bool(createSecondAccountString), createSecondAccountBool {
                createSecondAccount = true
            }
        }
    }
}
