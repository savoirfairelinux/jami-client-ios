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
import RealmSwift
import SwiftyBeaver

class ContactViewModel {

    /**
     logguer
     */
    private let log = SwiftyBeaver.self

    private let nameService = AppDelegate.nameService
    private let disposeBag = DisposeBag()
    private let contact: ContactModel
    private lazy var realm: Realm = {
        guard let realm = try? Realm() else {
            fatalError("Enable to instantiate Realm")
        }

        return realm
    }()

    let userName = Variable("")

    init(withContact contact: ContactModel) {
        self.contact = contact

        if let userName = self.contact.userName {
            self.userName.value = userName
        } else {
            self.lookupUserName()
        }
    }

    func lookupUserName() {

        nameService.usernameLookupStatus
            .observeOn(MainScheduler.instance)
            .filter({ [unowned self] lookupNameResponse in
                return lookupNameResponse.address != nil && lookupNameResponse.address == self.contact.ringId
            }).subscribe(onNext: { [unowned self] lookupNameResponse in
                if lookupNameResponse.state == .found {

                    do {
                        try self.realm.write { [unowned self] in
                            self.contact.userName = lookupNameResponse.name
                        }
                    } catch let error {
                        self.log.error("Realm persistence with error: \(error)")
                    }

                    self.userName.value = lookupNameResponse.name
                } else {
                    self.userName.value = lookupNameResponse.address
                }
            }).disposed(by: disposeBag)

        nameService.lookupAddress(withAccount: "", nameserver: "", address: self.contact.ringId)
    }
}
