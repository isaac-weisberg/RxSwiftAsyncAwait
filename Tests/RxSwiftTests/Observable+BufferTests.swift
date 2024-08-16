//
//  Observable+BufferTests.swift
//  Tests
//
//  Created by Krunoslav Zaher on 4/29/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

import XCTest
import RxSwift
import RxTest

class ObservableBufferTest : RxTest {
}

extension ObservableBufferTest {
    func testBufferWithTimeOrCount_Basic() async {
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
        
        
        let res = await scheduler.start {
            await xs.buffer(timeSpan: .seconds(70), count: 3, scheduler: scheduler).map { EquatableArray($0) }
        }
        
        XCTAssertEqual(res.events, [
            .next(240, EquatableArray([1, 2, 3])),
            .next(310, EquatableArray([4])),
            .next(370, EquatableArray([5, 6, 7])),
            .next(440, EquatableArray([8])),
            .next(510, EquatableArray([9])),
            .next(580, EquatableArray([])),
            .next(600, EquatableArray([])),
            .completed(600)
            ])
        
        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 600)
            ])
    }
    
    func testBufferWithTimeOrCount_Error() async {
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
            .error(600, testError)
            ])
        
        let res = await scheduler.start {
            await xs.buffer(timeSpan: .seconds(70), count: 3, scheduler: scheduler).map { EquatableArray($0) }
        }
        
        XCTAssertEqual(res.events, [
            .next(240, EquatableArray([1, 2, 3])),
            .next(310, EquatableArray([4])),
            .next(370, EquatableArray([5, 6, 7])),
            .next(440, EquatableArray([8])),
            .next(510, EquatableArray([9])),
            .next(580, EquatableArray([])),
            .error(600, testError)
            ])
        
        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 600)
            ])
    }
    
    func testBufferWithTimeOrCount_Disposed() async {
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
            await xs.buffer(timeSpan: .seconds(70), count: 3, scheduler: scheduler).map { EquatableArray($0) }
        }
        
        XCTAssertEqual(res.events, [
            .next(240, EquatableArray([1, 2, 3])),
            .next(310, EquatableArray([4])),
            .next(370, EquatableArray([5, 6, 7]))
            ])
        
        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 370)
            ])
    }

    func testBufferWithTimeOrCount_Default() async {
        let backgroundScheduler = SerialDispatchQueueScheduler(qos: .default)
        
        let result = try! await Observable.range(start: 1, count: 10, scheduler: backgroundScheduler)
            .buffer(timeSpan: .seconds(1000), count: 3, scheduler: backgroundScheduler)
            .skip(1)
            .toBlocking()
            .first()
            
        XCTAssertEqual(result!, [4, 5, 6])
    }

    #if TRACE_RESOURCES
    func testBufferReleasesResourcesOnComplete() async {
        let scheduler = await TestScheduler(initialClock: 0)
        _ = await Observable<Int>.just(1).buffer(timeSpan: .seconds(0), count: 10, scheduler: scheduler).subscribe()
        await scheduler.start()
        }

    func testBufferReleasesResourcesOnError() async {
        let scheduler = await TestScheduler(initialClock: 0)
        _ = await Observable<Int>.error(testError).buffer(timeSpan: .seconds(0), count: 10, scheduler: scheduler).subscribe()
        await scheduler.start()
        }
    #endif
}
