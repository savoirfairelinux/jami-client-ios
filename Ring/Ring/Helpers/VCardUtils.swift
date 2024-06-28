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

class Profile {
    var uri: String
    var alias: String?
    var photo: String?
    var type: String

    init(uri: String, alias: String?, photo: String?, type: String) {
        self.uri = uri
        self.alias = alias
        self.photo = photo
        self.type = type

        // Increment the created count
        Profile.createdCount += 1
        // Add self to the instances array
        Profile.instances.append(self)
    }

    // Method to get the number of profiles currently in memory
    static func profilesInMemory() -> Int {
        return instances.count
    }

    var memorySize: Int {
        var size = MemoryLayout.size(ofValue: self)
        size += uri.utf8.count
        if let alias = alias {
            size += alias.utf8.count
        }
        size += type.utf8.count
        if let photo = photo {
            size += photo.utf8.count
        }
        return size
    }

    static func totalMemorySize() -> Int {
        return instances.compactMap { $0.memorySize }.reduce(0, +)
    }

    // Static counter for created profiles
    static var createdCount = 0
    // Array to hold weak references to profile instances
    static var instances: [Profile] = []
}

enum ProfileType: String {
    case ring = "RING"
    case sip = "SIP"
}

protocol VCardSender {
    func sendChunk(callID: String, message: [String: String], accountId: String, from: String)
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

    class func sendVCard(card: Profile, callID: String, accountID: String, sender: VCardSender, from: String) {
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

    class func parseToProfile(filePath: String) -> Profile? {
        guard let profileStr = try? String(contentsOfFile: filePath, encoding: .utf8) else { return nil}
        //        guard let encoding = data.stringUTF8OrUTF16Encoding,
        //              let profileStr = String(data: data, encoding: encoding) else {
        //            return nil
        //        }
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
        // return nil
        return Profile(uri: profileUri, alias: alias, photo: avatar, type: type.rawValue)
    }

    class func getNameFromVCard(filePath: String) -> String? {
        guard let fileStream = InputStream(fileAtPath: filePath) else {
            return nil
        }

        fileStream.open()

        defer {
            fileStream.close()
        }

        let bufferSize = 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)

        defer {
            buffer.deallocate()
        }

        while fileStream.hasBytesAvailable {
            let bytesRead = fileStream.read(buffer, maxLength: bufferSize)

            guard bytesRead > 0 else {
                break
            }

            let stringRead = String(bytesNoCopy: buffer, length: bytesRead, encoding: .utf8, freeWhenDone: false)

            if let lines = stringRead?.split(whereSeparator: \.isNewline) {
                for line in lines where line.hasPrefix(VCardFields.fullName.rawValue) {
                    return line.replacingOccurrences(of: VCardFields.fullName.rawValue, with: "")
                }
            }
        }

        return nil
    }
}
