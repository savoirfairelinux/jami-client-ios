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

import UIKit

import RxSwift

class ContactHelper {

    fileprivate static let ringIdPrefix = "ring:"

    static func lookupUserName(forRingId ringId: String, nameService: NameService, disposeBag: DisposeBag) -> Variable<String> {

        let userName = Variable("")

        //Lookup the user name observer
        nameService.usernameLookupStatus
            .observeOn(MainScheduler.instance)
            .filter({ lookupNameResponse in
                return lookupNameResponse.address != nil && lookupNameResponse.address == ringId
            }).subscribe(onNext: { lookupNameResponse in
                if lookupNameResponse.state == .found {
                    userName.value = lookupNameResponse.name
                } else {
                    userName.value = lookupNameResponse.address
                }
            }).addDisposableTo(disposeBag)

        nameService.lookupAddress(withAccount: "", nameserver: "", address: ringId)

        return userName
    }

    static func ringId(fromURI uri: String) -> String? {
        if uri.contains(ContactHelper.ringIdPrefix) {
            let index = uri.range(of: ContactHelper.ringIdPrefix)?.upperBound
            return uri.substring(from: index!)
        } else {
            return nil
        }
    }

    static func uri(fromRingId ringId: String) -> String {
        return ContactHelper.ringIdPrefix.appending(ringId)
    }
}
