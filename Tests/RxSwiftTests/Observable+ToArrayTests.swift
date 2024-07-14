//
//  Observable+ToArrayTests.swift
//  Tests
//
//  Created by Krunoslav Zaher on 4/29/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

import XCTest
import RxSwift
import RxTest

class ObservableToArrayTest : RxTest {

}

extension ObservableToArrayTest {

    func test_ToArrayWithSingleItem_Return() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs: TestableObservable<Int> = await scheduler.createColdObservable([
            .next(10, 1),
            .completed(20)
            ])

        let res = await scheduler.start {
            return await xs.toArray().map { EquatableArray($0) }
        }

        let correctMessages = Recorded.events(
            .next(220, EquatableArray([1])),
            .completed(220)
        )

        let correctSubscriptions = [
            Subscription(200, 220)
        ]

        XCTAssertEqual(res.events, correctMessages)
        XCTAssertEqual(xs.subscriptions, correctSubscriptions)
    }

    func test_ToArrayWithMultipleItems_Return() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs: TestableObservable<Int> = await scheduler.createColdObservable([
            .next(10, 1),
            .next(20, 2),
            .next(30, 3),
            .next(40, 4),
            .completed(50)
            ])

        let res = await scheduler.start {
            return await xs.toArray().map { EquatableArray($0) }
        }

        let correctMessages = Recorded.events(
            .next(250, EquatableArray([1,2,3,4])),
            .completed(250)
        )

        let correctSubscriptions = [
            Subscription(200, 250)
        ]

        XCTAssertEqual(res.events, correctMessages)
        XCTAssertEqual(xs.subscriptions, correctSubscriptions)
    }

    func test_ToArrayWithNoItems_Empty() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs: TestableObservable<Int> = await scheduler.createColdObservable([
            .completed(50)
            ])

        let res = await scheduler.start {
            return await xs.toArray().map { EquatableArray($0) }
        }

        let correctMessages = Recorded.events(
            .next(250, EquatableArray([Int]())),
            .completed(250)
        )

        let correctSubscriptions = [
            Subscription(200, 250)
        ]

        XCTAssertEqual(res.events, correctMessages)
        XCTAssertEqual(xs.subscriptions, correctSubscriptions)
    }

    func test_ToArrayWithSingleItem_Never() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(150, 1)
            ])

        let res = await scheduler.start {
            return await xs.toArray().map { EquatableArray($0) }
        }

        let correctMessages: [Recorded<Event<EquatableArray<Int>>>] = [
        ]

        let correctSubscriptions = [
            Subscription(200, 1000)
        ]

        XCTAssertEqual(res.events, correctMessages)
        XCTAssertEqual(xs.subscriptions, correctSubscriptions)
    }

    func test_ToArrayWithImmediateError_Throw() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs: TestableObservable<Int> = await scheduler.createColdObservable([
            .error(10, testError)
            ])

        let res = await scheduler.start {
            return await xs.toArray().map { EquatableArray($0) }
        }

        let correctMessages = [
            Recorded.error(210, testError, EquatableArray<Int>.self)
        ]

        let correctSubscriptions = [
            Subscription(200, 210)
        ]

        XCTAssertEqual(res.events, correctMessages)
        XCTAssertEqual(xs.subscriptions, correctSubscriptions)
    }

    func test_ToArrayWithMultipleItems_Throw() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs: TestableObservable<Int> = await scheduler.createColdObservable([
            .next(10, 1),
            .next(20, 2),
            .next(30, 3),
            .next(40, 4),
            .error(50, testError)
            ])

        let res = await scheduler.start {
            return await xs.toArray().map { EquatableArray($0) }
        }

        let correctMessages = [
            Recorded.error(250, testError, EquatableArray<Int>.self)
        ]

        let correctSubscriptions = [
            Subscription(200, 250)
        ]

        XCTAssertEqual(res.events, correctMessages)
        XCTAssertEqual(xs.subscriptions, correctSubscriptions)
    }

    #if TRACE_RESOURCES
    func testToArrayReleasesResourcesOnComplete() async {
        _ = await Observable<Int>.just(1).toArray().subscribe()
        }

    func testToArrayReleasesResourcesOnError() async {
        _ = await Observable<Int>.just(1).toArray().subscribe()
        }
    #endif

}
