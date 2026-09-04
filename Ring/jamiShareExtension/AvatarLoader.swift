/*
 *  Copyright (C) 2026 Savoir-faire Linux Inc.
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

import UIKit
import RxSwift

enum AvatarLoader {
    static let queue = DispatchQueue(label: "com.savoirfairelinux.ring.share.avatar", qos: .userInitiated)

    static let scheduler = SerialDispatchQueueScheduler(queue: queue,
                                                        internalSerialQueueName: "com.savoirfairelinux.ring.share.avatar.rx")

    static func decode(base64: String, targetPixels: CGFloat, completion: @escaping (UIImage?) -> Void) {
        queue.async {
            let image = decode(base64: base64, targetPixels: targetPixels)
            DispatchQueue.main.async {
                completion(image)
            }
        }
    }

    static func decode(base64: String, targetPixels: CGFloat) -> UIImage? {
        return autoreleasepool { () -> UIImage? in
            let options = [kCGImageSourceShouldCache: false] as CFDictionary
            guard let data = Data(base64Encoded: base64, options: .ignoreUnknownCharacters),
                  let source = CGImageSourceCreateWithData(data as CFData, options) else {
                return nil
            }
            return UIImage.createResizedImage(imageSource: source, size: targetPixels)
        }
    }
}
