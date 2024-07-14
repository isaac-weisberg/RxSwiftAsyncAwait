//
//  CompletableTest.swift
//  Tests
//
//  Created by Krunoslav Zaher on 9/17/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

import XCTest
import RxSwift
import RxTest

class CompletableTest : RxTest {

}

// completable
extension CompletableTest {
    func testCompletable_Subscription_completed() async {
        let xs = await Completable.empty()

        var events: [CompletableEvent] = []

        _ = await xs.subscribe { event in
            events.append(event)
        }

        XCTAssertEqual(events, [.completed])
    }

    func testCompletable_Subscription_error() async {
        let xs = await Completable.error(testError)

        var events: [CompletableEvent] = []

        _ = await xs.subscribe { event in
            events.append(event)
        }

        XCTAssertEqual(events, [.error(testError)])
    }

    func testCompletable_Subscription_onDisposed() async {
        // Given
        let scheduler = await TestScheduler(initialClock: 0)
        let res = scheduler.createObserver(Void.self)
        var observer: ((CompletableEvent) async -> Void)!
        var subscription: Disposable!
        var onDisposesCalled = 0
        // When
        await scheduler.scheduleAt(201) {
            subscription = await Completable.create {
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

    func testCompletable_Subscription_onDisposed_completed() async {
        // Given
        let maybe = await Completable.empty()
        var onDisposedCalled = 0
        // When
        _ = await maybe.subscribe(onDisposed: {
            onDisposedCalled += 1
        })
        // Then
        XCTAssertEqual(onDisposedCalled, 1)
    }

    func testCompletable_Subscription_onDisposed_error() async {
        // Given
        let single = await Completable.error(testError)
        var onDisposedCalled = 0
        // When
        _ = await single.subscribe(onDisposed: {
            onDisposedCalled += 1
        })
        // Then
        XCTAssertEqual(onDisposedCalled, 1)
    }

    func testCompletable_create_completed() async {
        let scheduler = await TestScheduler(initialClock: 0)

        var observer: ((CompletableEvent) async -> Void)! = nil

        var disposedTime: Int?

        await scheduler.scheduleAt(201, action: {
            await observer(.completed)
        })
        await scheduler.scheduleAt(203, action: {
            await observer(.error(testError))
        })
        await scheduler.scheduleAt(204, action: {
            await observer(.completed)
        })

        let res = await scheduler.start {
            await Completable.create { _observer in
                observer = _observer
                return await Disposables.create {
                    disposedTime = scheduler.clock
                }
                }
        }

        XCTAssertEqual(res.events, [
            .completed(201, Never.self)
            ])

        XCTAssertEqual(disposedTime, 201)
    }

    func testCompletable_create_error() async {
        let scheduler = await TestScheduler(initialClock: 0)

        var observer: ((CompletableEvent) async -> Void)! = nil

        var disposedTime: Int?

        await scheduler.scheduleAt(201, action: {
            await observer(.error(testError))
        })
        await scheduler.scheduleAt(202, action: {
            await observer(.completed)
        })
        await scheduler.scheduleAt(203, action: {
            await observer(.error(testError))
        })

        let res = await scheduler.start {
            await Completable.create { _observer in
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

    func testCompletable_create_disposing() async {
        let scheduler = await TestScheduler(initialClock: 0)

        var observer: ((CompletableEvent) -> Void)! = nil
        var disposedTime: Int?
        var subscription: Disposable! = nil
        let res = scheduler.createObserver(Never.self)

        scheduler.scheduleAt(201, action: {
            subscription = Completable.create { _observer in
                observer = _observer
                return Disposables.create {
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
            observer(.completed)
        })
        await scheduler.scheduleAt(204, action: {
            observer(.error(testError))
        })

        await scheduler.start()

        XCTAssertEqual(res.events, [
            ])

        XCTAssertEqual(disposedTime, 202)
    }
}

extension CompletableTest {
    func test_error_fails() async {
        do {
            _ = try await Completable.error(testError).toBlocking().first()
            XCTFail()
        }
        catch let e {
            XCTAssertEqual(e as! TestError, testError)
        }
    }

    func test_never_producesElement() async {
        var event: CompletableEvent?
        let subscription = await Completable.never().subscribe { _event in
            event = _event
        }

        XCTAssertNil(event)
        await subscription.dispose()
    }

    func test_deferred() async {
        let result = try! await (Completable.deferred { await Completable.empty() } as Completable).toBlocking().toArray()
        XCTAssertEqual(result, [])
    }

    func test_delaySubscription() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let res = await scheduler.start {
            await Completable.empty().delaySubscription(.seconds(2), scheduler: scheduler)
        }

        XCTAssertEqual(res.events, [
            .completed(202)
            ])
    }

    func test_delay() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let res = await scheduler.start {
            await Completable.empty().delay(.seconds(2), scheduler: scheduler)
        }

        XCTAssertEqual(res.events, [
            .completed(202)
            ])
    }

    func test_observeOn() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let res = await scheduler.start {
            await Completable.empty().observe(on:scheduler)
        }

        XCTAssertEqual(res.events, [
            .completed(201)
            ])
    }

    func test_subscribeOn() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let res = await scheduler.start {
            await Completable.empty().subscribe(on: scheduler)
        }

        XCTAssertEqual(res.events, [
            .completed(201)
            ])
    }

    func test_catchError() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let res = await scheduler.start {
            await Completable.error(testError).catch { _ in await Completable.empty() }
        }

        XCTAssertEqual(res.events, [
            .completed(200)
            ])
    }

    func test_retry() async {
        let scheduler = await TestScheduler(initialClock: 0)

        var isFirst = true
        let res = await scheduler.start {
            await Completable.error(testError)
                .catch { e in
                    defer {
                        isFirst = false
                    }
                    if isFirst {
                        return await Completable.error(e)
                    }

                    return await Completable.empty()
                }
                .retry(2)
        }

        XCTAssertEqual(res.events, [
            .completed(200)
            ])
    }

    func test_retryWhen1() async {
        let scheduler = await TestScheduler(initialClock: 0)

        var isFirst = true
        let res = await scheduler.start {
            await Completable.error(testError)
                .catch { e in
                    defer {
                        isFirst = false
                    }
                    if isFirst {
                        return await Completable.error(e)
                    }

                    return await Completable.empty()
                }
                .retry { (e: Observable<Error>) in
                    return e
                }
        }

        XCTAssertEqual(res.events, [
            .completed(200)
            ])
    }

    func test_retryWhen2() async {
        let scheduler = await TestScheduler(initialClock: 0)

        var isFirst = true
        let res = await scheduler.start {
            await Completable.error(testError)
                .catch { e in
                    defer {
                        isFirst = false
                    }
                    if isFirst {
                        return await Completable.error(e)
                    }

                    return await Completable.empty()
                }
                .retry { e in
                    return e
                }
        }

        XCTAssertEqual(res.events, [
            .completed(200)
            ])
    }

    func test_debug() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let res = await scheduler.start {
            await Completable.empty().debug()
        }

        XCTAssertEqual(res.events, [
            .completed(200)
            ])
    }

    func test_using() async {
        let scheduler = await TestScheduler(initialClock: 0)

        var disposeInvoked = 0
        var createInvoked = 0

        var disposable: MockDisposable!
        var xs: TestableObservable<Never>!
        var _d: MockDisposable!

        let res = await scheduler.start {
            await Completable.using({ () -> MockDisposable in
                disposeInvoked += 1
                disposable = MockDisposable(scheduler: scheduler)
                return disposable
            }, primitiveSequenceFactory: { (d: MockDisposable) -> Completable in
                _d = d
                createInvoked += 1
                xs = await scheduler.createColdObservable([
                    .completed(100)
                    ])
                return await xs.asObservable().asCompletable()
            })
        }

        XCTAssert(disposable === _d)

        XCTAssertEqual(1, createInvoked)
        XCTAssertEqual(1, disposeInvoked)

        XCTAssertEqual(res.events, [
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
            .completed(20)
            ]).asCompletable()

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
            .completed(20)
            ]).asCompletable()

        let xs2 = await scheduler.createColdObservable([
            .completed(20)
            ]).asCompletable()

        let res = await scheduler.start {
            await xs.timeout(.seconds(5), other: xs2, scheduler: scheduler)
        }

        XCTAssertEqual(res.events, [
            .completed(225)
            ])
    }

    func test_timeout_succeeds() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createColdObservable([
            .completed(20)
            ]).asCompletable()

        let res = await scheduler.start {
            await xs.timeout(.seconds(30), scheduler: scheduler)
        }

        XCTAssertEqual(res.events, [
            .completed(220)
            ])
    }

    func test_timeout_other_succeeds() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createColdObservable([
            .completed(20)
            ]).asCompletable()

        let xs2 = await scheduler.createColdObservable([
            .completed(20)
            ]).asCompletable()

        let res = await scheduler.start {
            await xs.timeout(.seconds(30), other: xs2, scheduler: scheduler)
        }

        XCTAssertEqual(res.events, [
            .completed(220)
            ])
    }
}

extension CompletableTest {
    func test_do() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let res = await scheduler.start {
            await Completable.empty().do(onError: { _ in () }, onSubscribe: { () in () }, onSubscribed: { () in () }, onDispose: { () in () })
        }

        XCTAssertEqual(res.events, [
            .completed(200)
            ])
    }

    func test_concat() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let res = await scheduler.start {
            await Completable.empty().concat(Completable.empty())
        }

        XCTAssertEqual(res.events, [
            .completed(200)
            ])
    }

    func test_concat_sequence() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let res = await scheduler.start {
            await Completable.concat(AnySequence([Completable.empty()]))
        }

        XCTAssertEqual(res.events, [
            .completed(200)
            ])
    }

    func test_concat_collection() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let res = await scheduler.start {
            await Completable.concat([Completable.empty()])
        }

        XCTAssertEqual(res.events, [
            .completed(200)
            ])
    }

    func test_concat_variadic() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let res = await scheduler.start {
            await Completable.concat(Completable.empty(), Completable.empty())
        }

        XCTAssertEqual(res.events, [
            .completed(200)
            ])
    }

    func test_zip_collection() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let res = await scheduler.start {
            await Completable.zip(AnyCollection([Completable.empty(), Completable.empty()]))
        }

        XCTAssertEqual(res.events, [
            .completed(200)
            ])
    }

    func test_zip_array() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let res = await scheduler.start {
            await Completable.zip([Completable.empty(), Completable.empty()])
        }

        XCTAssertEqual(res.events, [
            .completed(200)
            ])
    }

    func test_zip_variadic() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let res = await scheduler.start {
            await Completable.zip(Completable.empty(), Completable.empty())
        }

        XCTAssertEqual(res.events, [
            .completed(200)
            ])
    }
}

extension CompletableTest {
    func testDefaultErrorHandler() async {
        var loggedErrors = [TestError]()

        _ = await Completable.error(testError).subscribe()
        XCTAssertEqual(loggedErrors, [])

        let originalErrorHandler = await Hooks.getDefaultErrorHandler()

        await Hooks.setDefaultErrorHandler { _, error in
            loggedErrors.append(error as! TestError)
        }

        _ = await Completable.error(testError).subscribe()
        XCTAssertEqual(loggedErrors, [testError])

        await Hooks.setDefaultErrorHandler(originalErrorHandler) 

        _ = await Completable.error(testError).subscribe()
        XCTAssertEqual(loggedErrors, [testError])
    }
}

public func == (lhs: Never, rhs: Never) -> Bool {
}
