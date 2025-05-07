import Foundation
import UIKit
import RxSwift

enum MigrationAction {
    case migrate
    case remove
    case cancel
    case migrateAnother
}

class AccountMigrationModel: ObservableObject {
    @Published var profileImage: UIImage?
    @Published var accountName: String = ""
    @Published var jamiId: String = ""
    @Published var username: String = ""
    @Published var needsPassword: Bool = false
    @Published var canCancel: Bool = true
    @Published var canMigrateAnother: Bool = false
    @Published var isLoading: Bool = false
    @Published var error: String?
    
    private let accountService: AccountsService
    private let profileService: ProfilesService
    private let disposeBag = DisposeBag()
    private let accountId: String
    
    init(accountId: String, accountService: AccountsService, profileService: ProfilesService) {
        self.accountId = accountId
        self.accountService = accountService
        self.profileService = profileService
        updateAccountInfo()
    }
    
    private func updateAccountInfo() {
        // Get profile image
        profileService.getAccountProfile(accountId: accountId)
            .take(1)
            .subscribe(onNext: { [weak self] profile in
                if let photo = profile.photo,
                   let data = NSData(base64Encoded: photo,
                                     options: NSData.Base64DecodingOptions
                                        .ignoreUnknownCharacters) as Data? {
                    self?.profileImage = UIImage(data: data)
                } else {
                    self?.profileImage = UIImage(named: "fallback_avatar")
                }
            })
            .disposed(by: disposeBag)
        
        // Get account details
        let details = accountService.getAccountDetails(fromAccountId: accountId)
        accountName = details.get(withConfigKeyModel: ConfigKeyModel.init(withKey: .displayName))
        
        if let account = accountService.getAccount(fromAccountId: accountId) {
            jamiId = account.jamiId ?? ""
            username = account.registeredName
            needsPassword = AccountModelHelper(withAccount: account).hasPassword
            canCancel = accountService.hasValidAccount()
            canMigrateAnother = !accountService.hasValidAccount() &&
                accountService.accounts.count > 1
        }
    }
    
    func handleMigration(password: String = "") {//-> Observable<Void> {
//        isLoading = true
//        error = nil
        
//        return accountService.migrateAccount(account: accountId, password: password)
//            .do(onNext: { [weak self] _ in
//                if let account = self?.accountService.getAccount(fromAccountId: self?.accountId ?? ""),
//                   let selectedAccounKey = self?.accountService.selectedAccountID {
//                    UserDefaults.standard.set(self?.accountId, forKey: selectedAccounKey)
//                    self?.accountService.currentAccount = account
//                }
//                self?.isLoading = false
//            }, onError: { [weak self] error in
//                self?.isLoading = false
//                self?.error = error.localizedDescription
//            })
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
