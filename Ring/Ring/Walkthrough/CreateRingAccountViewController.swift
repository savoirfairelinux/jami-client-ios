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

import UIKit

import RxCocoa
import RxSwift

class CreateRingAccountViewController: UIViewController {

    var mAccountViewModel = CreateRingAccountViewModel(withAccountService: AppDelegate.accountService)

    @IBOutlet weak var mCreateAccountButton: RoundedButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        self.bindViews()
    }

    /**
     Bind all the necessary of this View to its ViewModel.
     That allows to build the binding part of the MVVM pattern.
     */
    fileprivate func bindViews() {
        //~ Create the stream. Won't start until an observer subscribes to it.
        let createAccountObservable:Observable<Void> = self.mCreateAccountButton
            .rx
            .tap
            .takeUntil(self.rx.deallocated)

        mAccountViewModel.configureAddAccountObservers(
            observable: createAccountObservable,
            onStartCallback: { [weak self] in
                self?.setCreateAccountAsLoading()
            },
            onSuccessCallback: { [weak self] in
                print("Account created.")
                self?.setCreateAccountAsIdle()
            },
            onErrorCallback:  { [weak self] (error) in
                print("Error creating account...")
                if error != nil {
                    print(error!)
                }
                self?.setCreateAccountAsIdle()
        })
    }

    fileprivate func setCreateAccountAsLoading() {
        print("Creating account...")
        self.mCreateAccountButton.setTitle("Loading...", for: .normal)
        self.mCreateAccountButton.isUserInteractionEnabled = false
    }

    fileprivate func setCreateAccountAsIdle() {
        self.mCreateAccountButton.setTitle("Create a Ring account", for: .normal)
        self.mCreateAccountButton.isUserInteractionEnabled = true
    }
}
