//
//  AtomicTests.swift
//  Tests
//
//  Created by Krunoslav Zaher on 10/29/18.
//  Copyright © 2018 Krunoslav Zaher. All rights reserved.
//

import XCTest
import Dispatch

#if true
typealias AtomicPrimitive = AtomicInt
#else
private struct AtomicIntSanityCheck {
    var atom: Int32 = 0

    init() {
    }

    init(_ atom: Int32) {
        self.atom = atom
    }

    mutating func add(_ value: Int32) -> Int32 {
        defer { self.atom += value }
        return self.atom
    }

    mutating func sub(_ value: Int32) -> Int32 {
        defer { self.atom -= value }
        return self.atom
    }

    mutating func fetchOr(_ value: Int32) -> Int32 {
        defer { self.atom |= value }
        return self.atom
    }

    func load() -> Int32 {
        self.atom
    }
}
private typealias AtomicPrimitive = AtomicIntSanityCheck
#endif

class AtomicTests: RxTest {}

extension AtomicTests {
    func testAtomicInitialValue() async {
        let atomic = await AtomicPrimitive(4)
        await assertEqual(await globalLoad(atomic), 4)
    }

    func testAtomicInitialDefaultValue() async {
        let atomic = await AtomicPrimitive()
        await assertEqual(await globalLoad(atomic), 0)
    }
}

extension AtomicTests {
    private static let repeatCount = 100
    private static let concurrency = 8

    func testFetchOrSetsBits() async {
        let atomic = await AtomicPrimitive()
        await assertEqual(await fetchOr(atomic, 0), 0)
        await assertEqual(await fetchOr(atomic, 4), 0)
        await assertEqual(await fetchOr(atomic, 8), 4)
        await assertEqual(await fetchOr(atomic, 0), 12)
    }

    func testFetchOrConcurrent() async {
        let queue = DispatchQueue.global(qos: .default)
        for _ in 0 ..< AtomicTests.repeatCount {
            let atomic = await AtomicPrimitive(0)

            let counter = await AtomicPrimitive(0)

            var expectations = [XCTestExpectation]()

            for _ in 0 ..< AtomicTests.concurrency {
                let expectation = self.expectation(description: "wait until operation completes")
                queue.async {
                    Task {
                        while await globalLoad(atomic) == 0 {}
                        
                        if await fetchOr(atomic, -1) == 1 {
                            await globalAdd(counter, 1)
                        }
                        
                        expectation.fulfill()
                    }
                }
                expectations.append(expectation)
            }
            await fetchOr(atomic, 1)

            #if os(Linux)
            self.waitForExpectations(timeout: 1.0) { _ in }
            #else
            await XCTWaiter().fulfillment(of: expectations, timeout: 1.0)
            #endif
            await assertEqual(await globalLoad(counter), 1)
        }
    }

    func testAdd() async {
        let atomic = await AtomicPrimitive(0)
        await assertEqual(await globalAdd(atomic, 4), 0)
        await assertEqual(await globalAdd(atomic, 3), 4)
        await assertEqual(await globalAdd(atomic, 10), 7)
    }

    func testAddConcurrent() async {
        let queue = DispatchQueue.global(qos: .default)
        for _ in 0 ..< AtomicTests.repeatCount {
            let atomic = await AtomicPrimitive(0)

            let counter = await AtomicPrimitive(0)

            var expectations = [XCTestExpectation]()

            for _ in 0 ..< AtomicTests.concurrency {
                let expectation = self.expectation(description: "wait until operation completes")
                queue.async {
                    Task {
                        while await globalLoad(atomic) == 0 {}
                        
                        await globalAdd(counter, 1)
                        
                        expectation.fulfill()
                    }
                }
                expectations.append(expectation)
            }
            await fetchOr(atomic, 1)

            #if os(Linux)
            waitForExpectations(timeout: 1.0) { _ in }
            #else
            await XCTWaiter().fulfillment(of: expectations, timeout: 1.0)
            #endif

            await assertEqual(await globalLoad(counter), 8)
        }
    }

    func testSub() async {
        let atomic = await AtomicPrimitive(0)
        await assertEqual(await sub(atomic, -4), 0)
        await assertEqual(await sub(atomic, -3), 4)
        await assertEqual(await sub(atomic, -10), 7)
    }

    func testSubConcurrent() async {
        let queue = DispatchQueue.global(qos: .default)
        for _ in 0 ..< AtomicTests.repeatCount {
            let atomic = await AtomicPrimitive(0)

            let counter = await AtomicPrimitive(0)

            var expectations = [XCTestExpectation]()

            for _ in 0 ..< AtomicTests.concurrency {
                let expectation = self.expectation(description: "wait until operation completes")
                queue.async {
                    Task {
                        while await globalLoad(atomic) == 0 {}
                        
                        await sub(counter, 1)
                        
                        expectation.fulfill()
                    }
                }
                expectations.append(expectation)
            }
            await fetchOr(atomic, 1)

            #if os(Linux)
            waitForExpectations(timeout: 1.0) { _ in }
            #else
            await XCTWaiter().fulfillment(of: expectations, timeout: 1.0)
            #endif

            await assertEqual(await globalLoad(counter), -8)
        }
    }
}

func assertEqual<T>(_ lhs: @autoclosure () async -> T, _ rhs: @autoclosure () async -> T, message: @escaping @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) async where T: Equatable {
    let lhsVal = await lhs()
    let rhsVal = await rhs()
    XCTAssertEqual(lhsVal, rhsVal, message(), file: file, line: line)
}
