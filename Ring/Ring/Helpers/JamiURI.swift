/*
 *  Copyright (C) 2019 Savoir-faire Linux Inc.
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

enum URIType {
    case ring
    case sip

    func getString() -> String {
        switch self {
        case .ring:
            return "ring"
        case .sip:
            return "sip"
        }
    }
}

class JamiURI {
    var schema: URIType
    var userInfo: String = ""
    var hostname: String = ""
    var port: String = ""

    init(schema: URIType) {
        self.schema = schema
    }

    init(schema: URIType, infoHach: String, account: AccountModel) {
        self.schema = schema
        self.parce(infoHach: infoHach, account: account)
    }

    init(schema: URIType, infoHach: String) {
        self.schema = schema
        self.parce(infoHach: infoHach)
    }

    fileprivate func parce(infoHach: String, account: AccountModel) {
        self.parce(infoHach: infoHach)
        if self.schema == .ring || self.userInfo.isEmpty {
            return
        }
        if self.hostname.isEmpty {
            self.hostname = account.details?
                .get(withConfigKeyModel: ConfigKeyModel(withKey: ConfigKey.accountHostname)) ?? ""
        }
        if self.port.isEmpty {
            self.port = account.details?
                .get(withConfigKeyModel: ConfigKeyModel(withKey: ConfigKey.localPort)) ?? ""
        }
    }

    fileprivate func parce(infoHach: String) {
        var info = infoHach.replacingOccurrences(of: "ring:", with: "")
            .replacingOccurrences(of: "sip:", with: "")
            .replacingOccurrences(of: "@ring.dht", with: "")
            .replacingOccurrences(of: "<", with: "")
            .replacingOccurrences(of: ">", with: "")
        if self.schema == .ring {
            userInfo = info
            return
        }
        if info.isEmpty { return }
        if info.firstIndex(of: "@") != nil {
            userInfo = String(info.split(separator: "@").first!)
            info = info.replacingOccurrences(of: userInfo + "@", with: "")
        } else {
            userInfo = info
            return
        }
        if info.firstIndex(of: ":") != nil {
            let parts = info.split(separator: ":")
            hostname = String(parts.first!)
            if parts.count == 2 {
                port = String(info.split(separator: ":")[1])
            }
        } else {
            hostname = info
        }
    }

    lazy var uriString: String? = {
        var infoString = self.schema.getString() + ":"
        if self.userInfo.isEmpty {
            return nil
        }
        if self.schema == .ring {
            infoString += self.userInfo
            return infoString
        }
        if self.hostname.isEmpty || self.port.isEmpty {
            return nil
        }
        infoString += self.userInfo + "@" + self.hostname + ":" + self.port
        return infoString
    }()

    lazy var hash: String? = {
        if self.userInfo.isEmpty {
            return nil
        }
        return self.userInfo
    }()

    lazy var isValid: Bool = {
        if self.schema == .ring {
            return !self.userInfo.isEmpty
        }
        return !self.userInfo.isEmpty &&
            !self.hostname.isEmpty &&
            !self.port.isEmpty
    }()
}
