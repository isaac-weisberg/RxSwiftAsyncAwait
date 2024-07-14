//
//  Observable+WithUnretainedTests.swift
//  Tests
//
//  Created by Vincent Pradeilles on 01/01/2021.
//  Copyright © 2021 Krunoslav Zaher. All rights reserved.
//

import XCTest
import RxSwift
import RxTest

class WithUnretainedTests: XCTestCase {
    fileprivate var testClass: TestClass!
    var values: TestableObservable<Int>!
    var tupleValues: TestableObservable<(Int, String)>!
    var scheduler: TestScheduler!

    override func setUp() async throws {
        try await super.setUp()
        scheduler = await TestScheduler(initialClock: 0)

        testClass = TestClass()
        values = await scheduler.createColdObservable([
            .next(210, 1),
            .next(215, 2),
            .next(220, 3),
            .next(225, 5),
            .next(230, 8),
            .completed(250)
        ])

        tupleValues = await scheduler.createColdObservable([
            .next(210, (1, "a")),
            .next(215, (2, "b")),
            .next(220, (3, "c")),
            .next(225, (5, "d")),
            .next(230, (8, "e")),
            .completed(250)
        ])
    }

    func testObjectAttached() async {
        let testClassId = testClass.id

        let correctValues: [Recorded<Event<String>>] = [
            .next(410, "\(testClassId), 1"),
            .next(415, "\(testClassId), 2"),
            .next(420, "\(testClassId), 3"),
            .next(425, "\(testClassId), 5"),
            .next(430, "\(testClassId), 8"),
            .completed(450)
        ]

        let res = await scheduler.start {
            await self.values
                .withUnretained(self.testClass)
                .map { "\($0.id), \($1)" }
        }

        XCTAssertEqual(res.events, correctValues)
    }

    func testObjectDeallocates() async {
        _ = await self.values
                .withUnretained(self.testClass)
                .subscribe()

        // Confirm the object can be deallocated
        XCTAssertTrue(testClass != nil)
        testClass = nil
        XCTAssertTrue(testClass == nil)
    }

    func testObjectDeallocatesSequenceCompletes() async {
        let testClassId = testClass.id

        let correctValues: [Recorded<Event<String>>] = [
            .next(410, "\(testClassId), 1"),
            .next(415, "\(testClassId), 2"),
            .next(420, "\(testClassId), 3"),
            .completed(425)
        ]

        let res = await scheduler.start {
            await self.values
                .withUnretained(self.testClass)
                .do(onNext: { _, value in
                    // Release the object in the middle of the sequence
                    // to confirm it properly terminates the sequence
                    if value == 3 {
                        self.testClass = nil
                    }
                })
                .map { "\($0.id), \($1)" }
        }

        XCTAssertEqual(res.events, correctValues)
    }

    func testResultsSelector() async {
        let testClassId = testClass.id

        let correctValues: [Recorded<Event<String>>] = [
            .next(410, "\(testClassId), 1, a"),
            .next(415, "\(testClassId), 2, b"),
            .next(420, "\(testClassId), 3, c"),
            .next(425, "\(testClassId), 5, d"),
            .next(430, "\(testClassId), 8, e"),
            .completed(450)
        ]

        let res = await scheduler.start {
            await self.tupleValues
                .withUnretained(self.testClass) { ($0, $1.0, $1.1) }
                .map { "\($0.id), \($1), \($2)" }
        }

        XCTAssertEqual(res.events, correctValues)
    }
}

private class TestClass {
    let id: String = UUID().uuidString
}
