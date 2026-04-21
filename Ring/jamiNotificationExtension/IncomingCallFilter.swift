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

import Foundation

/// Single source of truth for the wire-format strings the filter uses. Exposed
/// to Objective-C (Adapter.mm builds the contact-details dicts on this contract)
/// via the generated `jamiNotificationExtension-Swift.h` header.
@objc final class FilterKeys: NSObject {
    @objc static let contactId = "id"
    @objc static let contactBanned = "banned"
    @objc static let daemonTrue = "true"
    @objc static let publicInCalls = "DHT.PublicInCalls"
    private override init() {}
}

struct IncomingCallFilter {
    let allowFromUnknown: Bool
    let contactURIs: Set<String>

    init(allowFromUnknown: Bool, contactDetails: [[String: String]]) {
        self.allowFromUnknown = allowFromUnknown
        self.contactURIs = Set(
            contactDetails
                .filter { Bool($0[FilterKeys.contactBanned] ?? "") != true }
                .compactMap { $0[FilterKeys.contactId]?.canonicalJamiId() }
        )
    }

    func shouldAccept(peerId: String) -> Bool {
        return allowFromUnknown || contactURIs.contains(peerId.canonicalJamiId())
    }

    // Absent defaults to true (daemon's default); otherwise only the canonical
    // "true" allows — mirrors the daemon's parseBool strict match.
    static func parseAllowFromUnknown(accountDetails: [String: String]) -> Bool {
        guard let value = accountDetails[FilterKeys.publicInCalls] else { return true }
        return Bool(value) == true
    }
}

extension String {
    func canonicalJamiId() -> String {
        return self.replacingOccurrences(of: "ring:", with: "")
            .replacingOccurrences(of: "jami:", with: "")
            .lowercased()
    }
}
