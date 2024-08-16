//
//  Observable+PrimitiveSequenceTest.swift
//  Tests
//
//  Created by Krunoslav Zaher on 9/17/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

import XCTest
import RxSwift
import RxTest

class ObservablePrimitiveSequenceTest : RxTest {

}

extension ObservablePrimitiveSequenceTest {
    func testAsSingle_Empty() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(150, 1),
            .completed(250),
            .error(260, testError)
            ])

        let res = await scheduler.start {
            await xs.asSingle()
        }

        XCTAssertEqual(res.events, [
            .error(250, RxError.noElements)
            ])

        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 250)
            ])
    }

    func testAsSingle_One() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(150, 1),
            .next(210, 2),
            .completed(250),
            .error(260, testError)
            ])

        let res = await scheduler.start {
            await xs.asSingle()
        }

        XCTAssertEqual(res.events, [
            .next(250, 2),
            .completed(250)
            ])

        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 250)
            ])
    }

    func testAsSingle_Many() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(150, 1),
            .next(210, 2),
            .next(220, 3),
            .completed(250),
            .error(260, testError)
            ])

        let res = await scheduler.start {
            await xs.asSingle()
        }

        XCTAssertEqual(res.events, [
            .error(220, RxError.moreThanOneElement)
            ])

        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 220)
            ])
    }

    func testAsSingle_Error() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(150, 1),
            .error(210, testError)
            ])

        let res = await scheduler.start {
            await xs.asSingle()
        }

        XCTAssertEqual(res.events, [
            .error(210, testError)
            ])

        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 210)
            ])
    }

    func testAsSingle_Error2() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(150, 1),
            .next(205, 2),
            .error(210, testError)
            ])

        let res = await scheduler.start {
            await xs.asSingle()
        }

        XCTAssertEqual(res.events, [
            .error(210, testError)
            ])

        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 210)
            ])
    }

    func testAsSingle_subscribeOnSuccess() async {
        var events: [SingleEvent<Int>] = []

        _ = await Single.just(1).subscribe(onSuccess: { element in
            events.append(.success(element))
        }, onFailure: { error in
            events.append(.failure(error))
        })

        XCTAssertEqual(events, [.success(1)])
    }

    func testAsSingle_subscribeOnError() async {
        var events: [SingleEvent<Int>] = []

        _ = await Single.error(testError).subscribe(onSuccess: { element in
            events.append(.success(element))
        }, onFailure: { error in
            events.append(.failure(error))
        })

        XCTAssertEqual(events, [.failure(testError)])
    }

    #if TRACE_RESOURCES
    func testAsSingleReleasesResourcesOnComplete() async {
        _ = await Observable<Int>.just(1).asSingle().subscribe({ _ in })
    }

    func testAsSingleReleasesResourcesOnError1() async {
        _ = await Observable<Int>.error(testError).asSingle().subscribe({ _ in })
    }

    func testAsSingleReleasesResourcesOnError2() async {
        _ = await Observable<Int>.of(1, 2).asSingle().subscribe({ _ in })
    }
    #endif
}

extension ObservablePrimitiveSequenceTest {
    func testFirst_Empty() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let xs = await scheduler.createHotObservable([
            .next(150, 1),
            .completed(250),
            .error(260, testError)
            ])
        
        let res: TestableObserver<Int> = await scheduler.start {
            await xs.first().map { $0 ?? -1 }
        }
        
        XCTAssertEqual(res.events, [
            .next(250, -1),
            .completed(250)
            ])
        
        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 250)
            ])
    }
    
    func testFirst_One() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let xs = await scheduler.createHotObservable([
            .next(150, 1),
            .next(210, 2),
            .completed(250),
            .error(260, testError)
            ])
        
        let res = await scheduler.start {
            await xs.first().map { $0 ?? -1 }
        }
        
        XCTAssertEqual(res.events, [
            .next(210, 2),
            .completed(210)
            ])
        
        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 210)
            ])
    }
    
    func testFirst_Many() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let xs = await scheduler.createHotObservable([
            .next(150, 1),
            .next(210, 2),
            .next(220, 3),
            .completed(250),
            .error(260, testError)
            ])
        
        let res = await scheduler.start {
            await xs.first().map { $0 ?? -1 }
        }
        
        XCTAssertEqual(res.events, [
            .next(210, 2),
            .completed(210)
            ])
        
        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 210)
            ])
    }
    
    func testFirst_ManyWithoutCompletion() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let xs = await scheduler.createHotObservable([
            .next(150, 1),
            .next(160, 2),
            .next(280, 3),
            .next(250, 4),
            .next(300, 5)
            ])
        
        let res = await scheduler.start {
            await xs.first().map { $0 ?? -1 }
        }
        
        XCTAssertEqual(res.events, [
            .next(250, 4),
            .completed(250)
            ])
        
        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 250)
            ])
    }
    
    func testFirst_Error() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let xs = await scheduler.createHotObservable([
            .next(150, 1),
            .error(210, testError)
            ])
        
        let res = await scheduler.start {
            await xs.first().map { $0 ?? -1 }
        }
        
        XCTAssertEqual(res.events, [
            .error(210, testError)
            ])
        
        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 210)
            ])
    }
    
    #if TRACE_RESOURCES
    func testFirstReleasesResourcesOnComplete() async {
        _ = await Observable<Int>.just(1).first().subscribe({ _ in })
    }
    
    func testFirstReleasesResourcesOnError1() async {
        _ = await Observable<Int>.error(testError).first().subscribe({ _ in })
    }
    #endif
}

extension ObservablePrimitiveSequenceTest {
    func testAsMaybe_Empty() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(150, 1),
            .completed(250),
            .error(260, testError)
            ])

        let res = await scheduler.start {
            await xs.asMaybe()
        }

        XCTAssertEqual(res.events, [
            .completed(250)
            ])

        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 250)
            ])
    }

    func testAsMaybe_One() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(150, 1),
            .next(210, 2),
            .completed(250),
            .error(260, testError)
            ])

        let res = await scheduler.start {
            await xs.asMaybe()
        }

        XCTAssertEqual(res.events, [
            .next(250, 2),
            .completed(250)
            ])

        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 250)
            ])
    }

    func testAsMaybe_Many() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(150, 1),
            .next(210, 2),
            .next(220, 3),
            .completed(250),
            .error(260, testError)
            ])

        let res = await scheduler.start {
            await xs.asMaybe()
        }

        XCTAssertEqual(res.events, [
            .error(220, RxError.moreThanOneElement)
            ])

        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 220)
            ])
    }

    func testAsMaybe_Error() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(150, 1),
            .error(210, testError)
            ])

        let res = await scheduler.start {
            await xs.asMaybe()
        }

        XCTAssertEqual(res.events, [
            .error(210, testError)
            ])

        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 210)
            ])
    }

    func testAsMaybe_Error2() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(150, 1),
            .next(205, 2),
            .error(210, testError)
            ])

        let res = await scheduler.start {
            await xs.asMaybe()
        }

        XCTAssertEqual(res.events, [
            .error(210, testError)
            ])

        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 210)
            ])
    }

    func testAsMaybe_subscribeOnSuccess() async {
        var events: [MaybeEvent<Int>] = []

        _ = await Maybe.just(1).subscribe(onSuccess: { element in
            events.append(.success(element))
        }, onError: { error in
            events.append(.error(error))
        }, onCompleted: {
            events.append(.completed)
        })

        XCTAssertEqual(events, [.success(1)])
    }

    func testAsMaybe_subscribeOnError() async {
        var events: [MaybeEvent<Int>] = []

        _ = await Maybe.error(testError).subscribe(onSuccess: { element in
            events.append(.success(element))
        }, onError: { error in
            events.append(.error(error))
        }, onCompleted: {
            events.append(.completed)
        })

        XCTAssertEqual(events, [.error(testError)])
    }

    func testAsMaybe_subscribeOnCompleted() async {
        var events: [MaybeEvent<Int>] = []

        _ = await Maybe.empty().subscribe(onSuccess: { element in
            events.append(.success(element))
        }, onError: { error in
            events.append(.error(error))
        }, onCompleted: {
            events.append(.completed)
        })

        XCTAssertEqual(events, [.completed])
    }

    #if TRACE_RESOURCES
    func testAsMaybeReleasesResourcesOnComplete1() async {
        _ = await Observable<Int>.empty().asMaybe().subscribe({ _ in })
    }

    func testAsMaybeReleasesResourcesOnComplete2() async {
        _ = await Observable<Int>.just(1).asMaybe().subscribe({ _ in })
    }

    func testAsMaybeReleasesResourcesOnError1() async {
        _ = await Observable<Int>.error(testError).asMaybe().subscribe({ _ in })
    }

    func testAsMaybeReleasesResourcesOnError2() async {
        _ = await Observable<Int>.of(1, 2).asMaybe().subscribe({ _ in })
    }
    #endif
}

extension ObservablePrimitiveSequenceTest {
    func testAsCompletable_Empty() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .completed(250, Never.self),
            .error(260, testError)
            ])

        let res = await scheduler.start {
            return await xs.asCompletable()
        }

        XCTAssertEqual(res.events, [
            .completed(250)
            ])

        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 250)
            ])
    }

    func testAsCompletable_Error() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .error(210, testError, Never.self)
            ])

        let res = await scheduler.start {
            return await xs.asCompletable()
        }

        XCTAssertEqual(res.events, [
            .error(210, testError)
            ])

        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 210)
            ])
    }

    func testAsCompletable_subscribeOnCompleted() async {
        var events: [CompletableEvent] = []

        _ = await Completable.empty().subscribe(onCompleted: {
            events.append(.completed)
        }, onError: { error in
            events.append(.error(error))
        })

        XCTAssertEqual(events, [.completed])
    }

    func testAsCompletable_subscribeOnError() async {
        var events: [CompletableEvent] = []

        _ = await Completable.error(testError).subscribe(onCompleted: {
            events.append(.completed)
        }, onError: { error in
            events.append(.error(error))
        })

        XCTAssertEqual(events, [.error(testError)])
    }

    #if TRACE_RESOURCES
    func testAsCompletableReleasesResourcesOnComplete() async {
        _ = await Observable<Never>.empty().asCompletable().subscribe({ _ in })
    }

    func testAsCompletableReleasesResourcesOnError() async {
        _ = await Observable<Never>.error(testError).asCompletable().subscribe({ _ in })
    }
    #endif

    func testCompletable_merge() async {
        let factories: [(Completable, Completable) async -> Completable] =
            [
                { ys1, ys2 in await Completable.zip(ys1, ys2) },
                { ys1, ys2 in await Completable.zip([ys1, ys2]) },
                { ys1, ys2 in await Completable.zip(AnyCollection([ys1, ys2])) },
            ]

        for factory in factories {
            let scheduler = await TestScheduler(initialClock: 0)

            let ys1 = await scheduler.createHotObservable([
                .completed(250, Never.self),
                .error(260, testError)
                ])

            let ys2 = await scheduler.createHotObservable([
                .completed(300, Never.self)
                ])

            let res = await scheduler.start {
                await factory(ys1.asCompletable(), ys2.asCompletable())
            }

            XCTAssertEqual(res.events, [
                .completed(300)
                ])

            XCTAssertEqual(ys1.subscriptions, [
                Subscription(200, 250),
                ])

            XCTAssertEqual(ys2.subscriptions, [
                Subscription(200, 300),
                ])
        }
    }

    func testCompletable_concat() async {
        let factories: [(Completable, Completable) async -> Completable] =
            [
                { ys1, ys2 in await Completable.concat(ys1, ys2) },
                { ys1, ys2 in await Completable.concat([ys1, ys2]) },
                { ys1, ys2 in await Completable.concat(AnyCollection([ys1, ys2])) },
                { ys1, ys2 in await ys1.concat(ys2) }
        ]

        for factory in factories {
            let scheduler = await TestScheduler(initialClock: 0)

            let ys1 = await scheduler.createHotObservable([
                .completed(250, Never.self),
                .error(260, testError)
                ])

            let ys2 = await scheduler.createHotObservable([
                .completed(300, Never.self)
                ])

            let res = await scheduler.start {
                await factory(ys1.asCompletable(), ys2.asCompletable())
            }

            XCTAssertEqual(res.events, [
                .completed(300)
                ])

            XCTAssertEqual(ys1.subscriptions, [
                Subscription(200, 250),
                ])

            XCTAssertEqual(ys2.subscriptions, [
                Subscription(250, 300),
                ])
        }
    }
}
