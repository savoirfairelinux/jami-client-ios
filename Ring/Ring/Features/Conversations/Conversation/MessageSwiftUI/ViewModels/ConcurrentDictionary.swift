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
import Foundation

class ConcurentDictionary {
    let queue: DispatchQueue
    private var internalDictionary: [AnyHashable: Any]

    init(name: String, dictionary: [AnyHashable: Any]) {
        self.queue = DispatchQueue(label: name, qos: .background, attributes: .concurrent)
        self.internalDictionary = dictionary
    }

    func get(key: AnyHashable) -> Any? {
        var returnValue: Any?
        queue.sync(flags: .barrier) {[weak self] in
            returnValue = self?.internalDictionary[key]
        }
        return returnValue
    }

    func set(value: Any, for key: AnyHashable) {
        queue.sync(flags: .barrier) {[weak self] in
            self?.internalDictionary[key] = value
        }
    }

    func values() -> [Any] {
        var returnValue: [Any] = []
        queue.sync(flags: .barrier) { [weak self] in
            if let values = self?.internalDictionary.values {
                returnValue = Array(values)
            }
        }
        return returnValue
    }

    func filter(_ isIncluded: @escaping (Dictionary<AnyHashable, Any>.Element) throws -> Bool) rethrows -> [AnyHashable: Any]? {
        return try? self.internalDictionary.filter(isIncluded)
    }
}
