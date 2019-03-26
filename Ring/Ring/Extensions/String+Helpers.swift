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

    func toMD5HexString() -> String {
        let messageData = self.data(using: .utf8)!
        var digestData = Data(count: Int(CC_MD5_DIGEST_LENGTH))

        _ = digestData.withUnsafeMutableBytes { digestBytes in
            messageData.withUnsafeBytes { messageBytes in
                CC_MD5(messageBytes, CC_LONG(messageData.count), digestBytes)
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
}
