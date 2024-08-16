//
//  Observable+ThrottleTests.swift
//  Tests
//
//  Created by Krunoslav Zaher on 4/29/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

import XCTest
import RxSwift
import RxTest

import Foundation

class ObservableThrottleTest : RxTest {
}

extension ObservableThrottleTest {
    func test_ThrottleTimeSpan_NotLatest_Completed() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(150, 1),
            .next(210, 2),
            .next(250, 3),
            .next(310, 4),
            .next(350, 5),
            .next(410, 6),
            .next(450, 7),
            .completed(500)
            ])

        let res = await scheduler.start {
            await xs.throttle(.seconds(200), latest: false, scheduler: scheduler)
        }

        let correct = Recorded.events(
            .next(210, 2),
            .next(410, 6),
            .completed(500)
        )

        XCTAssertEqual(res.events, correct)

        let subscriptions = [
            Subscription(200, 500)
        ]

        XCTAssertEqual(xs.subscriptions, subscriptions)
    }

    func test_ThrottleTimeSpan_NotLatest_Never() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(150, 0),

            ])

        let res = await scheduler.start {
            await xs.throttle(.seconds(200), latest: false, scheduler: scheduler)
        }

        let correct: [Recorded<Event<Int>>] = [
        ]

        XCTAssertEqual(res.events, correct)

        let subscriptions = [
            Subscription(200, 1000)
        ]

        XCTAssertEqual(xs.subscriptions, subscriptions)
    }

    func test_ThrottleTimeSpan_NotLatest_Empty() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(150, 0),
            .completed(500)
            ])

        let res = await scheduler.start {
            await xs.throttle(.seconds(200), latest: false, scheduler: scheduler)
        }

        let correct = [
            Recorded.completed(500, Int.self)
        ]

        XCTAssertEqual(res.events, correct)

        let subscriptions = [
            Subscription(200, 500)
        ]

        XCTAssertEqual(xs.subscriptions, subscriptions)
    }

    func test_ThrottleTimeSpan_NotLatest_Error() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(150, 1),
            .next(210, 2),
            .next(250, 3),
            .next(310, 4),
            .next(350, 5),
            .error(410, testError),
            .next(450, 7),
            .completed(500)
            ])

        let res = await scheduler.start {
            await xs.throttle(.seconds(200), latest: false, scheduler: scheduler)
        }

        let correct = Recorded.events(
            .next(210, 2),
            .error(410, testError)
        )

        XCTAssertEqual(res.events, correct)

        let subscriptions = [
            Subscription(200, 410)
        ]

        XCTAssertEqual(xs.subscriptions, subscriptions)
    }

    func test_ThrottleTimeSpan_NotLatest_NoEnd() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(150, 1),
            .next(210, 2),
            .next(250, 3),
            .next(310, 4),
            .next(350, 5),
            .next(410, 6),
            .next(450, 7),
            ])

        let res = await scheduler.start {
            await xs.throttle(.seconds(200), latest: false, scheduler: scheduler)
        }

        let correct = Recorded.events(
            .next(210, 2),
            .next(410, 6)
        )

        XCTAssertEqual(res.events, correct)

        let subscriptions = [
            Subscription(200, 1000)
        ]

        XCTAssertEqual(xs.subscriptions, subscriptions)
    }

    func test_ThrottleTimeSpan_NotLatest_WithRealScheduler() async {
        #if !os(Linux)
        let scheduler = ConcurrentDispatchQueueScheduler(qos: .default)

        let start = Date()

        let a = try! await Observable.from([0, 1])
            .throttle(.seconds(2), latest: false, scheduler: scheduler)
            .toBlocking()
            .toArray()

        let end = Date()

        XCTAssertEqual(0.0, end.timeIntervalSince(start), accuracy: 0.5)
        XCTAssertEqual(a, [0])
        #endif
    }

    #if TRACE_RESOURCES
    func testThrottleNotLatestReleasesResourcesOnComplete() async {
        let scheduler = await TestScheduler(initialClock: 0)
        _ = await Observable<Int>.just(1).throttle(.seconds(0), latest: false, scheduler: scheduler).subscribe()
        await scheduler.start()
        }

    func testThrottleNotLatestReleasesResourcesOnError() async {
        let scheduler = await TestScheduler(initialClock: 0)
        _ = await Observable<Int>.error(testError).throttle(.seconds(0), latest: false, scheduler: scheduler).subscribe()
        await scheduler.start()
        }
    #endif
}

// MARK: Throttle
extension ObservableThrottleTest {

    func test_ThrottleTimeSpan_Completed() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(150, 1),
            .next(210, 2),
            .next(250, 3),
            .next(310, 4),
            .next(350, 5),
            .next(410, 6),
            .next(450, 7),
            .completed(500)
            ])

        let res = await scheduler.start {
            await xs.throttle(.seconds(200), scheduler: scheduler)
        }

        let correct = Recorded.events(
            .next(210, 2),
            .next(410, 6),
            .next(610, 7),
            .completed(610)
        )

        XCTAssertEqual(res.events, correct)

        let subscriptions = [
            Subscription(200, 500)
        ]

        XCTAssertEqual(xs.subscriptions, subscriptions)
    }

    func test_ThrottleTimeSpan_CompletedAfterDueTime() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(150, 1),
            .next(210, 2),
            .next(250, 3),
            .next(310, 4),
            .next(350, 5),
            .next(410, 6),
            .next(450, 7),
            .completed(900)
            ])

        let res = await scheduler.start {
            await xs.throttle(.seconds(200), scheduler: scheduler)
        }

        let correct = Recorded.events(
            .next(210, 2),
            .next(410, 6),
            .next(610, 7),
            .completed(900)
        )

        XCTAssertEqual(res.events, correct)

        let subscriptions = [
            Subscription(200, 900)
        ]

        XCTAssertEqual(xs.subscriptions, subscriptions)
    }

    func test_ThrottleTimeSpan_Never() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(150, 0),

            ])

        let res = await scheduler.start {
            await xs.throttle(.seconds(200), scheduler: scheduler)
        }

        let correct: [Recorded<Event<Int>>] = [
        ]

        XCTAssertEqual(res.events, correct)

        let subscriptions = [
            Subscription(200, 1000)
        ]

        XCTAssertEqual(xs.subscriptions, subscriptions)
    }

    func test_ThrottleTimeSpan_Empty() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(150, 0),
            .completed(500)
            ])

        let res = await scheduler.start {
            await xs.throttle(.seconds(200), scheduler: scheduler)
        }

        let correct = [
            Recorded.completed(500, Int.self)
        ]

        XCTAssertEqual(res.events, correct)

        let subscriptions = [
            Subscription(200, 500)
        ]

        XCTAssertEqual(xs.subscriptions, subscriptions)
    }

    func test_ThrottleTimeSpan_Error() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(150, 1),
            .next(210, 2),
            .next(250, 3),
            .next(310, 4),
            .next(350, 5),
            .error(410, testError),
            .next(450, 7),
            .completed(500)
            ])

        let res = await scheduler.start {
            await xs.throttle(.seconds(200), scheduler: scheduler)
        }

        let correct = Recorded.events(
            .next(210, 2),
            .error(410, testError)
        )

        XCTAssertEqual(res.events, correct)

        let subscriptions = [
            Subscription(200, 410)
        ]

        XCTAssertEqual(xs.subscriptions, subscriptions)
    }

    func test_ThrottleTimeSpan_NoEnd() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(150, 1),
            .next(210, 2),
            .next(250, 3),
            .next(310, 4),
            .next(350, 5),
            .next(410, 6),
            .next(450, 7),
            ])

        let res = await scheduler.start {
            await xs.throttle(.seconds(200), scheduler: scheduler)
        }

        let correct = Recorded.events(
            .next(210, 2),
            .next(410, 6),
            .next(610, 7)
        )
        
        XCTAssertEqual(res.events, correct)
        
        let subscriptions = [
            Subscription(200, 1000)
        ]
        
        XCTAssertEqual(xs.subscriptions, subscriptions)
    }
    
    func test_ThrottleTimeSpan_WithRealScheduler_seconds() async {
        let scheduler = ConcurrentDispatchQueueScheduler(qos: .default)

        let start = Date()

        let a = try! await Observable.from([0, 1])
            .throttle(.seconds(2), scheduler: scheduler)
            .toBlocking()
            .toArray()

        let end = Date()

        XCTAssertEqual(2, end.timeIntervalSince(start), accuracy: 0.5)
        XCTAssertEqual(a, [0, 1])
    }
    
    func test_ThrottleTimeSpan_WithRealScheduler_milliseconds() async {
        let scheduler = ConcurrentDispatchQueueScheduler(qos: .default)
        
        let start = Date()
        
        let a = try! await Observable.from([0, 1])
            .throttle(.milliseconds(2_000), scheduler: scheduler)
            .toBlocking()
            .toArray()
        
        let end = Date()
        
        XCTAssertEqual(2, end.timeIntervalSince(start), accuracy: 0.5)
        XCTAssertEqual(a, [0, 1])
    }
    
    func test_ThrottleTimeSpan_WithRealScheduler_microseconds() async {
        let scheduler = ConcurrentDispatchQueueScheduler(qos: .default)
        
        let start = Date()
        
        let a = try! await Observable.from([0, 1])
            .throttle(.microseconds(2_000_000), scheduler: scheduler)
            .toBlocking()
            .toArray()
        
        let end = Date()
        
        XCTAssertEqual(2, end.timeIntervalSince(start), accuracy: 0.5)
        XCTAssertEqual(a, [0, 1])
    }
    
    func test_ThrottleTimeSpan_WithRealScheduler_nanoseconds() async {
        let scheduler = ConcurrentDispatchQueueScheduler(qos: .default)
        
        let start = Date()
        
        let a = try! await Observable.from([0, 1])
            .throttle(.nanoseconds(2_000_000_000), scheduler: scheduler)
            .toBlocking()
            .toArray()
        
        let end = Date()
        
        XCTAssertEqual(2, end.timeIntervalSince(start), accuracy: 0.5)
        XCTAssertEqual(a, [0, 1])
    }

    #if TRACE_RESOURCES
    func testThrottleLatestReleasesResourcesOnComplete() async {
        let scheduler = await TestScheduler(initialClock: 0)
        _ = await Observable<Int>.just(1).throttle(.seconds(0), latest: true, scheduler: scheduler).subscribe()
        await scheduler.start()
        }

    func testThrottleLatestReleasesResourcesOnError() async {
        let scheduler = await TestScheduler(initialClock: 0)
        _ = await Observable<Int>.error(testError).throttle(.seconds(0), latest: true, scheduler: scheduler).subscribe()
        await scheduler.start()
        }
    #endif
}
