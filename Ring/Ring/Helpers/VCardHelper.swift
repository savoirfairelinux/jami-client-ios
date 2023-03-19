/*
 *  Copyright (C) 2017-2023 Savoir-faire Linux Inc.
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

enum VCardFields: String {
    case begin     = "BEGIN:VCARD"
    case uid       = "UID:"
    case photoJPEG = "PHOTO;ENCODING=BASE64;TYPE=JPEG:"
    case end       = "END:VCARD"
    case fullName  = "FN:"
    case telephone = "TEL;other:"
}

class VCardHelper {

    class func dataWithImageAndUUID(from profile: Profile, andImageCompression compressedSize: Int?, encoding: String.Encoding = .utf8) throws -> Data? {

        // create vCard string
        let beginString = VCardFields.begin.rawValue + "\n"
        let name = (profile.alias ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let phone = profile.uri
        let telephoneString = VCardFields.telephone.rawValue + phone + "\n"
        let fullNameString = VCardFields.fullName.rawValue + name + "\n"
        let endString = VCardFields.end.rawValue

        var vCardString = beginString + fullNameString + telephoneString

        guard let image = profile.photo  else {
            return (vCardString + endString).data(using: encoding)
        }
        let vcardImageString = VCardFields.photoJPEG.rawValue + image + "\n"
        vCardString += vcardImageString + VCardFields.end.rawValue

        return vCardString.data(using: encoding)
    }

    class func parseToProfile(data: Data) -> Profile? {
        var profileStr = String(data: data, encoding: .utf8)
        if profileStr == nil {
            profileStr = String(data: data, encoding: .utf16)
        }
        guard let profileStr = profileStr else { return nil}
        let lines = profileStr.split(whereSeparator: \.isNewline)
        var alias = "", avatar = "", profileUri = ""
        for line in lines {
            if line.starts(with: "PHOTO") {
                avatar = line.components(separatedBy: ":").last ?? ""
            }
            if line.starts(with: "FN") {
                alias = line.components(separatedBy: ":").last ?? ""
            }
            if line.starts(with: "TEL;other") {
                profileUri = line.components(separatedBy: ":").last ?? ""
            }
        }
        let type = profileUri.contains("ring") ? ProfileType.ring : ProfileType.sip
        return Profile(uri: profileUri, alias: alias, photo: avatar, type: type.rawValue)
    }
}
