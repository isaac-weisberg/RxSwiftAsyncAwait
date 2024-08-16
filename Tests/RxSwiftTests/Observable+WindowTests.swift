//
//  Observable+WindowTests.swift
//  Tests
//
//  Created by Krunoslav Zaher on 4/29/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

import XCTest
import RxSwift
import RxTest

class ObservableWindowTest : RxTest {
}

extension ObservableWindowTest {
    func testWindowWithTimeOrCount_Basic() async {
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
        
        let res = await scheduler.start { () -> Observable<String> in
            let window: Observable<Observable<Int>> = await xs.window(timeSpan: .seconds(70), count: 3, scheduler: scheduler)
            let mappedWithIndex = await window.enumerated().map { (i: Int, o: Observable<Int>) async -> Observable<String> in
                return await o.map { (e: Int) -> String in
                    return "\(i) \(e)"
                }
            }
            let result = await mappedWithIndex.merge()
            return result
        }
        
        XCTAssertEqual(res.events, [
            .next(205, "0 1"),
            .next(210, "0 2"),
            .next(240, "0 3"),
            .next(280, "1 4"),
            .next(320, "2 5"),
            .next(350, "2 6"),
            .next(370, "2 7"),
            .next(420, "3 8"),
            .next(470, "4 9"),
            .completed(600)
            ])
        
        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 600)
            ])
    }
    
    func testWindowWithTimeOrCount_Error() async {
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
        
        let res = await scheduler.start { () -> Observable<String> in
            let window: Observable<Observable<Int>> = await xs.window(timeSpan: .seconds(70), count: 3, scheduler: scheduler)
            let mappedWithIndex = await window.enumerated().map { (i: Int, o: Observable<Int>) -> Observable<String> in
                return await o.map { (e: Int) -> String in
                    return "\(i) \(e)"
                    }
            }
            let result = await mappedWithIndex.merge()
            return result
        }
        
        XCTAssertEqual(res.events, [
            .next(205, "0 1"),
            .next(210, "0 2"),
            .next(240, "0 3"),
            .next(280, "1 4"),
            .next(320, "2 5"),
            .next(350, "2 6"),
            .next(370, "2 7"),
            .next(420, "3 8"),
            .next(470, "4 9"),
            .error(600, testError)
            ])
        
        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 600)
            ])
    }
    
    func testWindowWithTimeOrCount_Disposed() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let xs = await scheduler.createHotObservable([
            .next(105, 0),
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
        
        let res = await scheduler.start(disposed: 370) { () -> Observable<String> in
            let window: Observable<Observable<Int>> = await xs.window(timeSpan: .seconds(70), count: 3, scheduler: scheduler)
            let mappedWithIndex = await window.enumerated().map { (i: Int, o: Observable<Int>) async -> Observable<String> in
                return await o.map { (e: Int) -> String in
                    return "\(i) \(e)"
                }
            }
            let result = await mappedWithIndex.merge()
            return result
        }
        
        XCTAssertEqual(res.events, [
            .next(205, "0 1"),
            .next(210, "0 2"),
            .next(240, "0 3"),
            .next(280, "1 4"),
            .next(320, "2 5"),
            .next(350, "2 6"),
            .next(370, "2 7")
            ])
        
        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 370)
            ])
    }
    
    func windowWithTimeOrCount_Default() async {
        let backgroundScheduler = SerialDispatchQueueScheduler(qos: .default)
        
        let result = try! await Observable.range(start: 1, count: 10, scheduler: backgroundScheduler)
            .window(timeSpan: .seconds(1000), count: 3, scheduler: backgroundScheduler)
            .enumerated().map { (i: Int, o: Observable<Int>) -> Observable<String> in
                return await o.map { (e: Int) -> String in
                    return "\(i) \(e)"
                    }
            }
            .merge()
            .skip(4)
            .toBlocking()
            .first()
    
        XCTAssertEqual(result!, "1 5")
    }

    #if TRACE_RESOURCES
    func testWindowReleasesResourcesOnComplete() async {
        let scheduler = await TestScheduler(initialClock: 0)
        _ = await Observable<Int>.just(1).window(timeSpan: .seconds(0), count: 10, scheduler: scheduler).subscribe()
        await scheduler.start()
        }

    func testWindowReleasesResourcesOnError() async {
        let scheduler = await TestScheduler(initialClock: 0)
        _ = await Observable<Int>.error(testError).window(timeSpan: .seconds(0), count: 10, scheduler: scheduler).subscribe()
        await scheduler.start()
        }
    #endif
}
