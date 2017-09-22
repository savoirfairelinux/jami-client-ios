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

class MeViewModel: Stateable, ViewModel {

    // MARK: - Rx Stateable
    private let stateSubject = PublishSubject<State>()

    let accountService: AccountsService
    var userName: Single<String?>
    let ringId: Single<String?>
     var image: Single<Image?>?

    lazy var state: Observable<State> = {
        return self.stateSubject.asObservable()
    }()

    required init(with injectionBag: InjectionBag) {
        self.accountService = injectionBag.accountService
        self.userName = Single.just(self.accountService.currentAccount?.volatileDetails?.get(withConfigKeyModel: ConfigKeyModel(withKey: ConfigKey.accountRegisteredName)))
        self.ringId = Single.just(self.accountService.currentAccount?.details?.get(withConfigKeyModel: ConfigKeyModel(withKey: .accountUsername)))

        guard let account = self.accountService.currentAccount else {
            return
        }

        let disposebag = DisposeBag()
        self.accountService.loadVCard(forAccounr: account)
            .subscribe(onSuccess: { card in
                if let data = card.imageData {
                    self.image = Single.just(UIImage(data: data)?.convert(toSize:CGSize(width:100.0, height:100.0), scale: UIScreen.main.scale).circleMasked)
                } else {
                    self.image = Single.just(nil)
                }
            }).disposed(by: disposebag)
    }

    func saveProfile(withImage image: UIImage) {
        let vcard = CNMutableContact()

        vcard.imageData = UIImagePNGRepresentation(image)
        vcard.familyName = (self.accountService.currentAccount!
            .volatileDetails!.get(withConfigKeyModel: ConfigKeyModel(withKey: ConfigKey.accountRegisteredName)))

        self.accountService
            .saveVCard(vCard: vcard, forAccounr: self.accountService.currentAccount!)
            .subscribe()
    }
}
