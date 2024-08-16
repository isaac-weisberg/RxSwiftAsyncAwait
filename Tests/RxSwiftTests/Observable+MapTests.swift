//
//  Observable+MapTests.swift
//  Tests
//
//  Created by Krunoslav Zaher on 4/29/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

import XCTest
import RxSwift
import RxTest

class ObservableMapTest : RxTest {
}

extension ObservableMapTest {
    func testMap_Never() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let xs = await scheduler.createHotObservable([
            .next(150, 1),
            ])
        
        let res = await scheduler.start { await xs.map { $0 * 2 } }
        
        let correctMessages: [Recorded<Event<Int>>] = [
        ]
        
        let correctSubscriptions = [
            Subscription(200, 1000)
        ]
        
        XCTAssertEqual(res.events, correctMessages)
        XCTAssertEqual(xs.subscriptions, correctSubscriptions)
    }
    
    func testMap_Empty() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let xs = await scheduler.createHotObservable([
            .next(150, 1),
            .completed(300)
            ])
        
        let res = await scheduler.start { await xs.map { $0 * 2 } }
        
        let correctMessages = [
            Recorded.completed(300, Int.self)
        ]
        
        let correctSubscriptions = [
            Subscription(200, 300)
        ]
        
        XCTAssertEqual(res.events, correctMessages)
        XCTAssertEqual(xs.subscriptions, correctSubscriptions)
    }
    
    func testMap_Range() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let xs = await scheduler.createHotObservable([
            .next(150, 1),
            .next(210, 0),
            .next(220, 1),
            .next(230, 2),
            .next(240, 4),
            .completed(300)
            ])
        
        let res = await scheduler.start { await xs.map { $0 * 2 } }
        
        let correctMessages = Recorded.events(
            .next(210, 0 * 2),
            .next(220, 1 * 2),
            .next(230, 2 * 2),
            .next(240, 4 * 2),
            .completed(300)
        )
        
        let correctSubscriptions = [
            Subscription(200, 300)
        ]
        
        XCTAssertEqual(res.events, correctMessages)
        XCTAssertEqual(xs.subscriptions, correctSubscriptions)
    }
    
    func testMap_Error() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let xs = await scheduler.createHotObservable([
            .next(150, 1),
            .next(210, 0),
            .next(220, 1),
            .next(230, 2),
            .next(240, 4),
            .error(300, testError)
            ])
        
        let res = await scheduler.start { await xs.map { $0 * 2 } }
        
        let correctMessages = Recorded.events(
            .next(210, 0 * 2),
            .next(220, 1 * 2),
            .next(230, 2 * 2),
            .next(240, 4 * 2),
            .error(300, testError)
        )
        
        let correctSubscriptions = [
            Subscription(200, 300)
        ]
        
        XCTAssertEqual(res.events, correctMessages)
        XCTAssertEqual(xs.subscriptions, correctSubscriptions)
    }
    
    func testMap_Dispose() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let xs = await scheduler.createHotObservable([
            .next(150, 1),
            .next(210, 0),
            .next(220, 1),
            .next(230, 2),
            .next(240, 4),
            .error(300, testError)
            ])
        
        let res = await scheduler.start(disposed: 290) { await xs.map { $0 * 2 } }
        
        let correctMessages = Recorded.events(
            .next(210, 0 * 2),
            .next(220, 1 * 2),
            .next(230, 2 * 2),
            .next(240, 4 * 2)
        )
        
        let correctSubscriptions = [
            Subscription(200, 290)
        ]
        
        XCTAssertEqual(res.events, correctMessages)
        XCTAssertEqual(xs.subscriptions, correctSubscriptions)
    }
    
    func testMap_SelectorThrows() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let xs = await scheduler.createHotObservable([
            .next(150, 1),
            .next(210, 0),
            .next(220, 1),
            .next(230, 2),
            .next(240, 4),
            .error(300, testError)
            ])
        
        let res = await scheduler.start { await xs.map { x throws -> Int in if x < 2 { return x * 2 } else { throw testError } } }
        
        let correctMessages = Recorded.events(
            .next(210, 0 * 2),
            .next(220, 1 * 2),
            .error(230, testError)
        )
        
        let correctSubscriptions = [
            Subscription(200, 230)
        ]
        
        XCTAssertEqual(res.events, correctMessages)
        XCTAssertEqual(xs.subscriptions, correctSubscriptions)
    }

    #if TRACE_RESOURCES
    func testMapReleasesResourcesOnComplete() async {
        _ = await Observable<Int>.just(1).map { _ in true }.subscribe()
        }

    func testMap1ReleasesResourcesOnError() async {
        _ = await Observable<Int>.error(testError).map { _ in true }.subscribe()
        }

    func testMap2ReleasesResourcesOnError() async {
        _ = await Observable<Int>.just(1).map { _ -> Bool in throw testError }.subscribe()
        }
    #endif
}

// MARK: map compose
extension ObservableMapTest {
    func testMapCompose_Never() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(150, 1),
            ])

        let res = await scheduler.start { await xs.map { $0 * 10 }.map { $0 + 1 } }

        let correctMessages: [Recorded<Event<Int>>] = [
        ]

        let correctSubscriptions = [
            Subscription(200, 1000)
        ]

        XCTAssertEqual(res.events, correctMessages)
        XCTAssertEqual(xs.subscriptions, correctSubscriptions)
    }

    func testMapCompose_Empty() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(150, 1),
            .completed(300)
            ])

        let res = await scheduler.start { await xs.map { $0 * 10 }.map { $0 + 1 } }

        let correctMessages = [
            Recorded.completed(300, Int.self)
        ]

        let correctSubscriptions = [
            Subscription(200, 300)
        ]

        XCTAssertEqual(res.events, correctMessages)
        XCTAssertEqual(xs.subscriptions, correctSubscriptions)
    }

    func testMapCompose_Range() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(150, 1),
            .next(210, 0),
            .next(220, 1),
            .next(230, 2),
            .next(240, 4),
            .completed(300)
            ])

        let res = await scheduler.start { await xs.map { $0 * 10 }.map { $0 + 1 } }

        let correctMessages = Recorded.events(
            .next(210, 0 * 10 + 1),
            .next(220, 1 * 10 + 1),
            .next(230, 2 * 10 + 1),
            .next(240, 4 * 10 + 1),
            .completed(300)
        )

        let correctSubscriptions = [
            Subscription(200, 300)
        ]

        XCTAssertEqual(res.events, correctMessages)
        XCTAssertEqual(xs.subscriptions, correctSubscriptions)
    }

    func testMapCompose_Error() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(150, 1),
            .next(210, 0),
            .next(220, 1),
            .next(230, 2),
            .next(240, 4),
            .error(300, testError)
            ])

        let res = await scheduler.start { await xs.map { $0 * 10 }.map { $0 + 1 } }

        let correctMessages = Recorded.events(
            .next(210, 0 * 10 + 1),
            .next(220, 1 * 10 + 1),
            .next(230, 2 * 10 + 1),
            .next(240, 4 * 10 + 1),
            .error(300, testError)
        )

        let correctSubscriptions = [
            Subscription(200, 300)
        ]

        XCTAssertEqual(res.events, correctMessages)
        XCTAssertEqual(xs.subscriptions, correctSubscriptions)
    }

    func testMapCompose_Dispose() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(150, 1),
            .next(210, 0),
            .next(220, 1),
            .next(230, 2),
            .next(240, 4),
            .error(300, testError)
            ])

        let res = await scheduler.start(disposed: 290) { await xs.map { $0 * 10 }.map { $0 + 1 } }

        let correctMessages = Recorded.events(
            .next(210, 0 * 10 + 1),
            .next(220, 1 * 10 + 1),
            .next(230, 2 * 10 + 1),
            .next(240, 4 * 10 + 1)
        )

        let correctSubscriptions = [
            Subscription(200, 290)
        ]

        XCTAssertEqual(res.events, correctMessages)
        XCTAssertEqual(xs.subscriptions, correctSubscriptions)
    }

    func testMapCompose_Selector1Throws() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(150, 1),
            .next(210, 0),
            .next(220, 1),
            .next(230, 2),
            .next(240, 4),
            .error(300, testError)
            ])

        let res = await scheduler.start {
            await xs
            .map { x throws -> Int in if x < 2 { return x * 10 } else { throw testError } }
            .map { $0 + 1 }
        }

        let correctMessages = Recorded.events(
            .next(210, 0 * 10 + 1),
            .next(220, 1 * 10 + 1),
            .error(230, testError)
        )

        let correctSubscriptions = [
            Subscription(200, 230)
        ]

        XCTAssertEqual(res.events, correctMessages)
        XCTAssertEqual(xs.subscriptions, correctSubscriptions)
    }

    func testMapCompose_Selector2Throws() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(150, 1),
            .next(210, 0),
            .next(220, 1),
            .next(230, 2),
            .next(240, 4),
            .error(300, testError)
            ])

        let res = await scheduler.start {
            await xs
                .map { $0 * 10 }
                .map { x throws -> Int in if x < 20 { return x + 1 } else { throw testError } }
        }

        let correctMessages = Recorded.events(
            .next(210, 0 * 10 + 1),
            .next(220, 1 * 10 + 1),
            .error(230, testError)
        )

        let correctSubscriptions = [
            Subscription(200, 230)
        ]

        XCTAssertEqual(res.events, correctMessages)
        XCTAssertEqual(xs.subscriptions, correctSubscriptions)
    }
}
