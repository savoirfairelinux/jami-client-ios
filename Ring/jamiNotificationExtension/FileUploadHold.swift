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

/// Keeps the notification extension alive while it serves files to peers.
/// A request is counted when it is decrypted, because the peer's file channel
/// can open after the conversation has finished syncing.
struct FileUploadHold {
    private var pending = 0
    private var active = 0

    var isHolding: Bool {
        return pending > 0 || active > 0
    }

    mutating func requested() {
        pending += 1
    }

    mutating func started() {
        pending = max(pending - 1, 0)
        active += 1
    }

    mutating func ended() {
        active = max(active - 1, 0)
    }
}
