//
//  Observable+TakeUntilTests.swift
//  Tests
//
//  Created by Krunoslav Zaher on 4/29/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

import XCTest
import RxSwift
import RxTest

class ObservableTakeUntilTest: RxTest {
}

extension ObservableTakeUntilTest {
    func testTakeUntil_Preempt_SomeData_Next() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let l = await scheduler.createHotObservable([
            .next(150, 1),
            .next(210, 2),
            .next(220, 3),
            .next(230, 4),
            .next(240, 5),
            .completed(250)
        ])
        
        let r = await scheduler.createHotObservable([
            .next(150, 1),
            .next(225, 99),
            .completed(230)
        ])
        
        let res = await scheduler.start {
            await l.take(until: r)
        }
    
        XCTAssertEqual(res.events, [
            .next(210, 2),
            .next(220, 3),
            .completed(225)
        ])
        
        XCTAssertEqual(l.subscriptions, [
            Subscription(200, 225)
        ])

        XCTAssertEqual(r.subscriptions, [
            Subscription(200, 225)
        ])
    }
    
    func testTakeUntil_Preempt_SomeData_Error() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let l = await scheduler.createHotObservable([
            .next(150, 1),
            .next(210, 2),
            .next(220, 3),
            .next(230, 4),
            .next(240, 5),
            .completed(250)
            ])
        
        let r = await scheduler.createHotObservable([
            .next(150, 1),
            .error(225, testError),
            ])
        
        let res = await scheduler.start {
            await l.take(until: r)
        }

        XCTAssertEqual(res.events, [
            .next(210, 2),
            .next(220, 3),
            .error(225, testError)
        ])
        
        XCTAssertEqual(l.subscriptions, [
            Subscription(200, 225)
            ])
        
        XCTAssertEqual(r.subscriptions, [
            Subscription(200, 225)
            ])
    }
    
    func testTakeUntil_NoPreempt_SomeData_Empty() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let l = await scheduler.createHotObservable([
            .next(150, 1),
            .next(210, 2),
            .next(220, 3),
            .next(230, 4),
            .next(240, 5),
            .completed(250)
            ])
        
        let r = await scheduler.createHotObservable([
            .next(150, 1),
            .completed(225)
        ])
        
        let res = await scheduler.start {
            await l.take(until: r)
        }
        
        XCTAssertEqual(res.events, [
            .next(210, 2),
            .next(220, 3),
            .next(230, 4),
            .next(240, 5),
            .completed(250)
            ])
        
        XCTAssertEqual(l.subscriptions, [
            Subscription(200, 250)
            ])
        
        XCTAssertEqual(r.subscriptions, [
            Subscription(200, 225)
            ])
    }
    
    func testTakeUntil_NoPreempt_SomeData_Never() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let l = await scheduler.createHotObservable([
            .next(150, 1),
            .next(210, 2),
            .next(220, 3),
            .next(230, 4),
            .next(240, 5),
            .completed(250)
            ])
        
        let r = await scheduler.createHotObservable([
            .next(150, 1),
            ])
        
        let res = await scheduler.start {
            await l.take(until: r)
        }
        
        XCTAssertEqual(res.events, [
            .next(210, 2),
            .next(220, 3),
            .next(230, 4),
            .next(240, 5),
            .completed(250)
            ])
        
        XCTAssertEqual(l.subscriptions, [
            Subscription(200, 250)
            ])
        
        XCTAssertEqual(r.subscriptions, [
            Subscription(200, 250)
            ])
    }
    
    func testTakeUntil_Preempt_Never_Next() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let l = await scheduler.createHotObservable([
            .next(150, 1),
            ])
        
        let r = await scheduler.createHotObservable([
            .next(150, 1),
            .next(225, 2),
            .completed(250)
            ])
        
        let res = await scheduler.start {
            await l.take(until: r)
        }
        
        XCTAssertEqual(res.events, [
            .completed(225)
            ])
        
        XCTAssertEqual(l.subscriptions, [
            Subscription(200, 225)
            ])
        
        XCTAssertEqual(r.subscriptions, [
            Subscription(200, 225)
            ])
    }
    
    func testTakeUntil_Preempt_Never_Error() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let l = await scheduler.createHotObservable([
            .next(150, 1),
            ])
        
        let r = await scheduler.createHotObservable([
            .next(150, 1),
            .error(225, testError)
            ])
        
        let res = await scheduler.start {
            await l.take(until: r)
        }
        
        XCTAssertEqual(res.events, [
            .error(225, testError)
            ])
        
        XCTAssertEqual(l.subscriptions, [
            Subscription(200, 225)
            ])
        
        XCTAssertEqual(r.subscriptions, [
            Subscription(200, 225)
            ])
    }

    func testTakeUntil_NoPreempt_Never_Empty() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let l = await scheduler.createHotObservable([
            .next(150, 1),
            ])
        
        let r = await scheduler.createHotObservable([
            .next(150, 1),
            .completed(225)
            ])
        
        let res = await scheduler.start {
            await l.take(until: r)
        }
        
        XCTAssertEqual(res.events, [
            ])
        
        XCTAssertEqual(l.subscriptions, [
            Subscription(200, 1000)
            ])
        
        XCTAssertEqual(r.subscriptions, [
            Subscription(200, 225)
            ])
    }
    
    func testTakeUntil_NoPreempt_Never_Never() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let l = await scheduler.createHotObservable([
            .next(150, 1),
            ])
        
        let r = await scheduler.createHotObservable([
            .next(150, 1),
            ])
        
        let res = await scheduler.start {
            await l.take(until: r)
        }
        
        XCTAssertEqual(res.events, [
            ])
        
        XCTAssertEqual(l.subscriptions, [
            Subscription(200, 1000)
            ])
        
        XCTAssertEqual(r.subscriptions, [
            Subscription(200, 1000)
            ])
    }
    
    func testTakeUntil_Preempt_BeforeFirstProduced() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let l = await scheduler.createHotObservable([
            .next(150, 1),
            .next(230, 2),
            .completed(240)
            ])
        
        let r = await scheduler.createHotObservable([
            .next(150, 1),
            .next(210, 2),
            .completed(220)
            ])
        
        let res = await scheduler.start {
            await l.take(until: r)
        }
        
        XCTAssertEqual(res.events, [
            .completed(210)
            ])
        
        XCTAssertEqual(l.subscriptions, [
            Subscription(200, 210)
            ])
        
        XCTAssertEqual(r.subscriptions, [
            Subscription(200, 210)
            ])
    }
    
    func testTakeUntil_Preempt_BeforeFirstProduced_RemainSilentAndProperlyDisposed() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let l = await scheduler.createHotObservable([
            .next(150, 1),
            .error(215, testError),
            .completed(240)
            ])
        
        let r = await scheduler.createHotObservable([
            .next(150, 1),
            .next(210, 2),
            .completed(220)
            ])
        
        var sourceNotDisposed = false
        
        let res = await scheduler.start {
            await l.do(onNext: { _ in sourceNotDisposed = true }).take(until: r)
        }
        
        XCTAssertEqual(res.events, [
            .completed(210)
            ])
        
        XCTAssertFalse(sourceNotDisposed)
    }
    
    func testTakeUntil_NoPreempt_AfterLastProduced_ProperlyDisposed() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let l = await scheduler.createHotObservable([
            .next(150, 1),
            .next(230, 2),
            .completed(240)
            ])
        
        let r = await scheduler.createHotObservable([
            .next(150, 1),
            .next(250, 2),
            .completed(260)
            ])
        
        var sourceNotDisposed = false
        
        let res = await scheduler.start {
            await l.take(until: r.do(onNext: { _ in sourceNotDisposed = true }))
        }
        
        XCTAssertEqual(res.events, [
            .next(230, 2),
            .completed(240)
            ])
        
        XCTAssertFalse(sourceNotDisposed)
    }
    
    func testTakeUntil_Error_Some() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let l = await scheduler.createHotObservable([
            .next(150, 1),
            .error(225, testError)
            ])
        
        let r = await scheduler.createHotObservable([
            .next(150, 1),
            .next(240, 2),
            ])
        
        let sourceNotDisposed = false
        
        let res = await scheduler.start {
            await l.take(until: r)
        }
        
        XCTAssertEqual(res.events, [
            .error(225, testError),
            ])
        
        XCTAssertFalse(sourceNotDisposed)
    }

    #if TRACE_RESOURCES
    func testTakeUntil1ReleasesResourcesOnComplete() async {
        let scheduler = await TestScheduler(initialClock: 0)
        _ = await Observable.just(1).delay(.seconds(10), scheduler: scheduler).take(until: Observable.just(1)).subscribe()
        await scheduler.start()
        }

    func testTakeUntil2ReleasesResourcesOnComplete() async {
        let scheduler = await TestScheduler(initialClock: 0)
        _ = await Observable.just(1).take(until: Observable.just(1).delay(.seconds(10), scheduler: scheduler)).subscribe()
        await scheduler.start()
        }

    func testTakeUntil1ReleasesResourcesOnError() async {
        let scheduler = await TestScheduler(initialClock: 0)
        _ = await Observable<Int>.never().timeout(.seconds(20), scheduler: scheduler).take(until: Observable<Int>.never()).subscribe()
        await scheduler.start()
        }

    func testTakeUntil2ReleasesResourcesOnError() async {
        let scheduler = await TestScheduler(initialClock: 0)
        _ = await Observable<Int>.never().take(until: Observable<Int>.never().timeout(.seconds(20), scheduler: scheduler)).subscribe()
        await scheduler.start()
        }
    #endif
}

// MARK: TakeUntil Predicate Tests - Exclusive
extension ObservableTakeUntilTest {
    func testTakeUntilPredicate_Exclusive_Preempt_SomeData_Next() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let l = await scheduler.createHotObservable([
            .next(150, 1),
            .next(210, 2),
            .next(220, 3),
            .next(230, 4),
            .next(240, 5),
            .completed(250)
            ])

        let res = await scheduler.start {
            await l.take(until: { $0 == 4 }, behavior: .exclusive)
        }

        XCTAssertEqual(res.events, [
            .next(210, 2),
            .next(220, 3),
            .completed(230)
        ])

        XCTAssertEqual(l.subscriptions, [
            Subscription(200, 230)
        ])
    }

    func testTakeUntilPredicate_Exclusive_Preempt_SomeData_Error() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let l = await scheduler.createHotObservable([
            .next(150, 1),
            .next(210, 2),
            .next(220, 3),
            .error(225, testError)
        ])

        let res = await scheduler.start {
            await l.take(until: { $0 == 4 }, behavior: .exclusive)
        }

        XCTAssertEqual(res.events, [
            .next(210, 2),
            .next(220, 3),
            .error(225, testError)
        ])

        XCTAssertEqual(l.subscriptions, [
            Subscription(200, 225)
        ])
    }

    func testTakeUntilPredicate_Exclusive_AlwaysFailingPredicate() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let l = await scheduler.createHotObservable([
            .next(150, 1),
            .next(210, 2),
            .next(220, 3),
            .next(230, 4),
            .next(240, 5),
            .completed(250)
        ])

        let res = await scheduler.start {
            await l.take(until: { _ in false }, behavior: .exclusive)
        }

        XCTAssertEqual(res.events, [
            .next(210, 2),
            .next(220, 3),
            .next(230, 4),
            .next(240, 5),
            .completed(250)
        ])

        XCTAssertEqual(l.subscriptions, [
            Subscription(200, 250)
        ])
    }

    func testTakeUntilPredicate_Exclusive_ImmediatelySuccessfulPredicate() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let l = await scheduler.createHotObservable([
            .next(150, 1),
            .next(210, 2),
            .next(220, 3),
            .next(230, 4),
            .next(240, 5),
            .completed(250)
        ])

        let res = await scheduler.start {
            await l.take(until: { _ in true }, behavior: .exclusive)
        }

        XCTAssertEqual(res.events, [
            .completed(210)
        ])

        XCTAssertEqual(l.subscriptions, [
            Subscription(200, 210)
        ])
    }
}

// MARK: TakeUntil Predicate Tests - Inclusive
extension ObservableTakeUntilTest {
    func testTakeUntilPredicate_Inclusive_Preempt_SomeData_Next() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let l = await scheduler.createHotObservable([
            .next(150, 1),
            .next(210, 2),
            .next(220, 3),
            .next(230, 4),
            .next(240, 5),
            .completed(250)
            ])

        let res = await scheduler.start {
            await l.take(until: { $0 == 4 }, behavior: .inclusive)
        }

        XCTAssertEqual(res.events, [
            .next(210, 2),
            .next(220, 3),
            .next(230, 4),
            .completed(230)
            ])

        XCTAssertEqual(l.subscriptions, [
            Subscription(200, 230)
            ])
    }

    func testTakeUntilPredicate_Inclusive_Preempt_SomeData_Error() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let l = await scheduler.createHotObservable([
            .next(150, 1),
            .next(210, 2),
            .next(220, 3),
            .error(225, testError)
            ])

        let res = await scheduler.start {
            await l.take(until: { $0 == 4 }, behavior: .inclusive)
        }

        XCTAssertEqual(res.events, [
            .next(210, 2),
            .next(220, 3),
            .error(225, testError)
            ])

        XCTAssertEqual(l.subscriptions, [
            Subscription(200, 225)
            ])
    }

    func testTakeUntilPredicate_Inclusive_AlwaysFailingPredicate() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let l = await scheduler.createHotObservable([
            .next(150, 1),
            .next(210, 2),
            .next(220, 3),
            .next(230, 4),
            .next(240, 5),
            .completed(250)
            ])

        let res = await scheduler.start {
            await l.take(until: { _ in false }, behavior: .inclusive)
        }

        XCTAssertEqual(res.events, [
            .next(210, 2),
            .next(220, 3),
            .next(230, 4),
            .next(240, 5),
            .completed(250)
            ])

        XCTAssertEqual(l.subscriptions, [
            Subscription(200, 250)
            ])
    }

    func testTakeUntilPredicate_Inclusive_ImmediatelySuccessfulPredicate() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let l = await scheduler.createHotObservable([
            .next(150, 1),
            .next(210, 2),
            .next(220, 3),
            .next(230, 4),
            .next(240, 5),
            .completed(250)
            ])

        let res = await scheduler.start {
            await l.take(until: { _ in true }, behavior: .inclusive)
        }

        XCTAssertEqual(res.events, [
            .next(210, 2),
            .completed(210)
            ])

        XCTAssertEqual(l.subscriptions, [
            Subscription(200, 210)
            ])
    }
}

