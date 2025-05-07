import Foundation
import UIKit
import RxSwift

enum MigrationAction {
    case migrate
    case remove
    case cancel
    case migrateAnother
}

class AccountMigrationModel: ObservableObject, AccountProfileObserver {
    @Published  var avatar: UIImage = UIImage()

    @Published var profileName: String = ""

    @Published var registeredName: String = ""

    @Published var bestName: String = ""

    var profileDisposeBag = DisposeBag()
    var selectedAccount: String?

    var avatarSize: CGFloat = 500
    @Published var jamiId: String = ""
    @Published var needsPassword: Bool = false
    @Published var isLoading: Bool = false
    @Published var migrationCompleted: Bool = false
    @Published var error: String?

    private let accountService: AccountsService
    let profileService: ProfilesService
    private let disposeBag = DisposeBag()
    private let accountId: String

    init(accountId: String, accountService: AccountsService, profileService: ProfilesService) {
        self.accountId = accountId
        self.selectedAccount = accountId
        self.accountService = accountService
        self.profileService = profileService
        self.updateAccountInfo()
    }

    private func updateAccountInfo() {
        if let account = accountService.getAccount(fromAccountId: accountId) {
            jamiId = account.jamiId
            needsPassword = AccountModelHelper(withAccount: account).hasPassword
            self.updateProfileDetails(account: account)
        }
    }

    func handleMigration(password: String = "") {
//        isLoading = true
//        error = nil

        if let account = self.accountService.getAccount(fromAccountId: self.accountId) {
            let selectedAccounKey = self.accountService.selectedAccountID
            UserDefaults.standard.set(self.accountId, forKey: selectedAccounKey)
            self.accountService.currentAccount = account
        } else {
        self.error = "failed"
    }


//        accountService.migrateAccount(account: accountId, password: password)
//            .subscribe(onNext: { [weak self] success in
//                guard let self = self else { return }
//                if success {
//                    if let account = self.accountService.getAccount(fromAccountId: self.accountId) {
//                       let selectedAccounKey = self.accountService.selectedAccountID 
//                        UserDefaults.standard.set(self.accountId, forKey: selectedAccounKey)
//                        self.accountService.currentAccount = account
//                    }
//                } else {
//                    self.error = "failed"
//                }
//                self.isLoading = false
//                self.migrationCompleted = true
//                completion()
//            }, onError: { [weak self] error in
//                self?.isLoading = false
//                self?.error = error.localizedDescription
//            })
//            .disposed(by: disposeBag)
    }
    
    func removeAccount() {
        accountService.removeAccount(id: accountId)
    }
    
    func getNextAccountToMigrate() -> String? {
        for account in accountService.accounts where
            (account.id != accountId && account.status == .errorNeedMigration) {
            return account.id
        }
        return nil
    }
    
    func getNextValidAccount() -> String? {
        for account in accountService.accounts where
            (account.id != accountId && account.status != .errorNeedMigration) {
            return account.id
        }
        return nil
    }
    
    var hasValidAccounts: Bool {
        return accountService.hasValidAccount()
    }
    
    var hasMultipleAccounts: Bool {
        return accountService.accounts.count > 1
    }
} 
