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

class RINGCreateRingAccountViewController: UIViewController {
    @IBOutlet weak var mCreateAccountButton: RINGRoundedButton!

    var mAccountViewModel: RINGAccountViewModel?

    override func viewDidLoad() {
        super.viewDidLoad()

        self.mAccountViewModel = RINGAccountViewModel.init(
            withAccount: nil,
            createAccountAction:self.mCreateAccountButton
                .rx
                .tap
                .takeUntil(self.rx.deallocated)
                .asObservable()
        )

        _ = self.mAccountViewModel?.mAccount?.asObservable().subscribe(onNext: { accountModel in
            print(accountModel)
        }, onError: { error in
            print(error.localizedDescription)
        }, onCompleted: { 
            print("mAccountViewModel Completed")
        }, onDisposed: { 
            print("mAccountViewModel Disposed")
        })
    }
}
