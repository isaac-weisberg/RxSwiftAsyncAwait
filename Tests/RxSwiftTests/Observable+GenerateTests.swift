//
//  Observable+GenerateTests.swift
//  Tests
//
//  Created by Krunoslav Zaher on 4/29/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

import XCTest
import RxSwift
import RxTest

class ObservableGenerateTest : RxTest {
}

extension ObservableGenerateTest {
    func testGenerate_Finite() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let res = await scheduler.start {
            await Observable.generate(initialState: 0, condition: { x in x <= 3 }, scheduler: scheduler) { x in
                x + 1
            }
        }

        XCTAssertEqual(res.events, [
            .next(201, 0),
            .next(202, 1),
            .next(203, 2),
            .next(204, 3),
            .completed(205)
            ])

    }

    func testGenerate_ThrowCondition() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let res = await scheduler.start {
            await Observable.generate(initialState: 0, condition: { _ in throw testError }, scheduler: scheduler) { x in
                x + 1
            }
        }

        XCTAssertEqual(res.events, [
            .error(201, testError)
            ])

    }

    func testGenerate_ThrowIterate() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let res = await scheduler.start {
            await Observable.generate(initialState: 0, condition: { _ in true }, scheduler: scheduler) { (_: Int) -> Int in
                throw testError
            }
        }

        XCTAssertEqual(res.events, [
            .next(201, 0),
            .error(202, testError)
            ])

    }

    func testGenerate_Dispose() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let res = await scheduler.start(disposed: 203) {
            await Observable.generate(initialState: 0, condition: { _ in true }, scheduler: scheduler) { x in
                x + 1
            }
        }

        XCTAssertEqual(res.events, [
            .next(201, 0),
            .next(202, 1)
            ])

    }

    func testGenerate_take() async {
        var count = 0

        var elements = [Int]()

        _ = await Observable.generate(initialState: 0, condition: { _ in true }) { x in
            count += 1
            return x + 1
            }
            .take(4)
            .subscribe(onNext: { x in
                elements.append(x)
            })

        XCTAssertEqual(elements, [0, 1, 2, 3])
        XCTAssertEqual(count, 3)
    }

    #if TRACE_RESOURCES
    func testGenerateReleasesResourcesOnComplete() async {
        let testScheduler = await TestScheduler(initialClock: 0)
        _ = await Observable<Int>.generate(initialState: 0, condition: { _ in false }, scheduler: testScheduler) { (x: Int) -> Int in
                return x
            }.subscribe()
        await testScheduler.start()
        }

    func testGenerateReleasesResourcesOnError() async {
        let testScheduler = await TestScheduler(initialClock: 0)
        _ = await Observable<Int>.generate(initialState: 0, condition: { _ in false }, scheduler: testScheduler) { _ -> Int in
                throw testError
            }.subscribe()
        await testScheduler.start()
        }
    #endif
}
