//
//  Observable+TimeoutTests.swift
//  Tests
//
//  Created by Krunoslav Zaher on 4/29/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

import XCTest
import RxSwift
import RxTest

class ObservableTimeoutTest : RxTest {
}

extension ObservableTimeoutTest {
    func testTimeout_Empty() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let xs = await scheduler.createHotObservable([
            .next(150, 0),
            .completed(300)
            ])
        
        let res = await scheduler.start {
            await xs.timeout(.seconds(200), scheduler: scheduler)
        }
        
        XCTAssertEqual(res.events, [
            .completed(300)
            ])
        
        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 300)
            ])
    }
    
    func testTimeout_Error() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let xs = await scheduler.createHotObservable([
            .next(150, 0),
            .error(300, testError)
            ])
        
        let res = await scheduler.start {
            await xs.timeout(.seconds(200), scheduler: scheduler)
        }
        
        XCTAssertEqual(res.events, [
            .error(300, testError)
            ])
        
        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 300)
            ])
    }
    
    func testTimeout_Never() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let xs = await scheduler.createHotObservable([
            .next(150, 0),
            ])
        
        let res = await scheduler.start {
            await xs.timeout(.seconds(1000), scheduler: scheduler)
        }
        
        XCTAssertEqual(res.events, [])
        
        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 1000)
            ])
    }
    
    func testTimeout_Duetime_Simple() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let xs = await scheduler.createColdObservable([
            .next(10, 42),
            .next(25, 43),
            .next(40, 44),
            .next(50, 45),
            .completed(60)
            ])
        
        let res = await scheduler.start {
            await xs.timeout(.seconds(30), scheduler: scheduler)
        }
        
        XCTAssertEqual(res.events, [
            .next(210, 42),
            .next(225, 43),
            .next(240, 44),
            .next(250, 45),
            .completed(260)
            ])
        
        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 260)
            ])
    }
    
    func testTimeout_Duetime_Timeout_Exact() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let xs = await scheduler.createColdObservable([
            .next(10, 42),
            .next(20, 43),
            .next(50, 44),
            .next(60, 45),
            .completed(70)
            ])
        
        let res = await scheduler.start {
            await xs.timeout(.seconds(30), scheduler: scheduler)
        }
        
        XCTAssertEqual(res.events, [
            .next(210, 42),
            .next(220, 43),
            .next(250, 44),
            .next(260, 45),
            .completed(270)
            ])
        
        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 270)
            ])
    }

    func testTimeout_Duetime_Timeout() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createColdObservable([
            .next(10, 42),
            .next(20, 43),
            .next(50, 44),
            .next(60, 45),
            .completed(70)
            ])

        let res = await scheduler.start {
            await xs.timeout(.seconds(25), scheduler: scheduler)
        }

        XCTAssertEqual(res.events, [
            .next(210, 42),
            .next(220, 43),
            .error(245, RxError.timeout)
            ])

        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 245)
            ])
    }
    
    func testTimeout_Duetime_Disposed() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let xs = await scheduler.createHotObservable([
            .next(205, 1),
            .next(210, 2),
            .next(240, 3),
            .next(280, 4),
            .next(320, 5),
            .next(350, 6),
            .next(370, 7),
            .next(420, 8),
            .next(470, 9),
            .completed(600)
            ])
        
        let res = await scheduler.start(disposed: 370) {
            await xs.timeout(.seconds(40), scheduler: scheduler)
        }
        
        XCTAssertEqual(res.events, [
            .next(205, 1),
            .next(210, 2),
            .next(240, 3),
            .next(280, 4),
            .next(320, 5),
            .next(350, 6),
            .next(370, 7)
            ])
        
        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 370)
            ])
    }
    
    func testTimeout_TimeoutOccurs_1() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let xs = await scheduler.createHotObservable([
            .next(70, 1),
            .next(130, 2),
            .next(310, 3),
            .next(400, 4),
            .completed(500)
            ])

        let ys = await scheduler.createColdObservable([
            .next(50, -1),
            .next(200, -2),
            .next(310, -3),
            .completed(320)
            ])
        
        let res = await scheduler.start {
            await xs.timeout(.seconds(100), other: ys, scheduler: scheduler)
        }
        
        XCTAssertEqual(res.events, [
            .next(350, -1),
            .next(500, -2),
            .next(610, -3),
            .completed(620)
            ])
        
        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 300)
            ])
        
        XCTAssertEqual(ys.subscriptions, [
            Subscription(300, 620)
            ])
    }
    
    func testTimeout_TimeoutOccurs_2() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let xs = await scheduler.createHotObservable([
            .next(70, 1),
            .next(130, 2),
            .next(240, 3),
            .next(310, 4),
            .next(430, 5),
            .completed(500)
            ])
        
        let ys = await scheduler.createColdObservable([
            .next(50, -1),
            .next(200, -2),
            .next(310, -3),
            .completed(320)
            ])
        
        let res = await scheduler.start {
            await xs.timeout(.seconds(100), other: ys, scheduler: scheduler)
        }
        
        XCTAssertEqual(res.events, [
            .next(240, 3),
            .next(310, 4),
            .next(460, -1),
            .next(610, -2),
            .next(720, -3),
            .completed(730)
            ])
        
        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 410)
            ])
        
        XCTAssertEqual(ys.subscriptions, [
            Subscription(410, 730)
            ])
    }
    
    func testTimeout_TimeoutOccurs_Never() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let xs = await scheduler.createHotObservable([
            .next(70, 1),
            .next(130, 2),
            .next(240, 3),
            .next(310, 4),
            .next(430, 5),
            .completed(500)
            ])
        
        let ys: TestableObservable<Int> = await scheduler.createColdObservable([
            ])
        
        let res = await scheduler.start {
            await xs.timeout(.seconds(100), other: ys, scheduler: scheduler)
        }
        
        XCTAssertEqual(res.events, [
            .next(240, 3),
            .next(310, 4)
            ])
        
        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 410)
            ])
        
        XCTAssertEqual(ys.subscriptions, [
            Subscription(410, 1000)
            ])
    }
    
    func testTimeout_TimeoutOccurs_Completed() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let xs: TestableObservable<Int> = await scheduler.createHotObservable([
            .completed(500)
            ])
        
        let ys = await scheduler.createColdObservable([
            .next(100, -1)
            ])
        
        let res = await scheduler.start {
            await xs.timeout(.seconds(100), other: ys, scheduler: scheduler)
        }
        
        XCTAssertEqual(res.events, [
            .next(400, -1),
            ])
        
        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 300)
            ])
        
        XCTAssertEqual(ys.subscriptions, [
            Subscription(300, 1000)
            ])
    }

    func testTimeout_TimeoutOccurs_Error() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs: TestableObservable<Int> = await scheduler.createHotObservable([
            .error(500, testError)
            ])

        let ys = await scheduler.createColdObservable([
            .next(100, -1)
            ])

        let res = await scheduler.start {
            await xs.timeout(.seconds(100), other: ys, scheduler: scheduler)
        }

        XCTAssertEqual(res.events, [
            .next(400, -1),
            ])

        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 300)
            ])

        XCTAssertEqual(ys.subscriptions, [
            Subscription(300, 1000)
            ])
    }
    
    func testTimeout_TimeoutOccurs_NextIsError() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let xs: TestableObservable<Int> = await scheduler.createHotObservable([
            .next(500, 42)
            ])
        
        let ys: TestableObservable<Int> = await scheduler.createColdObservable([
            .error(100, testError)
            ])
        
        let res = await scheduler.start {
            await xs.timeout(.seconds(100), other: ys, scheduler: scheduler)
        }
        
        XCTAssertEqual(res.events, [
            .error(400, testError)
            ])
        
        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 300)
            ])
        
        XCTAssertEqual(ys.subscriptions, [
            Subscription(300, 400)
            ])
    }
    
    func testTimeout_TimeoutNotOccurs_Completed() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let xs: TestableObservable<Int> = await scheduler.createHotObservable([
            .completed(250)
            ])
        
        let ys: TestableObservable<Int> = await scheduler.createColdObservable([
            .next(100, -1)
            ])
        
        let res = await scheduler.start {
            await xs.timeout(.seconds(100), other: ys, scheduler: scheduler)
        }
        
        XCTAssertEqual(res.events, [
            .completed(250)
            ])
        
        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 250)
            ])
        
        XCTAssertEqual(ys.subscriptions, [])
    }
    
    func testTimeout_TimeoutNotOccurs_Error() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let xs: TestableObservable<Int> = await scheduler.createHotObservable([
            .error(250, testError)
            ])
        
        let ys: TestableObservable<Int> = await scheduler.createColdObservable([
            .next(100, -1)
            ])
        
        let res = await scheduler.start {
            await xs.timeout(.seconds(100), other: ys, scheduler: scheduler)
        }
        
        XCTAssertEqual(res.events, [
            .error(250, testError)
            ])
        
        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 250)
            ])
        
        XCTAssertEqual(ys.subscriptions, [])
    }
    
    func testTimeout_TimeoutNotOccurs() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let xs = await scheduler.createHotObservable([
            .next(70, 1),
            .next(130, 2),
            .next(240, 3),
            .next(320, 4),
            .next(410, 5),
            .completed(500)
            ])
        
        let ys = await scheduler.createColdObservable([
            .next(50, -1),
            .next(200, -2),
            .next(310, -3),
            .completed(320)
            ])
        
        let res = await scheduler.start {
            await xs.timeout(.seconds(100), other: ys, scheduler: scheduler)
        }
        
        XCTAssertEqual(res.events, [
            .next(240, 3),
            .next(320, 4),
            .next(410, 5),
            .completed(500)
            ])
        
        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 500)
            ])
        
        XCTAssertEqual(ys.subscriptions, [
            ])
    }

    #if TRACE_RESOURCES
    func testTimeoutReleasesResourcesOnComplete() async {
        let scheduler = await TestScheduler(initialClock: 0)
        _ = await Observable<Int>.just(1).timeout(.seconds(100), other: Observable.empty(), scheduler: scheduler).subscribe()
        await scheduler.start()
        }

    func testTimeoutReleasesResourcesOnError() async {
        let scheduler = await TestScheduler(initialClock: 0)
        _ = await Observable<Int>.error(testError).timeout(.seconds(100), other: Observable.empty(), scheduler: scheduler).subscribe()
        await scheduler.start()
        }
    #endif

}
