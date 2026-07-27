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

/// Multicast fan-out for call events. `AsyncStream` is single-consumer,
/// so each subscriber gets its own buffered stream; a lock protects the
/// subscriber list (`send` can be called from the store actor while
/// subscribers come and go on other tasks).
final class EventBroadcaster<Event: Sendable>: @unchecked Sendable {

    private let lock = NSLock()
    private var subscribers: [UUID: @Sendable (Event) -> Void] = [:]

    func subscribe() -> AsyncStream<Event> {
        return subscribe(replaying: [], where: { _ in true })
    }

    /// Registers before yielding `events`, so a caller can atomically replay
    /// current state and then receive live deltas without an observation gap.
    func subscribe(replaying events: [Event],
                   where isIncluded: @escaping @Sendable (Event) -> Bool)
    -> AsyncStream<Event> {
        let (stream, continuation) = AsyncStream.makeStream(
            of: Event.self, bufferingPolicy: .unbounded)
        let id = UUID()
        continuation.onTermination = { [weak self] _ in
            guard let self = self else { return }
            self.lock.lock()
            self.subscribers[id] = nil
            self.lock.unlock()
        }

        lock.lock()
        subscribers[id] = { event in
            guard isIncluded(event) else { return }
            continuation.yield(event)
        }
        for event in events where isIncluded(event) {
            continuation.yield(event)
        }
        lock.unlock()
        return stream
    }

    func send(_ event: Event) {
        lock.lock()
        let currentSubscribers = Array(subscribers.values)
        lock.unlock()
        for subscriber in currentSubscribers {
            subscriber(event)
        }
    }
}
