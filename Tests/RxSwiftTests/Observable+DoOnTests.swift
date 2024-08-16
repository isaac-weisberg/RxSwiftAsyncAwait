//
//  Observable+DoOnTests.swift
//  Tests
//
//  Created by Krunoslav Zaher on 4/29/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

import XCTest
import RxSwift
import RxTest

class ObservableDoOnTest : RxTest {
}

extension ObservableDoOnTest {
    func testDoOn_shouldSeeAllValues() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(150, 1),
            .next(210, 2),
            .next(220, 3),
            .next(230, 4),
            .next(240, 5),
            .completed(250)
            ])

        var i = 0
        var sum = 2 + 3 + 4 + 5
        let res = await scheduler.start { await xs.do(onNext: { element in
                i += 1
                sum -= element
            })
        }

        XCTAssertEqual(i, 4)
        XCTAssertEqual(sum, 0)

        let correctMessages = Recorded.events(
            .next(210, 2),
            .next(220, 3),
            .next(230, 4),
            .next(240, 5),
            .completed(250)
        )

        let correctSubscriptions = [
            Subscription(200, 250)
        ]

        XCTAssertEqual(res.events, correctMessages)
        XCTAssertEqual(xs.subscriptions, correctSubscriptions)
    }

    func testDoOn_plainAction() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(150, 1),
            .next(210, 2),
            .next(220, 3),
            .next(230, 4),
            .next(240, 5),
            .completed(250)
            ])

        var i = 0
        let res = await scheduler.start { await xs.do(onNext: { _ in
                i += 1
            })
        }

        XCTAssertEqual(i, 4)

        let correctMessages = Recorded.events(
            .next(210, 2),
            .next(220, 3),
            .next(230, 4),
            .next(240, 5),
            .completed(250)
        )

        let correctSubscriptions = [
            Subscription(200, 250)
        ]

        XCTAssertEqual(res.events, correctMessages)
        XCTAssertEqual(xs.subscriptions, correctSubscriptions)
    }

    func testDoOn_nextCompleted() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(150, 1),
            .next(210, 2),
            .next(220, 3),
            .next(230, 4),
            .next(240, 5),
            .completed(250)
            ])

        var i = 0
        var sum = 2 + 3 + 4 + 5
        var completedEvaluation = false
        let res = await scheduler.start { await xs.do(onNext: { value in
                i += 1
                sum -= value
            }, onCompleted: {
                completedEvaluation = true
            })
        }

        XCTAssertEqual(i, 4)
        XCTAssertEqual(sum, 0)
        XCTAssertEqual(completedEvaluation, true)

        let correctMessages = Recorded.events(
            .next(210, 2),
            .next(220, 3),
            .next(230, 4),
            .next(240, 5),
            .completed(250)
        )

        let correctSubscriptions = [
            Subscription(200, 250)
        ]

        XCTAssertEqual(res.events, correctMessages)
        XCTAssertEqual(xs.subscriptions, correctSubscriptions)
    }

    func testDoOn_completedNever() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let recordedEvents: [Recorded<Event<Int>>] = [
        ]

        let xs = await scheduler.createHotObservable(recordedEvents)

        var i = 0
        var completedEvaluation = false
        let res = await scheduler.start { await xs.do(onNext: { _ in
                i += 1
            }, onCompleted: {
                completedEvaluation = true
            })
        }

        XCTAssertEqual(i, 0)
        XCTAssertEqual(completedEvaluation, false)

        let correctMessages: [Recorded<Event<Int>>] = [
        ]

        let correctSubscriptions = [
            Subscription(200, 1000)
        ]

        XCTAssertEqual(res.events, correctMessages)
        XCTAssertEqual(xs.subscriptions, correctSubscriptions)
    }

    func testDoOn_nextError() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(150, 1),
            .next(210, 2),
            .next(220, 3),
            .next(230, 4),
            .next(240, 5),
            .error(250, testError)
            ])

        var i = 0
        var sum = 2 + 3 + 4 + 5
        var sawError = false
        let res = await scheduler.start { await xs.do(onNext: { value in
                i += 1
                sum -= value
            }, onError: { _ in
                sawError = true
            })
        }

        XCTAssertEqual(i, 4)
        XCTAssertEqual(sum, 0)
        XCTAssertEqual(sawError, true)

        let correctMessages = Recorded.events(
            .next(210, 2),
            .next(220, 3),
            .next(230, 4),
            .next(240, 5),
            .error(250, testError)
        )

        let correctSubscriptions = [
            Subscription(200, 250)
        ]

        XCTAssertEqual(res.events, correctMessages)
        XCTAssertEqual(xs.subscriptions, correctSubscriptions)
    }

    func testDoOn_nextErrorNot() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(150, 1),
            .next(210, 2),
            .next(220, 3),
            .next(230, 4),
            .next(240, 5),
            .completed(250)
            ])

        var i = 0
        var sum = 2 + 3 + 4 + 5
        var sawError = false
        let res = await scheduler.start { await xs.do(onNext: { value in
                i += 1
                sum -= value
            }, onError: { _ in
                sawError = true
            })
        }

        XCTAssertEqual(i, 4)
        XCTAssertEqual(sum, 0)
        XCTAssertEqual(sawError, false)

        let correctMessages = Recorded.events(
            .next(210, 2),
            .next(220, 3),
            .next(230, 4),
            .next(240, 5),
            .completed(250)
        )

        let correctSubscriptions = [
            Subscription(200, 250)
        ]

        XCTAssertEqual(res.events, correctMessages)
        XCTAssertEqual(xs.subscriptions, correctSubscriptions)
    }

    func testDoOnNext_normal() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(150, 1),
            .next(210, 2),
            .next(220, 3),
            .next(230, 4),
            .next(240, 5),
            .completed(250)
            ])

        var numberOfTimesInvoked = 0

        let res = await scheduler.start { await xs.do(onNext: { _ in
                numberOfTimesInvoked += 1
            })
        }

        let correctMessages = Recorded.events(
            .next(210, 2),
            .next(220, 3),
            .next(230, 4),
            .next(240, 5),
            .completed(250)
        )

        let correctSubscriptions = [
            Subscription(200, 250)
        ]

        XCTAssertEqual(res.events, correctMessages)
        XCTAssertEqual(xs.subscriptions, correctSubscriptions)

        XCTAssertEqual(numberOfTimesInvoked, 4)
    }

    func testDoOnNext_throws() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(150, 1),
            .next(210, 2),
            .next(220, 3),
            .next(230, 4),
            .next(240, 5),
            .completed(250)
            ])

        var numberOfTimesInvoked = 0

        let res = await scheduler.start { await xs.do(onNext: { _ in
                if numberOfTimesInvoked > 2 {
                    throw testError
                }
                numberOfTimesInvoked += 1
            })
        }

        let correctMessages = Recorded.events(
            .next(210, 2),
            .next(220, 3),
            .next(230, 4),
            .error(240, testError)
        )

        let correctSubscriptions = [
            Subscription(200, 240)
        ]

        XCTAssertEqual(res.events, correctMessages)
        XCTAssertEqual(xs.subscriptions, correctSubscriptions)

        XCTAssertEqual(numberOfTimesInvoked, 3)
    }

    func testDoOnError_normal() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(150, 1),
            .next(210, 2),
            .error(250, testError)
            ])

        var recordedError: Swift.Error!
        var numberOfTimesInvoked = 0

        let res = await scheduler.start { await xs.do(onError: { error in
                recordedError = error
                numberOfTimesInvoked += 1
            })
        }

        let correctMessages = Recorded.events(
            .next(210, 2),
            .error(250, testError)
        )

        let correctSubscriptions = [
            Subscription(200, 250)
        ]

        XCTAssertEqual(res.events, correctMessages)
        XCTAssertEqual(xs.subscriptions, correctSubscriptions)

        XCTAssertEqual(recordedError as! TestError, testError)
        XCTAssertEqual(numberOfTimesInvoked, 1)
    }

    func testDoOnError_throws() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(150, 1),
            .next(210, 2),
            .error(250, testError)
            ])

        let res = await scheduler.start { await xs.do(onError: { _ in
                throw testError1
            })
        }

        let correctMessages = Recorded.events(
            .next(210, 2),
            .error(250, testError1)
        )

        let correctSubscriptions = [
            Subscription(200, 250)
        ]

        XCTAssertEqual(res.events, correctMessages)
        XCTAssertEqual(xs.subscriptions, correctSubscriptions)
    }

    func testDoOnCompleted_normal() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(150, 1),
            .next(210, 2),
            .next(220, 3),
            .next(230, 4),
            .next(240, 5),
            .completed(250)
            ])

        var didComplete = false

        let res = await scheduler.start { await xs.do(onCompleted: {
                didComplete = true
            })
        }

        let correctMessages = Recorded.events(
            .next(210, 2),
            .next(220, 3),
            .next(230, 4),
            .next(240, 5),
            .completed(250)
        )

        let correctSubscriptions = [
            Subscription(200, 250)
        ]

        XCTAssertEqual(res.events, correctMessages)
        XCTAssertEqual(xs.subscriptions, correctSubscriptions)

        XCTAssertEqual(didComplete, true)
    }

    func testDoOnCompleted_throws() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(150, 1),
            .next(210, 2),
            .next(220, 3),
            .next(230, 4),
            .next(240, 5),
            .completed(250)
            ])

        let res = await scheduler.start { await xs.do(onCompleted: {
                throw testError
            })
        }

        let correctMessages = Recorded.events(
            .next(210, 2),
            .next(220, 3),
            .next(230, 4),
            .next(240, 5),
            .error(250, testError)
        )

        let correctSubscriptions = [
            Subscription(200, 250)
        ]

        XCTAssertEqual(res.events, correctMessages)
        XCTAssertEqual(xs.subscriptions, correctSubscriptions)
    }

    enum DoOnEvent {
        case sourceSubscribe
        case sourceDispose
        case doOnNext
        case doOnCompleted
        case doOnError
        case doOnSubscribe
        case doOnSubscribed
        case doOnDispose
    }

    func testDoOnOrder_Completed_Async() async {
        var events = [DoOnEvent]()

        let scheduler = await TestScheduler(initialClock: 0)

        _ = await scheduler.start {
            await Observable<Int>.create { observer in
                    events.append(.sourceSubscribe)
                await scheduler.scheduleAt(300) {
                    await observer.on(.next(0))
                    await observer.on(.completed)
                    }
                return await Disposables.create {
                        events.append(.sourceDispose)
                    }
                }
                .do(
                    onNext: { _ in events.append(.doOnNext) },
                    onCompleted: { events.append(.doOnCompleted) },
                    onSubscribe: { events.append(.doOnSubscribe) },
                    onSubscribed: { events.append(.doOnSubscribed) },
                    onDispose: { events.append(.doOnDispose) }
                )
        }


        XCTAssertEqual(events, [.doOnSubscribe, .sourceSubscribe, .doOnSubscribed, .doOnNext, .doOnCompleted, .sourceDispose, .doOnDispose])
    }

    func testDoOnOrder_Completed_Sync() async {
        var events = [DoOnEvent]()

        let scheduler = await TestScheduler(initialClock: 0)

        _ = await scheduler.start {
            await Observable<Int>.create { observer in
                    events.append(.sourceSubscribe)
                await observer.on(.next(0))
                await observer.on(.completed)
                return await Disposables.create {
                        events.append(.sourceDispose)
                    }
                }
                .do(
                    onNext: { _ in events.append(.doOnNext) },
                    onCompleted: { events.append(.doOnCompleted) },
                    onSubscribe: { events.append(.doOnSubscribe) },
                    onSubscribed: { events.append(.doOnSubscribed) },
                    onDispose: { events.append(.doOnDispose) }
            )
        }


        XCTAssertEqual(events, [.doOnSubscribe, .sourceSubscribe, .doOnNext, .doOnCompleted, .sourceDispose, .doOnSubscribed, .doOnDispose])
    }

    func testDoOnOrder_Error() async {
        var events = [DoOnEvent]()

        _ = await Observable<Int>.create { observer in
                events.append(.sourceSubscribe)
            await observer.on(.next(0))
            await observer.on(.error(testError))
            return await Disposables.create {
                    events.append(.sourceDispose)
                }
            }
            .do(
                onNext: { _ in events.append(.doOnNext) },
                onError: { _ in events.append(.doOnError) },
                onSubscribe: { events.append(.doOnSubscribe) },
                onSubscribed: { events.append(.doOnSubscribed) },
                onDispose: { events.append(.doOnDispose) }
            )
            .subscribe { _ in }


        XCTAssertEqual(events, [.doOnSubscribe, .sourceSubscribe, .doOnNext, .doOnError, .sourceDispose, .doOnSubscribed, .doOnDispose])
    }

    func testDoOnOrder_Dispose() async {
        var events = [DoOnEvent]()

        await await Observable<Int>.create { observer in
                events.append(.sourceSubscribe)
            await observer.on(.next(0))
            return await Disposables.create {
                    events.append(.sourceDispose)
                }
            }
            .do(
                onNext: { _ in events.append(.doOnNext) },
                onSubscribe: { events.append(.doOnSubscribe) },
                onSubscribed: { events.append(.doOnSubscribed) },
                onDispose: { events.append(.doOnDispose) }
            )
            .subscribe { _ in }
            .dispose()


        XCTAssertEqual(events, [.doOnSubscribe, .sourceSubscribe, .doOnNext, .doOnSubscribed, .sourceDispose, .doOnDispose])
    }

    #if TRACE_RESOURCES
    func testDoReleasesResourcesOnComplete() async {
        _ = await Observable<Int>.just(1).do().subscribe()
        }

    func testDoReleasesResourcesOnError() async {
        _ = await Observable<Int>.error(testError).do().subscribe()
        }
    #endif
}
