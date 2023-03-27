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
import Contacts
import RxSwift
// swiftlint:disable identifier_name

enum VCardFolders: String {
    case contacts
    case profile
}

enum VCardFields: String {
    case begin     = "BEGIN:VCARD"
    case photoJPEG = "PHOTO;ENCODING=BASE64;TYPE=JPEG:"
    case end       = "END:VCARD"
    case fullName  = "FN:"
    case telephone = "TEL;other:"
}

enum VCardFiles: String {
    case myProfile
}
class VCardUtils {

    class func getName(from vCard: CNContact?) -> String {
        guard let vCard = vCard else {
            return ""
        }
        var name = ""

        if !vCard.givenName.isEmpty {
            name = vCard.givenName
        }

        if !vCard.familyName.isEmpty {
            if !name.isEmpty {
                name += " "
            }
            name += vCard.familyName
        }
        return name
    }

    class func sendVCard(card: Profile, callID: String, accountID: String, sender: CallsService, from: String) {
        do {
            guard let vCardData = try VCardUtils.dataWithImageAndUUID(from: card),
                  var vCardString = String(data: vCardData, encoding: String.Encoding.utf8) else {
                return
            }
            var vcardLength = vCardString.count
            let chunkSize = 1024
            let idKey = UInt64.random(in: 0 ... 10000000)
            let total = vcardLength / chunkSize + (((vcardLength % chunkSize) == 0) ? 0 : 1)
            var i = 1
            while vcardLength > 0 {
                var chunk = [String: String]()
                let id = "id=" + "\(idKey)" + ","
                let part = "part=" + "\(i)" + ","
                let of = "of=" + "\(total)"
                let key = "x-ring/ring.profile.vcard;" + id + part + of
                if vcardLength >= chunkSize {
                    let body = String(vCardString.prefix(chunkSize))
                    let index = vCardString.index(vCardString.startIndex, offsetBy: (chunkSize))
                    vCardString = String(vCardString.suffix(from: index))
                    vcardLength = vCardString.count
                    chunk[key] = body
                } else {
                    vcardLength = 0
                    chunk[key] = vCardString
                }
                i += 1
                sender.sendChunk(callID: callID, message: chunk, accountId: accountID, from: from)
            }
        } catch {
            print(error)
        }
    }

    class func dataWithImageAndUUID(from profile: Profile) throws -> Data? {

        // create vCard string
        let beginString = VCardFields.begin.rawValue + "\n"
        let name = (profile.alias ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let phone = profile.uri
        let telephoneString = VCardFields.telephone.rawValue + phone + "\n"
        let fullNameString = VCardFields.fullName.rawValue + name + "\n"
        let endString = VCardFields.end.rawValue

        var vCardString = beginString + fullNameString + telephoneString

        guard let image = profile.photo  else {
            return (vCardString + endString).data(using: .utf8)
        }
        let vcardImageString = VCardFields.photoJPEG.rawValue + image + "\n"
        vCardString += vcardImageString + VCardFields.end.rawValue
        return vCardString.data(using: .utf8)
    }

    class func parseToProfile(data: Data) -> Profile? {
        guard let encoding = data.stringUTF8OrUTF16Encoding,
              let profileStr = String(data: data, encoding: encoding) else {
            return nil
        }
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
                profileUri = line.replacingOccurrences(of: "TEL;other:", with: "")
            }
        }
        let type = profileUri.contains("ring") ? ProfileType.ring : ProfileType.sip
        return Profile(uri: profileUri, alias: alias, photo: avatar, type: type.rawValue)
    }
}
