/*
 * Copyright (C) 2026-2026 Savoir-faire Linux Inc.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA.
 */

import Foundation
import RxRelay

final class ReplyTargetRegistry {

    let targets = BehaviorRelay(value: [MessageModel]())

    private let lock = NSLock()
    private var requestedIds = [String]()

    func request(_ messageId: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if requestedIds.contains(messageId) {
            return false
        }
        requestedIds.append(messageId)
        return true
    }

    func isRequested(_ messageId: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return requestedIds.contains(messageId)
    }

    func target(withId messageId: String) -> MessageModel? {
        return targets.value.first(where: { $0.id == messageId })
    }

    func resolve(_ message: MessageModel) {
        var updatedTargets = targets.value
        if !updatedTargets.contains(where: { $0.id == message.id }) {
            updatedTargets.append(message)
            targets.accept(updatedTargets)
        }
        lock.lock()
        requestedIds.removeAll { $0 == message.id }
        lock.unlock()
    }
}
