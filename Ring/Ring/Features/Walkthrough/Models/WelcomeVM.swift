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

class DismissHandler {

    var dismiss = PublishSubject<Bool>()

    func dismissView() {
        dismiss.onNext(true)
    }
}

class WelcomeVM: ViewModel, ObservableObject {

    @Published var creationState: AccountCreationState = .initial

    private let accountService: AccountsService
    private let nameService: NameService
    private let profileService: ProfilesService
    let injectionBag: InjectionBag

    let disposeBag = DisposeBag()

    let registrationTimeout: CGFloat = 30

    var profileName: String = ""
    var profileImage: UIImage?

    required init (with injectionBag: InjectionBag) {
        self.accountService = injectionBag.accountService
        self.nameService = injectionBag.nameService
        self.profileService = injectionBag.profileService
        self.injectionBag = injectionBag
    }

    func finish(stateHandler: StatePublisher<WalkthroughState>) {
        stateHandler.emitState(WalkthroughState.completed)
    }

    func openAccountCreation(stateHandler: StatePublisher<WalkthroughState>) {
        stateHandler.emitState(WalkthroughState.accountCreation(createAction: { [weak self, weak stateHandler] (name, password, profileName, profileImage)  in
            guard let self = self,
                  let stateHandler = stateHandler else { return }
            self.setProfileInfo(profileName: profileName, profileImage: profileImage)
            self.createAccount(name: name,
                               password: password,
                               stateHandler: stateHandler)
        }))
    }

    func openLinkDevice(stateHandler: StatePublisher<WalkthroughState>) {
        stateHandler.emitState(WalkthroughState.linkDevice(linkAction: { [weak self, weak stateHandler] in
            guard let self = self,
                  let stateHandler = stateHandler else { return }
            self.linkDeviceCompleted(stateHandler: stateHandler)
        }))
    }

    func openImportArchive(stateHandler: StatePublisher<WalkthroughState>) {
        stateHandler.emitState(WalkthroughState.importArchive(importAction: { [weak self, weak stateHandler] url, password in
            guard let self = self,
                  let stateHandler = stateHandler else { return }
            self.importFromArchive(path: url, password: password, stateHandler: stateHandler)
        }))
    }

    func openJAMS(stateHandler: StatePublisher<WalkthroughState>) {
        stateHandler.emitState(WalkthroughState.connectJAMS(connectAction: { [weak self, weak stateHandler] username, password, server in
            guard let self = self,
                  let stateHandler = stateHandler else { return }
            self.connectToAccountManager(userName: username,
                                         password: password,
                                         server: server,
                                         stateHandler: stateHandler)
        }))
    }

    func openAboutJami(stateHandler: StatePublisher<WalkthroughState>) {
        stateHandler.emitState(WalkthroughState.aboutJami)
    }

    func openSIP(stateHandler: StatePublisher<WalkthroughState>) {
        stateHandler.emitState(WalkthroughState.connectSIP(connectAction: { [weak self, weak stateHandler] username, password, server in
            guard let self = self,
                  let stateHandler = stateHandler else { return }
            self.createSipAccount(userName: username,
                                  password: password,
                                  server: server,
                                  stateHandler: stateHandler)
        }))
    }

    func setProfileInfo(profileName: String, profileImage: UIImage?) {
        self.profileName = profileName
        self.profileImage = profileImage
    }
}

// MARK: - Create account
extension WelcomeVM {
    func createAccount(name: String,
                       password: String,
                       stateHandler: StatePublisher<WalkthroughState>) {
        self.creationState = .started

        self.accountService
            .addJamiAccount(username: name,
                            password: password,
                            pin: "",
                            arhivePath: "",
                            profileName: self.profileName)
            .subscribe(onNext: { [weak self, weak stateHandler] accountId in
                guard let stateHandler = stateHandler else { return }
                self?.handleAccountCreationSuccess(accountId,
                                                   username: name,
                                                   password: password,
                                                   stateHandler: stateHandler)
            }, onError: { [weak self] error in
                self?.handleAccountCreationError(error)
            })
            .disposed(by: disposeBag)
    }

    private func handleAccountCreationSuccess(_ accountId: String,
                                              username: String,
                                              password: String,
                                              stateHandler: StatePublisher<WalkthroughState>) {
        self.enablePushNotifications()
        self.saveProfile(accountId: accountId)
        if !username.isEmpty {
            self.registerAccountName(for: accountId,
                                     username: username,
                                     password: password,
                                     stateHandler: stateHandler)
        } else {
            self.accountCreated(stateHandler: stateHandler)
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
                                     password: String,
                                     stateHandler: StatePublisher<WalkthroughState>) {
        let registerName = nameService
            .registerNameObservable(accountId: accountId,
                                    password: password,
                                    name: username)
            .subscribe(onNext: { [weak self, weak stateHandler] registered in
                guard let stateHandler = stateHandler else { return }
                self?.handleNameRegistrationResult(registered,
                                                   stateHandler: stateHandler)
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

    private func handleNameRegistrationResult(_ registered: Bool,
                                              stateHandler: StatePublisher<WalkthroughState>) {
        if registered {
            accountCreated(stateHandler: stateHandler)
        } else {
            self.setState(state: .nameNotRegistered)
        }
    }

    private func handleNameRegistrationTimeout() {
        if !creationState.isCompleted {
            self.setState(state: .timeOut)
        }
    }

    private func accountCreated(stateHandler: StatePublisher<WalkthroughState>) {
        self.setState(state: .success)
        DispatchQueue.main.async {[weak stateHandler] in
            stateHandler?.emitState(WalkthroughState.completed)
        }
    }

    func enablePushNotifications() {
        NotificationCenter
            .default
            .post(name: NSNotification.Name(rawValue: NotificationName.enablePushNotifications.rawValue),
                  object: nil)
    }

    private func saveProfile(accountId: String) {
        // Run on a background thread
        Task {
            guard let account = self.accountService.getAccount(fromAccountId: accountId) else {
                return
            }
            let photo = convertProfileImageToBase64()

            if photo == nil && profileName.isEmpty {
                // No changes for profile
                return
            }

            let avatar: String = photo ?? ""

            await self.accountService.updateProfile(accountId: account.id, displayName: self.profileName, avatar: avatar, fileType: "JPEG")
        }
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
extension WelcomeVM {
    func linkDeviceCompleted(stateHandler: StatePublisher<WalkthroughState>) {
        self.accountCreated(stateHandler: stateHandler)
    }
}

// MARK: - import account
extension WelcomeVM {
    func importFromArchive(path: URL,
                           password: String,
                           stateHandler: StatePublisher<WalkthroughState>) {
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
            .subscribe(onNext: { [weak self, weak stateHandler] _ in
                guard let self = self,
                      let stateHandler = stateHandler else { return }
                self.enablePushNotifications()
                self.accountCreated(stateHandler: stateHandler)
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
extension WelcomeVM {
    func connectToAccountManager(userName: String,
                                 password: String,
                                 server: String,
                                 stateHandler: StatePublisher<WalkthroughState>) {
        self.creationState = .started
        self.accountService
            .connectToAccountManager(username: userName,
                                     password: password,
                                     serverUri: server)
            .subscribe(onNext: { [weak self, weak stateHandler] (_) in
                guard let self = self,
                      let stateHandler = stateHandler else { return }
                self.enablePushNotifications()
                self.accountCreated(stateHandler: stateHandler)
            }, onError: { [weak self] (error) in
                self?.handleAccountCreationError(error)
            })
            .disposed(by: self.disposeBag)
    }
}

// MARK: - configure SIP account
extension WelcomeVM {
    func createSipAccount(userName: String,
                          password: String,
                          server: String,
                          stateHandler: StatePublisher<WalkthroughState>) {
        let created = self.accountService
            .addSipAccount(userName: userName,
                           password: password,
                           sipServer: server)
        if created {
            self.accountCreated(stateHandler: stateHandler)
        } else {
            self.setState(state: .error(error: .unknown))
        }
    }
}
