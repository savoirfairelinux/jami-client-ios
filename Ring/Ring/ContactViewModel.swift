/*
 *  Copyright (C) 2017 Savoir-faire Linux Inc.
 *
 *  Author: Silbino Gonçalves Matado <silbino.gmatado@savoirfairelinux.com>
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

class ContactViewModel {

    private let nameService = AppDelegate.nameService
    private let disposeBag = DisposeBag()
    private let contact: ContactModel

    let userName = Variable("")

    init(withContact contact: ContactModel) {
        self.contact = contact

        //Lookup the user name
        nameService.usernameLookupStatus
            .observeOn(MainScheduler.instance)
            .filter({ [unowned self] lookupNameResponse in
                return lookupNameResponse.address != nil && lookupNameResponse.address == self.contact.ringId
        }).subscribe(onNext: { [unowned self] lookupNameResponse in
            if lookupNameResponse.state == .found {
                self.contact.userName = lookupNameResponse.name
                self.userName.value = lookupNameResponse.name
            } else {
                self.userName.value = lookupNameResponse.address
            }
        }).addDisposableTo(disposeBag)

        nameService.lookupAddress(withAccount: "", nameserver: "", address: self.contact.ringId)
    }
}
