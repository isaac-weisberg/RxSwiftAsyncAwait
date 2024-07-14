//
//  Observable+TakeLastTests.swift
//  Tests
//
//  Created by Krunoslav Zaher on 4/29/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

import XCTest
import RxSwift
import RxTest

class ObservableTakeLastTest : RxTest {
}

extension ObservableTakeLastTest {
    func testTakeLast_Complete_Less() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let xs = await scheduler.createHotObservable([
            .next(70, 6),
            .next(150, 4),
            .next(210, 9),
            .next(230, 13),
            .next(270, 7),
            .next(280, 1),
            .next(300, -1),
            .completed(300)
            ])
        
        let res = await scheduler.start {
            await xs.takeLast(7)
        }
        
        XCTAssertEqual(res.events, [
            .next(300, 9),
            .next(300, 13),
            .next(300, 7),
            .next(300, 1),
            .next(300, -1),
            .completed(300)
            ])
        
        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 300)
            ])
    }
    
    func testTakeLast_Complete_Same() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let xs = await scheduler.createHotObservable([
            .next(70, 6),
            .next(150, 4),
            .next(210, 9),
            .next(230, 13),
            .next(270, 7),
            .next(280, 1),
            .next(300, -1),
            .completed(310)
            ])
        
        let res = await scheduler.start {
            await xs.takeLast(5)
        }
        
        XCTAssertEqual(res.events, [
            .next(310, 9),
            .next(310, 13),
            .next(310, 7),
            .next(310, 1),
            .next(310, -1),
            .completed(310)
            ])
        
        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 310)
            ])
    }
    
    func testTakeLast_Complete_More() async {
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
            .completed(350)
            ])
        
        let res = await scheduler.start {
            await xs.takeLast(5)
        }
        
        XCTAssertEqual(res.events, [
            .next(350, 7),
            .next(350, 1),
            .next(350, -1),
            .next(350, 3),
            .next(350, 8),
            .completed(350)
            ])
        
        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 350)
            ])
    }
    
    func testTakeLast_Error_Less() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let xs = await scheduler.createHotObservable([
            .next(70, 6),
            .next(150, 4),
            .next(210, 9),
            .next(230, 13),
            .next(270, 7),
            .next(280, 1),
            .next(290, 64),
            .error(300, testError)
            ])
        
        let res = await scheduler.start {
            await xs.takeLast(7)
        }
        
        XCTAssertEqual(res.events, [
            .error(300, testError)
            ])
        
        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 300)
            ])
    }
    
    func testTakeLast_Error_Same() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let xs = await scheduler.createHotObservable([
            .next(70, 6),
            .next(150, 4),
            .next(210, 9),
            .next(230, 13),
            .next(270, 7),
            .next(280, 1),
            .next(300, -1),
            .error(310, testError)
            ])
        
        let res = await scheduler.start {
            await xs.takeLast(5)
        }
        
        XCTAssertEqual(res.events, [
            .error(310, testError)
            ])
        
        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 310)
            ])
    }
    
    func testTakeLast_Error_More() async {
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
            .next(340, 64),
            .error(360, testError)
            ])
        
        let res = await scheduler.start {
            await xs.takeLast(5)
        }
        
        XCTAssertEqual(res.events, [
            .error(360, testError)
            ])
        
        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 360)
            ])
    }
    
    func testTakeLast_0_DefaultScheduler() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let xs = await scheduler.createHotObservable([
            .next(70, 6),
            .next(150, 4),
            .next(210, 9),
            .next(230, 13)
            ])
        
        let res = await scheduler.start {
            await xs.takeLast(0)
        }
        
        XCTAssertEqual(res.events, [
            ])
        
        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 1000)
            ])
    }
    
    func testTakeLast_TakeLast1() async {
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
            await xs.takeLast(3)
        }
        
        XCTAssertEqual(res.events, [
            .next(400, 3),
            .next(400, 8),
            .next(400, 11),
            .completed(400)
            ])
        
        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 400)
            ])
    }
    
    func testTakeLast_DecrementCountsFirst() async {
        let k = await BehaviorSubject(value: false)

        var elements = [Bool]()
        _ = await k.takeLast(1).subscribe(onNext: { n in
            elements.append(n)
            await k.on(.next(!n))
        })

        await k.on(.completed)

        XCTAssertEqual(elements, [false])
    }

    #if TRACE_RESOURCES
    func testTakeLastReleasesResourcesOnComplete() async {
        _ = await Observable<Int>.of(1, 2).takeLast(1).subscribe()
        }

    func testTakeLastReleasesResourcesOnError() async {
        _ = await Observable<Int>.error(testError).takeLast(1).subscribe()
        }
    #endif
}
