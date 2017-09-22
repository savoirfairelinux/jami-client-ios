/*
 *  Copyright (C) 2017 Savoir-faire Linux Inc.
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

enum VCardFolders: String {
    case contacts
    case profile
}
class VCardUtils {

    class func saveVCard(vCard: CNContact, withName name: String, inFolder folder: String) -> Observable<Void> {
        return Observable.create { observable in
            if let directoryURL = VCardUtils.getFilePath(forFile: name, inFolder: folder, createIfNotExists: true) {
                do {
                    let data = try CNContactVCardSerialization.dataWithImageAndUUID(from: vCard, andImageCompression: nil)
                    try data.write(to: directoryURL)
                    observable.on(.completed)

                } catch {
                    observable.on(.error(ContactServiceError.saveVCardFailed))
                }
            } else {
                observable.on(.error(ContactServiceError.saveVCardFailed))
            }
            return Disposables.create { }
        }
    }

    class func loadVCard(named name: String, inFolder folder: String) -> Single<CNContact> {
        return Single.create(subscribe: { single in
            if let directoryURL = VCardUtils.getFilePath(forFile: name, inFolder: folder, createIfNotExists: false) {
                do {
                    if let data = FileManager.default.contents(atPath: directoryURL.path) {
                        let vCard = try CNContactVCardSerialization.contacts(with: data)
                        if vCard.isEmpty {
                            single(.error(ContactServiceError.loadVCardFailed))
                        } else {
                            single(.success(vCard.first!))
                        }
                    }
                } catch {
                    single(.error(ContactServiceError.loadVCardFailed))
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
}
