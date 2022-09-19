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
/*
 *This extension adds fields UID and PHOTO to vCard  provided by default
 *It also provides image compression that mostly could be useful when sending contact request
 */

enum VCardFields: String {
    case begin     = "BEGIN:VCARD"
    case uid       = "UID:"
    case photoJPEG = "PHOTO;ENCODING=BASE64;TYPE=JPEG:"
    case photoPNG  = "PHOTO;ENCODING=BASE64;TYPE=PNG:"
    case end       = "END:VCARD"
    case fullName  = "FN:"
    case telephone = "TEL;other:"
}

extension CNContactVCardSerialization {

    class func dataWithImageAndUUID(from contact: CNContact, andImageCompression compressedSize: Int?, encoding: String.Encoding = .utf16) throws -> Data? {

        // recreate vCard string
        let beginString = VCardFields.begin.rawValue + "\n"
        let entryUIDString = VCardFields.uid.rawValue + contact.identifier + "\n"
        let name = contact.familyName.trimmingCharacters(in: .whitespacesAndNewlines)
        let phone = contact.phoneNumbers.isEmpty ? "" : contact.phoneNumbers[0].value.stringValue
        let telephoneString = VCardFields.telephone.rawValue + phone + "\n"
        let fullNameString = VCardFields.fullName.rawValue + name + "\n"
        let endString = VCardFields.end.rawValue

        var vCardString = beginString + entryUIDString + fullNameString + telephoneString + endString

        // if contact have an image add it to vCard data
        guard var image = contact.imageData  else {
            return vCardString.data(using: encoding)
        }

        var photofieldName = VCardFields.photoPNG

        // if we need smallest image first scale it and than compress
        var scaledImage: UIImage?
        if compressedSize != nil {
            scaledImage = UIImage(data: image)?
                .convert(toSize: CGSize(width: 400.0, height: 400.0), scale: 1.0)
        }
        if let scaledImage = scaledImage, let data = scaledImage.pngData() {
            image = data
        }

        if let compressionSize = compressedSize {
            // compress image before sending vCard
            guard let compressedImage = UIImage(data: image)?
                    .convertToData(ofMaxSize: compressionSize) else {
                return vCardString.data(using: encoding)
            }

            image = compressedImage
            photofieldName = VCardFields.photoJPEG
        }

        let base64Image = image.base64EncodedString(options: Data.Base64EncodingOptions.init(rawValue: 0))
        let vcardImageString = photofieldName.rawValue + base64Image + "\n"
        vCardString = vCardString.replacingOccurrences(of: VCardFields.end.rawValue, with: (vcardImageString + VCardFields.end.rawValue))

        return vCardString.data(using: encoding)
    }

    class func parseToVCard(data: Data) -> CNContact? {
        var contact: CNContact?
        do {
            try ObjCHandler.try {
                guard let vCards = try? CNContactVCardSerialization.contacts(with: data),
                      let vCard = vCards.first else { return }
                var stringData = String(data: data, encoding: .utf16)
                if stringData == nil {
                    stringData = String(data: data, encoding: .utf8)
                }
                guard let returnData = stringData else { return }
                let contentArr = returnData.components(separatedBy: "\n")
                let vcard = CNMutableContact()
                if let nameRow = contentArr.filter({ String($0.prefix(3)) == VCardFields.fullName.rawValue }).first {
                    let name = String(nameRow.suffix(nameRow.count - 3))
                    vcard.familyName = name
                }
                vcard.phoneNumbers = vCard.phoneNumbers
                vcard.imageData = vCard.imageData
                contact = vcard
            }
        } catch {
            print("An error ocurred during CNContactVCardSerialization: \(error)")
        }
        return contact
    }
}
