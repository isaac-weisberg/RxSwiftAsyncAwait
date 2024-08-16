//
//  Observable+CatchTests.swift
//  Tests
//
//  Created by Krunoslav Zaher on 4/29/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

import XCTest
import RxSwift
import RxTest

class ObservableCatchTest : RxTest {
}

extension ObservableCatchTest {
    func testCatch_ErrorSpecific_Caught() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let o1 = await scheduler.createHotObservable([
            .next(150, 1),
            .next(210, 2),
            .next(220, 3),
            .error(230, testError)
        ])
        
        let o2 = await scheduler.createHotObservable([
            .next(240, 4),
            .completed(250)
        ])
        
        var handlerCalled: Int?
        
        let res = await scheduler.start {
            await o1.catch { _ in
                handlerCalled = scheduler.clock
                return await o2.asObservable()
            }
        }
        
        XCTAssertEqual(230, handlerCalled!)
        
        XCTAssertEqual(res.events, [
            .next(210, 2),
            .next(220, 3),
            .next(240, 4),
            .completed(250)
        ])
        
        XCTAssertEqual(o1.subscriptions, [
            Subscription(200, 230)
        ])
        
        XCTAssertEqual(o2.subscriptions, [
            Subscription(230, 250)
        ])
    }
    
    func testCatch_HandlerThrows() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let o1 = await scheduler.createHotObservable([
            .next(150, 1),
            .next(210, 2),
            .next(220, 3),
            .error(230, testError)
        ])
        
        var handlerCalled: Int?
        
        let res = await scheduler.start {
            await o1.catch { _ in
                handlerCalled = scheduler.clock
                throw testError1
            }
        }
        
        XCTAssertEqual(230, handlerCalled!)
        
        XCTAssertEqual(res.events, [
            .next(210, 2),
            .next(220, 3),
            .error(230, testError1),
        ])
        
        XCTAssertEqual(o1.subscriptions, [
            Subscription(200, 230)
        ])
    }

    #if TRACE_RESOURCES
    func testCatchReleasesResourcesOnComplete() async {
        _ = await Observable<Int>.just(1).catch { _ in await Observable<Int>.just(1) }.subscribe()
        }

    func tesCatch1ReleasesResourcesOnError() async {
        _ = await Observable<Int>.error(testError).catch { _ in await Observable<Int>.just(1) }.subscribe()
        }

    func tesCatch2ReleasesResourcesOnError() async {
        _ = await Observable<Int>.error(testError).catch { _ in await Observable<Int>.error(testError) }.subscribe()
        }
    #endif
}

// catch enumerable
extension ObservableCatchTest {
    func testCatchSequenceOf_IEofIO() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let xs1 = await scheduler.createColdObservable([
            .next(10, 1),
            .next(20, 2),
            .next(30, 3),
            .error(40, testError)
        ])
        
        let xs2 = await scheduler.createColdObservable([
            .next(10, 4),
            .next(20, 5),
            .error(30, testError)
        ])
        
        let xs3 = await scheduler.createColdObservable([
            .next(10, 6),
            .next(20, 7),
            .next(30, 8),
            .next(40, 9),
            .completed(50)
        ])
        
        let res = await scheduler.start {
            await Observable.catch(sequence: [xs1.asObservable(), xs2.asObservable(), xs3.asObservable()])
        }
        
        XCTAssertEqual(res.events, [
            .next(210, 1),
            .next(220, 2),
            .next(230, 3),
            .next(250, 4),
            .next(260, 5),
            .next(280, 6),
            .next(290, 7),
            .next(300, 8),
            .next(310, 9),
            .completed(320)
            ])
        
        XCTAssertEqual(xs1.subscriptions, [
            Subscription(200, 240)
            ])
        
        XCTAssertEqual(xs2.subscriptions, [
            Subscription(240, 270)
            ])
        
        XCTAssertEqual(xs3.subscriptions, [
            Subscription(270, 320)
            ])
    }
    
    func testCatchAnySequence_NoErrors() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let xs1 = await scheduler.createHotObservable([
            .next(150, 1),
            .next(210, 2),
            .next(220, 3),
            .completed(230)
            ])
        
        let xs2 = await scheduler.createHotObservable([
            .next(240, 4),
            .completed(250)
            ])
        
        let res = await scheduler.start {
            await Observable.catch(sequence: [xs1, xs2].map { await $0.asObservable() })
        }
        
        XCTAssertEqual(res.events, [
            .next(210, 2),
            .next(220, 3),
            .completed(230)
            ])
        
        XCTAssertEqual(xs1.subscriptions, [
            Subscription(200, 230)
            ])
        
        XCTAssertEqual(xs2.subscriptions, [
            ])
    }

    func testCatchAnySequence_Never() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let xs1 = await scheduler.createHotObservable([
            .next(150, 1),
            ])
        
        let xs2 = await scheduler.createHotObservable([
            .next(240, 4),
            .completed(250)
            ])
        
        let res = await scheduler.start {
            await Observable.catch(sequence: [xs1, xs2].map { await $0.asObservable() })
        }
        
        XCTAssertEqual(res.events, [
            ])
        
        XCTAssertEqual(xs1.subscriptions, [
            Subscription(200, 1000)
            ])
        
        XCTAssertEqual(xs2.subscriptions, [
            ])
    }
    
    func testCatchAnySequence_Empty() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let xs1 = await scheduler.createHotObservable([
            .next(150, 1),
            .completed(230)
            ])
        
        let xs2 = await scheduler.createHotObservable([
            .next(240, 4),
            .completed(250)
            ])
        
        let res = await scheduler.start {
            await Observable.catch(sequence: [xs1, xs2].map { await $0.asObservable() })
        }
        
        XCTAssertEqual(res.events, [
            .completed(230)
            ])
        
        XCTAssertEqual(xs1.subscriptions, [
            Subscription(200, 230)
            ])
        
        XCTAssertEqual(xs2.subscriptions, [
            ])
    }
    
    func testCatchSequenceOf_Error() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let xs1 = await scheduler.createHotObservable([
            .next(150, 1),
            .next(210, 2),
            .next(220, 3),
            .error(230, testError)
            ])
        
        let xs2 = await scheduler.createHotObservable([
            .next(240, 4),
            .completed(250)
            ])
        
        let res = await scheduler.start {
            await Observable.catch(sequence: [xs1, xs2].map { await $0.asObservable() })
        }
        
        XCTAssertEqual(res.events, [
            .next(210, 2),
            .next(220, 3),
            .next(240, 4),
            .completed(250)
            ])
        
        XCTAssertEqual(xs1.subscriptions, [
            Subscription(200, 230)
            ])
        
        XCTAssertEqual(xs2.subscriptions, [
            Subscription(230, 250)
            ])
    }
    
    func testCatchSequenceOf_ErrorNever() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let xs1 = await scheduler.createHotObservable([
            .next(150, 1),
            .next(210, 2),
            .next(220, 3),
            .error(230, testError)
            ])
        
        let xs2 = await scheduler.createHotObservable([
            .next(150, 1),
            ])
        
        let res = await scheduler.start {
            await Observable.catch(sequence: [xs1, xs2].map { await $0.asObservable() })
        }
        
        XCTAssertEqual(res.events, [
            .next(210, 2),
            .next(220, 3),
            ])
        
        XCTAssertEqual(xs1.subscriptions, [
            Subscription(200, 230)
            ])
        
        XCTAssertEqual(xs2.subscriptions, [
            Subscription(230, 1000)
            ])
    }
    
    func testCatchSequenceOf_ErrorError() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let xs1 = await scheduler.createHotObservable([
            .next(150, 1),
            .next(210, 2),
            .next(220, 3),
            .error(230, testError)
            ])
        
        let xs2 = await scheduler.createHotObservable([
            .next(150, 1),
            .error(250, testError)
            ])
        
        let res = await scheduler.start {
            await Observable.catch(sequence: [xs1, xs2].map { await $0.asObservable() })
        }
        
        XCTAssertEqual(res.events, [
            .next(210, 2),
            .next(220, 3),
            .error(250, testError)
            ])
        
        XCTAssertEqual(xs1.subscriptions, [
            Subscription(200, 230)
            ])
        
        XCTAssertEqual(xs2.subscriptions, [
            Subscription(230, 250)
            ])
    }
    
    func testCatchSequenceOf_Multiple() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let xs1 = await scheduler.createHotObservable([
            .next(150, 1),
            .next(210, 2),
            .error(215, testError)
            ])
        
        let xs2 = await scheduler.createHotObservable([
            .next(220, 3),
            .error(225, testError)
            ])
        
        let xs3 = await scheduler.createHotObservable([
            .next(230, 4),
            .completed(235)
            ])
        
        let res = await scheduler.start {
            await Observable.catch(sequence: [xs1.asObservable(), xs2.asObservable(), xs3.asObservable()])
        }
        
        XCTAssertEqual(res.events, [
            .next(210, 2),
            .next(220, 3),
            .next(230, 4),
            .completed(235)
            ])
        
        XCTAssertEqual(xs1.subscriptions, [
            Subscription(200, 215)
            ])
        
        XCTAssertEqual(xs2.subscriptions, [
            Subscription(215, 225)
            ])
        
        XCTAssertEqual(xs3.subscriptions, [
            Subscription(225, 235)
            ])
    }

    #if TRACE_RESOURCES
    func testCatchSequenceReleasesResourcesOnComplete() async {
        _ = await Observable.catch(sequence: [Observable<Int>.just(1)]).subscribe()
        }
    #endif
}

extension ObservableCatchTest {
    func testRetry_Basic() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createColdObservable([
            .next(100, 1),
            .next(150, 2),
            .next(200, 3),
            .completed(250)
            ])

        let res = await scheduler.start {
            await xs.retry()
        }

        XCTAssertEqual(res.events, [
            .next(300, 1),
            .next(350, 2),
            .next(400, 3),
            .completed(450)
            ])

        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 450)
            ])
    }

    func testRetry_Infinite() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createColdObservable([
            .next(100, 1),
            .next(150, 2),
            .next(200, 3),
            ])

        let res = await scheduler.start {
            await xs.retry()
        }

        XCTAssertEqual(res.events, [
            .next(300, 1),
            .next(350, 2),
            .next(400, 3),
            ])

        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 1000)
            ])
    }

    func testRetry_Observable_Error() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createColdObservable([
            .next(100, 1),
            .next(150, 2),
            .next(200, 3),
            .error(250, testError),
            ])

        let res = await scheduler.start(disposed: 1100) {
            await xs.retry()
        }

        XCTAssertEqual(res.events, [
            .next(300, 1),
            .next(350, 2),
            .next(400, 3),
            .next(550, 1),
            .next(600, 2),
            .next(650, 3),
            .next(800, 1),
            .next(850, 2),
            .next(900, 3),
            .next(1050, 1)
            ])

        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 450),
            Subscription(450, 700),
            Subscription(700, 950),
            Subscription(950, 1100)
            ])
    }

    func testRetryCount_Basic() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createColdObservable([
            .next(5, 1),
            .next(10, 2),
            .next(15, 3),
            .error(20, testError)
            ])

        let res = await scheduler.start {
            await xs.retry(3)
        }

        XCTAssertEqual(res.events, [
            .next(205, 1),
            .next(210, 2),
            .next(215, 3),
            .next(225, 1),
            .next(230, 2),
            .next(235, 3),
            .next(245, 1),
            .next(250, 2),
            .next(255, 3),
            .error(260, testError)
            ])

        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 220),
            Subscription(220, 240),
            Subscription(240, 260)
            ])
    }

    func testRetryCount_Dispose() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createColdObservable([
            .next(5, 1),
            .next(10, 2),
            .next(15, 3),
            .error(20, testError)
            ])

        let res = await scheduler.start(disposed: 231) {
            await xs.retry(3)
        }

        XCTAssertEqual(res.events, [
            .next(205, 1),
            .next(210, 2),
            .next(215, 3),
            .next(225, 1),
            .next(230, 2),
            ])

        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 220),
            Subscription(220, 231),
            ])
    }

    func testRetryCount_Infinite() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createColdObservable([
            .next(5, 1),
            .next(10, 2),
            .next(15, 3),
            .error(20, testError)
            ])

        let res = await scheduler.start(disposed: 231) {
            await xs.retry(3)
        }

        XCTAssertEqual(res.events, [
            .next(205, 1),
            .next(210, 2),
            .next(215, 3),
            .next(225, 1),
            .next(230, 2),
            ])

        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 220),
            Subscription(220, 231),
            ])
    }

    func testRetryCount_Completed() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createColdObservable([
            .next(100, 1),
            .next(150, 2),
            .next(200, 3),
            .completed(250)
            ])

        let res = await scheduler.start {
            await xs.retry(3)
        }

        XCTAssertEqual(res.events, [
            .next(300, 1),
            .next(350, 2),
            .next(400, 3),
            .completed(450)
            ])

        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 450),
            ])
    }

    func testRetry_tailRecursiveOptimizationsTest() async {
        var count = 1
        let sequenceSendingImmediateError: Observable<Int> = await Observable.create { observer in
            await observer.on(.next(0))
            await observer.on(.next(1))
            await observer.on(.next(2))
            if count < 2 {
                await observer.on(.error(testError))
                count += 1
            }
            await observer.on(.next(3))
            await observer.on(.next(4))
            await observer.on(.next(5))
            await observer.on(.completed)

            return Disposables.create()
        }

        _ = await sequenceSendingImmediateError
            .retry()
            .subscribe { _ in
            }
    }

    #if TRACE_RESOURCES
    func testRetryReleasesResourcesOnComplete() async {
        _ = await Observable<Int>.just(1).retry().subscribe()
        }

    func testRetryReleasesResourcesOnError() async {
        _ = await Observable<Int>.error(testError).retry(1).subscribe()
        }
    #endif
}
