//
//  Observable+JustTests.swift
//  Tests
//
//  Created by Krunoslav Zaher on 4/29/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

import XCTest
import RxSwift
import RxTest

class ObservableJustTest : RxTest {
}

extension ObservableJustTest {
    func testJust_Immediate() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let res = await scheduler.start {
            return await Observable.just(42)
        }

        XCTAssertEqual(res.events, [
            .next(200, 42),
            .completed(200)
            ])
    }

    func testJust_Basic() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let res = await scheduler.start {
            return await Observable.just(42, scheduler: scheduler)
        }

        XCTAssertEqual(res.events, [
            .next(201, 42),
            .completed(202)
            ])
    }

    func testJust_Disposed() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let res = await scheduler.start(disposed: 200) {
            return await Observable.just(42, scheduler: scheduler)
        }

        XCTAssertEqual(res.events, [
            ])
    }

    func testJust_DisposeAfterNext() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let d = await SingleAssignmentDisposable()

        let res = scheduler.createObserver(Int.self)

        await scheduler.scheduleAt(100) {
            let subscription = await Observable.just(42, scheduler: scheduler).subscribe { e in
                res.on(e)

                switch e {
                case .next:
                    await d.dispose()
                default:
                    break
                }
            }

            await d.setDisposable(subscription)
        }

        await scheduler.start()

        XCTAssertEqual(res.events, [
            .next(101, 42)
            ])
    }

    func testJust_DefaultScheduler() async {
        let res = try! await Observable.just(42, scheduler: MainScheduler.instance)
            .toBlocking()
            .toArray()

        XCTAssertEqual(res, [
            42
            ])
    }

    func testJust_CompilesInMap() async {
        _ = await (1 as Int?).map { await Observable.just($0)}
    }

    #if TRACE_RESOURCES
    func testJustReleasesResourcesOnComplete() async {
        _ = await Observable<Int>.just(1).subscribe()
        }
        #endif

        #if TRACE_RESOURCES
    func testJustSchdedulerReleasesResourcesOnComplete() async {
        let testScheduler = await TestScheduler(initialClock: 0)
        _ = await Observable<Int>.just(1, scheduler: testScheduler).subscribe()
        await testScheduler.start()
        }
    #endif
}

extension Optional {
    func map<U>(_ transform: (Wrapped) async -> U ) async -> U? {
        switch self {
        case .some(let value):
            return await transform(value)
        case .none:
            return nil
        }
    }
}
