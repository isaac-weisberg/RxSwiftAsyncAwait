//
//  Observable+SkipTests.swift
//  Tests
//
//  Created by Krunoslav Zaher on 4/29/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

import XCTest
import RxSwift
import RxTest

class ObservableSkipTest : RxTest {
}

extension ObservableSkipTest {
    func testSkip_Complete_After() async {
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
            await xs.skip(20)
        }
        
        XCTAssertEqual(res.events, [
            .completed(690)
        ])
        
        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 690)
        ])
    }
    
    
    func testSkip_Complete_Some() async {
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
            await xs.skip(17)
        }
        
        XCTAssertEqual(res.events, [
            .completed(690)
            ])
        
        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 690)
            ])
    }
    
    func testSkip_Complete_Before() async {
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
            await xs.skip(10)
        }
        
        XCTAssertEqual(res.events, [
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
    
    func testSkip_Complete_Zero() async {
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
            await xs.skip(0)
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
    
    func testSkip_Error_After() async {
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
            await xs.skip(20)
        }
        
        XCTAssertEqual(res.events, [
            .error(690, testError)
            ])
        
        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 690)
            ])
    }
    
    func testSkip_Error_Same() async {
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
            await xs.skip(17)
        }
        
        XCTAssertEqual(res.events, [
            .error(690, testError)
            ])
        
        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 690)
            ])
    }
    
    func testSkip_Error_Before() async {
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
            await xs.skip(3)
        }
        
        XCTAssertEqual(res.events, [
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
    
    func testSkip_Dispose_Before() async {
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
            ])
        
        let res = await scheduler.start(disposed: 250) {
            await xs.skip(3)
        }
        
        XCTAssertEqual(res.events, [
            ])
        
        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 250)
            ])
    }
    
    func testSkip_Dispose_After() async {
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
            ])
        
        let res = await scheduler.start(disposed: 400) {
            await xs.skip(3)
        }
        
        XCTAssertEqual(res.events, [
            .next(280, 1),
            .next(300, -1),
            .next(310, 3),
            .next(340, 8),
            .next(370, 11),
            ])
        
        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 400)
            ])
    }

    #if TRACE_RESOURCES
    func testSkipReleasesResourcesOnComplete() async {
        _ = await Observable<Int>.just(1).skip(1).subscribe()
        }

    func testSkipReleasesResourcesOnError() async {
        _ = await Observable<Int>.error(testError).skip(1).subscribe()
        }
    #endif
}


extension ObservableSkipTest {
    func testSkip_Zero() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(210, 1),
            .next(220, 2),
            .completed(230)
        ])

        let res = await scheduler.start {
            await xs.skip(.seconds(0), scheduler: scheduler)
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

    func testSkip_Some() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(210, 1),
            .next(220, 2),
            .completed(230)
            ])

        let res = await scheduler.start {
            await xs.skip(.seconds(15), scheduler: scheduler)
        }

        XCTAssertEqual(res.events, [
            .next(220, 2),
            .completed(230)
            ])

        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 230)
            ])
    }

    func testSkip_Late() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(210, 1),
            .next(220, 2),
            .completed(230)
            ])

        let res = await scheduler.start {
            await xs.skip(.seconds(50), scheduler: scheduler)
        }

        XCTAssertEqual(res.events, [
            .completed(230)
            ])

        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 230)
            ])
    }

    func testSkip_Error() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs: TestableObservable<Int> = await scheduler.createHotObservable([
            .error(210, testError)
            ])

        let res = await scheduler.start {
            await xs.skip(.seconds(50), scheduler: scheduler)
        }

        XCTAssertEqual(res.events, [
            .error(210, testError)
            ])

        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 210)
            ])
    }

    func testSkip_Never() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs: TestableObservable<Int> = await scheduler.createHotObservable([
            ])

        let res = await scheduler.start {
            await xs.skip(.seconds(50), scheduler: scheduler)
        }

        XCTAssertEqual(res.events, [
            ])

        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 1000)
            ])
    }

    #if TRACE_RESOURCES
    func testSkipTimeReleasesResourcesOnComplete() async {
        let scheduler = await TestScheduler(initialClock: 0)
        _ = await Observable<Int>.just(1).skip(.seconds(35), scheduler: scheduler).subscribe()
        await scheduler.start()
        }

    func testSkipTimeReleasesResourcesOnError() async {
        let scheduler = await TestScheduler(initialClock: 0)
        _ = await Observable<Int>.error(testError).skip(.seconds(35), scheduler: scheduler).subscribe()
        await scheduler.start()
        }
    #endif
}
