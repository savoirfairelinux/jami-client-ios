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

import XCTest
@testable import Ring

// swiftlint:disable identifier_name
final class ThreadSafeDictionaryTests: XCTestCase {

    // MARK: - Basic CRUD

    func testGetReturnsNilForMissingKey() {
        let dict = ThreadSafeDictionary<String, String>()
        XCTAssertNil(dict["missing"])
    }

    func testSetAndGet() {
        let dict = ThreadSafeDictionary<String, String>()
        dict["key1"] = "value1"
        XCTAssertEqual(dict["key1"], "value1")
    }

    func testSetOverwritesExistingValue() {
        let dict = ThreadSafeDictionary<String, Int>()
        dict["key"] = 1
        dict["key"] = 2
        XCTAssertEqual(dict["key"], 2)
    }

    func testRemoveValue() {
        let dict = ThreadSafeDictionary<String, String>()
        dict["key"] = "value"
        let removed = dict.removeValue(forKey: "key")
        XCTAssertEqual(removed, "value")
        XCTAssertNil(dict["key"])
    }

    func testRemoveValueReturnsNilForMissingKey() {
        let dict = ThreadSafeDictionary<String, String>()
        let removed = dict.removeValue(forKey: "missing")
        XCTAssertNil(removed)
    }

    func testRemoveAll() {
        let dict = ThreadSafeDictionary<String, Int>()
        dict["a"] = 1
        dict["b"] = 2
        dict["c"] = 3
        dict.removeAll()
        XCTAssertTrue(dict.isEmpty)
        XCTAssertEqual(dict.count, 0)
    }

    // MARK: - Bulk Reads

    func testValuesReturnsAllValues() {
        let dict = ThreadSafeDictionary<String, Int>()
        dict["a"] = 1
        dict["b"] = 2
        dict["c"] = 3
        let values = dict.values.sorted()
        XCTAssertEqual(values, [1, 2, 3])
    }

    func testKeysReturnsAllKeys() {
        let dict = ThreadSafeDictionary<String, Int>()
        dict["a"] = 1
        dict["b"] = 2
        let keys = dict.keys.sorted()
        XCTAssertEqual(keys, ["a", "b"])
    }

    func testCountReflectsEntries() {
        let dict = ThreadSafeDictionary<String, String>()
        XCTAssertEqual(dict.count, 0)
        dict["a"] = "1"
        XCTAssertEqual(dict.count, 1)
        dict["b"] = "2"
        XCTAssertEqual(dict.count, 2)
        dict.removeValue(forKey: "a")
        XCTAssertEqual(dict.count, 1)
    }

    func testIsEmptyTrueWhenEmpty() {
        let dict = ThreadSafeDictionary<String, String>()
        XCTAssertTrue(dict.isEmpty)
    }

    func testIsEmptyFalseWhenNotEmpty() {
        let dict = ThreadSafeDictionary<String, String>()
        dict["key"] = "value"
        XCTAssertFalse(dict.isEmpty)
    }

    // MARK: - Filter

    func testFilterReturnsMatchingEntries() {
        let dict = ThreadSafeDictionary<String, Int>()
        dict["a"] = 1
        dict["b"] = 2
        dict["c"] = 3
        dict["d"] = 4
        dict["e"] = 5
        let result = dict.filter { _, value in value > 3 }
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result["d"], 4)
        XCTAssertEqual(result["e"], 5)
    }

    func testFilterReturnsEmptyWhenNothingMatches() {
        let dict = ThreadSafeDictionary<String, Int>()
        dict["a"] = 1
        dict["b"] = 2
        let result = dict.filter { _, value in value > 100 }
        XCTAssertTrue(result.isEmpty)
    }

    func testFilterOnEmptyDictionary() {
        let dict = ThreadSafeDictionary<String, Int>()
        let result = dict.filter { _, _ in true }
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - Iteration / Sequence

    func testForEachVisitsAllEntries() {
        let dict = ThreadSafeDictionary<String, Int>()
        dict["a"] = 1
        dict["b"] = 2
        dict["c"] = 3
        var visited = [String: Int]()
        dict.forEach { key, value in
            visited[key] = value
        }
        XCTAssertEqual(visited, ["a": 1, "b": 2, "c": 3])
    }

    func testMakeIteratorCoversAllEntries() {
        let dict = ThreadSafeDictionary<String, Int>()
        dict["a"] = 1
        dict["b"] = 2
        var collected = [String: Int]()
        for (key, value) in dict {
            collected[key] = value
        }
        XCTAssertEqual(collected, ["a": 1, "b": 2])
    }

    func testIteratorUsesSnapshot() {
        let dict = ThreadSafeDictionary<String, Int>()
        for idx in 0..<100 {
            dict["\(idx)"] = idx
        }
        var iteratedKeys = [String]()
        for (key, _) in dict {
            dict["new_\(key)"] = 999
            iteratedKeys.append(key)
        }
        XCTAssertEqual(iteratedKeys.count, 100)
    }

    // MARK: - Shared Lock

    func testSharedLock() {
        let sharedLock = NSLock()
        let dict1 = ThreadSafeDictionary<String, Int>(lock: sharedLock)
        let dict2 = ThreadSafeDictionary<String, String>(lock: sharedLock)
        dict1["count"] = 42
        dict2["name"] = "test"
        XCTAssertEqual(dict1["count"], 42)
        XCTAssertEqual(dict2["name"], "test")
    }

    func testDedicatedLockByDefault() {
        let dict1 = ThreadSafeDictionary<String, Int>()
        let dict2 = ThreadSafeDictionary<String, Int>()
        dict1["key"] = 1
        dict2["key"] = 2
        XCTAssertEqual(dict1["key"], 1)
        XCTAssertEqual(dict2["key"], 2)
    }

    // MARK: - Thread Safety Stress Tests

    func testConcurrentSetAndGet() {
        let dict = ThreadSafeDictionary<Int, Int>()
        let iterations = 1000

        DispatchQueue.concurrentPerform(iterations: iterations) { idx in
            dict[idx] = idx
        }

        for idx in 0..<iterations {
            XCTAssertEqual(dict[idx], idx, "Missing value for key \(idx)")
        }
    }

    func testConcurrentFilterDuringWrites() {
        let dict = ThreadSafeDictionary<Int, Int>()
        let iterations = 500
        let expectation = XCTestExpectation(description: "Concurrent filter and writes complete")
        expectation.expectedFulfillmentCount = 2

        DispatchQueue.global(qos: .userInitiated).async {
            for idx in 0..<iterations {
                dict[idx] = idx
            }
            expectation.fulfill()
        }

        DispatchQueue.global(qos: .background).async {
            for _ in 0..<100 {
                _ = dict.filter { _, value in value % 2 == 0 }
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)
    }

    func testConcurrentIterationDuringWrites() {
        let dict = ThreadSafeDictionary<Int, Int>()
        for idx in 0..<100 {
            dict[idx] = idx
        }
        let expectation = XCTestExpectation(description: "Concurrent iteration and writes complete")
        expectation.expectedFulfillmentCount = 2

        DispatchQueue.global(qos: .userInitiated).async {
            for idx in 100..<500 {
                dict[idx] = idx
            }
            expectation.fulfill()
        }

        DispatchQueue.global(qos: .background).async {
            for _ in 0..<50 {
                var count = 0
                for _ in dict {
                    count += 1
                }
                XCTAssertGreaterThan(count, 0)
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)
    }

    func testConcurrentMixedOperations() {
        let dict = ThreadSafeDictionary<Int, Int>()
        let iterations = 200

        DispatchQueue.concurrentPerform(iterations: iterations) { idx in
            dict[idx] = idx
            _ = dict[idx]
            _ = dict.count
            _ = dict.values
            _ = dict.filter { _, val in val == idx }
            if idx % 3 == 0 {
                dict.removeValue(forKey: idx)
            }
        }
    }

    // MARK: - Mutate (atomic read-modify-write)

    func testMutateModifiesDictionary() {
        let dict = ThreadSafeDictionary<String, Int>()
        dict["counter"] = 0
        dict.mutate { storage in
            storage["counter"] = (storage["counter"] ?? 0) + 10
            storage["new"] = 42
        }
        XCTAssertEqual(dict["counter"], 10)
        XCTAssertEqual(dict["new"], 42)
    }

    func testConcurrentMutateProducesConsistentState() {
        let dict = ThreadSafeDictionary<String, Int>()
        dict["counter"] = 0
        let iterations = 1000

        DispatchQueue.concurrentPerform(iterations: iterations) { _ in
            dict.mutate { storage in
                storage["counter"] = (storage["counter"] ?? 0) + 1
            }
        }

        XCTAssertEqual(dict["counter"], iterations)
    }

    // MARK: - Generic Type Safety

    func testWorksWithClassValues() {
        class Box {
            let value: String
            init(_ value: String) { self.value = value }
        }
        let dict = ThreadSafeDictionary<String, Box>()
        let box = Box("hello")
        dict["key"] = box
        XCTAssertTrue(dict["key"] === box)
    }

    func testWorksWithOptionalValues() {
        let dict = ThreadSafeDictionary<String, String?>()
        dict["key"] = nil
        XCTAssertNil(dict["key"])
    }
}
// swiftlint:enable identifier_name
