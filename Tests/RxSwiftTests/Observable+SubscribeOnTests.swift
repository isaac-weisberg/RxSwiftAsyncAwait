//
//  Observable+SubscribeOnTests.swift
//  Tests
//
//  Created by Krunoslav Zaher on 4/29/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

import XCTest
import RxSwift
import RxTest

class ObservableSubscribeOnTest : RxTest {
}

extension ObservableSubscribeOnTest {
    func testSubscribeOn_SchedulerSleep() async {
        let scheduler = await TestScheduler(initialClock: 0)

        var scheduled = 0
        var disposed = 0

        let xs: Observable<Int> = await Observable.create { _ in
            scheduled = scheduler.clock
            return await Disposables.create {
                disposed = scheduler.clock
            }
        }

        let res = await scheduler.start {
            await xs.subscribe(on: scheduler)
        }

        XCTAssertEqual(res.events, [

            ])

        XCTAssertEqual(scheduled, 201)
        XCTAssertEqual(disposed, 1001)
    }

    func testSubscribeOn_SchedulerCompleted() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs: TestableObservable<Int> = await scheduler.createHotObservable([
            .completed(300)
            ])

        let res = await scheduler.start {
            await xs.subscribe(on: scheduler)
        }

        XCTAssertEqual(res.events, [
            .completed(300)
            ])

        XCTAssertEqual(xs.subscriptions, [
            Subscription(201, 301)
            ])
    }

    func testSubscribeOn_SchedulerError() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs: TestableObservable<Int> = await scheduler.createHotObservable([
            .error(300, testError)
            ])

        let res = await scheduler.start {
            await xs.subscribe(on: scheduler)
        }

        XCTAssertEqual(res.events, [
            .error(300, testError)
            ])

        XCTAssertEqual(xs.subscriptions, [
            Subscription(201, 301)
            ])
    }

    func testSubscribeOn_SchedulerDispose() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(150, 1),
            .next(210, 2),
            ])

        let res = await scheduler.start {
            await xs.subscribe(on: scheduler)
        }

        XCTAssertEqual(res.events, [
            .next(210, 2),
            ])

        XCTAssertEqual(xs.subscriptions, [
            Subscription(201, 1001)
            ])
    }

    #if TRACE_RESOURCES
    func testSubscribeOnSerialReleasesResourcesOnComplete() async {
        let testScheduler = await TestScheduler(initialClock: 0)
        _ = await Observable<Int>.just(1).subscribe(on: testScheduler).subscribe()
        await testScheduler.start()
        }
        
    func testSubscribeOnSerialReleasesResourcesOnError() async {
        let testScheduler = await TestScheduler(initialClock: 0)
        _ = await Observable<Int>.error(testError).subscribe(on: testScheduler).subscribe()
        await testScheduler.start()
        }
    #endif
}
