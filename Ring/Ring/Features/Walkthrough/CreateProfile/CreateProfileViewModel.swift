/*
 *  Copyright (C) 2017 Savoir-faire Linux Inc.
 *
 *  Author: Thibault Wittemberg <thibault.wittemberg@savoirfairelinux.com>
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

class CreateProfileViewModel: Stateable, ViewModel {

    // MARK: - Rx Stateable
    private let stateSubject = PublishSubject<State>()
    lazy var state: Observable<State> = {
        return self.stateSubject.asObservable()
    }()
    var profileName = Variable<String>("")
    var profilePhoto = Variable<UIImage?>(nil)

    lazy var profileExists: Observable<Bool>  = {

        return Observable.combineLatest(self.profileName.asObservable(),
                                        self.profilePhoto.asObservable()) {(username, image) -> Bool in

            if !username.isEmpty {
                return true
            }

            let defaultImage = UIImage(named: "ic_contact_picture")
            if let image = image, !defaultImage!.isEqual(image) {
                return true
            }
            return false
        }
    }()

    var skipButtonTitle = Variable<String>("")

    var walkthroughType: WalkthroughType! {
        didSet {
            if self.walkthroughType == .createAccount {
                self.skipButtonTitle.value = L10n.Createprofile.createAccount
            } else {
                self.skipButtonTitle.value = L10n.Createprofile.linkDevice
            }

            profileExists.subscribe(onNext: { [unowned self] (state) in
                if state {
                    self.skipButtonTitle.value = L10n.Createprofile.createAccountWithProfile
                } else if self.walkthroughType == .createAccount {
                    self.skipButtonTitle.value = L10n.Createprofile.createAccount
                } else {
                    self.skipButtonTitle.value = L10n.Createprofile.linkDevice
                }
            }).disposed(by: self.disposeBag)
        }
    }

    let disposeBag = DisposeBag()

    required init (with injectionBag: InjectionBag) {

    }

    func proceedWithAccountCreationOrDeviceLink() {
        self.stateSubject.onNext(WalkthroughState.profileCreated(withType: self.walkthroughType))
    }

}
