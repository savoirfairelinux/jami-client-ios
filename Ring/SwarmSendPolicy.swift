/*
 * Copyright (C) 2026 Savoir-faire Linux Inc.
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import Foundation

/// Shared by the app and share extension. Missing grants never allow a send.
@objc final class SwarmSendPolicy: NSObject {
    @objc static func allows(_ grants: [String]?, file: Bool, parentId: String) -> Bool {
        let permission = file ? (parentId.isEmpty ? "file" : "fileReply")
                              : (parentId.isEmpty ? "text" : "textReply")
        return grants?.contains(permission) == true
    }

    @objc static func canPublish(_ grants: [String]?) -> Bool {
        allows(grants, file: false, parentId: "") || allows(grants, file: true, parentId: "")
    }
}
