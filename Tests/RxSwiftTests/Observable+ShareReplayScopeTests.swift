//
//  Observable+ShareReplayScopeTests.swift
//  Tests
//
//  Created by Krunoslav Zaher on 5/28/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

import XCTest
import RxSwift
import RxTest

class ObservableShareReplayScopeTests : RxTest {
}

extension ObservableShareReplayScopeTests {
    func test_testDefaultArguments() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(210, 1),
            .next(220, 2),
            .next(230, 3),
            .next(240, 4),
            .next(250, 5),
            .next(320, 6),
            .next(550, 7)
            ])

        var subscription1: Disposable! = nil
        var subscription2: Disposable! = nil
        var subscription3: Disposable! = nil

        let res1 = scheduler.createObserver(Int.self)
        let res2 = scheduler.createObserver(Int.self)
        let res3 = scheduler.createObserver(Int.self)

        var ys: Observable<Int>! = nil

        await scheduler.scheduleAt(Defaults.created) { ys = await xs.share() }

        await scheduler.scheduleAt(200) { subscription1 = await ys.subscribe(res1) }
        await scheduler.scheduleAt(300) { subscription2 = await ys.subscribe(res2) }

        await scheduler.scheduleAt(350) { await subscription1.dispose() }
        await scheduler.scheduleAt(400) { await subscription2.dispose() }

        await scheduler.scheduleAt(500) { subscription3 = await ys.subscribe(res3) }
        await scheduler.scheduleAt(600) { await subscription3.dispose() }

        await scheduler.start()

        XCTAssertEqual(res1.events, [
            .next(210, 1),
            .next(220, 2),
            .next(230, 3),
            .next(240, 4),
            .next(250, 5),
            .next(320, 6)
            ])

        let replayedEvents2 = (0 ..< 0).map { Recorded.next(300, 6 - 0 + $0) }

        XCTAssertEqual(res2.events, replayedEvents2 + [.next(320, 6)])
        XCTAssertEqual(res3.events, [.next(550, 7)])

        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 400),
            Subscription(500, 600)
            ])
    }


    func test_forever_receivesCorrectElements() async {
        for i in 0 ..< 5 {
            let scheduler = await TestScheduler(initialClock: 0)

            let xs = await scheduler.createHotObservable([
                    .next(210, 1),
                    .next(220, 2),
                    .next(230, 3),
                    .next(240, 4),
                    .next(250, 5),
                    .next(320, 6),
                    .next(550, 7)
                ])

            var subscription1: Disposable! = nil
            var subscription2: Disposable! = nil
            var subscription3: Disposable! = nil

            let res1 = scheduler.createObserver(Int.self)
            let res2 = scheduler.createObserver(Int.self)
            let res3 = scheduler.createObserver(Int.self)

            var ys: Observable<Int>! = nil

            await scheduler.scheduleAt(Defaults.created) { ys = await xs.share(replay: i, scope: .forever) }

            await scheduler.scheduleAt(200) { subscription1 = await ys.subscribe(res1) }
            await scheduler.scheduleAt(300) { subscription2 = await ys.subscribe(res2) }

            await scheduler.scheduleAt(350) { await subscription1.dispose() }
            await scheduler.scheduleAt(400) { await subscription2.dispose() }

            await scheduler.scheduleAt(500) { subscription3 = await ys.subscribe(res3) }
            await scheduler.scheduleAt(600) { await subscription3.dispose() }

            await scheduler.start()

            XCTAssertEqual(res1.events, [
                .next(210, 1),
                .next(220, 2),
                .next(230, 3),
                .next(240, 4),
                .next(250, 5),
                .next(320, 6)
                ])

            let replayedEvents2 = (0 ..< i).map { Recorded.next(300, 6 - i + $0) }
            let replayedEvents3 = (0 ..< i).map { Recorded.next(500, 7 - i + $0) }

            XCTAssertEqual(res2.events, replayedEvents2 + [.next(320, 6)])
            XCTAssertEqual(res3.events, replayedEvents3 + [.next(550, 7)])

            XCTAssertEqual(xs.subscriptions, [
                Subscription(200, 400),
                Subscription(500, 600)
                ])
        }
    }

    func test_whileConnected_receivesCorrectElements() async {
        for i in 0 ..< 5 {
            let scheduler = await TestScheduler(initialClock: 0)

            let xs = await scheduler.createHotObservable([
                .next(210, 1),
                .next(220, 2),
                .next(230, 3),
                .next(240, 4),
                .next(250, 5),
                .next(320, 6),
                .next(550, 7)
                ])

            var subscription1: Disposable! = nil
            var subscription2: Disposable! = nil
            var subscription3: Disposable! = nil

            let res1 = scheduler.createObserver(Int.self)
            let res2 = scheduler.createObserver(Int.self)
            let res3 = scheduler.createObserver(Int.self)

            var ys: Observable<Int>! = nil

            await scheduler.scheduleAt(Defaults.created) { ys = await xs.share(replay: i, scope: .whileConnected) }

            await scheduler.scheduleAt(200) { subscription1 = await ys.subscribe(res1) }
            await scheduler.scheduleAt(300) { subscription2 = await ys.subscribe(res2) }

            await scheduler.scheduleAt(350) { await subscription1.dispose() }
            await scheduler.scheduleAt(400) { await subscription2.dispose() }

            await scheduler.scheduleAt(500) { subscription3 = await ys.subscribe(res3) }
            await scheduler.scheduleAt(600) { await subscription3.dispose() }

            await scheduler.start()

            XCTAssertEqual(res1.events, [
                .next(210, 1),
                .next(220, 2),
                .next(230, 3),
                .next(240, 4),
                .next(250, 5),
                .next(320, 6)
                ])

            let replayedEvents2 = (0 ..< i).map { Recorded.next(300, 6 - i + $0) }

            XCTAssertEqual(res2.events, replayedEvents2 + [.next(320, 6)])
            XCTAssertEqual(res3.events, [.next(550, 7)])

            XCTAssertEqual(xs.subscriptions, [
                Subscription(200, 400),
                Subscription(500, 600)
                ])
        }
    }

    func test_forever_error() async {
        for i in 0 ..< 5 {
            let scheduler = await TestScheduler(initialClock: 0)

            let xs = await scheduler.createHotObservable([
                .next(210, 1),
                .next(220, 2),
                .next(230, 3),
                .next(240, 4),
                .next(250, 5),
                .next(320, 6),
                .error(330, testError),
                .next(340, -1),
                .next(550, 7),
                ])

            var subscription1: Disposable! = nil
            var subscription2: Disposable! = nil
            var subscription3: Disposable! = nil

            let res1 = scheduler.createObserver(Int.self)
            let res2 = scheduler.createObserver(Int.self)
            let res1_ = scheduler.createObserver(Int.self)
            let res2_ = scheduler.createObserver(Int.self)
            let res3 = scheduler.createObserver(Int.self)

            var ys: Observable<Int>! = nil

            await scheduler.scheduleAt(Defaults.created) { ys = await xs.share(replay: i, scope: .forever) }

            await scheduler.scheduleAt(200) {
                subscription1 = await ys.subscribe { event in
                    res1.on(event)
                    switch event {
                    case .error: subscription1 = await ys.subscribe(res1_)
                    case .completed: subscription1 = await ys.subscribe(res1_)
                    case .next: break
                    }
                }
            }
            await scheduler.scheduleAt(300) {
                subscription2 = await ys.subscribe { event in
                    res2.on(event)
                    switch event {
                    case .error: subscription2 = await ys.subscribe(res2_)
                    case .completed: subscription2 = await ys.subscribe(res2_)
                    case .next: break
                    }
                }
            }

            await scheduler.scheduleAt(350) { await subscription1.dispose() }
            await scheduler.scheduleAt(400) { await subscription2.dispose() }

            await scheduler.scheduleAt(500) { subscription3 = await ys.subscribe(res3) }
            await scheduler.scheduleAt(600) { await subscription3.dispose() }

            await scheduler.start()

            XCTAssertEqual(res1.events, [
                .next(210, 1),
                .next(220, 2),
                .next(230, 3),
                .next(240, 4),
                .next(250, 5),
                .next(320, 6),
                .error(330, testError)
                ])

            let replayedEvents1 = (0 ..< i).map { Recorded.next(330, 7 - i + $0) }
            
            XCTAssertEqual(res1_.events, replayedEvents1 + [.error(330, testError)])
            XCTAssertEqual(res2_.events, replayedEvents1 + [.error(330, testError)])


            let replayedEvents2 = (0 ..< i).map { Recorded.next(300, 6 - i + $0) }
            XCTAssertEqual(res2.events, replayedEvents2 + [.next(320, 6), .error(330, testError)])


            let replayedEvents3 = (0 ..< i).map { Recorded.next(500, 7 - i + $0) }
            XCTAssertEqual(res3.events, replayedEvents3 + [.error(500, testError)])

            XCTAssertEqual(xs.subscriptions, [
                Subscription(200, 330),
                ])
        }
    }

    func test_whileConnected_error() async {
        for i in 0 ..< 5 {
            let scheduler = await TestScheduler(initialClock: 0)

            let xs = await scheduler.createHotObservable([
                .next(210, 1),
                .next(220, 2),
                .next(230, 3),
                .next(240, 4),
                .next(250, 5),
                .next(320, 6),
                .error(330, testError),
                .next(340, -1),
                .next(550, 7),
                ])

            var subscription1: Disposable! = nil
            var subscription2: Disposable! = nil
            var subscription3: Disposable! = nil

            let res1 = scheduler.createObserver(Int.self)
            let res2 = scheduler.createObserver(Int.self)
            let res1_ = scheduler.createObserver(Int.self)
            let res2_ = scheduler.createObserver(Int.self)
            let res3 = scheduler.createObserver(Int.self)

            var ys: Observable<Int>! = nil

            await scheduler.scheduleAt(Defaults.created) { ys = await xs.share(replay: i, scope: .whileConnected) }

            await scheduler.scheduleAt(200) {
                subscription1 = await ys.subscribe { event in
                    res1.on(event)
                    switch event {
                    case .error: subscription1 = await ys.subscribe(res1_)
                    case .completed: subscription1 = await ys.subscribe(res1_)
                    case .next: break
                    }
                }
            }
            await scheduler.scheduleAt(300) {
                subscription2 = await ys.subscribe { event in
                    res2.on(event)
                    switch event {
                    case .error: subscription2 = await ys.subscribe(res2_)
                    case .completed: subscription2 = await ys.subscribe(res2_)
                    case .next: break
                    }
                }
            }

            await scheduler.scheduleAt(350) { await subscription1.dispose() }
            await scheduler.scheduleAt(400) { await subscription2.dispose() }

            await scheduler.scheduleAt(500) { subscription3 = await ys.subscribe(res3) }
            await scheduler.scheduleAt(600) { await subscription3.dispose() }

            await scheduler.start()

            XCTAssertEqual(res1.events, [
                .next(210, 1),
                .next(220, 2),
                .next(230, 3),
                .next(240, 4),
                .next(250, 5),
                .next(320, 6),
                .error(330, testError)
                ])

            XCTAssertEqual(res1_.events, [.next(340, -1)])
            XCTAssertEqual(res2_.events, [.next(340, -1)])

            let replayedEvents2 = (0 ..< i).map { Recorded.next(300, 6 - i + $0) }
            XCTAssertEqual(res2.events, replayedEvents2 + [.next(320, 6), .error(330, testError)])

            XCTAssertEqual(res3.events, [.next(550, 7)])
            
            XCTAssertEqual(xs.subscriptions, [
                Subscription(200, 330),
                Subscription(330, 400),
                Subscription(500, 600)
                ])
        }
    }

    func test_forever_completed() async {
        for i in 0 ..< 5 {
            let scheduler = await TestScheduler(initialClock: 0)

            let xs = await scheduler.createHotObservable([
                .next(210, 1),
                .next(220, 2),
                .next(230, 3),
                .next(240, 4),
                .next(250, 5),
                .next(320, 6),
                .completed(330),
                .next(340, -1),
                .next(550, 7),
                ])

            var subscription1: Disposable! = nil
            var subscription2: Disposable! = nil
            var subscription3: Disposable! = nil

            let res1 = scheduler.createObserver(Int.self)
            let res2 = scheduler.createObserver(Int.self)
            let res1_ = scheduler.createObserver(Int.self)
            let res2_ = scheduler.createObserver(Int.self)
            let res3 = scheduler.createObserver(Int.self)

            var ys: Observable<Int>! = nil

            await scheduler.scheduleAt(Defaults.created) { ys = await xs.share(replay: i, scope: .forever) }

            await scheduler.scheduleAt(200) {
                subscription1 = await ys.subscribe { event in
                    res1.on(event)
                    switch event {
                    case .error: subscription1 = await ys.subscribe(res1_)
                    case .completed: subscription1 = await ys.subscribe(res1_)
                    case .next: break
                    }
                }
            }
            await scheduler.scheduleAt(300) {
                subscription2 = await ys.subscribe { event in
                    res2.on(event)
                    switch event {
                    case .error: subscription2 = await ys.subscribe(res2_)
                    case .completed: subscription2 = await ys.subscribe(res2_)
                    case .next: break
                    }
                }
            }

            await scheduler.scheduleAt(350) { await subscription1.dispose() }
            await scheduler.scheduleAt(400) { await subscription2.dispose() }

            await scheduler.scheduleAt(500) { subscription3 = await ys.subscribe(res3) }
            await scheduler.scheduleAt(600) { await subscription3.dispose() }

            await scheduler.start()

            XCTAssertEqual(res1.events, [
                .next(210, 1),
                .next(220, 2),
                .next(230, 3),
                .next(240, 4),
                .next(250, 5),
                .next(320, 6),
                .completed(330)
                ])

            let replayedEvents1 = (0 ..< i).map { Recorded.next(330, 7 - i + $0) }

            XCTAssertEqual(res1_.events, replayedEvents1 + [.completed(330)])
            XCTAssertEqual(res2_.events, replayedEvents1 + [.completed(330)])


            let replayedEvents2 = (0 ..< i).map { Recorded.next(300, 6 - i + $0) }
            XCTAssertEqual(res2.events, replayedEvents2 + [.next(320, 6), .completed(330)])


            let replayedEvents3 = (0 ..< i).map { Recorded.next(500, 7 - i + $0) }
            XCTAssertEqual(res3.events, replayedEvents3 + [.completed(500)])

            XCTAssertEqual(xs.subscriptions, [
                Subscription(200, 330),
                ])
        }
    }

    func test_whileConnected_completed() async {
        for i in 0 ..< 5 {
            let scheduler = await TestScheduler(initialClock: 0)

            let xs = await scheduler.createHotObservable([
                .next(210, 1),
                .next(220, 2),
                .next(230, 3),
                .next(240, 4),
                .next(250, 5),
                .next(320, 6),
                .completed(330),
                .next(340, -1),
                .next(550, 7),
                ])

            var subscription1: Disposable! = nil
            var subscription2: Disposable! = nil
            var subscription3: Disposable! = nil

            let res1 = scheduler.createObserver(Int.self)
            let res2 = scheduler.createObserver(Int.self)
            let res1_ = scheduler.createObserver(Int.self)
            let res2_ = scheduler.createObserver(Int.self)
            let res3 = scheduler.createObserver(Int.self)

            var ys: Observable<Int>! = nil

            await scheduler.scheduleAt(Defaults.created) { ys = await xs.share(replay: i, scope: .whileConnected) }

            await scheduler.scheduleAt(200) {
                subscription1 = await ys.subscribe { event in
                    res1.on(event)
                    switch event {
                    case .error: subscription1 = await ys.subscribe(res1_)
                    case .completed: subscription1 = await ys.subscribe(res1_)
                    case .next: break
                    }
                }
            }
            await scheduler.scheduleAt(300) {
                subscription2 = await ys.subscribe { event in
                    res2.on(event)
                    switch event {
                    case .error: subscription2 = await ys.subscribe(res2_)
                    case .completed: subscription2 = await ys.subscribe(res2_)
                    case .next: break
                    }
                }
            }

            await scheduler.scheduleAt(350) { await subscription1.dispose() }
            await scheduler.scheduleAt(400) { await subscription2.dispose() }

            await scheduler.scheduleAt(500) { subscription3 = await ys.subscribe(res3) }
            await scheduler.scheduleAt(600) { await subscription3.dispose() }

            await scheduler.start()

            XCTAssertEqual(res1.events, [
                .next(210, 1),
                .next(220, 2),
                .next(230, 3),
                .next(240, 4),
                .next(250, 5),
                .next(320, 6),
                .completed(330)
                ])

            XCTAssertEqual(res1_.events, [.next(340, -1)])
            XCTAssertEqual(res2_.events, [.next(340, -1)])

            let replayedEvents2 = (0 ..< i).map { Recorded.next(300, 6 - i + $0) }
            XCTAssertEqual(res2.events, replayedEvents2 + [.next(320, 6), .completed(330)])
            
            XCTAssertEqual(res3.events, [.next(550, 7)])
            
            XCTAssertEqual(xs.subscriptions, [
                Subscription(200, 330),
                Subscription(330, 400),
                Subscription(500, 600)
                ])
        }
    }

    #if TRACE_RESOURCES
    func testReleasesResourcesOnComplete() async {
            for i in 0 ..< 5 {
                _ = await Observable<Int>.just(1).share(replay: i, scope: .forever).subscribe()
                _ = await Observable<Int>.just(1).share(replay: i, scope: .whileConnected).subscribe()
            }
        }

    func testReleasesResourcesOnError() async {
            for i in 0 ..< 5 {
                _ = await Observable<Int>.error(testError).share(replay: i, scope: .forever).subscribe()
                _ = await Observable<Int>.error(testError).share(replay: i, scope: .whileConnected).subscribe()
            }
        }
    #endif
}
