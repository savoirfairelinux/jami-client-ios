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

import RxSwift

/**
 A structure representing the ViewModel (MVVM) of the accounts managed by Ring.
 Its responsabilities:
 - expose to the Views a public API for its interactions concerning the Accounts,
 - react to the Views user events concerning the Accounts (add an account...)
 */
struct AccountViewModel {
    /**
     Dispose bag that contains the Disposable objects of the ViewModel, and managing their disposes.
     */
    fileprivate let disposeBag = DisposeBag()

    /**
     Create the observers to the streams passed in parameters.
     It will allow this ViewModel to react to other entities' events.

     - Parameter observable: An observable stream to subscribe on.
     Any observed event on this stream will trigger the action of creating an account.
     - Parameter onStart: Closure that will be triggered when the action will begin.
     - Parameter onError: Closure that will be triggered in case of error.
    */
    func configureAddAccountObservers(observable: Observable<Void>,
                                      onStart: ((() -> Void)?),
                                      onSuccess: ((() -> Void)?),
                                      onError: (((Error?) -> Void)?)) {
        _ = observable
            .subscribe(onNext: {
                if onStart != nil {
                    onStart!()
                }
                AccountsService.sharedInstance.addAccount()
            }, onError: { (error) in
                if onError != nil {
                    onError!(error)
                }
            }, onCompleted: {
                //~ Nothing to do.
            }, onDisposed: {
                //~ Nothing to do.
            })
            .addDisposableTo(disposeBag)
    }
}
