/*
 *  Copyright (C) 2024 Savoir-faire Linux Inc.
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

import SwiftUI
import UIKit

class EditProfileVM: ObservableObject, AvatarViewDataModel {
    var profileImageData: Data?
    
    var size: CGFloat
    
    @Published var profileImage: UIImage?
    @Published var profileName: String = ""

    @Published var username: String?
    @Published var jamiId: String = ""

    let account: AccountModel
    let accountService: AccountsService
    let profileService: ProfilesService

    init(injectionBag: InjectionBag, account: AccountModel, profileImage: UIImage?, profileName: String, username: String?) {
        self.accountService = injectionBag.accountService
        self.profileService = injectionBag.profileService
        self.account = account
        self.profileImage = profileImage
        self.profileName = profileName
        self.username = username
        self.profileImageData = nil
        self.size = 0
    }

    func updateProfile() {
        // Run on a background thread
        Task {
            var photo: String?

            if let image = self.profileImage?.fixOrientation(),
               let imageData = image.convertToData(ofMaxSize: 40000) {
                photo = imageData.base64EncodedString()
            }

            let avatar: String = photo ?? ""

            await self.accountService.updateProfile(accountId: self.account.id, displayName: self.profileName, avatar: avatar, fileType: "JPEG")
        }
    }
}
