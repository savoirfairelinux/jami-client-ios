/*
 *  Copyright (C) 2017-2019 Savoir-faire Linux Inc.
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
import RxCocoa
import Contacts
import SwiftyBeaver

class RequestItem {

    let request: RequestModel

    let userName = BehaviorRelay(value: "")
    let profileName = BehaviorRelay(value: "")
    let profileImageData = BehaviorRelay<Data?>(value: nil)
    lazy var bestName: Observable<String> = {
        return Observable
            .combineLatest(userName.asObservable(),
                           profileName.asObservable()) {(userName, displayname) in
                if displayname.isEmpty {
                    return userName
                }
                return displayname
            }
    }()

    let disposeBag = DisposeBag()

    init(withRequest request: RequestModel, profileService: ProfilesService,
         contactService: ContactsService) {
        self.request = request
        self.userName.accept(request.name)
        self.profileImageData.accept(self.request.avatar)
        self.profileName.accept(request.name)
    }
}
