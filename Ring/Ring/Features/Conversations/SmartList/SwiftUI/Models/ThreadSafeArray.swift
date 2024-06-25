/*
 *  Copyright (C) 2024 Savoir-faire Linux Inc.
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

import Foundation

class ThreadSafeArray<T>: Sequence {
    private var array: [T] = []
    private let accessQueue: DispatchQueue

    init(label: String) {
        accessQueue = DispatchQueue(label: label, attributes: .concurrent)
    }

    func append(_ element: T) {
        accessQueue.async(flags: .barrier) {
            self.array.append(element)
        }
    }

    func append(contentsOf elements: [T]) {
        accessQueue.async(flags: .barrier) {
            self.array.append(contentsOf: elements)
        }
    }

    func removeAll(where shouldBeRemoved: @escaping (T) -> Bool) {
        accessQueue.async(flags: .barrier) {
            self.array.removeAll(where: shouldBeRemoved)
        }
    }

    func filter(_ isIncluded: @escaping (T) -> Bool) -> [T] {
        var result: [T] = []
        accessQueue.sync {
            result = self.array.filter(isIncluded)
        }
        return result
    }

    func sort(by areInIncreasingOrder: @escaping (T, T) -> Bool) {
        accessQueue.async(flags: .barrier) {
            self.array.sort(by: areInIncreasingOrder)
        }
    }

    func map<U>(_ transform: @escaping (T) -> U) -> [U] {
        var result: [U] = []
        accessQueue.sync {
            result = self.array.map(transform)
        }
        return result
    }

    func count() -> Int {
        var count = 0
        accessQueue.sync {
            count = self.array.count
        }
        return count
    }

    func element(at index: Int) -> T? {
        var element: T?
        accessQueue.sync {
            if index < self.array.count {
                element = self.array[index]
            }
        }
        return element
    }

    func contains(where predicate: @escaping (T) -> Bool) -> Bool {
        var doesContain = false
        accessQueue.sync {
            doesContain = self.array.contains(where: predicate)
        }
        return doesContain
    }

    func makeIterator() -> AnyIterator<T> {
        var currentIndex = 0
        var snapshot: [T] = []
        accessQueue.sync {
            snapshot = self.array
        }
        return AnyIterator {
            guard currentIndex < snapshot.count else {
                return nil
            }
            let element = snapshot[currentIndex]
            currentIndex += 1
            return element
        }
    }
}
