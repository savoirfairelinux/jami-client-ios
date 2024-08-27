/*
 *  Copyright (C) 2017-2024 Savoir-faire Linux Inc.
 *
 *  Author: Thibault Wittemberg <thibault.wittemberg@savoirfairelinux.com>
 *  Author: Quentin Muret <quentin.muret@savoirfairelinux.com>
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
import SwiftUI

class WelcomeViewModel: Stateable, ViewModel, ObservableObject {

    @Published var creationState: AccountCreationState = .initial

    // MARK: - Rx Stateable
    private let stateSubject = PublishSubject<State>()
    lazy var state: Observable<State> = {
        return self.stateSubject.asObservable()
    }()

    private let accountService: AccountsService
    private let nameService: NameService
    private let profileService: ProfilesService
    let injectionBag: InjectionBag

    let disposeBag = DisposeBag()

    var notCancelable = true

    let registrationTimeout: CGFloat = 30

    var profileName: String = ""
    var profileImage: UIImage?

    required init (with injectionBag: InjectionBag) {
        self.accountService = injectionBag.accountService
        self.nameService = injectionBag.nameService
        self.profileService = injectionBag.profileService
        self.injectionBag = injectionBag
    }

    func finish() {
        self.stateSubject.onNext(WalkthroughState.completed)
    }

    func setProfileInfo(profileName: String, profileImage: UIImage?) {
        self.profileName = profileName
        self.profileImage = profileImage
    }
}

// MARK: - Create account
extension WelcomeViewModel {
    func createAccount(name: String, password: String) {
        self.creationState = .started

        self.accountService
            .addJamiAccount(username: name,
                            password: password,
                            pin: "",
                            arhivePath: "",
                            profileName: self.profileName)
            .subscribe(onNext: { [weak self] accountId in
                self?.handleAccountCreationSuccess(accountId,
                                                   username: name,
                                                   password: password)
            }, onError: { [weak self] error in
                self?.handleAccountCreationError(error)
            })
            .disposed(by: disposeBag)
    }

    private func handleAccountCreationSuccess(_ accountId: String,
                                              username: String,
                                              password: String) {
        self.enablePushNotifications()
        self.saveProfile(accountId: accountId)
        if !username.isEmpty {
            self.registerAccountName(for: accountId,
                                     username: username,
                                     password: password)
        } else {
            self.accountCreated()
        }
    }

    private func handleAccountCreationError(_ error: Error) {
        if let error = error as? AccountCreationError {
            self.setState(state: .error(error: error))
        } else {
            self.setState(state: .error(error: .unknown))
        }
    }

    private func registerAccountName(for accountId: String,
                                     username: String,
                                     password: String) {
        let registerName = nameService
            .registerNameObservable(accountId: accountId,
                                    password: password,
                                    name: username)
            .subscribe(onNext: { [weak self] registered in
                self?.handleNameRegistrationResult(registered)
            }, onError: { [weak self] _ in
                self?.setState(state: .nameNotRegistered)
            })
        registerName.disposed(by: disposeBag)

        DispatchQueue.main
            .asyncAfter(deadline: .now() + registrationTimeout) { [weak self] in
                registerName.dispose()
                self?.handleNameRegistrationTimeout()
            }
    }

    private func setState(state: AccountCreationState) {
        if self.creationState == state { return }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.creationState = state
        }
    }

    private func handleNameRegistrationResult(_ registered: Bool) {
        if registered {
            accountCreated()
        } else {
            self.setState(state: .nameNotRegistered)
        }
    }

    private func handleNameRegistrationTimeout() {
        if !creationState.isCompleted {
            self.setState(state: .timeOut)
        }
    }

    private func accountCreated() {
        self.setState(state: .success)
        DispatchQueue.main.async {
            self.stateSubject
                .onNext(WalkthroughState.completed)
        }
    }

    func enablePushNotifications() {
        NotificationCenter
            .default
            .post(name: NSNotification.Name(rawValue: NotificationName.enablePushNotifications.rawValue),
                  object: nil)
    }

    private func saveProfile(accountId: String) {
        guard let account = self.accountService.getAccount(fromAccountId: accountId) else {
            return
        }
        let photo = convertProfileImageToBase64()

        if photo == nil && profileName.isEmpty {
            // No changes for profile
            return
        }

        let accountURI = AccountModelHelper(withAccount: account).uri ?? ""
        profileService.updateAccountProfile(accountId: accountId,
                                            alias: profileName,
                                            photo: photo,
                                            accountURI: accountURI)
    }

    private func convertProfileImageToBase64() -> String? {
        guard let image = profileImage?.fixOrientation(),
              let imageData = image.convertToData(ofMaxSize: 40000) else {
            return nil
        }
        return imageData.base64EncodedString()
    }
}

// MARK: - link account
extension WelcomeViewModel {
    func linkDevice(pin: String, password: String) {
        self.creationState = .started
        self.accountService
            .addJamiAccount(username: "",
                            password: password,
                            pin: pin,
                            arhivePath: "",
                            profileName: self.profileName)
            .subscribe(onNext: { [weak self] _ in
                guard let self = self else { return }
                self.enablePushNotifications()
                self.accountCreated()
            }, onError: { [weak self] error in
                self?.handleAccountCreationError(error)
            })
            .disposed(by: disposeBag)
    }
}

// MARK: - import account
extension WelcomeViewModel {
    func importFromArchive(path: URL, password: String) {
        guard path.startAccessingSecurityScopedResource() else {
            self.setState(state: .error(error: .unknown))
            return
        }

        self.creationState = .started

        func stopResourceAccess() {
            path.stopAccessingSecurityScopedResource()
        }

        /*
         Set a timer to ensure stopAccessingSecurityScopedResource
         is called, in case the operation does not complete.
         */
        let stopTimer: Timer? = Timer.scheduledTimer(withTimeInterval: 60.0,
                                                     repeats: false) { _ in
            stopResourceAccess()
        }

        self.accountService
            .addJamiAccount(username: "",
                            password: password,
                            pin: "",
                            arhivePath: path.absoluteURL.path,
                            profileName: self.profileName)
            .subscribe(onNext: { [weak self] _ in
                guard let self = self else { return }
                self.enablePushNotifications()
                self.accountCreated()
                stopResourceAccess()
                if let timer = stopTimer, timer.isValid {
                    timer.invalidate()
                }
            }, onError: { [weak self] error in
                self?.handleAccountCreationError(error)
                stopResourceAccess()
                if let timer = stopTimer, timer.isValid {
                    timer.invalidate()
                }
            })
            .disposed(by: disposeBag)
    }
}

// MARK: - connect to account manager
extension WelcomeViewModel {
    func connectToAccountManager(userName: String,
                                 password: String,
                                 server: String) {
        self.creationState = .started
        self.accountService
            .connectToAccountManager(username: userName,
                                     password: password,
                                     serverUri: server)
            .subscribe(onNext: { [weak self] (_) in
                guard let self = self else { return }
                self.enablePushNotifications()
                self.accountCreated()
            }, onError: { [weak self] (error) in
                self?.handleAccountCreationError(error)
            })
            .disposed(by: self.disposeBag)
    }
}

// MARK: - configure SIP account
extension WelcomeViewModel {
    func createSipAccount(userName: String,
                          password: String,
                          server: String) {
        let created = self.accountService
            .addSipAccount(userName: userName,
                           password: password,
                           sipServer: server)
        if created {
            self.accountCreated()
        } else {
            self.setState(state: .error(error: .unknown))
        }
    }
}
