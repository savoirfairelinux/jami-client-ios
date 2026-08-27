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

struct Profile {
    var uri: String
    var alias: String?
    var photo: String?
    var type: String

    static var empty: Profile {
        Profile(uri: "", alias: nil, photo: nil, type: "")
    }

    var hasNoOverrides: Bool {
        alias.nonEmptyOverride() == nil && photo.nonEmptyOverride() == nil
    }

    func merging(localOverride: Profile?) -> Profile {
        guard let localOverride else { return self }
        return Profile(uri: uri,
                       alias: localOverride.alias.nonEmptyOverride() ?? alias,
                       photo: localOverride.photo.nonEmptyOverride() ?? photo,
                       type: type)
    }
}

enum ProfileType: String {
    case ring = "RING"
    case sip = "SIP"
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

    class func dataForLocalOverride(_ profile: Profile) -> Data? {
        var lines = [VCardFields.begin.rawValue]
        if let alias = profile.alias.nonEmptyOverride() {
            lines.append(VCardFields.fullName.rawValue + alias)
        }
        if let photo = profile.photo.nonEmptyOverride() {
            lines.append(VCardFields.photoJPEG.rawValue + photo)
        }
        lines.append(VCardFields.telephone.rawValue + profile.uri)
        lines.append(VCardFields.end.rawValue)
        return lines.joined(separator: "\n").data(using: .utf8)
    }

    class func parseProfile(from string: String) -> Profile? {
        var alias: String?, avatar: String?, profileUri = ""

        func parseLine(_ line: String) -> (key: String, value: Substring)? {
            guard let colonIndex = line.firstIndex(of: ":") else { return nil }
            let key = String(line[..<colonIndex])
            let value = line[line.index(after: colonIndex)...]
            return (key, value)
        }

        string.enumerateLines { line, _ in
            guard let (key, value) = parseLine(line) else { return }
            switch true {
            case key.hasPrefix("PHOTO"):
                avatar = String(value)
            case key == "FN":
                alias = String(value)
            case key == "TEL;other":
                profileUri = String(value)
            default:
                break
            }
        }
        let type = profileUri.contains("ring") ? ProfileType.ring : ProfileType.sip
        return Profile(uri: profileUri, alias: alias, photo: avatar, type: type.rawValue)
    }

    class func parseDataToProfile(data: Data) -> Profile? {
        guard let profileStr = String(data: data, encoding: .utf8) else { return nil }
        return parseProfile(from: profileStr)
    }

    class func parseToProfile(filePath: String) -> Profile? {
        guard let profileStr = try? String(contentsOfFile: filePath, encoding: .utf8) else {
            return nil
        }
        return parseProfile(from: profileStr)
    }

    class func nameFromMergedProfile(basePath: String?, overridePath: String?) -> String? {
        if let overridePath,
           let name = getNameFromVCard(filePath: overridePath),
           !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return name
        }
        return basePath.flatMap { getNameFromVCard(filePath: $0) }
    }

    class func parseMergedProfile(basePath: String?, overridePath: String?) -> Profile? {
        let base = basePath.flatMap { parseToProfile(filePath: $0) }
        let localOverride = overridePath.flatMap { parseToProfile(filePath: $0) }
        return base?.merging(localOverride: localOverride) ?? localOverride
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

private extension Optional where Wrapped == String {
    func nonEmptyOverride() -> String? {
        guard let trimmed = self?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}
