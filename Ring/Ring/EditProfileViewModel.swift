/*
 *  Copyright (C) 2017-2019 Savoir-faire Linux Inc.
 *
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
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
import Contacts

class EditProfileViewModel {

    let disposeBag = DisposeBag()
    let defaultImage = UIImage(named: "add_avatar")
    var image = Variable<UIImage?>(nil)
    var profileName = Variable<String>("")

    init() {

        self.image.value = defaultImage

        VCardUtils.loadVCard(named: VCardFiles.myProfile.rawValue, inFolder: VCardFolders.profile.rawValue) .subscribe(onSuccess: { [unowned self]card in
                             self.profileName.value = card.familyName
                            if let data = card.imageData {
                                self.image.value = UIImage(data: data)?.convert(toSize: CGSize(width: 100.0, height: 100.0), scale: UIScreen.main.scale).circleMasked
                            }
                        }).disposed(by: disposeBag)
      }

    func saveProfile() {

        let vcard = CNMutableContact()
        if let image = self.image.value, !image.isEqual(defaultImage) {
            vcard.imageData = UIImagePNGRepresentation(image)
        }
            vcard.familyName = self.profileName.value
        _ = VCardUtils.saveVCard(vCard: vcard, withName: VCardFiles.myProfile.rawValue, inFolder: VCardFolders.profile.rawValue).subscribe()

    }

    func updateImage(_ image: UIImage) {
        self.image.value = image
        self.saveProfile()
    }

    func updateName(_ name: String) {
        self.profileName.value = name
        self.saveProfile()
    }
}
