import Foundation
import UIKit
import RxSwift

enum MigrationAction {
    case migrate
    case remove
    case cancel
    case migrateAnother
}

enum MigrationError: LocalizedError {
    case migrationFailed
    case accountNotFound

    var errorDescription: String? {
        switch self {
        case .migrationFailed:
            return "Account migration failed"
        case .accountNotFound:
            return "Account to migrate not found"
        }
    }
}

final class AccountMigrationModel: ObservableObject, AvatarViewDataModel {
    @Published var profileImage: UIImage?
    @Published var profileName: String = ""
    @Published var username: String?
    @Published var migrationCompleted: Bool = false
    @Published var error: String?
    @Published var jamiId: String = ""
    @Published var needsPassword: Bool = false
    @Published var isLoading: Bool = false

    let avatarSize: CGFloat = 150
    private(set) var selectedAccount: String?

    private let accountService: AccountsService
    private let profileService: ProfilesService
    private let accountId: String
    private let disposeBag = DisposeBag()
    private let profileDisposeBag = DisposeBag()

    var hasValidAccounts: Bool {
        accountService.hasValidAccount()
    }

    var hasMultipleAccounts: Bool {
        accountService.accounts.count > 1
    }

    init(accountId: String, accountService: AccountsService, profileService: ProfilesService) {
        self.accountId = accountId
        self.selectedAccount = accountId
        self.accountService = accountService
        self.profileService = profileService
        self.updateAccountInfo()
    }

    func handleMigration(password: String = "") {
        isLoading = true
        error = nil

        accountService.migrateAccount(account: accountId, password: password)
            .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
            .subscribe(onNext: { [weak self] success in
                guard let self = self else { return }
                self.handleMigrationResult(success)
            }, onError: { [weak self] _ in
                self?.handleMigrationError()
            })
            .disposed(by: disposeBag)
    }

    func removeAccount() {
        accountService.removeAccount(id: accountId)
    }

    func getNextAccountToMigrate() -> String? {
        accountService.accounts.first { account in
            account.id != accountId && account.status == .errorNeedMigration
        }?.id
    }

    func getNextValidAccount() -> String? {
        accountService.accounts.first { account in
            account.id != accountId && account.status != .errorNeedMigration
        }?.id
    }

    private func updateAccountInfo() {
        guard let account = accountService.getAccount(fromAccountId: accountId) else {
            error = MigrationError.accountNotFound.localizedDescription
            return
        }

        jamiId = account.jamiId
        needsPassword = AccountModelHelper(withAccount: account).hasPassword
        username = extractUsername()
        subscribeProfile()
    }

    private func subscribeProfile() {
        profileService.getAccountProfile(accountId: accountId)
            .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
            .subscribe { [weak self] profile in
                self?.updateProfileInfo(profile)
            }
            .disposed(by: profileDisposeBag)
    }

    private func updateProfileInfo(_ profile: Profile) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            if let imageString = profile.photo,
               let image = imageString.createImage(size: self.avatarSize * 2) {
                self.profileImage = image
            }

            if let name = profile.alias {
                self.profileName = name
            }
        }
    }

    private func extractUsername() -> String? {
        guard let account = accountService.getAccount(fromAccountId: accountId) else {
            return nil
        }

        if !account.registeredName.isEmpty {
            return account.registeredName
        }

        if let userNameData = UserDefaults.standard.dictionary(forKey: registeredNamesKey),
           let accountName = userNameData[account.id] as? String,
           !accountName.isEmpty {
            return accountName
        }

        return nil
    }

    private func handleMigrationResult(_ success: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            if success {
                self.updateCurrentAccount()
            } else {
                self.error = MigrationError.migrationFailed.errorDescription
            }

            self.isLoading = false
            self.migrationCompleted = success
        }
    }

    private func handleMigrationError() {
        DispatchQueue.main.async { [weak self] in
            self?.isLoading = false
            self?.error = MigrationError.migrationFailed.errorDescription
        }
    }

    private func updateCurrentAccount() {
        guard let account = accountService.getAccount(fromAccountId: accountId) else { return }
        let selectedAccountKey = accountService.selectedAccountID
        UserDefaults.standard.set(accountId, forKey: selectedAccountKey)
        accountService.currentAccount = account
    }
}
