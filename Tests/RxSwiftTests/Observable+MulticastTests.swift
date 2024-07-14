//
//  Observable+MulticastTests.swift
//  Tests
//
//  Created by Krunoslav Zaher on 4/29/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

import XCTest
import RxSwift
import RxTest

class ObservableMulticastTest : RxTest {
}

extension ObservableMulticastTest {
    func testMulticastWhileConnected_connectControlsSourceSubscription() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(110, 7),
            .next(220, 3),
            .next(280, 4),
            .next(290, 1),
            .next(340, 8),
            .next(360, 5),
            .next(370, 6),
            .next(390, 7),
            .next(410, 13),
            .next(430, 2),
            .next(450, 9),
            .next(520, 11),
            .next(560, 20),
            .next(570, 21),
            .next(580, 23),
            .next(590, 24),
            .next(600, 25),
            .next(610, 26),
            .next(620, 27),
            .next(630, 28),
            .error(800, testError)
            ])

        var ys: ConnectableObservable<Int>! = nil
        var subscription: Disposable! = nil
        var connection: Disposable! = nil
        var innerConnection: Disposable! = nil
        var lastConnection: Disposable! = nil
        let res = scheduler.createObserver(Int.self)

        await scheduler.scheduleAt(Defaults.created) { ys = await xs.multicast(makeSubject: { await ReplaySubject.create(bufferSize: 3) }) }
        await scheduler.scheduleAt(405, action: { subscription = await ys.subscribe(res) })
        await scheduler.scheduleAt(Defaults.disposed) { await subscription.dispose() }

        await scheduler.scheduleAt(300) { connection = await ys.connect() }
        await scheduler.scheduleAt(400) { await connection.dispose() }

        await scheduler.scheduleAt(420) { connection = await ys.connect() }
        await scheduler.scheduleAt(440) { innerConnection = await ys.connect() }
        await scheduler.scheduleAt(530) { await innerConnection.dispose() }
        await scheduler.scheduleAt(575) { lastConnection = await ys.connect() }
        await scheduler.scheduleAt(590) { await connection.dispose() }

        await scheduler.scheduleAt(621) { await lastConnection.dispose() }

        await scheduler.start()

        XCTAssertEqual(res.events, [
            .next(430, 2),
            .next(450, 9),
            .next(520, 11),
            ])

        XCTAssertEqual(xs.subscriptions, [
            Subscription(300, 400),
            Subscription(420, 530),
            Subscription(575, 621)
            ])
    }

    func testMulticastWhileConnected_connectFirstThenSubscribe() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(110, 7),
            .next(220, 3),
            .next(280, 4),
            .next(290, 1),
            .next(340, 8),
            .next(360, 5),
            .next(370, 6),
            .next(390, 7),
            .next(410, 13),
            .next(430, 2),
            .next(450, 9),
            .next(520, 11),
            .next(560, 20),
            .next(570, 21),
            .next(580, 23),
            .next(590, 24),
            .next(600, 25),
            .next(610, 26),
            .next(620, 27),
            .next(630, 28),
            .error(800, testError)
            ])

        var ys: ConnectableObservable<Int>! = nil
        var subscription: Disposable! = nil
        var connection: Disposable! = nil
        var innerConnection: Disposable! = nil
        var lastConnection: Disposable! = nil
        let res = scheduler.createObserver(Int.self)

        await scheduler.scheduleAt(Defaults.created) { ys = await xs.multicast(makeSubject: { await ReplaySubject.create(bufferSize: 1) }) }
        await scheduler.scheduleAt(470, action: { subscription = await ys.subscribe(res) })
        await scheduler.scheduleAt(Defaults.disposed) { await subscription.dispose() }

        await scheduler.scheduleAt(300) { connection = await ys.connect() }
        await scheduler.scheduleAt(400) { await connection.dispose() }

        await scheduler.scheduleAt(420) { connection = await ys.connect() }
        await scheduler.scheduleAt(440) { innerConnection = await ys.connect() }
        await scheduler.scheduleAt(530) { await innerConnection.dispose() }
        await scheduler.scheduleAt(575) { lastConnection = await ys.connect() }
        await scheduler.scheduleAt(590) { await connection.dispose() }

        await scheduler.scheduleAt(621) { await lastConnection.dispose() }

        await scheduler.start()

        XCTAssertEqual(res.events, [
            .next(470, 9),
            .next(520, 11),
            ])

        XCTAssertEqual(xs.subscriptions, [
            Subscription(300, 400),
            Subscription(420, 530),
            Subscription(575, 621)
            ])
    }

    func testMulticastWhileConnected_completed() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(110, 7),
            .next(220, 3),
            .next(280, 4),
            .next(290, 1),
            .next(340, 8),
            .next(360, 5),
            .next(370, 6),
            .next(390, 7),
            .next(410, 13),
            .next(430, 2),
            .completed(435),
            .next(450, 9),
            .next(520, 11),
            .next(560, 20),
            .next(570, 21),
            .next(580, 23),
            .next(590, 24),
            .next(600, 25),
            .next(610, 26),
            .next(620, 27),
            .next(630, 28),
            .error(800, testError)
            ])

        var ys: ConnectableObservable<Int>! = nil
        var subscription: Disposable! = nil
        var connection: Disposable! = nil
        var innerConnection: Disposable! = nil
        var lastConnection: Disposable! = nil
        let res = scheduler.createObserver(Int.self)

        await scheduler.scheduleAt(Defaults.created) { ys = await xs.multicast(makeSubject: { await ReplaySubject.create(bufferSize: 1) }) }
        await scheduler.scheduleAt(405, action: {
            subscription = await ys.do(onCompleted: {
                subscription = await ys.subscribe(res)
                _ = await ys.connect()
            }).subscribe(res)
        })
        await scheduler.scheduleAt(Defaults.disposed) { await subscription.dispose() }

        await scheduler.scheduleAt(300) { connection = await ys.connect() }
        await scheduler.scheduleAt(400) { await connection.dispose() }

        await scheduler.scheduleAt(420) { connection = await ys.connect() }
        await scheduler.scheduleAt(440) { innerConnection = await ys.connect() }
        await scheduler.scheduleAt(530) { await innerConnection.dispose() }
        await scheduler.scheduleAt(575) { lastConnection = await ys.connect() }
        await scheduler.scheduleAt(590) { await connection.dispose() }

        await scheduler.scheduleAt(621) { await lastConnection.dispose() }

        await scheduler.start()

        XCTAssertEqual(res.events, [
            .next(430, 2),
            .completed(435),
            .next(450, 9),
            .next(520, 11),
            ])

        XCTAssertEqual(xs.subscriptions, [
            Subscription(300, 400),
            Subscription(420, 435),
            Subscription(435, 530),
            Subscription(575, 621),
            ])
    }

    func testMulticastWhileConnected_error() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(110, 7),
            .next(220, 3),
            .next(280, 4),
            .next(290, 1),
            .next(340, 8),
            .next(360, 5),
            .next(370, 6),
            .next(390, 7),
            .next(410, 13),
            .next(430, 2),
            .error(435, testError),
            .next(450, 9),
            .next(520, 11),
            .next(560, 20),
            .next(570, 21),
            .next(580, 23),
            .next(590, 24),
            .next(600, 25),
            .next(610, 26),
            .next(620, 27),
            .next(630, 28),
            .error(800, testError)
            ])

        var ys: ConnectableObservable<Int>! = nil
        var subscription: Disposable! = nil
        var connection: Disposable! = nil
        var innerConnection: Disposable! = nil
        var lastConnection: Disposable! = nil
        let res = scheduler.createObserver(Int.self)

        await scheduler.scheduleAt(Defaults.created) { ys = await xs.multicast(makeSubject: { await ReplaySubject.create(bufferSize: 1) }) }
        await scheduler.scheduleAt(405, action: {
            subscription = await ys.do(onError: { _ in
                subscription = await ys.subscribe(res)
                _ = await ys.connect()
            }).subscribe(res)
        })
        await scheduler.scheduleAt(Defaults.disposed) { await subscription.dispose() }

        await scheduler.scheduleAt(300) { connection = await ys.connect() }
        await scheduler.scheduleAt(400) { await connection.dispose() }

        await scheduler.scheduleAt(420) { connection = await ys.connect() }
        await scheduler.scheduleAt(440) { innerConnection = await ys.connect() }
        await scheduler.scheduleAt(530) { await innerConnection.dispose() }
        await scheduler.scheduleAt(575) { lastConnection = await ys.connect() }
        await scheduler.scheduleAt(590) { await connection.dispose() }

        await scheduler.scheduleAt(621) { await lastConnection.dispose() }

        await scheduler.start()

        XCTAssertEqual(res.events, [
            .next(430, 2),
            .error(435, testError),
            .next(450, 9),
            .next(520, 11),
            ])

        XCTAssertEqual(xs.subscriptions, [
            Subscription(300, 400),
            Subscription(420, 435),
            Subscription(435, 530),
            Subscription(575, 621),
            ])
    }

    func testMulticastForever_connectControlsSourceSubscription() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(110, 7),
            .next(220, 3),
            .next(280, 4),
            .next(290, 1),
            .next(340, 8),
            .next(360, 5),
            .next(370, 6),
            .next(390, 7),
            .next(410, 13),
            .next(430, 2),
            .next(450, 9),
            .next(520, 11),
            .next(560, 20),
            .next(570, 21),
            .next(580, 23),
            .next(590, 24),
            .next(600, 25),
            .next(610, 26),
            .next(620, 27),
            .next(630, 28),
            .error(800, testError)
            ])

        var ys: ConnectableObservable<Int>! = nil
        var subscription: Disposable! = nil
        var connection: Disposable! = nil
        var innerConnection: Disposable! = nil
        var lastConnection: Disposable! = nil
        let res = scheduler.createObserver(Int.self)

        await scheduler.scheduleAt(Defaults.created) { ys = await xs.multicast(ReplaySubject.create(bufferSize: 3)) }
        await scheduler.scheduleAt(405, action: { subscription = await ys.subscribe(res) })
        await scheduler.scheduleAt(Defaults.disposed) { await subscription.dispose() }

        await scheduler.scheduleAt(300) { connection = await ys.connect() }
        await scheduler.scheduleAt(400) { await connection.dispose() }

        await scheduler.scheduleAt(420) { connection = await ys.connect() }
        await scheduler.scheduleAt(440) { innerConnection = await ys.connect() }
        await scheduler.scheduleAt(530) { await innerConnection.dispose() }
        await scheduler.scheduleAt(575) { lastConnection = await ys.connect() }
        await scheduler.scheduleAt(590) { await connection.dispose() }

        await scheduler.scheduleAt(621) { await lastConnection.dispose() }

        await scheduler.start()

        XCTAssertEqual(res.events, [
            .next(405, 5),
            .next(405, 6),
            .next(405, 7),
            .next(430, 2),
            .next(450, 9),
            .next(520, 11),
            .next(580, 23),
            .next(590, 24),
            .next(600, 25),
            .next(610, 26),
            .next(620, 27),
            ])

        XCTAssertEqual(xs.subscriptions, [
            Subscription(300, 400),
            Subscription(420, 530),
            Subscription(575, 621)
            ])
    }

    func testMulticastForever_connectFirstThenSubscribe() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(110, 7),
            .next(220, 3),
            .next(280, 4),
            .next(290, 1),
            .next(340, 8),
            .next(360, 5),
            .next(370, 6),
            .next(390, 7),
            .next(410, 13),
            .next(430, 2),
            .next(450, 9),
            .next(520, 11),
            .next(560, 20),
            .next(570, 21),
            .next(580, 23),
            .next(590, 24),
            .next(600, 25),
            .next(610, 26),
            .next(620, 27),
            .next(630, 28),
            .error(800, testError)
            ])

        var ys: ConnectableObservable<Int>! = nil
        var subscription: Disposable! = nil
        var connection: Disposable! = nil
        var innerConnection: Disposable! = nil
        var lastConnection: Disposable! = nil
        let res = scheduler.createObserver(Int.self)

        await scheduler.scheduleAt(Defaults.created) { ys = await xs.multicast(ReplaySubject.create(bufferSize: 1)) }
        await scheduler.scheduleAt(470, action: { subscription = await ys.subscribe(res) })
        await scheduler.scheduleAt(Defaults.disposed) { await subscription.dispose() }

        await scheduler.scheduleAt(300) { connection = await ys.connect() }
        await scheduler.scheduleAt(400) { await connection.dispose() }

        await scheduler.scheduleAt(420) { connection = await ys.connect() }
        await scheduler.scheduleAt(440) { innerConnection = await ys.connect() }
        await scheduler.scheduleAt(530) { await innerConnection.dispose() }
        await scheduler.scheduleAt(575) { lastConnection = await ys.connect() }
        await scheduler.scheduleAt(590) { await connection.dispose() }

        await scheduler.scheduleAt(621) { await lastConnection.dispose() }

        await scheduler.start()

        XCTAssertEqual(res.events, [
            .next(470, 9),
            .next(520, 11),
            .next(580, 23),
            .next(590, 24),
            .next(600, 25),
            .next(610, 26),
            .next(620, 27),
            ])

        XCTAssertEqual(xs.subscriptions, [
            Subscription(300, 400),
            Subscription(420, 530),
            Subscription(575, 621)
            ])
    }

    func testMulticastForever_completed() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(110, 7),
            .next(220, 3),
            .next(280, 4),
            .next(290, 1),
            .next(340, 8),
            .next(360, 5),
            .next(370, 6),
            .next(390, 7),
            .next(410, 13),
            .next(430, 2),
            .completed(435),
            .next(450, 9),
            .next(520, 11),
            .next(560, 20),
            .next(570, 21),
            .next(580, 23),
            .next(590, 24),
            .next(600, 25),
            .next(610, 26),
            .next(620, 27),
            .next(630, 28),
            .error(800, testError)
            ])

        var ys: ConnectableObservable<Int>! = nil
        var subscription: Disposable! = nil
        var connection: Disposable! = nil
        var innerConnection: Disposable! = nil
        var lastConnection: Disposable! = nil
        let res = scheduler.createObserver(Int.self)

        await scheduler.scheduleAt(Defaults.created) { ys = await xs.multicast(ReplaySubject.create(bufferSize: 1)) }
        await scheduler.scheduleAt(405, action: {
            subscription = await ys.do(onCompleted: {
                subscription = await ys.subscribe(res)
                _ = await ys.connect()
            }).subscribe(res)
        })
        await scheduler.scheduleAt(Defaults.disposed) { await subscription.dispose() }

        await scheduler.scheduleAt(300) { connection = await ys.connect() }
        await scheduler.scheduleAt(400) { await connection.dispose() }

        await scheduler.scheduleAt(420) { connection = await ys.connect() }
        await scheduler.scheduleAt(440) { innerConnection = await ys.connect() }
        await scheduler.scheduleAt(530) { await innerConnection.dispose() }
        await scheduler.scheduleAt(575) { lastConnection = await ys.connect() }
        await scheduler.scheduleAt(590) { await connection.dispose() }

        await scheduler.scheduleAt(621) { await lastConnection.dispose() }

        await scheduler.start()

        XCTAssertEqual(res.events, [
            .next(405, 7),
            .next(430, 2),
            .next(435, 2),
            .completed(435),
            .completed(435),
            ])

        XCTAssertEqual(xs.subscriptions, [
            Subscription(300, 400),
            Subscription(420, 435),
            Subscription(435, 530),
            Subscription(575, 621),
            ])
    }

    func testMulticastForever_error() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(110, 7),
            .next(220, 3),
            .next(280, 4),
            .next(290, 1),
            .next(340, 8),
            .next(360, 5),
            .next(370, 6),
            .next(390, 7),
            .next(410, 13),
            .next(430, 2),
            .error(435, testError),
            .next(450, 9),
            .next(520, 11),
            .next(560, 20),
            .next(570, 21),
            .next(580, 23),
            .next(590, 24),
            .next(600, 25),
            .next(610, 26),
            .next(620, 27),
            .next(630, 28),
            .error(800, testError)
            ])

        var ys: ConnectableObservable<Int>! = nil
        var subscription: Disposable! = nil
        var connection: Disposable! = nil
        var innerConnection: Disposable! = nil
        var lastConnection: Disposable! = nil
        let res = scheduler.createObserver(Int.self)

        await scheduler.scheduleAt(Defaults.created) { ys = await xs.multicast(ReplaySubject.create(bufferSize: 1)) }
        await scheduler.scheduleAt(405, action: {
            subscription = await ys.do(onError: { _ in
                subscription = await ys.subscribe(res)
                _ = await ys.connect()
            }).subscribe(res)
        })
        await scheduler.scheduleAt(Defaults.disposed) { await subscription.dispose() }

        await scheduler.scheduleAt(300) { connection = await ys.connect() }
        await scheduler.scheduleAt(400) { await connection.dispose() }

        await scheduler.scheduleAt(420) { connection = await ys.connect() }
        await scheduler.scheduleAt(440) { innerConnection = await ys.connect() }
        await scheduler.scheduleAt(530) { await innerConnection.dispose() }
        await scheduler.scheduleAt(575) { lastConnection = await ys.connect() }
        await scheduler.scheduleAt(590) { await connection.dispose() }

        await scheduler.scheduleAt(621) { await lastConnection.dispose() }

        await scheduler.start()

        XCTAssertEqual(res.events, [
            .next(405, 7),
            .next(430, 2),
            .next(435, 2),
            .error(435, testError),
            .error(435, testError),
            ])

        XCTAssertEqual(xs.subscriptions, [
            Subscription(300, 400),
            Subscription(420, 435),
            Subscription(435, 530),
            Subscription(575, 621),
            ])
    }

    #if TRACE_RESOURCES
    func testMulticastWhileConnected_ReleasesResourcesOnComplete() async {
        let publish = await Observable<Int>.just(1).multicast(makeSubject: { await PublishSubject() })
        _ = await publish.subscribe()
        _ = await publish.connect()
        }

    func testMulticastWhileConnected_ReleasesResourcesOnError() async {
        let publish = await Observable<Int>.error(testError).multicast(makeSubject: { await PublishSubject() })
        _ = await publish.subscribe()
        _ = await publish.connect()
        }

    func testMulticastForever_ReleasesResourcesOnComplete() async {
        let publish = await Observable<Int>.just(1).multicast(PublishSubject())
        _ = await publish.subscribe()
        _ = await publish.connect()
        }

    func testMulticastForever_ReleasesResourcesOnError() async {
        let publish = await Observable<Int>.error(testError).multicast(PublishSubject())
        _ = await publish.subscribe()
        _ = await publish.connect()
        }
    #endif
}

extension ObservableMulticastTest {
    func testMulticast_Cold_Completed() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(40, 0),
            .next(90, 1),
            .next(150, 2),
            .next(210, 3),
            .next(240, 4),
            .next(270, 5),
            .next(330, 6),
            .next(340, 7),
            .completed(390)
            ])

        let res = await scheduler.start {
            await xs.multicast({ PublishSubject<Int>() }) { $0 }
        }

        XCTAssertEqual(res.events, [
            .next(210, 3),
            .next(240, 4),
            .next(270, 5),
            .next(330, 6),
            .next(340, 7),
            .completed(390)
            ])

        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 390)
            ])
    }

    func testMulticast_Cold_Error() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(40, 0),
            .next(90, 1),
            .next(150, 2),
            .next(210, 3),
            .next(240, 4),
            .next(270, 5),
            .next(330, 6),
            .next(340, 7),
            .error(390, testError)
            ])

        let res = await scheduler.start {
            await xs.multicast({ PublishSubject<Int>() }) { $0 }
        }

        XCTAssertEqual(res.events, [
            .next(210, 3),
            .next(240, 4),
            .next(270, 5),
            .next(330, 6),
            .next(340, 7),
            .error(390, testError)
            ])

        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 390)
            ])
    }

    func testMulticast_Cold_Dispose() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(40, 0),
            .next(90, 1),
            .next(150, 2),
            .next(210, 3),
            .next(240, 4),
            .next(270, 5),
            .next(330, 6),
            .next(340, 7),
            ])

        let res = await scheduler.start {
            await xs.multicast({ PublishSubject<Int>() }) { $0 }
        }

        XCTAssertEqual(res.events, [
            .next(210, 3),
            .next(240, 4),
            .next(270, 5),
            .next(330, 6),
            .next(340, 7),
            ])

        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 1000)
            ])
    }

    func testMulticast_Cold_Zip() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(40, 0),
            .next(90, 1),
            .next(150, 2),
            .next(210, 3),
            .next(240, 4),
            .next(270, 5),
            .next(330, 6),
            .next(340, 7),
            .completed(390)
            ])

        let res = await scheduler.start {
            await xs.multicast({ PublishSubject<Int>() }) { Observable.zip($0, $0) { a, b in a + b } }
        }

        XCTAssertEqual(res.events, [
            .next(210, 6),
            .next(240, 8),
            .next(270, 10),
            .next(330, 12),
            .next(340, 14),
            .completed(390)
            ])

        XCTAssertEqual(xs.subscriptions, [
            Subscription(200, 390)
            ])
    }

    func testMulticast_SubjectSelectorThrows() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(210, 1),
            .next(240, 2),
            .completed(300)
            ])

        let res = await scheduler.start {
            await xs.multicast({ () throws -> PublishSubject<Int> in throw testError }) { $0 }
        }

        XCTAssertEqual(res.events, [
            .error(200, testError)
            ])

        XCTAssertEqual(xs.subscriptions, [
            ])
    }

    func testMulticast_SelectorThrows() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(210, 1),
            .next(240, 2),
            .completed(300)
            ])

        let res = await scheduler.start {
            await xs.multicast({ PublishSubject<Int>() }) { _ -> Observable<Int> in throw testError }
        }

        XCTAssertEqual(res.events, [
            .error(200, testError)
            ])

        XCTAssertEqual(xs.subscriptions, [
            ])
    }

    #if TRACE_RESOURCES
    func testMulticastReleasesResourcesOnComplete() async {
        _ = await Observable<Int>.just(1).multicast({ PublishSubject<Int>() }) { Observable.zip($0, $0) { a, b in a + b } }.subscribe()
        }

    func testMulticastReleasesResourcesOnError() async {
        _ = await Observable<Int>.error(testError).multicast({ PublishSubject<Int>() }) { Observable.zip($0, $0) { a, b in a + b } }.subscribe()
        }
    #endif
}

// publish
extension ObservableMulticastTest {
    #if TRACE_RESOURCES
    func testPublishReleasesResourcesOnComplete() async {
        let publish = await Observable<Int>.just(1).publish()
        _ = await publish.subscribe()
        _ = await publish.connect()
        }

    func testPublishReleasesResourcesOnError() async {
        let publish = await Observable<Int>.error(testError).publish()
        _ = await publish.subscribe()
        _ = await publish.connect()
        }
    #endif
}

// refCount
extension ObservableMulticastTest {
    func testRefCount_DeadlockSimple() async {
        let subject = MySubject<Int>()

        var nEvents = 0

        let observable = await TestConnectableObservable(o: Observable.of(0, 1, 2), s: subject)
        let d = await observable.subscribe(onNext: { _ in
            nEvents += 1
        })

        defer {
            d.dispose()
        }

        await observable.connect().dispose()

        XCTAssertEqual(nEvents, 3)
    }

    func testRefCount_DeadlockErrorAfterN() async {
        let subject = MySubject<Int>()

        var nEvents = 0

        let observable = await TestConnectableObservable(o: Observable.concat([Observable.of(0, 1, 2), Observable.error(testError)]), s: subject)
        let d = await observable.subscribe(onError: { _ in
            nEvents += 1
        })

        defer {
            d.dispose()
        }

        await observable.connect().dispose()

        XCTAssertEqual(nEvents, 1)
    }

    func testRefCount_DeadlockErrorImmediately() async {
        let subject = MySubject<Int>()

        var nEvents = 0

        let observable = await TestConnectableObservable(o: Observable.error(testError), s: subject)
        let d = await observable.subscribe(onError: { _ in
            nEvents += 1
        })

        defer {
            d.dispose()
        }

        await observable.connect().dispose()

        XCTAssertEqual(nEvents, 1)
    }

    func testRefCount_DeadlockEmpty() async {
        let subject = MySubject<Int>()

        var nEvents = 0

        let observable = await TestConnectableObservable(o: Observable.empty(), s: subject)
        let d = await observable.subscribe(onCompleted: {
            nEvents += 1
        })

        defer {
            d.dispose()
        }

        await observable.connect().dispose()

        XCTAssertEqual(nEvents, 1)
    }

    func testRefCount_ConnectsOnFirst() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(210, 1),
            .next(220, 2),
            .next(230, 3),
            .next(240, 4),
            .completed(250)
            ])

        let subject = MySubject<Int>()
        
        let conn = await TestConnectableObservable(o: xs.asObservable(), s: subject)

        let res = await scheduler.start { await conn.refCount() }

        XCTAssertEqual(res.events, [
            .next(210, 1),
            .next(220, 2),
            .next(230, 3),
            .next(240, 4),
            .completed(250)
            ])

        XCTAssertEqual(xs.subscriptions, [Subscription(200, 250)])
        XCTAssertTrue(subject.isDisposed)
    }

    func testRefCount_DoesntConnectsOnFirstInCaseSynchronousCompleted() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(210, 1),
            ])

        let subject = await PublishSubject<Int>()
        await subject.on(.completed)

        let conn = await TestConnectableObservable(o: xs.asObservable(), s: subject)

        let res = await scheduler.start { await conn.refCount() }

        XCTAssertEqual(res.events, [
            .completed(200, Int.self)
            ])

        XCTAssertEqual(xs.subscriptions, [])
    }

    func testRefCount_DoesntConnectsOnFirstInCaseSynchronousError() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(210, 1),
            ])

        let subject = await PublishSubject<Int>()
        await subject.on(.error(testError))

        let conn = await TestConnectableObservable(o: xs.asObservable(), s: subject)

        let res = await scheduler.start { await conn.refCount() }

        XCTAssertEqual(res.events, [
            .error(200, testError, Int.self)
            ])

        XCTAssertEqual(xs.subscriptions, [])
    }

    func testRefCount_NotConnected() async {
        _ = await TestScheduler(initialClock: 0)

        var disconnected = false
        var count = 0

        let xs: Observable<Int> = await Observable.deferred {
            count += 1
            return await Observable.create { _ in
                return await Disposables.create {
                    disconnected = true
                }
            }
        }

        let subject = MySubject<Int>()

        let conn = await TestConnectableObservable(o: xs, s: subject)
        let refd = await conn.refCount()

        let dis1 = await refd.subscribe { _ -> Void in () }
        XCTAssertEqual(1, count)
        XCTAssertEqual(1, subject.subscribeCount)
        XCTAssertFalse(disconnected)

        let dis2 = await refd.subscribe { _ -> Void in () }
        XCTAssertEqual(1, count)
        XCTAssertEqual(2, subject.subscribeCount)
        XCTAssertFalse(disconnected)

        await dis1.dispose()
        XCTAssertFalse(disconnected)
        await dis2.dispose()
        XCTAssertTrue(disconnected)
        disconnected = false

        let dis3 = await refd.subscribe { _ -> Void in () }
        XCTAssertEqual(2, count)
        XCTAssertEqual(3, subject.subscribeCount)
        XCTAssertFalse(disconnected)

        await dis3.dispose()
        XCTAssertTrue(disconnected)
    }

    func testRefCount_Error() async {
        let xs: Observable<Int> = await Observable.error(testError)

        let res = await xs.publish().refCount()
        _ = await res.subscribe { event in
            switch event {
            case .next:
                XCTAssertTrue(false)
            case .error(let error):
                XCTAssertErrorEqual(error, testError)
            case .completed:
                XCTAssertTrue(false)
            }
        }
        _ = await res.subscribe { event in
            switch event {
            case .next:
                XCTAssertTrue(false)
            case .error(let error):
                XCTAssertErrorEqual(error, testError)
            case .completed:
                XCTAssertTrue(false)
            }
        }
    }

    func testRefCount_Publish() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(210, 1),
            .next(220, 2),
            .next(230, 3),
            .next(240, 4),
            .next(250, 5),
            .next(260, 6),
            .next(270, 7),
            .next(280, 8),
            .next(290, 9),
            .completed(300)
            ])

        let res = await xs.publish().refCount()

        var d1: Disposable!
        let o1 = scheduler.createObserver(Int.self)
        await scheduler.scheduleAt(215) { d1 = await res.subscribe(o1) }
        await scheduler.scheduleAt(235) { await d1.dispose() }

        var d2: Disposable!
        let o2 = scheduler.createObserver(Int.self)
        await scheduler.scheduleAt(225) { d2 = await res.subscribe(o2) }
        await scheduler.scheduleAt(275) { await d2.dispose() }

        var d3: Disposable!
        let o3 = scheduler.createObserver(Int.self)
        await scheduler.scheduleAt(255) { d3 = await res.subscribe(o3) }
        await scheduler.scheduleAt(265) { await d3.dispose() }

        var d4: Disposable!
        let o4 = scheduler.createObserver(Int.self)
        await scheduler.scheduleAt(285) { d4 = await res.subscribe(o4) }
        await scheduler.scheduleAt(320) { await d4.dispose() }

        await scheduler.start()

        XCTAssertEqual(o1.events, [
            .next(220, 2),
            .next(230, 3)
            ])

        XCTAssertEqual(o2.events, [
            .next(230, 3),
            .next(240, 4),
            .next(250, 5),
            .next(260, 6),
            .next(270, 7)
            ])

        XCTAssertEqual(o3.events, [
            .next(260, 6)
            ])

        XCTAssertEqual(o4.events, [
            .next(290, 9),
            .completed(300)
            ])

        XCTAssertEqual(xs.subscriptions, [
            Subscription(215, 275),
            Subscription(285, 300)
            ])
    }

    func testRefCount_synchronousResubscribingOnErrorWorks() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs1 = await scheduler.createColdObservable([
            .next(10, 1),
            .error(20, testError)
            ])

        let xs2 = await scheduler.createColdObservable([
            .next(10, 2),
            .error(30, testError1)
            ])

        let xs3 = await scheduler.createColdObservable([
            .next(10, 3),
            .error(40, testError2)
            ])

        var attempts = 0

        let xs = await Observable.deferred { () -> Observable<Int> in
            defer { attempts += 1 }
            switch attempts {
            case 0: return await xs1.asObservable()
            case 1: return await xs2.asObservable()
            default: return await xs3.asObservable()
            }
        }

        let res = await xs.multicast { await PublishSubject() }.refCount()

        let o1 = scheduler.createObserver(Int.self)
        let o2 = scheduler.createObserver(Int.self)
        let o3 = scheduler.createObserver(Int.self)
        await scheduler.scheduleAt(215) {
            _ = await res.subscribe { event in
                o1.on(event)
                switch event {
                case .error:
                    _ = await res.subscribe(o1)
                default: break
                }
            }
        }
        await scheduler.scheduleAt(220) {
            _ = await res.subscribe { event in
                o2.on(event)
                switch event {
                case .error:
                    _ = await res.subscribe(o2)
                default: break
                }
            }
        }

        await scheduler.scheduleAt(400) {
            _ = await res.subscribe(o3)
        }

        await scheduler.start()

        XCTAssertEqual(o1.events, [
            .next(225, 1),
            .error(235, testError),
            .next(245, 2),
            .error(265, testError1)
            ])

        XCTAssertEqual(o2.events, [
            .next(225, 1),
            .error(235, testError),
            .next(245, 2),
            .error(265, testError1)
            ])

        XCTAssertEqual(o3.events, [
            .next(410, 3),
            .error(440, testError2)
            ])

        XCTAssertEqual(xs1.subscriptions, [
            Subscription(215, 235),
            ])
        XCTAssertEqual(xs2.subscriptions, [
            Subscription(235, 265),
            ])
        XCTAssertEqual(xs3.subscriptions, [
            Subscription(400, 440),
            ])
    }

    func testRefCount_synchronousResubscribingOnCompletedWorks() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs1 = await scheduler.createColdObservable([
            .next(10, 1),
            .completed(20)
            ])

        let xs2 = await scheduler.createColdObservable([
            .next(10, 2),
            .completed(30)
            ])

        let xs3 = await scheduler.createColdObservable([
            .next(10, 3),
            .completed(40)
            ])

        var attempts = 0

        let xs = await Observable.deferred { () -> Observable<Int> in
            defer { attempts += 1 }
            switch attempts {
            case 0: return await xs1.asObservable()
            case 1: return await xs2.asObservable()
            default: return await xs3.asObservable()
            }
        }

        let res = await xs.multicast { await PublishSubject() }.refCount()

        let o1 = scheduler.createObserver(Int.self)
        let o2 = scheduler.createObserver(Int.self)
        let o3 = scheduler.createObserver(Int.self)
        await scheduler.scheduleAt(215) {
            _ = await res.subscribe { event in
                o1.on(event)
                switch event {
                case .completed:
                    _ = await res.subscribe(o1)
                default: break
                }
            }
        }
        await scheduler.scheduleAt(220) {
            _ = await res.subscribe { event in
                o2.on(event)
                switch event {
                case .completed:
                    _ = await res.subscribe(o2)
                default: break
                }
            }
        }

        await scheduler.scheduleAt(400) {
            _ = await res.subscribe(o3)
        }

        await scheduler.start()

        XCTAssertEqual(o1.events, [
            .next(225, 1),
            .completed(235),
            .next(245, 2),
            .completed(265)
            ])

        XCTAssertEqual(o2.events, [
            .next(225, 1),
            .completed(235),
            .next(245, 2),
            .completed(265)
            ])

        XCTAssertEqual(o3.events, [
            .next(410, 3),
            .completed(440),
            ])

        XCTAssertEqual(xs1.subscriptions, [
            Subscription(215, 235),
            ])
        XCTAssertEqual(xs2.subscriptions, [
            Subscription(235, 265),
            ])
        XCTAssertEqual(xs3.subscriptions, [
            Subscription(400, 440),
            ])
    }

    #if TRACE_RESOURCES
    func testRefCountReleasesResourcesOnComplete() async {
        _ = await Observable<Int>.just(1).publish().refCount().subscribe()
        }

    func testRefCountReleasesResourcesOnError() async {
        _ = await Observable<Int>.error(testError).publish().refCount().subscribe()
        }
    #endif
}

extension ObservableMulticastTest {
    func testReplayCount_Basic() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createColdObservable([
            .next(10, 5),
            .next(20, 9),
            .next(30, 11),
            .next(40, 20),
            .next(50, 22),
            .next(60, 23),
            .next(70, 24),
            .next(80, 25),
            .error(130, testError)
            ])

        var ys: ConnectableObservable<Int>! = nil
        var subscription: Disposable! = nil
        var connection: Disposable! = nil
        let res = scheduler.createObserver(Int.self)

        await scheduler.scheduleAt(Defaults.created) { ys = await xs.debug("1").replay(3) }
        await scheduler.scheduleAt(450, action: { subscription = await ys.debug("2").subscribe(res) })
        await scheduler.scheduleAt(Defaults.disposed) { await subscription.dispose() }

        await scheduler.scheduleAt(400) { connection = await ys.connect() }
        await scheduler.scheduleAt(520) { await connection.dispose() }

        await scheduler.scheduleAt(650) { connection = await ys.connect() }
        await scheduler.scheduleAt(700) { await connection.dispose() }

        await scheduler.start()

        XCTAssertEqual(res.events, [
            .next(450, 9),
            .next(450, 11),
            .next(450, 20),
            .next(450, 22),
            .next(460, 23),
            .next(470, 24),
            .next(480, 25),
            ])

        XCTAssertEqual(xs.subscriptions, [
            Subscription(400, 520),
            Subscription(650, 700)
            ])
    }

    func testReplayCount_Error() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createColdObservable([
            .next(10, 5),
            .next(20, 9),
            .next(30, 11),
            .next(40, 20),
            .next(50, 22),
            .next(60, 23),
            .next(70, 24),
            .next(80, 25),
            .error(90, testError)
            ])

        var ys: ConnectableObservable<Int>! = nil
        var subscription: Disposable! = nil
        var connection: Disposable! = nil
        let res = scheduler.createObserver(Int.self)

        await scheduler.scheduleAt(Defaults.created) { ys = await xs.replay(3) }
        await scheduler.scheduleAt(450, action: { subscription = await ys.subscribe(res) })
        await scheduler.scheduleAt(Defaults.disposed) { await subscription.dispose() }

        await scheduler.scheduleAt(400) { connection = await ys.connect() }
        await scheduler.scheduleAt(520) { await connection.dispose() }

        await scheduler.scheduleAt(650) { connection = await ys.connect() }
        await scheduler.scheduleAt(700) { await connection.dispose() }

        await scheduler.start()

        XCTAssertEqual(res.events, [
            .next(450, 9),
            .next(450, 11),
            .next(450, 20),
            .next(450, 22),
            .next(460, 23),
            .next(470, 24),
            .next(480, 25),
            .error(490, testError),
            ])

        XCTAssertEqual(xs.subscriptions, [
            Subscription(400, 490),
            Subscription(650, 700)
            ])
    }

    func testReplayCount_Complete() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createColdObservable([
            .next(10, 5),
            .next(20, 9),
            .next(30, 11),
            .next(40, 20),
            .next(50, 22),
            .next(60, 23),
            .next(70, 24),
            .next(80, 25),
            .completed(90)
            ])

        var ys: ConnectableObservable<Int>! = nil
        var subscription: Disposable! = nil
        var connection: Disposable! = nil
        let res = scheduler.createObserver(Int.self)

        await scheduler.scheduleAt(Defaults.created) { ys = await xs.replay(3) }
        await scheduler.scheduleAt(450, action: { subscription = await ys.subscribe(res) })
        await scheduler.scheduleAt(Defaults.disposed) { await subscription.dispose() }

        await scheduler.scheduleAt(400) { connection = await ys.connect() }
        await scheduler.scheduleAt(520) { await connection.dispose() }

        await scheduler.scheduleAt(650) { connection = await ys.connect() }
        await scheduler.scheduleAt(700) { await connection.dispose() }

        await scheduler.start()

        XCTAssertEqual(res.events, [
            .next(450, 9),
            .next(450, 11),
            .next(450, 20),
            .next(450, 22),
            .next(460, 23),
            .next(470, 24),
            .next(480, 25),
            .completed(490),
            ])

        XCTAssertEqual(xs.subscriptions, [
            Subscription(400, 490),
            Subscription(650, 700)
            ])
    }

    func testReplayCount_Dispose() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createColdObservable([
            .next(10, 5),
            .next(20, 9),
            .next(30, 11),
            .next(40, 20),
            .next(50, 22),
            .next(60, 23),
            .next(70, 24),
            .next(80, 25),
            .completed(130)
            ])

        var ys: ConnectableObservable<Int>! = nil
        var subscription: Disposable! = nil
        var connection: Disposable! = nil
        let res = scheduler.createObserver(Int.self)

        await scheduler.scheduleAt(Defaults.created) { ys = await xs.replay(3) }
        await scheduler.scheduleAt(450, action: { subscription = await ys.subscribe(res) })
        await scheduler.scheduleAt(475) { await subscription.dispose() }

        await scheduler.scheduleAt(400) { connection = await ys.connect() }
        await scheduler.scheduleAt(520) { await connection.dispose() }

        await scheduler.scheduleAt(650) { connection = await ys.connect() }
        await scheduler.scheduleAt(700) { await connection.dispose() }

        await scheduler.start()

        XCTAssertEqual(res.events, [
            .next(450, 9),
            .next(450, 11),
            .next(450, 20),
            .next(450, 22),
            .next(460, 23),
            .next(470, 24),
            ])

        XCTAssertEqual(xs.subscriptions, [
            Subscription(400, 520),
            Subscription(650, 700)
            ])
    }

    func testReplayOneCount_Basic() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createColdObservable([
            .next(10, 5),
            .next(20, 9),
            .next(30, 11),
            .next(40, 20),
            .next(50, 22),
            .next(60, 23),
            .next(70, 24),
            .next(80, 25),
            .completed(130)
            ])

        var ys: ConnectableObservable<Int>! = nil
        var subscription: Disposable! = nil
        var connection: Disposable! = nil
        let res = scheduler.createObserver(Int.self)

        await scheduler.scheduleAt(Defaults.created) { ys = await xs.replay(1) }
        await scheduler.scheduleAt(450, action: { subscription = await ys.subscribe(res) })
        await scheduler.scheduleAt(Defaults.disposed) { await subscription.dispose() }

        await scheduler.scheduleAt(400) { connection = await ys.connect() }
        await scheduler.scheduleAt(520) { await connection.dispose() }

        await scheduler.scheduleAt(650) { connection = await ys.connect() }
        await scheduler.scheduleAt(700) { await connection.dispose() }

        await scheduler.start()

        XCTAssertEqual(res.events, [
            .next(450, 20),
            .next(450, 22),
            .next(460, 23),
            .next(470, 24),
            .next(480, 25),
            ])

        XCTAssertEqual(xs.subscriptions, [
            Subscription(400, 520),
            Subscription(650, 700)
            ])
    }

    func testReplayOneCount_Error() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createColdObservable([
            .next(10, 5),
            .next(20, 9),
            .next(30, 11),
            .next(40, 20),
            .next(50, 22),
            .next(60, 23),
            .next(70, 24),
            .next(80, 25),
            .error(90, testError)
            ])

        var ys: ConnectableObservable<Int>! = nil
        var subscription: Disposable! = nil
        var connection: Disposable! = nil
        let res = scheduler.createObserver(Int.self)

        await scheduler.scheduleAt(Defaults.created) { ys = await xs.replay(1) }
        await scheduler.scheduleAt(450, action: { subscription = await ys.subscribe(res) })
        await scheduler.scheduleAt(Defaults.disposed) { await subscription.dispose() }

        await scheduler.scheduleAt(400) { connection = await ys.connect() }
        await scheduler.scheduleAt(520) { await connection.dispose() }

        await scheduler.scheduleAt(650) { connection = await ys.connect() }
        await scheduler.scheduleAt(700) { await connection.dispose() }

        await scheduler.start()

        XCTAssertEqual(res.events, [
            .next(450, 20),
            .next(450, 22),
            .next(460, 23),
            .next(470, 24),
            .next(480, 25),
            .error(490, testError)
            ])

        XCTAssertEqual(xs.subscriptions, [
            Subscription(400, 490),
            Subscription(650, 700)
            ])
    }

    func testReplayOneCount_Complete() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createColdObservable([
            .next(10, 5),
            .next(20, 9),
            .next(30, 11),
            .next(40, 20),
            .next(50, 22),
            .next(60, 23),
            .next(70, 24),
            .next(80, 25),
            .completed(90)
            ])

        var ys: ConnectableObservable<Int>! = nil
        var subscription: Disposable! = nil
        var connection: Disposable! = nil
        let res = scheduler.createObserver(Int.self)

        await scheduler.scheduleAt(Defaults.created) { ys = await xs.replay(1) }
        await scheduler.scheduleAt(450, action: { subscription = await ys.subscribe(res) })
        await scheduler.scheduleAt(Defaults.disposed) { await subscription.dispose() }

        await scheduler.scheduleAt(400) { connection = await ys.connect() }
        await scheduler.scheduleAt(520) { await connection.dispose() }

        await scheduler.scheduleAt(650) { connection = await ys.connect() }
        await scheduler.scheduleAt(700) { await connection.dispose() }

        await scheduler.start()

        XCTAssertEqual(res.events, [
            .next(450, 20),
            .next(450, 22),
            .next(460, 23),
            .next(470, 24),
            .next(480, 25),
            .completed(490)
            ])

        XCTAssertEqual(xs.subscriptions, [
            Subscription(400, 490),
            Subscription(650, 700)
            ])
    }

    func testReplayOneCount_Dispose() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createColdObservable([
            .next(10, 5),
            .next(20, 9),
            .next(30, 11),
            .next(40, 20),
            .next(50, 22),
            .next(60, 23),
            .next(70, 24),
            .next(80, 25),
            .completed(90)
            ])

        var ys: ConnectableObservable<Int>! = nil
        var subscription: Disposable! = nil
        var connection: Disposable! = nil
        let res = scheduler.createObserver(Int.self)

        await scheduler.scheduleAt(Defaults.created) { ys = await xs.replay(1) }
        await scheduler.scheduleAt(450, action: { subscription = await ys.subscribe(res) })
        await scheduler.scheduleAt(475) { await subscription.dispose() }

        await scheduler.scheduleAt(400) { connection = await ys.connect() }
        await scheduler.scheduleAt(520) { await connection.dispose() }

        await scheduler.scheduleAt(650) { connection = await ys.connect() }
        await scheduler.scheduleAt(700) { await connection.dispose() }

        await scheduler.start()

        XCTAssertEqual(res.events, [
            .next(450, 20),
            .next(450, 22),
            .next(460, 23),
            .next(470, 24),
            ])

        XCTAssertEqual(xs.subscriptions, [
            Subscription(400, 490),
            Subscription(650, 700)
            ])
    }

    func testReplayAll_Basic() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createColdObservable([
            .next(10, 5),
            .next(20, 9),
            .next(30, 11),
            .next(40, 20),
            .next(50, 22),
            .next(60, 23),
            .next(70, 24),
            .next(80, 25),
            .completed(130)
            ])

        var ys: ConnectableObservable<Int>! = nil
        var subscription: Disposable! = nil
        var connection: Disposable! = nil
        let res = scheduler.createObserver(Int.self)

        await scheduler.scheduleAt(Defaults.created) { ys = await xs.replayAll() }
        await scheduler.scheduleAt(450, action: { subscription = await ys.subscribe(res) })
        await scheduler.scheduleAt(Defaults.disposed) { await subscription.dispose() }

        await scheduler.scheduleAt(400) { connection = await ys.connect() }
        await scheduler.scheduleAt(520) { await connection.dispose() }

        await scheduler.scheduleAt(650) { connection = await ys.connect() }
        await scheduler.scheduleAt(700) { await connection.dispose() }

        await scheduler.start()

        XCTAssertEqual(res.events, [
            .next(450, 5),
            .next(450, 9),
            .next(450, 11),
            .next(450, 20),
            .next(450, 22),
            .next(460, 23),
            .next(470, 24),
            .next(480, 25),
            ])

        XCTAssertEqual(xs.subscriptions, [
            Subscription(400, 520),
            Subscription(650, 700)
            ])
    }


    func testReplayAll_Error() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createColdObservable([
            .next(10, 5),
            .next(20, 9),
            .next(30, 11),
            .next(40, 20),
            .next(50, 22),
            .next(60, 23),
            .next(70, 24),
            .next(80, 25),
            .error(90, testError)
            ])

        var ys: ConnectableObservable<Int>! = nil
        var subscription: Disposable! = nil
        var connection: Disposable! = nil
        let res = scheduler.createObserver(Int.self)

        await scheduler.scheduleAt(Defaults.created) { ys = await xs.replayAll() }
        await scheduler.scheduleAt(450, action: { subscription = await ys.subscribe(res) })
        await scheduler.scheduleAt(Defaults.disposed) { await subscription.dispose() }

        await scheduler.scheduleAt(400) { connection = await ys.connect() }
        await scheduler.scheduleAt(520) { await connection.dispose() }

        await scheduler.scheduleAt(650) { connection = await ys.connect() }
        await scheduler.scheduleAt(700) { await connection.dispose() }

        await scheduler.start()

        XCTAssertEqual(res.events, [
            .next(450, 5),
            .next(450, 9),
            .next(450, 11),
            .next(450, 20),
            .next(450, 22),
            .next(460, 23),
            .next(470, 24),
            .next(480, 25),
            .error(490, testError)
            ])

        XCTAssertEqual(xs.subscriptions, [
            Subscription(400, 490),
            Subscription(650, 700)
            ])
    }

    func testReplayAll_Complete() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createColdObservable([
            .next(10, 5),
            .next(20, 9),
            .next(30, 11),
            .next(40, 20),
            .next(50, 22),
            .next(60, 23),
            .next(70, 24),
            .next(80, 25),
            .completed(90)
            ])

        var ys: ConnectableObservable<Int>! = nil
        var subscription: Disposable! = nil
        var connection: Disposable! = nil
        let res = scheduler.createObserver(Int.self)

        await scheduler.scheduleAt(Defaults.created) { ys = await xs.replayAll() }
        await scheduler.scheduleAt(450, action: { subscription = await ys.subscribe(res) })
        await scheduler.scheduleAt(Defaults.disposed) { await subscription.dispose() }

        await scheduler.scheduleAt(400) { connection = await ys.connect() }
        await scheduler.scheduleAt(520) { await connection.dispose() }

        await scheduler.scheduleAt(650) { connection = await ys.connect() }
        await scheduler.scheduleAt(700) { await connection.dispose() }

        await scheduler.start()

        XCTAssertEqual(res.events, [
            .next(450, 5),
            .next(450, 9),
            .next(450, 11),
            .next(450, 20),
            .next(450, 22),
            .next(460, 23),
            .next(470, 24),
            .next(480, 25),
            .completed(490)
            ])

        XCTAssertEqual(xs.subscriptions, [
            Subscription(400, 490),
            Subscription(650, 700)
            ])
    }

    func testReplayAll_Dispose() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createColdObservable([
            .next(10, 5),
            .next(20, 9),
            .next(30, 11),
            .next(40, 20),
            .next(50, 22),
            .next(60, 23),
            .next(70, 24),
            .next(80, 25),
            .completed(130)
            ])

        var ys: ConnectableObservable<Int>! = nil
        var subscription: Disposable! = nil
        var connection: Disposable! = nil
        let res = scheduler.createObserver(Int.self)

        await scheduler.scheduleAt(Defaults.created) { ys = await xs.replayAll() }
        await scheduler.scheduleAt(450, action: { subscription = await ys.subscribe(res) })
        await scheduler.scheduleAt(475) { await subscription.dispose() }

        await scheduler.scheduleAt(400) { connection = await ys.connect() }
        await scheduler.scheduleAt(520) { await connection.dispose() }

        await scheduler.scheduleAt(650) { connection = await ys.connect() }
        await scheduler.scheduleAt(700) { await connection.dispose() }

        await scheduler.start()

        XCTAssertEqual(res.events, [
            .next(450, 5),
            .next(450, 9),
            .next(450, 11),
            .next(450, 20),
            .next(450, 22),
            .next(460, 23),
            .next(470, 24),
            ])

        XCTAssertEqual(xs.subscriptions, [
            Subscription(400, 520),
            Subscription(650, 700)
            ])
    }

    #if TRACE_RESOURCES
    func testReplayNReleasesResourcesOnComplete() async {
        let replay = await Observable<Int>.just(1).replay(1)
        _ = await replay.connect()
        _ = await replay.subscribe()
        }

    func testReplayNReleasesResourcesOnError() async {
        let replay = await Observable<Int>.error(testError).replay(1)
        _ = await replay.connect()
        _ = await replay.subscribe()
        }

    func testReplayAllReleasesResourcesOnComplete() async {
        let replay = await Observable<Int>.just(1).replayAll()
        _ = await replay.connect()
        _ = await replay.subscribe()
        }
        
    func testReplayAllReleasesResourcesOnError() async {
        let replay = await Observable<Int>.error(testError).replayAll()
        _ = await replay.connect()
        _ = await replay.subscribe()
        }
    #endif
}
