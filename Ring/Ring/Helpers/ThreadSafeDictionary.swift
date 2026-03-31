/*
 *  Copyright (C) 2025 Savoir-faire Linux Inc.
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

/// A generic thread-safe dictionary backed by NSLock.
///
/// Multiple instances can share a single lock to reduce overhead
/// (e.g., all caches in one view model share one lock).
final class ThreadSafeDictionary<Key: Hashable, Value> {
    private var storage = [Key: Value]()
    private let lock: NSLock

    /// Creates a dictionary with its own dedicated lock.
    init() {
        self.lock = NSLock()
    }

    /// Creates a dictionary sharing an existing lock.
    /// Use this when multiple dictionaries in the same owner
    /// should share a single lock to reduce resource overhead.
    init(lock: NSLock) {
        self.lock = lock
    }

    // MARK: - Single-element access

    subscript(key: Key) -> Value? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return storage[key]
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            storage[key] = newValue
        }
    }

    @discardableResult
    func removeValue(forKey key: Key) -> Value? {
        lock.lock()
        defer { lock.unlock() }
        return storage.removeValue(forKey: key)
    }

    // MARK: - Bulk reads

    var values: [Value] {
        lock.lock()
        defer { lock.unlock() }
        return Array(storage.values)
    }

    var keys: [Key] {
        lock.lock()
        defer { lock.unlock() }
        return Array(storage.keys)
    }

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return storage.count
    }

    var isEmpty: Bool {
        lock.lock()
        defer { lock.unlock() }
        return storage.isEmpty
    }

    /// Thread-safe filter. Takes a snapshot under lock, applies predicate.
    func filter(_ isIncluded: (Key, Value) -> Bool) -> [Key: Value] {
        lock.lock()
        defer { lock.unlock() }
        return storage.filter { isIncluded($0.key, $0.value) }
    }

    /// Thread-safe forEach.
    func forEach(_ body: (Key, Value) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        storage.forEach { body($0.key, $0.value) }
    }

    // MARK: - Bulk write

    func removeAll() {
        lock.lock()
        defer { lock.unlock() }
        storage.removeAll()
    }

    /// Atomic read-modify-write. The block runs under the lock.
    func mutate(_ block: (inout [Key: Value]) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        block(&storage)
    }
}

// MARK: - Sequence

extension ThreadSafeDictionary: Sequence {
    /// Returns an iterator over a snapshot of the dictionary.
    /// Mutations after the iterator is created do not affect iteration.
    func makeIterator() -> AnyIterator<(key: Key, value: Value)> {
        lock.lock()
        let snapshot = Array(storage)
        lock.unlock()
        var index = 0
        return AnyIterator {
            guard index < snapshot.count else { return nil }
            let element = snapshot[index]
            index += 1
            return element
        }
    }
}
