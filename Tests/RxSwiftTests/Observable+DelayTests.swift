//
//  Observable+DelayTests.swift
//  Tests
//
//  Created by Krunoslav Zaher on 4/29/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

import XCTest
import RxSwift
import RxTest
import Dispatch

class ObservableDelayTest : RxTest {
}

extension ObservableDelayTest {
    
    func testDelay_TimeSpan_Simple1() async {
        let scheduler = await TestScheduler(initialClock: 0)
    
        let xs = await scheduler.createHotObservable([
            .next(150, 1),
            .next(250, 2),
            .next(350, 3),
            .next(450, 4),
            .completed(550)
            ])
    
        let res = await scheduler.start {
            await xs.delay(.seconds(100), scheduler: scheduler)
        }
    
        XCTAssertEqual(res.events, [
            .next(350, 2),
            .next(450, 3),
            .next(550, 4),
            .completed(650)
            ])
    
        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 550)
            ])
    }
    
    func testDelay_TimeSpan_Simple2() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let xs = await scheduler.createHotObservable([
            .next(150, 1),
            .next(250, 2),
            .next(350, 3),
            .next(450, 4),
            .completed(550)
            ])
        
        let res = await scheduler.start {
            await xs.delay(.seconds(50), scheduler: scheduler)
        }
        
        XCTAssertEqual(res.events, [
            .next(300, 2),
            .next(400, 3),
            .next(500, 4),
            .completed(600)
            ])
        
        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 550)
            ])
    }
    
    func testDelay_TimeSpan_Simple3() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let xs = await scheduler.createHotObservable([
            .next(150, 1),
            .next(250, 2),
            .next(350, 3),
            .next(450, 4),
            .completed(550)
            ])
        
        let res = await scheduler.start {
            await xs.delay(.seconds(150), scheduler: scheduler)
        }
        
        XCTAssertEqual(res.events, [
            .next(400, 2),
            .next(500, 3),
            .next(600, 4),
            .completed(700)
            ])
        
        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 550)
            ])
    }

    func testDelay_TimeSpan_Error() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(150, 1),
            .error(250, testError)
            ])

        let res = await scheduler.start {
            await xs.delay(.seconds(150), scheduler: scheduler)
        }

        XCTAssertEqual(res.events, [
            .error(250, testError)
            ])

        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 250)
            ])
    }

    func testDelay_TimeSpan_Completed() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(150, 1),
            .completed(250)
            ])

        let res = await scheduler.start {
            await xs.delay(.seconds(150), scheduler: scheduler)
        }

        XCTAssertEqual(res.events, [
            .completed(400)
            ])

        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 250)
            ])
    }

    func testDelay_TimeSpan_Error1() async {
        let scheduler = await TestScheduler(initialClock: 0)
    
        let xs = await scheduler.createHotObservable([
            .next(150, 1),
            .next(250, 2),
            .next(350, 3),
            .next(450, 4),
            .error(550, testError)
            ])
    
        let res = await scheduler.start {
            await xs.delay(.seconds(50), scheduler: scheduler)
        }
    
        XCTAssertEqual(res.events, [
            .next(300, 2),
            .next(400, 3),
            .next(500, 4),
            .error(550, testError)
            ])
        
        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 550)
            ])
    }
    
    func testDelay_TimeSpan_Error2() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let xs = await scheduler.createHotObservable([
            .next(150, 1),
            .next(250, 2),
            .next(350, 3),
            .next(450, 4),
            .error(550, testError)
            ])
        
        let res = await scheduler.start {
            await xs.delay(.seconds(150), scheduler: scheduler)
        }
        
        XCTAssertEqual(res.events, [
            .next(400, 2),
            .next(500, 3),
            .error(550, testError)
            ])
        
        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 550)
            ])
    }
    
    func testDelay_TimeSpan_Real_Simple() async {
        let waitForError: ReplaySubject<()> = await ReplaySubject.create(bufferSize: 1)
        let scheduler = ConcurrentDispatchQueueScheduler(qos: .default)
        
        let s = await PublishSubject<Int>()
    
        let res = await s.delay(.milliseconds(10), scheduler: scheduler)
    
        var array = [Int]()
        
        let subscription = await res.subscribe(
            onNext: { i in
                array.append(i)
            },
            onCompleted: {
                await waitForError.onCompleted()
        })
        
        DispatchQueue.global(qos: .default).async {
            Task {
                await s.onNext(1)
                await s.onNext(2)
                await s.onNext(3)
                await s.onCompleted()
            }
        }

        try! _ = await waitForError.toBlocking(timeout: 5.0).first()
        
        await subscription.dispose()
        
        XCTAssertEqual([1, 2, 3], array)
    }
    
    func testDelay_TimeSpan_Real_Error1() async {
        let errorReceived: ReplaySubject<()> = await ReplaySubject.create(bufferSize: 1)
        let scheduler = ConcurrentDispatchQueueScheduler(qos: .default)
        
        let s = await PublishSubject<Int>()

        let res = await s.delay(.milliseconds(10), scheduler: scheduler)
        
        var array = [Int]()

        var error: Swift.Error?
        
        let subscription = await res.subscribe(
            onNext: { i in
                array.append(i)
            },
            onError: { e in
                error = e
                await errorReceived.onCompleted()
        })
        
        DispatchQueue.global(qos: .default).async {
            Task {
                await s.onNext(1)
                await s.onNext(2)
                await s.onNext(3)
                await s.onError(testError)
            }
        }

        try! await errorReceived.toBlocking(timeout: 5.0).first()
        
        await subscription.dispose()

        XCTAssertEqual(error! as! TestError, testError)
    }
    
    func testDelay_TimeSpan_Real_Error2() async {
        let elementProcessed: ReplaySubject<()> = await ReplaySubject.create(bufferSize: 1)
        let errorReceived: ReplaySubject<()> = await ReplaySubject.create(bufferSize: 1)
        let scheduler = ConcurrentDispatchQueueScheduler(qos: .default)
        
        let s = await PublishSubject<Int>()
        
        let res = await s.delay(.milliseconds(10), scheduler: scheduler)
        
        var array = [Int]()
        var err: TestError?
        
        let subscription = await res.subscribe(
            onNext: { i in
                array.append(i)
                await elementProcessed.onCompleted()
            },
            onError: { ex in
                err = ex as? TestError
                await errorReceived.onCompleted()
        })
        
        DispatchQueue.global(qos: .default).async {
            Task {
                await s.onNext(1)
                try! _ = await elementProcessed.toBlocking(timeout: 5.0).first()
                await s.onError(testError)
            }
        }

        try! _ = await errorReceived.toBlocking(timeout: 5.0).first()
        
        await subscription.dispose()
        
        XCTAssertEqual([1], array)
        XCTAssertEqual(testError, err)
    }


    func testDelay_TimeSpan_Real_Error3() async {
        let elementProcessed: ReplaySubject<()> = await ReplaySubject.create(bufferSize: 1)
        let errorReceived: ReplaySubject<()> = await ReplaySubject.create(bufferSize: 1)
        let acknowledged: ReplaySubject<()> = await ReplaySubject.create(bufferSize: 1)
        let scheduler = ConcurrentDispatchQueueScheduler(qos: .default)
        
        let s = await PublishSubject<Int>()
        
        let res = await s.delay(.milliseconds(10), scheduler: scheduler)
        
        var array = [Int]()
        var err: TestError?
        
        let subscription = await res.subscribe(
            onNext: { i in
                array.append(i)
                await elementProcessed.onCompleted()
                try! _ = await acknowledged.toBlocking(timeout: 5.0).first()
            },
            onError: { ex in
                err = ex as? TestError
                await errorReceived.onCompleted()
        })
        
        DispatchQueue.global(qos: .default).async {
            Task {
                await s.onNext(1)
                try! _ = await elementProcessed.toBlocking(timeout: 5.0).first()
                await s.onError(testError)
                await acknowledged.onCompleted()
            }
        }

        try! _ = await errorReceived.toBlocking(timeout: 5.0).first()
        
        await subscription.dispose()
        
        XCTAssertEqual([1], array)
        XCTAssertEqual(testError, err)
    }
    
    func testDelay_TimeSpan_Positive() async {
        let scheduler = await TestScheduler(initialClock: 0)
    
        let msgs = Recorded.events(
            .next(150, 1),
            .next(250, 2),
            .next(350, 3),
            .next(450, 4),
            .completed(550)
        )
    
        let xs = await scheduler.createHotObservable(msgs)
    
        let delay = 42
        let res = await scheduler.start {
            await xs.delay(.seconds(delay), scheduler: scheduler)
        }
    
        await XCTAssertEqual(res.events,
            msgs.map { Recorded(time: $0.time + delay, value: $0.value) }
                .filter { $0.time > 200 })
    }
    
    func testDelay_TimeSpan_DefaultScheduler() async {
        let scheduler = MainScheduler.instance!
        await assertEqual(try! await Observable.just(1).delay(.milliseconds(1), scheduler: scheduler).toBlocking(timeout: 5.0).toArray(), [1])
    }

    #if TRACE_RESOURCES
    func testDelayReleasesResourcesOnComplete() async {
        let scheduler = await TestScheduler(initialClock: 0)
        _ = await Observable<Int>.just(1).delay(.seconds(100), scheduler: scheduler).subscribe()
        await scheduler.start()
        }

    func testDelayReleasesResourcesOnError() async {
        let scheduler = await TestScheduler(initialClock: 0)
        _ = await Observable<Int>.error(testError).delay(.seconds(100), scheduler: scheduler).subscribe()
        await scheduler.start()
        }
    #endif
}
