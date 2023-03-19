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

    class func dataWithImageAndUUID(from profile: Profile, andImageCompression compressedSize: Int?, encoding: String.Encoding = .utf8) throws -> Data? {

        // recreate vCard string
        let beginString = VCardFields.begin.rawValue + "\n"
        // let entryUIDString = VCardFields.uid.rawValue + contact.identifier + "\n"
        let name = profile.alias!.trimmingCharacters(in: .whitespacesAndNewlines)
        let phone = profile.uri
        let telephoneString = VCardFields.telephone.rawValue + phone + "\n"
        let fullNameString = VCardFields.fullName.rawValue + name + "\n"
        let endString = VCardFields.end.rawValue

        var vCardString = beginString + fullNameString + telephoneString + endString

        // if contact have profile image add it to vCard data
        guard var image = profile.photo  else {
            return vCardString.data(using: encoding)
        }

        //        var photofieldName = VCardFields.photoPNG
        //
        //        // if we need smallest image first scale it and than compress
        //        var scaledImage: UIImage?
        //        if compressedSize != nil {
        //            scaledImage = UIImage(data: image)?
        //                .convert(toSize: CGSize(width: 400.0, height: 400.0), scale: 1.0)
        //        }
        //        if let scaledImage = scaledImage, let data = scaledImage.pngData() {
        //            image = data
        //        }
        //
        //        if let compressionSize = compressedSize {
        //            // compress image before sending vCard
        //            guard let compressedImage = UIImage(data: image)?
        //                    .convertToData(ofMaxSize: compressionSize) else {
        //                return vCardString.data(using: encoding)
        //            }
        //
        //            image = compressedImage
        //            photofieldName = VCardFields.photoJPEG
        //        }
        //
        //        let base64Image = image.base64EncodedString(options: Data.Base64EncodingOptions.init(rawValue: 0))
        let vcardImageString = VCardFields.photoJPEG.rawValue + image + "\n"
        vCardString = vCardString.replacingOccurrences(of: VCardFields.end.rawValue, with: (vcardImageString + VCardFields.end.rawValue))

        return vCardString.data(using: encoding)
    }

    class func parseToProfile(data: Data) -> Profile? {
        // var contact: CNContact?
        var stringData = String(data: data, encoding: .utf8)
        //        if stringData == nil {
        //            stringData = String(data: data, encoding: .utf16)
        //        }
        guard let str = stringData else { return nil}
        let lines = str.split(whereSeparator: \.isNewline)
        var alias: String = ""
        var avatar: String = ""
        var profileUri: String = ""
        for line in lines {
            print(line)
            if line.contains("PHOTO") {
                avatar = line.components(separatedBy: ":").last ?? ""
            } else if line.contains("FN") {
                alias = line.components(separatedBy: ":").last ?? ""
            }
            if line.contains("TEL;other") {
                profileUri = line.components(separatedBy: ":").last ?? ""
            }
        }
        let type = profileUri.contains("ring") ? ProfileType.ring : ProfileType.sip

        return Profile(uri: profileUri, alias: alias, photo: avatar, type: type.rawValue)
        //        let profile = Profile(uri: <#T##String#>, type: <#T##String#>)
        //        //let vcard = CNMutableContact()
        //        vcard.familyName = name
        //        vcard.imageData = avatar.data(using: .utf8)
        //        vcard.phoneNumbers = [CNLabeledValue(label: CNLabelPhoneNumberiPhone, value: CNPhoneNumber(stringValue: id))]
        //        //        vcard.phoneNumbers = [CNLabeledValue(label: "CNPhoneNumber", value: CNPhoneNumber.init(stringValue: id))]
        //        return vcard
        //        do {
        //            try ObjCHandler.try {
        //                guard let vCards = try? CNContactVCardSerialization.contacts(with: data),
        //                      let vCard = vCards.first else { return }
        //                //                var stringData = String(data: data, encoding: .utf16)
        //                //                if stringData == nil {
        //                //                    stringData = String(data: data, encoding: .utf8)
        //                //                }
        //                //                guard let returnData = stringData else { return }
        //                //                let contentArr = returnData.components(separatedBy: "\n")
        //                let vcard = CNMutableContact()
        //                //                if let nameRow = contentArr.filter({ String($0.prefix(3)) == VCardFields.fullName.rawValue }).first {
        //                //                    let name = String(nameRow.suffix(nameRow.count - 3))
        //                //                    vcard.familyName = name
        //                //                } else if !vCard.givenName.isEmpty {
        //                vcard.familyName = vCard.givenName
        //                // }
        //                vcard.phoneNumbers = vCard.phoneNumbers
        //                vcard.imageData = vCard.imageData
        //                contact = vcard
        //            }
        //        } catch {
        //            print("An error ocurred during CNContactVCardSerialization: \(error)")
        //        }
        //        return contact
    }
}
