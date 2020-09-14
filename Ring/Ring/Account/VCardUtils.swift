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
import Contacts
import RxSwift
// swiftlint:disable identifier_name

enum VCardFolders: String {
    case contacts
    case profile
}

enum VCardFiles: String {
    case myProfile
}
class VCardUtils {
    class func loadVCard(named name: String, inFolder folder: String, contactService: ContactsService? = nil) -> Single<CNContact> {
        return Single.create(subscribe: { single in
            if let contactRequest = contactService?.contactRequest(withRingId: name) {
                if let vCard = contactRequest.vCard {
                    single(.success(vCard))
                } else {
                    single(.error(ContactServiceError.loadVCardFailed))
                }
            } else if let directoryURL = VCardUtils.getFilePath(forFile: name, inFolder: folder, createIfNotExists: false) {
                if let data = FileManager.default.contents(atPath: directoryURL.path) {
                    if let vCard = CNContactVCardSerialization.parseToVCard(data: data) {
                        single(.success(vCard))
                    } else {
                        single(.error(ContactServiceError.loadVCardFailed))
                    }
                }
            } else {
                single(.error(ContactServiceError.loadVCardFailed))
            }
            return Disposables.create { }
        })
    }

    class func getFilePath(forFile fileName: String, inFolder folderName: String, createIfNotExists shouldCreate: Bool) -> URL? {

        var path: URL?

        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return path
        }
        let directoryURL = documentsURL.appendingPathComponent(folderName)
        var isDirectory = ObjCBool(true)
        let directoryExists = FileManager.default.fileExists(atPath: directoryURL.path, isDirectory: &isDirectory)
        if directoryExists && isDirectory.boolValue {
            path = directoryURL.appendingPathComponent(fileName)
            return path
        }
        if !shouldCreate {
            return path
        }

        do {
            try FileManager.default.createDirectory(atPath: directoryURL.path, withIntermediateDirectories: true, attributes: nil)
            path = directoryURL.appendingPathComponent(fileName)
            return path

        } catch _ as NSError {
            return path
        }
    }

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

    class func sendVCard(card: CNContact, callID: String, accountID: String, sender: CallsService) {
        do {
            let vCard = card
            guard let vCardData = try CNContactVCardSerialization.dataWithImageAndUUID(from: vCard, andImageCompression: 40000, encoding: .utf8),
                var vCardString = String(data: vCardData, encoding: String.Encoding.utf8) else {
                return
            }
            var vcardLength = vCardString.count
            let chunkSize = 1024
            let idKey = Int64(arc4random_uniform(10000000))
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
                sender.sendChunk(callID: callID, message: chunk, accountId: accountID)
            }
        } catch {
            print(error)
        }
    }
}
