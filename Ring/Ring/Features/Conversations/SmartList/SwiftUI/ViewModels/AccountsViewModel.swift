// MARK: - Migration Properties
@Published var migrationAccountProfile: UIImage?
@Published var migrationAccountName: String = ""
@Published var migrationAccountJamiId: String = ""
@Published var migrationAccountUsername: String = ""
@Published var accountNeedsPassword: Bool = false
@Published var canCancelMigration: Bool = true
@Published var canMigrateAnotherAccount: Bool = false

private func updateMigrationAccountInfo() {
    guard let account = accountToMigrate else { return }

    // Get profile image
    profileService.getAccountProfile(accountId: account)
        .take(1)
        .subscribe(onNext: { [weak self] profile in
            if let photo = profile.photo,
               let data = NSData(base64Encoded: photo,
                                 options: NSData.Base64DecodingOptions
                                    .ignoreUnknownCharacters) as Data? {
                self?.migrationAccountProfile = UIImage(data: data)
            } else {
                self?.migrationAccountProfile = UIImage(named: "fallback_avatar")
            }
        })
        .disposed(by: disposeBag)

    // Get account details
    let details = accountService.getAccountDetails(fromAccountId: account)
    migrationAccountName = details.get(withConfigKeyModel: ConfigKeyModel.init(withKey: .displayName))

    if let account = accountService.getAccount(fromAccountId: account) {
        migrationAccountJamiId = account.jamiId ?? ""
        migrationAccountUsername = account.registeredName

        // Check if account needs password
        accountNeedsPassword = AccountModelHelper(withAccount: account).hasPassword

        // Check if we can cancel migration
        canCancelMigration = accountService.hasValidAccount()

        // Check if we can migrate another account
        canMigrateAnotherAccount = !accountService.hasValidAccount() &&
            accountService.accounts.count > 1
    }
}

func handleMigrationAction(action: MigrationAction, password: String = "") {
    guard let account = accountToMigrate else { return }

    switch action {
    case .migrate:
        accountService.migrateAccount(account: account, password: password)
            .subscribe(onNext: { [weak self] _ in
                if let migratedAccount = self?.accountToMigrate,
                   let account = self?.accountService.getAccount(fromAccountId: migratedAccount),
                   let selectedAccounKey = self?.accountService.selectedAccountID {
                    UserDefaults.standard.set(migratedAccount, forKey: selectedAccounKey)
                    self?.accountService.currentAccount = account
                }
                self?.stateSubject.onNext(AppState.allSet)
            }, onError: { [weak self] _ in
                // Handle error
                self?.showMigrationError()
            })
            .disposed(by: disposeBag)

    case .remove:
        accountService.removeAccount(id: account)
        if accountService.accounts.isEmpty {
            stateSubject.onNext(AppState.needToOnboard(animated: false, isFirstAccount: true))
        } else {
            finishWithoutMigration()
        }

    case .cancel:
        finishWithoutMigration()

    case .migrateAnother:
        for account in accountService.accounts where
            (account.id != self.accountToMigrate && account.status == .errorNeedMigration) {
            stateSubject.onNext(AppState.needAccountMigration(accountId: account.id))
            return
        }
    }
}

private func finishWithoutMigration() {
    if !accountService.hasValidAccount() {
        migrateAnotherAccount()
        return
    }
    // choose next available account
    for account in accountService.accounts where
        (account.id != accountToMigrate && account.status != .errorNeedMigration) {
        UserDefaults.standard.set(account.id, forKey: accountService.selectedAccountID)
        accountService.currentAccount = account
        stateSubject.onNext(AppState.allSet)
    }
}

private func migrateAnotherAccount() {
    for account in accountService.accounts where
        (account.id != accountToMigrate && account.status == .errorNeedMigration) {
        stateSubject.onNext(AppState.needAccountMigration(accountId: account.id))
        return
    }
}

private func showMigrationError() {
    // Implement error handling
}
