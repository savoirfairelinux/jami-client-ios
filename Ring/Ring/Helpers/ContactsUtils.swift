/*
 *  Copyright (C) 2023 Savoir-faire Linux Inc.
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

class ContactsUtils {

    class func getFinalNameFrom(registeredName: String, profileName: String, hash: String) -> String {
        // priority: 1. profileName, 2. registeredName, 3. hash
        if registeredName.isEmpty && profileName.isEmpty {
            return hash
        }
        if !profileName.isEmpty {
            return profileName
        }
        return registeredName
    }

    class func deserializeUser(dictionary: [String: String]) -> JamiSearchViewModel.JamsUserSearchModel? {
        guard let jamiId = dictionary["id"] else {
            return nil
        }

        let username = dictionary["username"] ?? ""
        let firstName = dictionary["firstName"] ?? ""
        let lastName = dictionary["lastName"] ?? ""
        let organization = dictionary["organization"] ?? ""

        let base64Encoded = dictionary["profilePicture"]
        let imageData = base64Encoded.flatMap { $0.toImageData() }

        return JamiSearchViewModel.JamsUserSearchModel(username: username,
                                                       firstName: firstName,
                                                       lastName: lastName,
                                                       organization: organization,
                                                       jamiId: jamiId,
                                                       profilePicture: imageData)
    }

}
