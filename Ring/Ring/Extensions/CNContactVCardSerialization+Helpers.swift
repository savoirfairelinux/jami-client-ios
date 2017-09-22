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
/*
 *This extension adds fields UID and PHOTO to vCard  provided by default
 *It also provides image compresion that mostly could be usefull when sending contact request
 */

enum VCardFields: String {
    case begin     = "BEGIN:VCARD"
    case uid       = "UID:"
    case photoJPEG = "PHOTO;TYPE=JPEG;ENCODING=BASE64:"
    case photoPNG  = "PHOTO;TYPE=PNG;ENCODING=BASE64:"
    case end       = "END:VCARD"
}

extension CNContactVCardSerialization {

    class func dataWithImageAndUUID(from contact: CNContact, andImageCompression compressedSize: Int?) throws -> Data {

        var vcData = try CNContactVCardSerialization.data(with: [contact])

        guard var vcString = String(data: vcData, encoding: String.Encoding.utf8) else {
            return vcData
        }

        let entryUID = VCardFields.uid.rawValue + contact.identifier
        vcString = vcString.replacingOccurrences(of: VCardFields.begin.rawValue,
                                                 with: (VCardFields.begin.rawValue +
                                                    "\n" + entryUID))

        guard var image = contact.imageData  else {
            vcData = vcString.data(using: .utf8)!
            return vcData
        }

        var photofieldName = VCardFields.photoPNG

        // if we need smalest image first scale it and than compress
        var scaledImage: UIImage?
        if compressedSize != nil {
            scaledImage =  UIImage(data: image)?.convert(toSize: CGSize(width:50.0, height:50.0), scale: UIScreen.main.scale)
        }

        if let scaledImage = scaledImage {
            if UIImagePNGRepresentation(scaledImage) != nil {
                image = UIImagePNGRepresentation(scaledImage)!
            }
        }
        
        if let compressionSize = compressedSize, image.count > compressionSize {
            // compress image before sending vCard
            guard let compressedImage = UIImage(data: image)?.convertToData(ofMaxSize: compressionSize)else {
                vcData = vcString.data(using: .utf8)!
                return vcData
            }

            image = compressedImage
            photofieldName = VCardFields.photoJPEG
        }

        let base64Image =  image.base64EncodedString(options: Data.Base64EncodingOptions.init(rawValue: 0))
        let vcardImageString = photofieldName.rawValue + base64Image + "\n"
        vcString = vcString.replacingOccurrences(of: VCardFields.end.rawValue, with: (vcardImageString + VCardFields.end.rawValue))

        vcData = vcString.data(using: .utf8)!

        return vcData
    }
}
