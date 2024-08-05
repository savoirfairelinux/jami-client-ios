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

extension AppDelegate {

    func setUpTestDataIfNeed() {
        guard TestEnvironment.shared.isRunningTest else { return }

        removeAllAccounts()

        func addAccount(createFlag: Bool, accountIdSetter: @escaping (String) -> Void) {
            guard createFlag else { return }
            var disposeBag = DisposeBag()
            let dispatchGroup = DispatchGroup()
            dispatchGroup.enter()
            self.accountService.addJamiAccount(username: "", password: "", profileName: "", enable: false)
                .take(1)
                .subscribe(onNext: { account in
                    accountIdSetter(account.id)
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
