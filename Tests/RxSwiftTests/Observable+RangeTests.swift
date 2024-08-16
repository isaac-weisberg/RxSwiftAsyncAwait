//
//  Observable+RangeTests.swift
//  Tests
//
//  Created by Krunoslav Zaher on 4/29/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

import XCTest
import RxSwift
import RxTest

class ObservableRangeTest : RxTest {
}

extension ObservableRangeTest {
    func testRange_Boundaries() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let res = await scheduler.start {
            await Observable.range(start: Int.max, count: 1, scheduler: scheduler)
        }

        XCTAssertEqual(res.events, [
            .next(201, Int.max),
            .completed(202)
            ])
    }

    func testRange_ZeroCount() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let res = await scheduler.start {
            await Observable.range(start: 0, count: 0, scheduler: scheduler)
        }

        XCTAssertEqual(res.events, [
            .completed(201)
            ])
    }

    func testRange_Dispose() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let res = await scheduler.start(disposed: 204) {
            await Observable.range(start: -10, count: 5, scheduler: scheduler)
        }

        XCTAssertEqual(res.events, [
            .next(201, -10),
            .next(202, -9),
            .next(203, -8)
            ])
    }

    #if TRACE_RESOURCES
    func testRangeSchedulerReleasesResourcesOnComplete() async {
        let testScheduler = await TestScheduler(initialClock: 0)
        _ = await Observable<Int>.range(start: 0, count: 1, scheduler: testScheduler).subscribe()
        await testScheduler.start()
        }

    func testRangeReleasesResourcesOnComplete() async {
        _ = await Observable<Int>.range(start: 0, count: 1).subscribe()
        }
    #endif
}
