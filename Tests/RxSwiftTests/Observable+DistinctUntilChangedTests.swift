//
//  Observable+DistinctUntilChangedTests.swift
//  Tests
//
//  Created by Krunoslav Zaher on 4/29/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

import XCTest
import RxSwift
import RxTest

class ObservableDistinctUntilChangedTest : RxTest {
}

extension ObservableDistinctUntilChangedTest {
    func testDistinctUntilChanged_allChanges() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(150, 1),
            .next(210, 2),
            .next(220, 3),
            .next(230, 4),
            .next(240, 5),
            .completed(250)
        ])

        let res = await scheduler.start { await xs.distinctUntilChanged { $0 } }

        let correctMessages = Recorded.events(
            .next(210, 2),
            .next(220, 3),
            .next(230, 4),
            .next(240, 5),
            .completed(250)
        )

        let correctSubscriptions = [
            Subscription(200, 250)
        ]

        XCTAssertEqual(res.events, correctMessages)
        XCTAssertEqual(xs.subscriptions, correctSubscriptions)
    }

    func testDistinctUntilChanged_someChanges() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(150, 1),
            .next(210, 2), // *
            .next(215, 3), // *
            .next(220, 3),
            .next(225, 2), // *
            .next(230, 2),
            .next(230, 1), // *
            .next(240, 2), // *
            .completed(250)
            ])


        let res = await scheduler.start { await xs.distinctUntilChanged { $0 } }

        let correctMessages = Recorded.events(
            .next(210, 2),
            .next(215, 3),
            .next(225, 2),
            .next(230, 1),
            .next(240, 2),
            .completed(250)
        )

        let correctSubscriptions = [
            Subscription(200, 250)
        ]

        XCTAssertEqual(res.events, correctMessages)
        XCTAssertEqual(xs.subscriptions, correctSubscriptions)
    }

    func testDistinctUntilChanged_allEqual() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(150, 1),
            .next(210, 2),
            .next(220, 3),
            .next(230, 4),
            .next(240, 5),
            .completed(250)
            ])

        let res = await scheduler.start { await xs.distinctUntilChanged { _, _ in true } }

        let correctMessages = Recorded.events(
            .next(210, 2),
            .completed(250)
        )

        let correctSubscriptions = [
            Subscription(200, 250)
        ]

        XCTAssertEqual(res.events, correctMessages)
        XCTAssertEqual(xs.subscriptions, correctSubscriptions)
    }

    func testDistinctUntilChanged_allDifferent() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(150, 1),
            .next(210, 2),
            .next(220, 2),
            .next(230, 2),
            .next(240, 2),
            .completed(250)
            ])

        let res = await scheduler.start { await xs.distinctUntilChanged { _, _ in false } }

        let correctMessages = Recorded.events(
            .next(210, 2),
            .next(220, 2),
            .next(230, 2),
            .next(240, 2),
            .completed(250)
        )

        let correctSubscriptions = [
            Subscription(200, 250)
        ]

        XCTAssertEqual(res.events, correctMessages)
        XCTAssertEqual(xs.subscriptions, correctSubscriptions)
    }

    func testDistinctUntilChanged_keySelector_Div2() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(150, 1),
            .next(210, 2),
            .next(220, 4),
            .next(230, 3),
            .next(240, 5),
            .completed(250)
            ])

        let res = await scheduler.start { await xs.distinctUntilChanged({ $0 % 2 }) }

        let correctMessages = Recorded.events(
            .next(210, 2),
            .next(230, 3),
            .completed(250)
        )

        let correctSubscriptions = [
            Subscription(200, 250)
        ]

        XCTAssertEqual(res.events, correctMessages)
        XCTAssertEqual(xs.subscriptions, correctSubscriptions)
    }

    func testDistinctUntilChanged_keySelectorThrows() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(150, 1),
            .next(210, 2),
            .next(220, 3),
            .completed(250)
            ])

        let res = await scheduler.start { await xs.distinctUntilChanged { _, _ -> Bool in throw testError } }

        let correctMessages = Recorded.events(
            .next(210, 2),
            .error(220, testError)
        )

        let correctSubscriptions = [
            Subscription(200, 220)
        ]

        XCTAssertEqual(res.events, correctMessages)
        XCTAssertEqual(xs.subscriptions, correctSubscriptions)
    }

    func testDistinctUntilChangedKeyPath_allChanges() async {
        let scheduler = await TestScheduler(initialClock: 0)

        struct TestObject: Equatable {
            let value: Int
            let other = ""
        }

        let xs = await scheduler.createHotObservable([
            .next(150, TestObject(value: 1)),
            .next(210, TestObject(value: 2)),
            .next(220, TestObject(value: 3)),
            .next(230, TestObject(value: 4)),
            .next(240, TestObject(value: 5)),
            .completed(250)
        ])

        let res = await scheduler.start { await xs.distinctUntilChanged(at: \.value) }

        let correctMessages = Recorded.events(
            .next(210, TestObject(value: 2)),
            .next(220, TestObject(value: 3)),
            .next(230, TestObject(value: 4)),
            .next(240, TestObject(value: 5)),
            .completed(250)
        )

        let correctSubscriptions = [
            Subscription(200, 250)
        ]

        XCTAssertEqual(res.events, correctMessages)
        XCTAssertEqual(xs.subscriptions, correctSubscriptions)
    }

    func testDistinctUntilChanged_comparerThrows() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(150, 1),
            .next(210, 2),
            .next(220, 3),
            .completed(250)
            ])

        let res = await scheduler.start { await xs.distinctUntilChanged({ $0 }, comparer: { _, _ in throw testError }) }

        let correctMessages = Recorded.events(
            .next(210, 2),
            .error(220, testError)
        )

        let correctSubscriptions = [
            Subscription(200, 220)
        ]

        XCTAssertEqual(res.events, correctMessages)
        XCTAssertEqual(xs.subscriptions, correctSubscriptions)
    }

    #if TRACE_RESOURCES
    func testDistinctUntilChangedReleasesResourcesOnComplete() async {
        _ = await Observable<Int>.just(1).distinctUntilChanged().subscribe()
        }

    func testDistinctUntilChangedReleasesResourcesOnError() async {
        _ = await Observable<Int>.error(testError).distinctUntilChanged().subscribe()
        }
    #endif
}
