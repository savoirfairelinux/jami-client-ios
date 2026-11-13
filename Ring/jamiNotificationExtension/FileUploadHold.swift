/*
 *  Copyright (C) 2026 - 2026 Savoir-faire Linux Inc.
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

struct FileUploadHold {
    static let requestTimeout: TimeInterval = 10

    private var pendingDeadlines = [String: [TimeInterval]]()
    private var active = 0

    func isHolding(at uptime: TimeInterval) -> Bool {
        return active > 0 || pendingDeadlines.values.contains { $0.contains { $0 > uptime } }
    }

    mutating func requested(conversationId: String, at uptime: TimeInterval) {
        pendingDeadlines[conversationId, default: []].append(uptime + Self.requestTimeout)
    }

    mutating func started(conversationId: String) {
        if pendingDeadlines[conversationId]?.isEmpty == false {
            pendingDeadlines[conversationId]?.removeFirst()
        }
        active += 1
    }

    mutating func ended() {
        active = max(active - 1, 0)
    }
}
