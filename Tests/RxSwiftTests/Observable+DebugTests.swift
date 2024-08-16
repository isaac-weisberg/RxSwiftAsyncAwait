//
//  Observable+DebugTests.swift
//  Tests
//
//  Created by Krunoslav Zaher on 4/29/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

import XCTest
import RxSwift
import RxTest

class ObservableDebugTest : RxTest {
}

extension ObservableDebugTest {
    func testDebug_Completed() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(210, 0),
            .completed(600)
            ])

        let res = await scheduler.start { () -> Observable<Int> in
            return await xs.debug()
        }

        XCTAssertEqual(res.events, [
            .next(210, 0),
            .completed(600)
            ])

        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 600)
            ])
    }

    func testDebug_Error() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(210, 0),
            .error(600, testError)
            ])

        let res = await scheduler.start { () -> Observable<Int> in
            return await xs.debug()
        }

        XCTAssertEqual(res.events, [
            .next(210, 0),
            .error(600, testError)
            ])

        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 600)
            ])
    }

    #if TRACE_RESOURCES
    func testReplayNReleasesResourcesOnComplete() async {
        _ = await Observable<Int>.just(1).debug().subscribe()
        }

    func testReplayNReleasesResourcesOnError() async {
        _ = await Observable<Int>.error(testError).debug().subscribe()
        }
    #endif
}
