//
//  Observable+SkipUntilTests.swift
//  Tests
//
//  Created by Krunoslav Zaher on 4/29/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

import XCTest
import RxSwift
import RxTest

class ObservableSkipUntilTest : RxTest {
}

extension ObservableSkipUntilTest {
    func testSkipUntil_SomeData_Next() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let l = await scheduler.createHotObservable([
            .next(150, 1),
            .next(210, 2),
            .next(220, 3),
            .next(230, 4), //!
            .next(240, 5), //!
            .completed(250)
        ])
        
        let r = await scheduler.createHotObservable([
            .next(150, 1),
            .next(225, 99),
            .completed(230)
        ])
        
        let res = await scheduler.start {
            await l.skip(until: r)
        }
    
        XCTAssertEqual(res.events, [
            .next(230, 4),
            .next(240, 5),
            .completed(250)
        ])
        
        XCTAssertEqual(l.subscriptions, [
            Subscription(200, 250)
        ])

        XCTAssertEqual(r.subscriptions, [
            Subscription(200, 225)
        ])
    }
    
    func testSkipUntil_SomeData_Error() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let l = await scheduler.createHotObservable([
            .next(150, 1),
            .next(210, 2),
            .next(220, 3),
            .next(230, 4),
            .next(240, 5),
            .completed(250)
        ])
        
        let r = await scheduler.createHotObservable([
            .next(150, 1),
            .error(225, testError)
        ])
        
        let res = await scheduler.start {
            await l.skip(until: r)
        }
    
        XCTAssertEqual(res.events, [
            .error(225, testError),
        ])
        
        XCTAssertEqual(l.subscriptions, [
            Subscription(200, 225)
        ])

        XCTAssertEqual(r.subscriptions, [
            Subscription(200, 225)
        ])
    }
    
    func testSkipUntil_Error_SomeData() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let l = await scheduler.createHotObservable([
            .next(150, 1),
            .next(210, 2),
            .error(220, testError)
 
        ])
        
        let r = await scheduler.createHotObservable([
            .next(150, 1),
            .next(230, 2),
            .completed(250)
        ])
        
        let res = await scheduler.start {
            await l.skip(until: r)
        }
        
        XCTAssertEqual(res.events, [
            .error(220, testError),
        ])
        
        XCTAssertEqual(l.subscriptions, [
            Subscription(200, 220)
        ])

        XCTAssertEqual(r.subscriptions, [
            Subscription(200, 220)
        ])
    }
    
    func testSkipUntil_SomeData_Empty() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let l = await scheduler.createHotObservable([
            .next(150, 1),
            .next(210, 2),
            .next(220, 3),
            .next(230, 4),
            .next(240, 5),
            .completed(250)
        ])
        
        let r = await scheduler.createHotObservable([
            .next(150, 1),
            .completed(225)
        ])
        
        let res = await scheduler.start {
            await l.skip(until: r)
        }
        
        XCTAssertEqual(res.events, [
        ])
        
        XCTAssertEqual(l.subscriptions, [
            Subscription(200, 250)
        ])

        XCTAssertEqual(r.subscriptions, [
            Subscription(200, 225)
        ])
    }
    
    func testSkipUntil_Never_Next() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let l = await scheduler.createHotObservable([
            .next(150, 1)
        ])
        
        let r = await scheduler.createHotObservable([
            .next(150, 1),
            .next(225, 2), //!
            .completed(250)
        ])
        
        let res = await scheduler.start {
            await l.skip(until: r)
        }
        
        XCTAssertEqual(res.events, [
        ])
        
        XCTAssertEqual(l.subscriptions, [
            Subscription(200, 1000)
        ])

        XCTAssertEqual(r.subscriptions, [
            Subscription(200, 225)
        ])
    }
    
    func testSkipUntil_Never_Error1() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let l = await scheduler.createHotObservable([
            .next(150, 1)
        ])
        
        let r = await scheduler.createHotObservable([
            .next(150, 1),
            .error(225, testError)
        ])
        
        let res = await scheduler.start {
            await l.skip(until: r)
        }
        
        XCTAssertEqual(res.events, [
            .error(225, testError)
        ])
        
        XCTAssertEqual(l.subscriptions, [
            Subscription(200, 225)
        ])

        XCTAssertEqual(r.subscriptions, [
            Subscription(200, 225)
        ])
    }
    
    func testSkipUntil_SomeData_Error2() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let l = await scheduler.createHotObservable([
            .next(150, 1),
            .next(210, 2),
            .next(220, 3),
            .next(230, 4),
            .next(240, 5),
            .completed(250)
        ])
        
        let r = await scheduler.createHotObservable([
            .next(150, 1),
            .error(300, testError)
        ])
        
        let res = await scheduler.start {
            await l.skip(until: r)
        }
        
        XCTAssertEqual(res.events, [
        ])
        
        XCTAssertEqual(l.subscriptions, [
            Subscription(200, 250)
        ])

        XCTAssertEqual(r.subscriptions, [
            Subscription(200, 250)
        ])
    }
    
    func testSkipUntil_SomeData_Never() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let l = await scheduler.createHotObservable([
            .next(150, 1),
            .next(210, 2),
            .next(220, 3),
            .next(230, 4),
            .next(240, 5),
            .completed(250)
        ])
        
        let r = await scheduler.createHotObservable([
            .next(150, 1),
        ])
        
        let res = await scheduler.start {
            await l.skip(until: r)
        }
        
        XCTAssertEqual(res.events, [
        ])
        
        XCTAssertEqual(l.subscriptions, [
            Subscription(200, 250)
        ])

        XCTAssertEqual(r.subscriptions, [
            Subscription(200, 250)
        ])
    }
    
    func testSkipUntil_Never_Empty() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let l = await scheduler.createHotObservable([
            .next(150, 1),
        ])
        
        let r = await scheduler.createHotObservable([
            .next(150, 1),
            .completed(225)
        ])
        
        let res = await scheduler.start {
            await l.skip(until: r)
        }
        
        XCTAssertEqual(res.events, [
        ])
        
        XCTAssertEqual(l.subscriptions, [
            Subscription(200, 1000)
        ])
        
        XCTAssertEqual(r.subscriptions, [
            Subscription(200, 225)
        ])
    }
    
    func testSkipUntil_Never_Never() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let l = await scheduler.createHotObservable([
            .next(150, 1),
        ])
        
        let r = await scheduler.createHotObservable([
            .next(150, 1),
        ])
        
        let res = await scheduler.start {
            await l.skip(until: r)
        }
        
        XCTAssertEqual(res.events, [
        ])
        
        XCTAssertEqual(l.subscriptions, [
            Subscription(200, 1000)
        ])

        XCTAssertEqual(r.subscriptions, [
            Subscription(200, 1000)
        ])
    }
    
    func testSkipUntil_HasCompletedCausesDisposal() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        var isDisposed = false
        
        let l = await scheduler.createHotObservable([
            .next(150, 1),
            .next(210, 2),
            .next(220, 3),
            .next(230, 4),
            .next(240, 5),
            .completed(250)
        ])
        
        let r: Observable<Int> = await Observable.create { _ in
            return await Disposables.create {
                isDisposed = true
            }
        }
        
        let res = await scheduler.start {
            await l.skip(until: r)
        }
        
        XCTAssertEqual(res.events, [
        ])
        
        XCTAssert(isDisposed, "isDisposed")
    }

    #if TRACE_RESOURCES
    func testSkipUntilReleasesResourcesOnComplete1() async {
        let scheduler = await TestScheduler(initialClock: 0)
        _ = await Observable<Int>.just(1).delay(.seconds(20), scheduler: scheduler).skip(until: Observable<Int>.just(1)).subscribe()
        await scheduler.start()
        }

    func testSkipUntilReleasesResourcesOnComplete2() async {
        let scheduler = await TestScheduler(initialClock: 0)
        _ = await Observable<Int>.just(1).skip(until: Observable<Int>.just(1).delay(.seconds(20), scheduler: scheduler)).subscribe()
        await scheduler.start()
        }

    func testSkipUntilReleasesResourcesOnError1() async {
        let scheduler = await TestScheduler(initialClock: 0)
        _ = await Observable<Int>.never().timeout(.seconds(20), scheduler: scheduler).skip(until: Observable<Int>.just(1)).subscribe()
        await scheduler.start()
        }

    func testSkipUntilReleasesResourcesOnError2() async {
        let scheduler = await TestScheduler(initialClock: 0)
        _ = await Observable<Int>.just(1).skip(until: Observable<Int>.never().timeout(.seconds(20), scheduler: scheduler)).subscribe()
        await scheduler.start()
        }
    #endif
}

