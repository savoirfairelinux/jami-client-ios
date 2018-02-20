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
import Contacts
import SwiftyBeaver

class ContactRequestItem {

    let contactRequest: ContactRequestModel

    let userName = Variable("")
    let profileImageData = Variable<Data?>(nil)
    let disposeBag = DisposeBag()

    init(withContactRequest contactRequest: ContactRequestModel, profileService: ProfilesService,
         contactService: ContactsService) {
        self.contactRequest = contactRequest
        self.userName.value = contactRequest.ringId
        self.profileImageData.value = self.contactRequest.vCard?.imageData
        profileService.getProfile(ringId: contactRequest.ringId, createIfNotexists: false)
            .subscribe(onNext: { [unowned self] profile in
                if let photo = profile.photo,
                    let data = NSData(base64Encoded: photo,
                                      options: NSData.Base64DecodingOptions.ignoreUnknownCharacters) as Data? {
                    self.profileImageData.value = data
                }
            }).disposed(by: self.disposeBag)
    }
}
