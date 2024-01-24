/*
 *  Copyright (C) 2022 Savoir-faire Linux Inc.
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

public class Constants: NSObject {
    @objc public static let notificationReceived = "com.savoirfairelinux.notificationExtension.receivedNotification" as CFString
    @objc public static let notificationAppIsActive = "com.savoirfairelinux.jami.appActive" as CFString
    @objc public static let notificationData = "notificationData"
    @objc public static let updatedConversations = "updatedConversations"
    @objc public static let appGroupIdentifier = "group.com.savoirfairelinux.ring"
    @objc public static let notificationsCount = "notificationsCount"

    @objc public static let documentsPath: URL? = {
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?.appendingPathComponent("Documents")
    }()

    @objc public static let cachesPath: URL? = {
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?.appendingPathComponent("Library").appendingPathComponent("Caches")
    }()

    enum NotificationUserInfoKeys: String {
        case callID
        case name
        case messageContent
        case participantID
        case accountID
        case conversationID
    }

    public static let swarmColors: [String] = ["#E91E63",
                                               "#9C27B0",
                                               "#673AB7",
                                               "#3F51B5",
                                               "#2196F3",
                                               "#00BCD4",
                                               "#009688",
                                               "#4CAF50",
                                               "#8BC34A",
                                               "#9E9E9E",
                                               "#CDDC39",
                                               "#FFC107",
                                               "#FF5722",
                                               "#795548",
                                               "#607D8B"]
}
