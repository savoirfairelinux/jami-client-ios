/*
 *  Copyright (C) 2016 Savoir-faire Linux Inc.
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

import RxCocoa
import RxSwift

/**
 A structure representing the ViewModel (MVVM) of the accounts managed by Ring.
 Its responsabilities:
 - expose to the Views a public API for its interactions concerning the Accounts,
 - react to the Views user events concerning the Accounts (add an account...)
 */
class AccountViewModel {
    /**
     Dispose bag that contains the Disposable objects of the ViewModel, and managing their disposes.
     */
    fileprivate let disposeBag = DisposeBag()

    /**
     An accountservice instance.
     */
    fileprivate let accountService = AccountsService()

    /**
     Create the observers to the streams passed in parameters.
     It will allow this ViewModel to react to other entities' events.

     - Parameter observable: An observable stream to subscribe on.
     Any observed event on this stream will trigger the action of creating an account.
     - Parameter onStart: Closure that will be triggered when the action will begin.
     - Parameter onSuccessCallback: Closure that will be triggered when the action will succeed.
     - Parameter onError: Closure that will be triggered in case of error.
     */
    func configureAddAccountObservers(observable: Observable<Void>,
                                      onStartCallback: ((() -> Void)?),
                                      onSuccessCallback: ((() -> Void)?),
                                      onErrorCallback: (((Error?) -> Void)?)) {
        _ = observable
            .subscribe(onNext: { [weak self] in
                if onStartCallback != nil {
                    onStartCallback!()
                }

                self?.accountService.addAccount(
                    onSuccessCallback: {
                        if onSuccessCallback != nil {
                            onSuccessCallback!()
                        }
                },
                    onErrorCallback: { error in
                        if onErrorCallback != nil {
                            onErrorCallback!(error)
                        }
                })
            }, onError: { (error) in
                if onErrorCallback != nil {
                    onErrorCallback!(error)
                }
            })
            .addDisposableTo(disposeBag)
    }
}
