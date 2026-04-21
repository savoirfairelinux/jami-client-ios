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

#if DEBUG

import Foundation
import UIKit
import RxSwift

extension AppDelegate {

    func setUpTestDataIfNeed() {
        guard TestEnvironment.shared.isRunningTest else { return }

        removeAllAccounts()

        func addAccount(createFlag: Bool, accountIdSetter: @escaping (String) -> Void) {
            guard createFlag else { return }
            var disposeBag = DisposeBag()
            let dispatchGroup = DispatchGroup()
            dispatchGroup.enter()
            self.accountService.addJamiAccount(username: "", password: "", pin: "", arhivePath: "", profileName: "")
                .take(1)
                .subscribe(onNext: { accountId in
                    accountIdSetter(accountId)
                    dispatchGroup.leave()
                    disposeBag = DisposeBag()
                })
                .disposed(by: disposeBag)
            _ = dispatchGroup.wait(timeout: .now() + 5)
        }

        addAccount(createFlag: TestEnvironment.shared.createFirstAccount) { id in
            TestEnvironment.shared.firstAccountId = id
        }

        addAccount(createFlag: TestEnvironment.shared.createSecondAccount) { id in
            TestEnvironment.shared.secondAccountId = id
        }

        runContactsFormatCheckIfNeeded()
    }

    private func runContactsFormatCheckIfNeeded() {
        guard TestEnvironment.shared.seedTestContacts,
              let accountId = TestEnvironment.shared.firstAccountId else { return }
        let adapter = ContactsAdapter()
        let active = TestEnvironment.shared.activeContactPeerId
        let banned = TestEnvironment.shared.bannedContactPeerId
        adapter.addContact(withURI: active, accountId: accountId)
        adapter.addContact(withURI: banned, accountId: accountId)
        adapter.removeContact(withURI: banned, accountId: accountId, ban: true)
        let result = ContactsFormatCheck.run(forAccount: accountId, peerA: active, peerB: banned)
        publishContactsFormatCheckResult(result)
    }

    private func publishContactsFormatCheckResult(_ result: String) {
        DispatchQueue.main.async {
            guard let window = UIApplication.shared.connectedScenes
                    .compactMap({ ($0 as? UIWindowScene)?.windows.first(where: { $0.isKeyWindow }) })
                    .first else { return }
            let identifier = TestSupportAccessibilityIdentifiers.contactsFormatCheckResult
            let existing = window.subviews.first { $0.accessibilityIdentifier == identifier }
            let view = existing ?? UIView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
            view.isAccessibilityElement = true
            view.accessibilityIdentifier = identifier
            view.accessibilityLabel = result
            if existing == nil {
                window.addSubview(view)
            }
        }
    }

    func cleanTestDataIfNeed() {
        if TestEnvironment.shared.isRunningTest {
            removeAllAccounts()
        }
    }

    private func removeAllAccounts() {
        if let accountIds = self.accountService.getAccountsId() {
            let dispatchGroup = DispatchGroup()
            for accountId in accountIds {
                dispatchGroup.enter()
                var disposeBag = DisposeBag()
                self.accountService.removeAccountAndWaitForCompletion(id: accountId)
                    .take(1)
                    .subscribe(onNext: { _ in
                        dispatchGroup.leave()
                        disposeBag = DisposeBag()
                    })
                    .disposed(by: disposeBag)
            }
            _ = dispatchGroup.wait(timeout: .now() + 5)
        }
    }
}

#endif
