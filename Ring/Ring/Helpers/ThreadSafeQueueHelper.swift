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
import RxRelay
import RxSwift

final class ThreadSafeQueueHelper {
    private let queue: DispatchQueue

    private let queueKey = DispatchSpecificKey<Bool>()

    init(label: String, qos: DispatchQoS = .userInitiated) {
        self.queue = DispatchQueue(label: label, qos: qos, attributes: .concurrent)
        self.queue.setSpecific(key: queueKey, value: true)
    }

    init(queue: DispatchQueue) {
        self.queue = queue
        self.queue.setSpecific(key: queueKey, value: true)
    }

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

final class ThreadSafeValue<T> {
    private var value: T
    private let queueHelper: ThreadSafeQueueHelper

    init(_ initialValue: T, queueHelper: ThreadSafeQueueHelper) {
        self.value = initialValue
        self.queueHelper = queueHelper
    }

    func get() -> T {
        queueHelper.safeSync {
            value
        }
    }

    func update(_ block: @escaping (inout T) -> Void) {
        queueHelper.barrierAsync {
            block(&self.value)
        }
    }

    func set(_ newValue: T) {
        queueHelper.barrierAsync {
            self.value = newValue
        }
    }
}

final class SynchronizedRelay<T> {
    private let relay: BehaviorRelay<T>
    private let queueHelper: ThreadSafeQueueHelper

    init(initialValue: T, queueHelper: ThreadSafeQueueHelper) {
        self.relay = BehaviorRelay(value: initialValue)
        self.queueHelper = queueHelper
    }

    var observable: Observable<T> {
        relay.asObservable()
    }

    func get() -> T {
        queueHelper.safeSync {
            relay.value
        }
    }

    func set(_ newValue: T) {
        queueHelper.barrierAsync {
            self.relay.accept(newValue)
        }
    }

    func update(_ block: @escaping (inout T) -> Void) {
        queueHelper.barrierAsync {
            var value = self.relay.value
            block(&value)
            self.relay.accept(value)
        }
    }

    func updateSync(_ block: (inout T) -> Void) {
        queueHelper.safeBarrierSync {
            var value = self.relay.value
            block(&value)
            self.relay.accept(value)
        }
    }
}
