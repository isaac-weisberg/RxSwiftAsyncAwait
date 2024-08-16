//
//  Observable+TakeTests.swift
//  Tests
//
//  Created by Krunoslav Zaher on 4/29/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

import XCTest
import RxSwift
import RxTest

class ObservableTakeTest : RxTest {
}

extension ObservableTakeTest {
    func testTake_Complete_After() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let xs = await scheduler.createHotObservable([
            .next(70, 6),
            .next(150, 4),
            .next(210, 9),
            .next(230, 13),
            .next(270, 7),
            .next(280, 1),
            .next(300, -1),
            .next(310, 3),
            .next(340, 8),
            .next(370, 11),
            .next(410, 15),
            .next(415, 16),
            .next(460, 72),
            .next(510, 76),
            .next(560, 32),
            .next(570, -100),
            .next(580, -3),
            .next(590, 5),
            .next(630, 10),
            .completed(690)
            ])
        
        let res = await scheduler.start {
            await xs.take(20)
        }
        
        XCTAssertEqual(res.events, [
            .next(210, 9),
            .next(230, 13),
            .next(270, 7),
            .next(280, 1),
            .next(300, -1),
            .next(310, 3),
            .next(340, 8),
            .next(370, 11),
            .next(410, 15),
            .next(415, 16),
            .next(460, 72),
            .next(510, 76),
            .next(560, 32),
            .next(570, -100),
            .next(580, -3),
            .next(590, 5),
            .next(630, 10),
            .completed(690)
            ])
        
        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 690)
            ])
    }
    
    func testTake_Complete_Same() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let xs = await scheduler.createHotObservable([
            .next(70, 6),
            .next(150, 4),
            .next(210, 9),
            .next(230, 13),
            .next(270, 7),
            .next(280, 1),
            .next(300, -1),
            .next(310, 3),
            .next(340, 8),
            .next(370, 11),
            .next(410, 15),
            .next(415, 16),
            .next(460, 72),
            .next(510, 76),
            .next(560, 32),
            .next(570, -100),
            .next(580, -3),
            .next(590, 5),
            .next(630, 10),
            .completed(690)
            ])
        
        let res = await scheduler.start {
            await xs.take(17)
        }
        
        XCTAssertEqual(res.events, [
            .next(210, 9),
            .next(230, 13),
            .next(270, 7),
            .next(280, 1),
            .next(300, -1),
            .next(310, 3),
            .next(340, 8),
            .next(370, 11),
            .next(410, 15),
            .next(415, 16),
            .next(460, 72),
            .next(510, 76),
            .next(560, 32),
            .next(570, -100),
            .next(580, -3),
            .next(590, 5),
            .next(630, 10),
            .completed(630)
            ])
        
        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 630)
            ])
    }
    
    func testTake_Complete_Before() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let xs = await scheduler.createHotObservable([
            .next(70, 6),
            .next(150, 4),
            .next(210, 9),
            .next(230, 13),
            .next(270, 7),
            .next(280, 1),
            .next(300, -1),
            .next(310, 3),
            .next(340, 8),
            .next(370, 11),
            .next(410, 15),
            .next(415, 16),
            .next(460, 72),
            .next(510, 76),
            .next(560, 32),
            .next(570, -100),
            .next(580, -3),
            .next(590, 5),
            .next(630, 10),
            .completed(690)
            ])
        
        let res = await scheduler.start {
            await xs.take(10)
        }
        
        XCTAssertEqual(res.events, [
            .next(210, 9),
            .next(230, 13),
            .next(270, 7),
            .next(280, 1),
            .next(300, -1),
            .next(310, 3),
            .next(340, 8),
            .next(370, 11),
            .next(410, 15),
            .next(415, 16),
            .completed(415)
            ])
        
        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 415)
            ])
    }
    
    func testTake_Error_After() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let xs = await scheduler.createHotObservable([
            .next(70, 6),
            .next(150, 4),
            .next(210, 9),
            .next(230, 13),
            .next(270, 7),
            .next(280, 1),
            .next(300, -1),
            .next(310, 3),
            .next(340, 8),
            .next(370, 11),
            .next(410, 15),
            .next(415, 16),
            .next(460, 72),
            .next(510, 76),
            .next(560, 32),
            .next(570, -100),
            .next(580, -3),
            .next(590, 5),
            .next(630, 10),
            .error(690, testError)
            ])
        
        let res = await scheduler.start {
            await xs.take(20)
        }
        
        XCTAssertEqual(res.events, [
            .next(210, 9),
            .next(230, 13),
            .next(270, 7),
            .next(280, 1),
            .next(300, -1),
            .next(310, 3),
            .next(340, 8),
            .next(370, 11),
            .next(410, 15),
            .next(415, 16),
            .next(460, 72),
            .next(510, 76),
            .next(560, 32),
            .next(570, -100),
            .next(580, -3),
            .next(590, 5),
            .next(630, 10),
            .error(690, testError)
            ])
        
        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 690)
            ])
    }

    func testTake_Error_Same() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let xs = await scheduler.createHotObservable([
            .next(70, 6),
            .next(150, 4),
            .next(210, 9),
            .next(230, 13),
            .next(270, 7),
            .next(280, 1),
            .next(300, -1),
            .next(310, 3),
            .next(340, 8),
            .next(370, 11),
            .next(410, 15),
            .next(415, 16),
            .next(460, 72),
            .next(510, 76),
            .next(560, 32),
            .next(570, -100),
            .next(580, -3),
            .next(590, 5),
            .next(630, 10),
            .error(690, testError)
            ])
        
        let res = await scheduler.start {
            await xs.take(17)
        }
        
        XCTAssertEqual(res.events, [
            .next(210, 9),
            .next(230, 13),
            .next(270, 7),
            .next(280, 1),
            .next(300, -1),
            .next(310, 3),
            .next(340, 8),
            .next(370, 11),
            .next(410, 15),
            .next(415, 16),
            .next(460, 72),
            .next(510, 76),
            .next(560, 32),
            .next(570, -100),
            .next(580, -3),
            .next(590, 5),
            .next(630, 10),
            .completed(630)
            ])
        
        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 630)
            ])
    }
    
    func testTake_Error_Before() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let xs = await scheduler.createHotObservable([
            .next(70, 6),
            .next(150, 4),
            .next(210, 9),
            .next(230, 13),
            .next(270, 7),
            .next(280, 1),
            .next(300, -1),
            .next(310, 3),
            .next(340, 8),
            .next(370, 11),
            .next(410, 15),
            .next(415, 16),
            .next(460, 72),
            .next(510, 76),
            .next(560, 32),
            .next(570, -100),
            .next(580, -3),
            .next(590, 5),
            .next(630, 10),
            .error(690, testError)
            ])
        
        let res = await scheduler.start {
            await xs.take(3)
        }
        
        XCTAssertEqual(res.events, [
            .next(210, 9),
            .next(230, 13),
            .next(270, 7),
            .completed(270)
            ])
        
        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 270)
            ])
    }
    
    func testTake_Dispose_Before() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let xs = await scheduler.createHotObservable([
            .next(70, 6),
            .next(150, 4),
            .next(210, 9),
            .next(230, 13),
            .next(270, 7),
            .next(280, 1),
            .next(300, -1),
            .next(310, 3),
            .next(340, 8),
            .next(370, 11),
            .next(410, 15),
            .next(415, 16),
            .next(460, 72),
            .next(510, 76),
            .next(560, 32),
            .next(570, -100),
            .next(580, -3),
            .next(590, 5),
            .next(630, 10),
            .error(690, testError)
            ])
        
        let res = await scheduler.start(disposed: 250) {
            await xs.take(3)
        }
        
        XCTAssertEqual(res.events, [
            .next(210, 9),
            .next(230, 13),
            ])
        
        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 250)
            ])
    }
    
    func testTake_Dispose_After() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let xs = await scheduler.createHotObservable([
            .next(70, 6),
            .next(150, 4),
            .next(210, 9),
            .next(230, 13),
            .next(270, 7),
            .next(280, 1),
            .next(300, -1),
            .next(310, 3),
            .next(340, 8),
            .next(370, 11),
            .next(410, 15),
            .next(415, 16),
            .next(460, 72),
            .next(510, 76),
            .next(560, 32),
            .next(570, -100),
            .next(580, -3),
            .next(590, 5),
            .next(630, 10),
            .error(690, testError)
            ])
        
        let res = await scheduler.start(disposed: 400) {
            await xs.take(3)
        }
        
        XCTAssertEqual(res.events, [
            .next(210, 9),
            .next(230, 13),
            .next(270, 7),
            .completed(270)
            ])
        
        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 270)
            ])
    }
    
    func testTake_0_DefaultScheduler() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let xs = await scheduler.createHotObservable([
            .next(70, 6),
            .next(150, 4),
            .next(210, 9),
            .next(230, 13)
        ])
        
        let res = await scheduler.start {
            await xs.take(0)
        }
        
        XCTAssertEqual(res.events, [
            .completed(200)
        ])
        
        XCTAssertEqual(xs.subscriptions, [
        ])
    }
    
    func testTake_Take1() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let xs = await scheduler.createHotObservable([
            .next(70, 6),
            .next(150, 4),
            .next(210, 9),
            .next(230, 13),
            .next(270, 7),
            .next(280, 1),
            .next(300, -1),
            .next(310, 3),
            .next(340, 8),
            .next(370, 11),
            .completed(400)
            ])
        
        let res = await scheduler.start {
            await xs.take(3)
        }
        
        XCTAssertEqual(res.events, [
            .next(210, 9),
            .next(230, 13),
            .next(270, 7),
            .completed(270)
        ])
        
        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 270)
            ])
    }
    
    func testTake_DecrementCountsFirst() async {
        let k = await BehaviorSubject(value: false)
        
        _ = await k.take(1).subscribe(onNext: { n in
            await k.on(.next(!n))
        })
    }

    #if TRACE_RESOURCES
    func testTakeReleasesResourcesOnComplete() async {
        _ = await Observable<Int>.of(1, 2).take(1).subscribe()
        }

    func testTakeReleasesResourcesOnError() async {
        _ = await Observable<Int>.error(testError).take(1).subscribe()
        }
    #endif
}


extension ObservableTakeTest {

    func testTake_TakeZero() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(210, 1),
            .next(220, 2),
            .completed(230)
        ])

        let res = await scheduler.start {
            await xs.take(for: .seconds(0), scheduler: scheduler)
        }

        XCTAssertEqual(res.events, [
            .completed(201)
            ])

        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 201)
            ])
    }

    func testTake_Some() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(210, 1),
            .next(220, 2),
            .next(230, 3),
            .completed(240)
            ])

        let res = await scheduler.start {
            await xs.take(for: .seconds(25), scheduler: scheduler)
        }

        XCTAssertEqual(res.events, [
            .next(210, 1),
            .next(220, 2),
            .completed(225)
            ])

        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 225)
            ])
    }

    func testTake_TakeLate() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(210, 1),
            .next(220, 2),
            .completed(230),
            ])

        let res = await scheduler.start {
            await xs.take(for: .seconds(50), scheduler: scheduler)
        }

        XCTAssertEqual(res.events, [
            .next(210, 1),
            .next(220, 2),
            .completed(230)
            ])

        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 230)
            ])
    }

    func testTake_TakeError() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(0, 0),
            .error(210, testError)
            ])

        let res = await scheduler.start {
            await xs.take(for: .seconds(50), scheduler: scheduler)
        }

        XCTAssertEqual(res.events, [
            .error(210, testError),
            ])

        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 210)
            ])
    }

    func testTake_TakeNever() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(0, 0),
            ])

        let res = await scheduler.start {
            await xs.take(for: .seconds(50), scheduler: scheduler)
        }

        XCTAssertEqual(res.events, [
            .completed(250)
            ])

        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 250)
            ])
    }

    func testTake_TakeTwice1() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(210, 1),
            .next(220, 2),
            .next(230, 3),
            .next(240, 4),
            .next(250, 5),
            .next(260, 6),
            .completed(270)
            ])

        let res = await scheduler.start {
            await xs.take(for: .seconds(55), scheduler: scheduler).take(for: .seconds(35), scheduler: scheduler)
        }

        XCTAssertEqual(res.events, [
            .next(210, 1),
            .next(220, 2),
            .next(230, 3),
            .completed(235)
            ])

        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 235)
            ])
    }

    func testTake_TakeDefault() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(210, 1),
            .next(220, 2),
            .next(230, 3),
            .next(240, 4),
            .next(250, 5),
            .next(260, 6),
            .completed(270)
            ])

        let res = await scheduler.start {
            await xs.take(for: .seconds(35), scheduler: scheduler)
        }

        XCTAssertEqual(res.events, [
            .next(210, 1),
            .next(220, 2),
            .next(230, 3),
            .completed(235)
            ])

        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 235)
            ])
    }


    #if TRACE_RESOURCES
    func testTakeTimeReleasesResourcesOnComplete() async {
        let scheduler = await TestScheduler(initialClock: 0)
        _ = await Observable<Int>.just(1).take(for: .seconds(35), scheduler: scheduler).subscribe()
        await scheduler.start()
        }

    func testTakeTimeReleasesResourcesOnError() async {
        let scheduler = await TestScheduler(initialClock: 0)
        _ = await Observable<Int>.error(testError).take(for: .seconds(35), scheduler: scheduler).subscribe()
        await scheduler.start()
        }
    #endif
}
