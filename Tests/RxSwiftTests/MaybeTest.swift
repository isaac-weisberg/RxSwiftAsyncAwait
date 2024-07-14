//
//  MaybeTest.swift
//  Tests
//
//  Created by Krunoslav Zaher on 9/17/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

import XCTest
import RxSwift
import RxTest

class MaybeTest : RxTest {

}

// maybe
extension MaybeTest {
    func testMaybe_Subscription_success() async {
        let xs = await Maybe.just(1)

        var events: [MaybeEvent<Int>] = []

        _ = await xs.subscribe { event in
            events.append(event)
        }

        XCTAssertEqual(events, [.success(1)])
    }

    func testMaybe_Subscription_completed() async {
        let xs = await Maybe<Int>.empty()

        var events: [MaybeEvent<Int>] = []

        _ = await xs.subscribe { event in
            events.append(event)
        }

        XCTAssertEqual(events, [.completed])
    }

    func testMaybe_Subscription_error() async {
        let xs = await Maybe<Int>.error(testError)

        var events: [MaybeEvent<Int>] = []

        _ = await xs.subscribe { event in
            events.append(event)
        }

        XCTAssertEqual(events, [.error(testError)])
    }

    func testMaybe_Subscription_onDisposed() async {
        // Given
        let scheduler = await TestScheduler(initialClock: 0)
        let res = scheduler.createObserver(Int.self)
        var observer: ((MaybeEvent<Int>) async -> Void)!
        var subscription: Disposable!
        var onDisposesCalled = 0
        // When
        await scheduler.scheduleAt(201) {
            subscription = await Maybe<Int>.create {
                observer = $0
                return Disposables.create()
            }
            .subscribe(onDisposed: { onDisposesCalled += 1 })
        }
        await scheduler.scheduleAt(202) {
            await subscription.dispose()
        }
        await scheduler.scheduleAt(203) {
            await observer(.error(testError))
        }
        await scheduler.start()
        // Then
        XCTAssertTrue(res.events.isEmpty)
        XCTAssertEqual(onDisposesCalled, 1)
    }

    func testMaybe_Subscription_onDisposed_success() async {
        // Given
        let maybe = await Maybe.just(1)
        var onDisposedCalled = 0
        // When
        _ = await maybe.subscribe(onDisposed: {
            onDisposedCalled += 1
        })
        // Then
        XCTAssertEqual(onDisposedCalled, 1)
    }

    func testMaybe_Subscription_onDisposed_completed() async {
        // Given
        let maybe = await Maybe<Int>.empty()
        var onDisposedCalled = 0
        // When
        _ = await maybe.subscribe(onDisposed: {
            onDisposedCalled += 1
        })
        // Then
        XCTAssertEqual(onDisposedCalled, 1)
    }

    func testMaybe_Subscription_onDisposed_error() async {
        // Given
        let single = await Maybe<Int>.error(testError)
        var onDisposedCalled = 0
        // When
        _ = await single.subscribe(onDisposed: {
            onDisposedCalled += 1
        })
        // Then
        XCTAssertEqual(onDisposedCalled, 1)
    }

    func testMaybe_create_success() async {
        let scheduler = await TestScheduler(initialClock: 0)

        var observer: ((MaybeEvent<Int>) async -> Void)! = nil

        var disposedTime: Int?

        await scheduler.scheduleAt(201, action: {
            await observer(.success(1))
        })
        await scheduler.scheduleAt(202, action: {
            await observer(.success(1))
        })
        await scheduler.scheduleAt(203, action: {
            await observer(.error(testError))
        })
        await scheduler.scheduleAt(204, action: {
            await observer(.completed)
        })

        let res = await scheduler.start {
            await Maybe<Int>.create { _observer in
                observer = _observer
                return await Disposables.create {
                    disposedTime = scheduler.clock
                }
            }
        }

        XCTAssertEqual(res.events, [
            .next(201, 1),
            .completed(201)
            ])

        XCTAssertEqual(disposedTime, 201)
    }

    func testMaybe_create_completed() async {
        let scheduler = await TestScheduler(initialClock: 0)

        var observer: ((MaybeEvent<Int>) async -> Void)! = nil

        var disposedTime: Int?

        await scheduler.scheduleAt(201, action: {
            await observer(.completed)
        })
        await scheduler.scheduleAt(202, action: {
            await observer(.success(1))
        })
        await scheduler.scheduleAt(203, action: {
            await observer(.error(testError))
        })
        await scheduler.scheduleAt(204, action: {
            await observer(.completed)
        })

        let res = await scheduler.start {
            await Maybe<Int>.create { _observer in
                observer = _observer
                return await Disposables.create {
                    disposedTime = scheduler.clock
                }
            }
        }

        XCTAssertEqual(res.events, [
            .completed(201)
            ])

        XCTAssertEqual(disposedTime, 201)
    }

    func testMaybe_create_error() async {
        let scheduler = await TestScheduler(initialClock: 0)

        var observer: ((MaybeEvent<Int>) async -> Void)! = nil

        var disposedTime: Int?

        await scheduler.scheduleAt(201, action: {
            await observer(.error(testError))
        })
        await scheduler.scheduleAt(202, action: {
            await observer(.success(1))
        })
        await scheduler.scheduleAt(203, action: {
            await observer(.error(testError))
        })

        let res = await scheduler.start {
            await Maybe<Int>.create { _observer in
                observer = _observer
                return await Disposables.create {
                    disposedTime = scheduler.clock
                }
            }
        }

        XCTAssertEqual(res.events, [
            .error(201, testError)
            ])

        XCTAssertEqual(disposedTime, 201)
    }

    func testMaybe_create_disposing() async {
        let scheduler = await TestScheduler(initialClock: 0)

        var observer: ((MaybeEvent<Int>) async -> Void)! = nil
        var disposedTime: Int?
        var subscription: Disposable! = nil
        let res = scheduler.createObserver(Int.self)

        await scheduler.scheduleAt(201, action: {
            subscription = await Maybe<Int>.create { _observer in
                observer = _observer
                return await Disposables.create {
                    disposedTime = scheduler.clock
                }
                }
                .asObservable()
                .subscribe(res)
        })
        await scheduler.scheduleAt(202, action: {
            await subscription.dispose()
        })
        await scheduler.scheduleAt(203, action: {
            await observer(.success(1))
        })
        await scheduler.scheduleAt(204, action: {
            await observer(.error(testError))
        })

        await scheduler.start()

        XCTAssertEqual(res.events, [
            ])

        XCTAssertEqual(disposedTime, 202)
    }
}

extension MaybeTest {
    func test_just_producesElement() async {
        let result = try! await (Maybe.just(1) as Maybe<Int>).toBlocking().first()!
        XCTAssertEqual(result, 1)
    }

    func test_just2_producesElement() async {
        let result = try! await (Maybe.just(1, scheduler: CurrentThreadScheduler.instance) as Maybe<Int>).toBlocking().first()!
        XCTAssertEqual(result, 1)
    }

    func test_error_fails() async {
        do {
            _ = try await (Maybe<Int>.error(testError) as Maybe<Int>).toBlocking().first()
            XCTFail()
        }
        catch let e {
            XCTAssertEqual(e as! TestError, testError)
        }
    }

    func test_never_producesElement() async {
        var event: MaybeEvent<Int>?
        let subscription = await (Maybe<Int>.never() as Maybe<Int>).subscribe { _event in
            event = _event
        }

        XCTAssertNil(event)
        await subscription.dispose()
    }

    func test_deferred() async {
        let result = try! await (Maybe.deferred { await Maybe.just(1) } as Maybe<Int>).toBlocking().toArray()
        XCTAssertEqual(result, [1])
    }

    func test_delaySubscription() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let res = await scheduler.start {
            await Maybe.just(1).delaySubscription(.seconds(2), scheduler: scheduler)
        }

        XCTAssertEqual(res.events, [
            .next(202, 1),
            .completed(202)
            ])
    }

    func test_delay() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let res = await scheduler.start {
            await Maybe.just(1).delay(.seconds(2), scheduler: scheduler)
        }

        XCTAssertEqual(res.events, [
            .next(202, 1),
            .completed(203)
            ])
    }

    func test_observeOn() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let res = await scheduler.start {
            await Maybe.just(1).observe(on:scheduler)
        }

        XCTAssertEqual(res.events, [
            .next(201, 1),
            .completed(202)
            ])
    }

    func test_subscribeOn() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let res = await scheduler.start {
            await Maybe.just(1).subscribe(on: scheduler)
        }

        XCTAssertEqual(res.events, [
            .next(201, 1),
            .completed(201)
            ])
    }

    func test_catchError() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let res = await scheduler.start {
            await Maybe.error(testError).catch { _ in await Maybe.just(2) }
        }

        XCTAssertEqual(res.events, [
            .next(200, 2),
            .completed(200)
            ])
    }

    func test_catchAndReturn() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let res = await scheduler.start {
            await Maybe.error(testError).catchAndReturn(2)
        }

        XCTAssertEqual(res.events, [
            .next(200, 2),
            .completed(200)
        ])
    }

    func test_retry() async {
        let scheduler = await TestScheduler(initialClock: 0)

        var isFirst = true
        let res = await scheduler.start {
            await Maybe.error(testError)
                .catch { e in
                    defer {
                        isFirst = false
                    }
                    if isFirst {
                        return await Maybe.error(e)
                    }

                    return await Maybe.just(2)
                }
                .retry(2) as Maybe<Int>
        }

        XCTAssertEqual(res.events, [
            .next(200, 2),
            .completed(200)
            ])
    }

    func test_retryWhen1() async {
        let scheduler = await TestScheduler(initialClock: 0)

        var isFirst = true
        let res = await scheduler.start {
            await Maybe.error(testError)
                .catch { e in
                    defer {
                        isFirst = false
                    }
                    if isFirst {
                        return await Maybe.error(e)
                    }

                    return await Maybe.just(2)
                }
                .retry { (e: Observable<Error>) in
                    return e
                } as Maybe<Int>
        }

        XCTAssertEqual(res.events, [
            .next(200, 2),
            .completed(200)
            ])
    }

    func test_retryWhen2() async {
        let scheduler = await TestScheduler(initialClock: 0)

        var isFirst = true
        let res = await scheduler.start {
            await Maybe.error(testError)
                .catch { e in
                    defer {
                        isFirst = false
                    }
                    if isFirst {
                        return await Maybe.error(e)
                    }

                    return await Maybe.just(2)
                }
                .retry { e in
                    return e
                } as Maybe<Int>
        }

        XCTAssertEqual(res.events, [
            .next(200, 2),
            .completed(200)
            ])
    }

    func test_debug() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let res = await scheduler.start {
            await Maybe.just(1).debug()
        }

        XCTAssertEqual(res.events, [
            .next(200, 1),
            .completed(200)
            ])
    }

    func test_using() async {
        let scheduler = await TestScheduler(initialClock: 0)

        var disposeInvoked = 0
        var createInvoked = 0

        var disposable: MockDisposable!
        var xs: TestableObservable<Int>!
        var _d: MockDisposable!

        let res = await scheduler.start {
            await Maybe.using({ () -> MockDisposable in
                disposeInvoked += 1
                disposable = MockDisposable(scheduler: scheduler)
                return disposable
            }, primitiveSequenceFactory: { (d: MockDisposable) -> Maybe<Int> in
                _d = d
                createInvoked += 1
                xs = await scheduler.createColdObservable([
                    .next(100, scheduler.clock),
                    .completed(100)
                    ])
                return await xs.asObservable().asMaybe()
            })
        }

        XCTAssert(disposable === _d)

        XCTAssertEqual(1, createInvoked)
        XCTAssertEqual(1, disposeInvoked)

        XCTAssertEqual(res.events, [
            .next(300, 200),
            .completed(300)
            ])

        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 300)
            ])

        XCTAssertEqual(disposable.ticks, [
            200,
            300
            ])
    }

    func test_timeout() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createColdObservable([
            .next(10, 1),
            .completed(20)
            ]).asMaybe()

        let res = await scheduler.start {
            await xs.timeout(.seconds(5), scheduler: scheduler)
        }

        XCTAssertEqual(res.events, [
            .error(205, RxError.timeout)
            ])
    }

    func test_timeout_other() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createColdObservable([
            .next(10, 1),
            .completed(20)
        ]).asMaybe()

        let xs2 = await scheduler.createColdObservable([
            .next(20, 2),
            .completed(20)
        ]).asMaybe()

        let res = await scheduler.start {
            await xs.timeout(.seconds(5), other: xs2, scheduler: scheduler)
        }

        XCTAssertEqual(res.events, [
            .next(225, 2),
            .completed(225)
            ])
    }

    func test_timeout_succeeds() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createColdObservable([
            .next(10, 1),
            .completed(20)
        ]).asMaybe()

        let res = await scheduler.start {
            await xs.timeout(.seconds(30), scheduler: scheduler)
        }

        XCTAssertEqual(res.events, [
            .next(220, 1),
            .completed(220)
            ])
    }

    func test_timeout_other_succeeds() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createColdObservable([
            .next(10, 1),
            .completed(20)
        ]).asMaybe()

        let xs2 = await scheduler.createColdObservable([
            .next(20, 2),
            .completed(20)
        ]).asMaybe()

        let res = await scheduler.start {
            await xs.timeout(.seconds(30), other: xs2, scheduler: scheduler)
        }

        XCTAssertEqual(res.events, [
            .next(220, 1),
            .completed(220)
            ])
    }
}

extension MaybeTest {
    func test_timer() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let res = await scheduler.start {
            await Maybe<Int>.timer(.seconds(2), scheduler: scheduler)
        }

        XCTAssertEqual(res.events, [
            .next(202, 0),
            .completed(202)
            ])
    }
}

extension MaybeTest {
    func test_do() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let res = await scheduler.start {
            await Maybe<Int>.just(1).do(onNext: { _ in () }, afterNext: { _ in () }, onError: { _ in () }, afterError: { _ in }, onSubscribe: { () in () }, onSubscribed: { () in () }, onDispose: { () in () })
        }

        XCTAssertEqual(res.events, [
            .next(200, 1),
            .completed(200)
            ])
    }

    func test_filter() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let res = await scheduler.start {
            await Maybe<Int>.just(1).filter { _ in false }
        }

        XCTAssertEqual(res.events, [
            .completed(200)
            ])
    }

    func test_map() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let res = await scheduler.start {
            await Maybe<Int>.just(1).map { $0 * 2 }
        }

        XCTAssertEqual(res.events, [
            .next(200, 2),
            .completed(200)
            ])
    }

    func test_compactMap() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let res = await scheduler.start {
            await (Maybe<String>.just("1").compactMap(Int.init) as Maybe<Int>).asObservable()
        }
        
        XCTAssertEqual(res.events, [
            .next(200, 1),
            .completed(200)
            ])
    }

    func test_compactMapNil() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let res = await scheduler.start {
            await (Maybe<String>.just("a").compactMap(Int.init) as Maybe<Int>).asObservable()
        }
        
        XCTAssertEqual(res.events, [
            .completed(200)
            ])
    }
    
    func test_flatMap() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let res = await scheduler.start {
            await Maybe<Int>.just(1).flatMap { await .just($0 * 2) }
        }

        XCTAssertEqual(res.events, [
            .next(200, 2),
            .completed(200)
            ])
    }

    func test_ifEmptyDefault() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let res = await scheduler.start {
            await Maybe<Int>.empty().ifEmpty(default: 5) as Single<Int>
        }

        XCTAssertEqual(res.events, [
            .next(200, 5),
            .completed(200)
            ])
    }

    func test_ifEmptySwitchToMaybe() async {
        let scheduler = await TestScheduler(initialClock: 0)
        let source = await Maybe<Int>.empty()
        let switchSource = await Maybe.just(10)

        let res = await scheduler.start {
            await source.ifEmpty(switchTo: switchSource) as Maybe<Int>
        }

        XCTAssertEqual(res.events, [
            .next(200, 10),
            .completed(200)
            ])
    }

    func test_ifEmptySwitchToSingle() async {
        let scheduler = await TestScheduler(initialClock: 0)
        let source = await Maybe<Int>.empty()
        let switchSource = await Single.just(10)

        let res = await scheduler.start {
            await source.ifEmpty(switchTo: switchSource)
        }

        XCTAssertEqual(res.events, [
            .next(200, 10),
            .completed(200)
            ])
    }
}

extension MaybeTest {
    func test_zip_tuple() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let res = await scheduler.start {
            await (Maybe.zip(Maybe.just(1), Maybe.just(2)) as Maybe<(Int, Int)>).map { $0.0 + $0.1 }
        }

        XCTAssertEqual(res.events, [
            .next(200, 3),
            .completed(200)
            ])
    }

    func test_zip_resultSelector() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let res = await scheduler.start {
            await Maybe.zip(Maybe.just(1), Maybe.just(2)) { $0 + $1 }
        }

        XCTAssertEqual(res.events, [
            .next(200, 3),
            .completed(200)
            ])
    }
}

extension MaybeTest {
    func testDefaultErrorHandler() async {
        var loggedErrors = [TestError]()

        _ = await Maybe<Int>.error(testError).subscribe()
        XCTAssertEqual(loggedErrors, [])

        let originalErrorHandler = await Hooks.getDefaultErrorHandler()

        await Hooks.setDefaultErrorHandler { _, error in
            loggedErrors.append(error as! TestError)
        }

        _ = await Maybe<Int>.error(testError).subscribe()
        XCTAssertEqual(loggedErrors, [testError])

        await Hooks.setDefaultErrorHandler(originalErrorHandler)

        _ = await Maybe<Int>.error(testError).subscribe()
        XCTAssertEqual(loggedErrors, [testError])
    }
}



