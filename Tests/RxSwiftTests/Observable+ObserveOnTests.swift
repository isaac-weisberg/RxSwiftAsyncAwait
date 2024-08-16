//
//  Observable+ObserveOnTests.swift
//  Tests
//
//  Created by Krunoslav Zaher on 4/29/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

import XCTest
import RxSwift
import RxBlocking
import RxTest
import Foundation

class ObservableObserveOnTestBase : RxTest {
    var lock = NSLock()

    func performLocked(_ action: () -> Void) {
        lock.lock()
        action()
        lock.unlock()
    }

    override func tearDown() {
        super.tearDown()
    }
}

class ObservableObserveOnTest : ObservableObserveOnTestBase {
}

// observeOn serial scheduler
extension ObservableObserveOnTest {

    func runDispatchQueueSchedulerTests(_ tests: (SerialDispatchQueueScheduler) async -> Disposable) async {
        let scheduler = SerialDispatchQueueScheduler(internalSerialQueueName: "testQueue1")
        await runDispatchQueueSchedulerTests(scheduler, tests: tests).dispose()
    }

    func runDispatchQueueSchedulerTests(_ scheduler: SerialDispatchQueueScheduler, tests: (SerialDispatchQueueScheduler) async -> Disposable) async -> Disposable {
        // simplest possible solution, even though it has horrible efficiency in this case probably
        let disposable = await tests(scheduler)
        let expectation = self.expectation(description: "Wait for all tests to complete")

        _ = await scheduler.schedule(()) { _ in
            expectation.fulfill()
            return Disposables.create()
        }

        await waitForExpectations(timeout: 1.0)

        return disposable
    }

    func runDispatchQueueSchedulerMultiplexedTests(_ tests: [(SerialDispatchQueueScheduler) async -> Disposable]) async {
        let scheduler = SerialDispatchQueueScheduler(internalSerialQueueName: "testQueue1")

        let compositeDisposable = await CompositeDisposable()

        for test in tests {
            _ = await compositeDisposable.insert(runDispatchQueueSchedulerTests(scheduler, tests: test))
        }

        await compositeDisposable.dispose()
    }

    // tests

    func testObserveOnDispatchQueue_DoesPerformWorkOnQueue() async {
        let unitTestsThread = Thread.current

        var didExecute = false

        await runDispatchQueueSchedulerTests { scheduler in
            let observable = await Observable.just(0)
                .observe(on:scheduler)
            return await observable.subscribe(onNext: { _ in
                didExecute = true
                assert(Thread.current !== unitTestsThread)
            })
        }

        await assert(didExecute)
    }

    #if TRACE_RESOURCES
    func testObserveOnDispatchQueue_EnsureCorrectImplementationIsChosen() async {
        await runDispatchQueueSchedulerTests { scheduler in
            await assertTrue(await Resources.numberOfSerialDispatchQueueObservables == 0)
            let a = await Observable.just(0)
                .observe(on:scheduler)
            await assertTrue(a == a) // shut up swift compiler :(, we only need to keep this in memory
            await assert(await Resources.numberOfSerialDispatchQueueObservables == 1)
                return Disposables.create()
            }

        await assert(await Resources.numberOfSerialDispatchQueueObservables == 0)
        }

    func testObserveOnDispatchQueue_DispatchQueueSchedulerIsSerial() async {
        let numberOfConcurrentEvents = await AtomicInt(0)
        let numberOfExecutions = await AtomicInt(0)
        await runDispatchQueueSchedulerTests { scheduler in
            await assert(await Resources.numberOfSerialDispatchQueueObservables == 0)
                let action = { (s: Void) -> Disposable in
                    await assertEqual(await increment(numberOfConcurrentEvents), 0)
                    self.sleep(0.1) // should be enough to block the queue, so if it's concurrent, it will fail
                    await assertEqual(await decrement(numberOfConcurrentEvents), 1)
                    await increment(numberOfExecutions)
                    return Disposables.create()
                }
            _ = await scheduler.schedule((), action: action)
            _ = await scheduler.schedule((), action: action)
                return Disposables.create()
            }

        await assertEqual(await Resources.numberOfSerialDispatchQueueObservables, 0)
        await assertEqual(await globalLoad(numberOfExecutions), 2)
        }
    #endif

    func testObserveOnDispatchQueue_DeadlockErrorImmediately() async {
        var nEvents = 0

        await runDispatchQueueSchedulerTests { scheduler in
            let observable: Observable<Int> = await Observable.error(testError).observe(on:scheduler)
            return await observable.subscribe(onError: { _ in
                nEvents += 1
            })
        }

        await assertEqual(nEvents, 1)
    }

    func testObserveOnDispatchQueue_DeadlockEmpty() async {
        var nEvents = 0

        await runDispatchQueueSchedulerTests { scheduler in
            let observable: Observable<Int> = await Observable.empty().observe(on:scheduler)

            return await observable.subscribe(onCompleted: {
                nEvents += 1
            })
        }

        await assertEqual(nEvents, 1)
    }

    func testObserveOnDispatchQueue_Never() async {
        await runDispatchQueueSchedulerTests { scheduler in
            let xs: Observable<Int> = await Observable.never()
            return await xs
                .observe(on:scheduler)
                .subscribe(onNext: { _ in
                    assert(false)
                })
        }
    }

    func testObserveOnDispatchQueue_Simple() async {
        let xs = await PrimitiveHotObservable<Int>()
        let observer = PrimitiveMockObserver<Int>()

        await runDispatchQueueSchedulerMultiplexedTests([
            { scheduler in
                let subscription = await (xs.observe(on:scheduler)).subscribe(observer)
                await assert(await xs.subscriptions == [SubscribedToHotObservable])
                await xs.on(.next(0))

                return subscription
            },
            { scheduler in
                await assertEqual(observer.events, [
                    .next(0)
                    ])
                await xs.on(.next(1))
                await xs.on(.next(2))
                return Disposables.create()
            },
            { scheduler in
                await assertEqual(observer.events, [
                    .next(0),
                    .next(1),
                    .next(2)
                    ])
                await assert(await xs.subscriptions == [SubscribedToHotObservable])
                await xs.on(.completed)
                return Disposables.create()
            },
            { scheduler in
                await assertEqual(observer.events, [
                    .next(0),
                    .next(1),
                    .next(2),
                    .completed()
                    ])
                await assert(await xs.subscriptions == [UnsunscribedFromHotObservable])
                return Disposables.create()
            },
            ])
    }

    func testObserveOnDispatchQueue_Empty() async {
        let xs = await PrimitiveHotObservable<Int>()
        let observer = PrimitiveMockObserver<Int>()

        await runDispatchQueueSchedulerMultiplexedTests([
            { scheduler in
                let subscription = await (xs.observe(on:scheduler)).subscribe(observer)
                await assert(await xs.subscriptions == [SubscribedToHotObservable])
                await xs.on(.completed)
                return subscription
            },
            { scheduler in
                await assertEqual(observer.events, [
                    .completed()
                    ])
                await assert(await xs.subscriptions == [UnsunscribedFromHotObservable])
                return Disposables.create()
            }
            ])
    }

    func testObserveOnDispatchQueue_Error() async {
        let xs = await PrimitiveHotObservable<Int>()
        let observer = PrimitiveMockObserver<Int>()

        await runDispatchQueueSchedulerMultiplexedTests([
            { scheduler in
                let subscription = await (xs.observe(on:scheduler)).subscribe(observer)
                await assert(await xs.subscriptions == [SubscribedToHotObservable])
                await xs.on(.next(0))

                return subscription
            },
            { scheduler in
                await assertEqual(observer.events, [
                    .next(0)
                    ])
                await xs.on(.next(1))
                await xs.on(.next(2))
                return Disposables.create()
            },
            { scheduler in
                await assertEqual(observer.events, [
                    .next(0),
                    .next(1),
                    .next(2)
                    ])
                await assert(await xs.subscriptions == [SubscribedToHotObservable])
                await xs.on(.error(testError))
                return Disposables.create()
            },
            { scheduler in
                await assertEqual(observer.events, [
                    .next(0),
                    .next(1),
                    .next(2),
                    .error(testError)
                    ])
                await assert(await xs.subscriptions == [UnsunscribedFromHotObservable])
                return Disposables.create()
            },
            ])
    }

    func testObserveOnDispatchQueue_Dispose() async {
        let xs = await PrimitiveHotObservable<Int>()
        let observer = PrimitiveMockObserver<Int>()
        var subscription: Disposable!

        await runDispatchQueueSchedulerMultiplexedTests([
            { scheduler in
                subscription = await (xs.observe(on:scheduler)).subscribe(observer)
                await assert(await xs.subscriptions == [SubscribedToHotObservable])
                await xs.on(.next(0))

                return subscription
            },
            { scheduler in
                await assertEqual(observer.events, [
                    .next(0)
                    ])

                await assert(await xs.subscriptions == [SubscribedToHotObservable])
                await subscription.dispose()
                await assert(await xs.subscriptions == [UnsunscribedFromHotObservable])

                await xs.on(.error(testError))

                return Disposables.create()
            },
            { scheduler in
                await assertEqual(observer.events, [
                    .next(0),
                    ])
                await assert(await xs.subscriptions == [UnsunscribedFromHotObservable])
                return Disposables.create()
            }
            ])
    }

    #if TRACE_RESOURCES
    func testObserveOnSerialReleasesResourcesOnComplete() async {
        _ = await Observable<Int>.just(1).observe(on:MainScheduler.instance).subscribe()
        }

    func testObserveOnSerialReleasesResourcesOnError() async {
        _ = await Observable<Int>.error(testError).observe(on:MainScheduler.instance).subscribe()
        }
    #endif
}

// Because of `self.wait(for: [blockingTheSerialScheduler], timeout: 1.0)`.
// Testing this on Unix should be enough.
#if !os(Linux)
// Test event is cancelled properly.
extension ObservableObserveOnTest {
    func testDisposeWithEnqueuedElement() async {
        let emit = await PublishSubject<Int>()
        let blockingTheSerialScheduler = self.expectation(description: "blocking")
        let unblock = self.expectation(description: "unblock")
        let testDone = self.expectation(description: "test done")
        let scheduler = SerialDispatchQueueScheduler(qos: .default)
        var events: [Event<Int>] = []
        let subscription = await emit.observe(on:scheduler).subscribe { update in
            switch update {
            case .next(let value):
                if value == 0 {
                    blockingTheSerialScheduler.fulfill()
                    self.wait(for: [unblock], timeout: 1.0)
                }
            default:
                break
            }
            events.append(update)
        }
        await emit.on(.next(0))
        self.wait(for: [blockingTheSerialScheduler], timeout: 1.0)
        await emit.on(.next(1))
        _ = await scheduler.schedule(()) { _ in
            testDone.fulfill()
            return Disposables.create()
        }
        await subscription.dispose()
        unblock.fulfill()
        self.wait(for: [testDone], timeout: 1.0)
        await assertEqual(events, [.next(0)])
    }

    func testDisposeWithEnqueuedError() async {
        let emit = await PublishSubject<Int>()
        let blockingTheSerialScheduler = self.expectation(description: "blocking")
        let unblock = self.expectation(description: "unblock")
        let testDone = self.expectation(description: "test done")
        let scheduler = SerialDispatchQueueScheduler(qos: .default)
        var events: [Event<Int>] = []
        let subscription = await emit.observe(on:scheduler).subscribe { update in
            switch update {
            case .next(let value):
                if value == 0 {
                    blockingTheSerialScheduler.fulfill()
                    self.wait(for: [unblock], timeout: 1.0)
                }
            default:
                break
            }
            events.append(update)
        }
        await emit.on(.next(0))
        self.wait(for: [blockingTheSerialScheduler], timeout: 1.0)
        await emit.on(.error(TestError.dummyError))
        _ = await scheduler.schedule(()) { _ in
            testDone.fulfill()
            return Disposables.create()
        }
        await subscription.dispose()
        unblock.fulfill()
        self.wait(for: [testDone], timeout: 1.0)
        await assertEqual(events, [.next(0)])
    }

    func testDisposeWithEnqueuedCompleted() async {
        let emit = await PublishSubject<Int>()
        let blockingTheSerialScheduler = self.expectation(description: "blocking")
        let unblock = self.expectation(description: "unblock")
        let testDone = self.expectation(description: "test done")
        let scheduler = SerialDispatchQueueScheduler(qos: .default)
        var events: [Event<Int>] = []
        let subscription = await emit.observe(on:scheduler).subscribe { update in
            switch update {
            case .next(let value):
                if value == 0 {
                    blockingTheSerialScheduler.fulfill()
                    self.wait(for: [unblock], timeout: 1.0)
                }
            default:
                break
            }
            events.append(update)
        }
        await emit.on(.next(0))
        self.wait(for: [blockingTheSerialScheduler], timeout: 1.0)
        await emit.on(.completed)
        _ = await scheduler.schedule(()) { _ in
            testDone.fulfill()
            return Disposables.create()
        }
        await subscription.dispose()
        unblock.fulfill()
        self.wait(for: [testDone], timeout: 1.0)
        await assertEqual(events, [.next(0)])
    }
}
#endif

// observeOn concurrent scheduler
class ObservableObserveOnTestConcurrentSchedulerTest: ObservableObserveOnTestBase {

    func createScheduler() -> ImmediateSchedulerType {
        let operationQueue = OperationQueue()
        operationQueue.maxConcurrentOperationCount = 8
        return OperationQueueScheduler(operationQueue: operationQueue)
    }

    #if TRACE_RESOURCES
    func testObserveOn_EnsureCorrectImplementationIsChosen() async {
            let scheduler = self.createScheduler()

        await assert(await Resources.numberOfSerialDispatchQueueObservables == 0)
        _ = await Observable.just(0).observe(on:scheduler)
            self.sleep(0.1)
        await assert(await Resources.numberOfSerialDispatchQueueObservables == 0)
        }
    #endif

    func testObserveOn_EnsureTestsAreExecutedWithRealConcurrentScheduler() async {
        var events: [String] = []

        let stop = await BehaviorSubject(value: 0)

        #if os(Linux)
        /// A regression in the Swift 5.1 compiler causes a hang
        /// when using OperationQueue concurrency:
        /// https://bugs.swift.org/browse/SR-11647
        let scheduler = ConcurrentDispatchQueueScheduler(qos: .default)
        #else
        let scheduler = createScheduler()
        #endif

        let condition = NSCondition()

        var writtenStarted = 0
        var writtenEnded = 0

        let concurrent = { () async -> Disposable in
            self.performLocked {
                events.append("Started")
            }

            condition.lock()
            writtenStarted += 1
            condition.signal()
            while writtenStarted < 2 {
                condition.wait()
            }
            condition.unlock()

            self.performLocked {
                events.append("Ended")
            }

            condition.lock()
            writtenEnded += 1
            condition.signal()
            while writtenEnded < 2 {
                condition.wait()
            }
            condition.unlock()

            await stop.on(.completed)

            return Disposables.create()
        }

        _ = await scheduler.schedule((), action: concurrent)

        _ = await scheduler.schedule((), action: concurrent)

        _ = try! await stop.toBlocking().last()

        await assertEqual(events, ["Started", "Started", "Ended", "Ended"])
    }

    func testObserveOn_Never() async {
        let scheduler = createScheduler()

        let xs: Observable<Int> = await Observable.never()
        let subscription = await xs
            .observe(on:scheduler)
            .subscribe(onNext: { _ in
                assert(false)
            })

        sleep(0.1)

        await subscription.dispose()
    }

    func testObserveOn_Simple() async {
        let xs = await PrimitiveHotObservable<Int>()
        let observer = PrimitiveMockObserver<Int>()

        let scheduler = createScheduler()

        let subscription = await (xs.observe(on:scheduler)).subscribe(observer)
        await assert(await xs.subscriptions == [SubscribedToHotObservable])
        await xs.on(.next(0))

        sleep(0.1)

        await assertEqual(observer.events, [
            .next(0)
            ])
        await xs.on(.next(1))
        await xs.on(.next(2))

        sleep(0.1)

        await assertEqual(observer.events, [
            .next(0),
            .next(1),
            .next(2)
            ])
        await assert(await xs.subscriptions == [SubscribedToHotObservable])
        await xs.on(.completed)

        sleep(0.1)

        await assertEqual(observer.events, [
            .next(0),
            .next(1),
            .next(2),
            .completed()
            ])
        await assert(await xs.subscriptions == [UnsunscribedFromHotObservable])

        await subscription.dispose()

        sleep(0.1)
    }

    func testObserveOn_Empty() async {
        let xs = await PrimitiveHotObservable<Int>()
        let observer = PrimitiveMockObserver<Int>()

        let scheduler = createScheduler()

        _ = await xs.observe(on:scheduler).subscribe(observer)

        await assert(await xs.subscriptions == [SubscribedToHotObservable])
        await xs.on(.completed)

        sleep(0.1)

        await assertEqual(observer.events, [
            .completed()
            ])
        await assert(await xs.subscriptions == [UnsunscribedFromHotObservable])
    }

    func testObserveOn_ConcurrentSchedulerIsSerialized() async {
        let xs = await PrimitiveHotObservable<Int>()
        let observer = PrimitiveMockObserver<Int>()

        var executed = false

        let scheduler = createScheduler()

        let res = await xs
            .observe(on:scheduler)
            .map { v -> Int in
                if v == 0 {
                    self.sleep(0.1) // 100 ms is enough
                    executed = true
                }
                return v
        }
        let subscription = await res.subscribe(observer)

        await assert(await xs.subscriptions == [SubscribedToHotObservable])
        await xs.on(.next(0))
        await xs.on(.next(1))
        await xs.on(.completed)

        sleep(0.3)

        await assertEqual(observer.events, [
            .next(0),
            .next(1),
            .completed()
            ])
        await assert(await xs.subscriptions == [UnsunscribedFromHotObservable])

        await assert(executed)

        await subscription.dispose()
    }

    func testObserveOn_Error() async {
        let xs = await PrimitiveHotObservable<Int>()
        let observer = PrimitiveMockObserver<Int>()

        let scheduler = createScheduler()

        _ = await xs.observe(on:scheduler).subscribe(observer)

        await assert(await xs.subscriptions == [SubscribedToHotObservable])
        await xs.on(.next(0))

        sleep(0.1)

        await assertEqual(observer.events, [
            .next(0)
            ])
        await xs.on(.next(1))
        await xs.on(.next(2))

        sleep(0.1)

        await assertEqual(observer.events, [
            .next(0),
            .next(1),
            .next(2)
            ])
        await assert(await xs.subscriptions == [SubscribedToHotObservable])
        await xs.on(.error(testError))

        sleep(0.1)

        await assertEqual(observer.events, [
            .next(0),
            .next(1),
            .next(2),
            .error(testError)
            ])
        await assert(await xs.subscriptions == [UnsunscribedFromHotObservable])

    }

    func testObserveOn_Dispose() async {
        let xs = await PrimitiveHotObservable<Int>()
        let observer = PrimitiveMockObserver<Int>()

        let scheduler = createScheduler()
        let subscription = await xs.observe(on:scheduler).subscribe(observer)
        await assert(await xs.subscriptions == [SubscribedToHotObservable])
        await xs.on(.next(0))

        sleep(0.1)

        await assertEqual(observer.events, [
            .next(0)
            ])

        await assert(await xs.subscriptions == [SubscribedToHotObservable])
        await subscription.dispose()
        await assert(await xs.subscriptions == [UnsunscribedFromHotObservable])

        await xs.on(.error(testError))

        sleep(0.1)

        await assertEqual(observer.events, [
            .next(0),
            ])
        await assert(await xs.subscriptions == [UnsunscribedFromHotObservable])
    }

    #if TRACE_RESOURCES
    func testObserveOnReleasesResourcesOnComplete() async {
        let testScheduler = await TestScheduler(initialClock: 0)
        _ = await Observable<Int>.just(1).observe(on:testScheduler).subscribe()
        await testScheduler.start()
        }
        
    func testObserveOnReleasesResourcesOnError() async {
        let testScheduler = await TestScheduler(initialClock: 0)
        _ = await Observable<Int>.error(testError).observe(on:testScheduler).subscribe()
        await testScheduler.start()
        }
    #endif
}

final class ObservableObserveOnTestConcurrentSchedulerTest2 : ObservableObserveOnTestConcurrentSchedulerTest {
    override func createScheduler() -> ImmediateSchedulerType {
        ConcurrentDispatchQueueScheduler(qos: .default)
    }
}
