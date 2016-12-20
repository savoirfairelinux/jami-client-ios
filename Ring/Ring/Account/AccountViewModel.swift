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
 Protocol representing the blueprint of properties of this ViewModel
 */
protocol AccountViewModelProtocol {
    /**
     PublishSubject reacting to an action asking for the creation of an account.
     */
    var addAccountAction: PublishSubject<Void> { get }
}

/**
 A structure representing the ViewModel (MVVM) of the accounts managed by Ring.
 Its responsabilities:
 - expose to the Views a public API for its interactions concerning the Accounts,
 - react to the Views user events concerning the Accounts (add an account...)
 */
struct AccountViewModel: AccountViewModelProtocol {
    /**
     Dispose bag that contains the Disposable objects of the ViewModel, and managing their disposes.
     */
    fileprivate let disposeBag = DisposeBag()

    let addAccountAction = PublishSubject<Void>()

    init () {
        //~ Subscribing to the event to trigger the concrete action.
        //~ The trigger will be converted in a new signal in a future patch to break the strong link
        //~ between this ViewModel and the Service.
        self.addAccountAction
            .subscribe(onNext:{
                AccountsService.sharedInstance.addAccount()
            })
            .addDisposableTo(self.disposeBag)
    }
}
