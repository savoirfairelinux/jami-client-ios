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

        seedDriftTestContactsIfNeeded()
    }

    private func seedDriftTestContactsIfNeeded() {
        guard TestEnvironment.shared.seedDriftContacts,
              let accountId = TestEnvironment.shared.firstAccountId else { return }
        let adapter = ContactsAdapter()
        let peerA = "abc0000000000000000000000000000000000001"
        let peerB = "def0000000000000000000000000000000000002"
        adapter.addContact(withURI: peerA, accountId: accountId)
        adapter.addContact(withURI: peerB, accountId: accountId)
        adapter.removeContact(withURI: peerB, accountId: accountId, ban: true)
        let result = DriftCheck.run(forAccount: accountId, peerA: peerA, peerB: peerB)
        publishDriftResultForUITest(result)
    }

    private func publishDriftResultForUITest(_ result: String) {
        DispatchQueue.main.async {
            guard let window = UIApplication.shared.connectedScenes
                .compactMap({ ($0 as? UIWindowScene)?.windows.first(where: { $0.isKeyWindow }) })
                .first else { return }
            let existing = window.viewWithTag(0x0D1F7) as? UIView
            let view = existing ?? UIView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
            view.tag = 0x0D1F7
            view.isAccessibilityElement = true
            view.accessibilityIdentifier = "driftTestResult"
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
