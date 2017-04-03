/*
 *  Copyright (C) 2017 Savoir-faire Linux Inc.
 *
 *  Author: Romain Bertozzi <romain.bertozzi@savoirfairelinux.com>
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

import RxSwift

/**
 A class representing the ViewModel (MVVM) of the accounts managed by Ring.
 Its responsabilities:
 - expose to the Views a public API for its interactions concerning the Accounts,
 - react to the Views user events concerning the Accounts (add an account...)
 */
class CreateRingAccountViewModel {
    /**
     Dispose bag that contains the Disposable objects of the ViewModel, and managing their disposes.
     */
    fileprivate let disposeBag = DisposeBag()

    /**
     Retains the currently active stream adding an account.
     Useful to dispose it before starting a new one.
     */
    fileprivate var addAccountDisposable: Disposable?

    /**
     The account under this ViewModel.
     */
    fileprivate var account: AccountModel?

    /**
     Default constructor
     */
    init() {
        self.account = nil
    }

    /**
     Constructor with AccountModel.
     */
    init(withAccountModel account: AccountModel?) {
        self.account = account
    }

    /**
     Create the observers to the streams passed in parameters.
     It will allow this ViewModel to react to other entities' events.

     - Parameter observable: An observable stream to subscribe on.
     Any observed event on this stream will trigger the action of creating an account.
     - Parameter onStartCallback: Closure that will be triggered when the action will begin.
     - Parameter onSuccessCallback: Closure that will be triggered when the action will succeed.
     - Parameter onErrorCallback: Closure that will be triggered in case of error.
     */
    func configureAddAccountObservers(observable: Observable<Void>,
                                      onStartCallback: ((() -> Void)?),
                                      onSuccessCallback: ((() -> Void)?),
                                      onErrorCallback: (((Error?) -> Void)?)) {
        _ = observable
            .subscribe(
                onNext: { [weak self] in
                    //~ Let the caller know that the action has just begun.
                    onStartCallback?()

                    //~ Dispose any previously running stream. There is only one add account action
                    //~ simultaneously authorized.
                    self?.addAccountDisposable?.dispose()
                    //~ Subscribe on the AccountsService responseStream to get results.
                    self?.addAccountDisposable = AccountsService.sharedInstance
                        .sharedResponseStream
                        .subscribe(onNext:{ (event) in
                            if event.eventType == ServiceEventType.AccountsChanged {
                                onSuccessCallback?()
                            }
                        }, onError: { error in
                            onErrorCallback?(error)
                        })
                    self?.addAccountDisposable?.addDisposableTo((self?.disposeBag)!)

                    //~ Launch the action.
                    AccountsService.sharedInstance.addAccount()
                },
                onError: { (error) in
                    onErrorCallback?(error)
            })
            .addDisposableTo(disposeBag)

        _ = self.username.asObservable().subscribe(onNext: { username in
            print("username = \(username)")
        })
    }

    //MARK: - Rx Variables and Observers

    var username = Variable<String>("")
    var password = Variable<String>("")
    var repeatPassword = Variable<String>("")

    var usernameValid :Observable<Bool> {
        return username.asObservable().map({ username in
            return !username.isEmpty
        })
    }

    var passwordValid :Observable<Bool> {
        return password.asObservable().map({ password in
            return password.characters.count >= 6
        })
    }

    var passwordsEqual :Observable<Bool> {
        return Observable<Bool>.combineLatest(self.password.asObservable(),
                                              self.repeatPassword.asObservable())
        { password, repeatPassword in
            return password == repeatPassword
        }
    }

    var canCreateAccount :Observable<Bool> {
        return Observable<Bool>.combineLatest(self.registerUsername.asObservable(),
                                              self.usernameValidationStatus,
                                              self.passwordValid,
                                              self.passwordsEqual)
        { registerUsername, usernameValidationStatus, passwordValid, passwordsEquals in
            if registerUsername {
                return (usernameValidationStatus == .valid) && passwordValid && passwordsEquals
            } else {
                return passwordValid && passwordsEquals
            }
        }
    }

    var usernameValidationStatus :Observable<UsernameValidationStatus> {
        return self.username.asObservable().flatMapLatest({ username in
            return self.usernameValidation(username: username)
        }).observeOn(MainScheduler.instance)
    }

    var usernameValidationMessage :Observable<String> {
        return self.usernameValidationStatus.asObservable().map ({ status in
            switch status {
            case .lookingUp:
                return NSLocalizedString("LookingForUsernameAvailability",
                                         tableName: LocalizedStringTableNames.walkthrough,
                                         comment: "")
            case .invalid:
                return NSLocalizedString("InvalidUsername",
                                         tableName: LocalizedStringTableNames.walkthrough,
                                         comment: "")
            case .alreadyTaken:
                return NSLocalizedString("UsernameAlreadyTaken",
                                         tableName: LocalizedStringTableNames.walkthrough,
                                         comment: "")
            case .empty:
                return "empty"
            case .valid:
                return "valid"
            }
        }).observeOn(MainScheduler.instance)
    }

    var registerUsername = Variable<Bool>(true)

    //MARK: -

    /**
     Returns an Observable that send the state of the username validation request to the user
     or just an empty string if the field is empty or the username is valid
     */

    enum UsernameValidationStatus {
        case empty
        case lookingUp
        case invalid
        case alreadyTaken
        case valid
    }

    fileprivate func usernameValidation(username: String) -> Observable<UsernameValidationStatus> {

        if username.isEmpty {
            return Observable.just(.empty)
        }

        let observable = Observable<UsernameValidationStatus>.create({ [unowned self] observer in

            //TODO: Add to dispose bag
            //FIX: events called twice...
            //TODO: Add throttle

            let blockchainService = BlockchainService.sharedInstance

            blockchainService.sharedResponseStream.subscribe(onNext: { event in
                    if (event.eventType == ServiceEventType.RegisterNameFound) {
                        if let state :LookupNameState = event.getEventInput(ServiceEventInput.LookupNameState) {
                            if state == .Found {
                                observer.onNext(.alreadyTaken)
                            } else if state == .InvalidName {
                                observer.onNext(.invalid)
                            } else {
                                observer.onNext(.valid)
                            }
                            observer.onCompleted()
                        }
                    }
                }).addDisposableTo(self.disposeBag)

            //Request
            blockchainService.lookupName(with: "", nameserver: "", name: username)

            observer.onNext(.lookingUp)

            return Disposables.create()

        })

        return observable
    }

}
