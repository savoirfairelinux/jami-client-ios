/*
 *  Copyright (C) 2016-2018 Savoir-faire Linux Inc.
 *
 *  Author: Edric Ladent-Milaret <edric.ladent-milaret@savoirfairelinux.com>
 *  Author: Andreas Traczyk <andreas.traczyk@savoirfairelinux.com>
 *  Author: Quentin Muret <quentin.muret@savoirfairelinux.com>
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
import MobileCoreServices

extension String {
    func toBool() -> Bool? {
        switch self.lowercased() {
        case "true", "yes", "1":
            return true
        case "false", "no", "0":
            return false
        default:
            return nil
        }
    }

    func isSHA1() -> Bool {
        let sha1Regex = try? NSRegularExpression(pattern: "(ring:)?([0-9a-f]{40})", options: [])
        if sha1Regex?.firstMatch(in: self,
                                 options: NSRegularExpression.MatchingOptions.reportCompletion,
                                 range: NSRange(location: 0, length: self.count)) != nil {
            return true
        }
        return false
    }

    var isPhoneNumber: Bool {
        do {
            let detector = try NSDataDetector(types: NSTextCheckingResult.CheckingType.phoneNumber.rawValue)
            let matches = detector.matches(in: self, options: [], range: NSRange(location: 0, length: self.count))
            guard let res = matches.first else { return false }
            return res.resultType == .phoneNumber &&
                res.range.location == 0 &&
                res.range.length == self.count
        } catch {
            return false
        }
    }

    func toMD5HexString() -> String {
        guard let messageData = self.data(using: .utf8) else { return "" }
        var digestData = Data(count: Int(CC_MD5_DIGEST_LENGTH))

        digestData.withUnsafeMutableBytes { (digestBytes: UnsafeMutableRawBufferPointer) -> Void in
            messageData.withUnsafeBytes { (messageBytes: UnsafeRawBufferPointer) -> Void in
                CC_MD5(messageBytes.baseAddress,
                       CC_LONG(messageData.count),
                       digestBytes.bindMemory(to: UInt8.self).baseAddress)
            }
        }

        return digestData.map { String(format: "%02hhx", $0) }.joined()
    }

    func prefixString() -> String {
        return String(self.prefix(1))
    }

    func convertToSeconds() -> Int64 {
        let hourMinSec: [String] = self.components(separatedBy: ":")
        switch hourMinSec.count {
        case 1:
            return Int64(Int(hourMinSec[0]) ?? 0)
        case 2:
            return (Int64(hourMinSec[0]) ?? 0) * 60
                + (Int64(hourMinSec[1]) ?? 0)
        case 3:
            let sec: Int64 = Int64(hourMinSec[2]) ?? 0
            let min: Int64 = (Int64(hourMinSec[1]) ?? 0) * 60
            let hours: Int64 = (Int64(hourMinSec[0]) ?? 0) * 60 * 60
            return hours + min + sec
        default:
            return 0
        }
    }

    var boolValue: Bool {
        return (self as NSString).boolValue
    }

    func isMediaExtension() -> Bool {
        let uti = UTTypeCreatePreferredIdentifierForTag(
            kUTTagClassFilenameExtension,
            self as CFString,
            nil)

        var fileIsMedia = false
        if let value = uti?.takeRetainedValue(),
            UTTypeConformsTo(value, kUTTypeMovie) || UTTypeConformsTo(value, kUTTypeVideo)
                || UTTypeConformsTo(value, kUTTypeAudio) {
            fileIsMedia = true
        }
        let mediaExtension = ["ogg", "webm"]
        if mediaExtension.contains(where: { $0.compare(self, options: .caseInsensitive) == .orderedSame }) {
            fileIsMedia = true
        }
        return fileIsMedia
    }

    func isImageExtension() -> Bool {
        let uti = UTTypeCreatePreferredIdentifierForTag(
            kUTTagClassFilenameExtension,
            self as CFString,
            nil)

        var fileIsImage = false
        if let value = uti?.takeRetainedValue(),
            UTTypeConformsTo(value, kUTTypeImage) {
            fileIsImage = true
        }
        return fileIsImage
    }

    func toBase64() -> String {
        return Data(self.utf8).base64EncodedString()
    }

    func filterOutHost() -> String {
        return self.replacingOccurrences(of: "@ring.dht", with: "")
    }
}
