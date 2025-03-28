/*
 *  Copyright (C) 2025-2025 Savoir-faire Linux Inc.
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

final class ThreadSafeQueueHelper {
    private let queue: DispatchQueue

    /// Key for tracking whether the current thread is already on the queue
    private let queueKey = DispatchSpecificKey<Bool>()

    // MARK: - Initialization

    init(label: String, qos: DispatchQoS = .userInitiated) {
        self.queue = DispatchQueue(label: label, qos: qos, attributes: .concurrent)
        self.queue.setSpecific(key: queueKey, value: true)
    }

    init(queue: DispatchQueue) {
        self.queue = queue
        self.queue.setSpecific(key: queueKey, value: true)
    }

    // MARK: - Public Methods

    /// Execute a block synchronously if it's safe to do so, directly if already on the queue
    func safeSync<T>(_ work: () -> T) -> T {
        if isCurrentThreadOnQueue() {
            // Already on the queue, execute directly
            return work()
        } else {
            return queue.sync {
                return work()
            }
        }
    }

    /// Execute a block asynchronously with a barrier for write operations
    func barrierAsync(_ work: @escaping () -> Void) {
        queue.async(flags: .barrier) {
            work()
        }
    }

    /// Execute a block synchronously with a barrier if it's safe to do so
    func safeBarrierSync<T>(_ work: () -> T) -> T {
        if isCurrentThreadOnQueue() {
            // Already on the queue, direct execution to avoid deadlock
            // Note: This loses the barrier guarantee but prevents deadlock
            return work()
        } else {
            return queue.sync(flags: .barrier) {
                return work()
            }
        }
    }

    func isCurrentThreadOnQueue() -> Bool {
        return DispatchQueue.getSpecific(key: queueKey) == true
    }

    var underlyingQueue: DispatchQueue {
        return queue
    }
}
