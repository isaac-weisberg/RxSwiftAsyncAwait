//
//  ReplaySubjectTest.swift
//  Tests
//
//  Created by Ryszkiewicz Peter, US-204 on 5/18/16.
//  Copyright © 2016 Krunoslav Zaher. All rights reserved.
//

import XCTest
import RxSwift
import RxTest

class ReplaySubjectTest: RxTest {

    func test_hasObserversNoObservers() async {
        let scheduler = await TestScheduler(initialClock: 0)

        var subject: ReplaySubject<Int>! = nil

        await scheduler.scheduleAt(100) { subject = await ReplaySubject.create(bufferSize: 1) }
        await scheduler.scheduleAt(250) { await assertFalse(await subject.hasObservers()) }

        await scheduler.start()
    }

    func test_hasObserversOneObserver() async {
        let scheduler = await TestScheduler(initialClock: 0)

        var subject: ReplaySubject<Int>! = nil

        let results1 = scheduler.createObserver(Int.self)
        var subscription1: Disposable! = nil

        await scheduler.scheduleAt(100) { subject = await ReplaySubject.create(bufferSize: 1) }
        await scheduler.scheduleAt(250) { await assertFalse(await subject.hasObservers()) }
        await scheduler.scheduleAt(300) { subscription1 = await subject.subscribe(results1) }
        await scheduler.scheduleAt(350) { await assertTrue(await subject.hasObservers()) }
        await scheduler.scheduleAt(400) { await subscription1.dispose() }
        await scheduler.scheduleAt(450) { await assertFalse(await subject.hasObservers()) }

        await scheduler.start()
    }

    func test_hasObserversManyObserver() async {
        let scheduler = await TestScheduler(initialClock: 0)

        var subject: ReplaySubject<Int>! = nil

        let results1 = scheduler.createObserver(Int.self)
        var subscription1: Disposable! = nil

        let results2 = scheduler.createObserver(Int.self)
        var subscription2: Disposable! = nil

        let results3 = scheduler.createObserver(Int.self)
        var subscription3: Disposable! = nil

        await scheduler.scheduleAt(100) { subject = await ReplaySubject.create(bufferSize: 1) }
        await scheduler.scheduleAt(250) { await assertFalse(await subject.hasObservers()) }
        await scheduler.scheduleAt(300) { subscription1 = await subject.subscribe(results1) }
        await scheduler.scheduleAt(301) { subscription2 = await subject.subscribe(results2) }
        await scheduler.scheduleAt(302) { subscription3 = await subject.subscribe(results3) }
        await scheduler.scheduleAt(350) { await assertTrue(await subject.hasObservers()) }
        await scheduler.scheduleAt(400) { await subscription1.dispose() }
        await scheduler.scheduleAt(405) { await assertTrue(await subject.hasObservers()) }
        await scheduler.scheduleAt(410) { await subscription2.dispose() }
        await scheduler.scheduleAt(415) { await assertTrue(await subject.hasObservers()) }
        await scheduler.scheduleAt(420) { await subscription3.dispose() }
        await scheduler.scheduleAt(450) { await assertFalse(await subject.hasObservers()) }
        
        await scheduler.start()
    }

    func test_noEvents() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let subject = await ReplaySubject<Int>.create(bufferSize: 3)
        let result = scheduler.createObserver(Int.self)

        _ = await subject.subscribe(result)

        await assertTrue(result.events.isEmpty)
    }

    func test_fewerEventsThanBufferSize() async {
        let scheduler = await TestScheduler(initialClock: 0)

        var subject: ReplaySubject<Int>! = nil
        let result = scheduler.createObserver(Int.self)
        var subscription: Disposable! = nil

        await scheduler.scheduleAt(100) { subject = await ReplaySubject.create(bufferSize: 3) }
        await scheduler.scheduleAt(150) { await subject.onNext(1) }
        await scheduler.scheduleAt(200) { await subject.onNext(2) }
        await scheduler.scheduleAt(300) { subscription = await subject.subscribe(result) }
        await scheduler.scheduleAt(350) {
            XCTAssertEqual(result.events, [
                .next(300, 1),
                .next(300, 2),
            ])
        }
        await scheduler.scheduleAt(400) { await subscription.dispose() }

        await scheduler.start()
    }

    func test_moreEventsThanBufferSize() async {
        let scheduler = await TestScheduler(initialClock: 0)

        var subject: ReplaySubject<Int>! = nil
        let result = scheduler.createObserver(Int.self)
        var subscription: Disposable! = nil

        await scheduler.scheduleAt(100) { subject = await ReplaySubject.create(bufferSize: 3) }
        await scheduler.scheduleAt(150) { await subject.onNext(1) }
        await scheduler.scheduleAt(200) { await subject.onNext(2) }
        await scheduler.scheduleAt(250) { await subject.onNext(3) }
        await scheduler.scheduleAt(300) { await subject.onNext(4) }
        await scheduler.scheduleAt(350) { await subject.onNext(5) }
        await scheduler.scheduleAt(400) { subscription = await subject.subscribe(result) }
        await scheduler.scheduleAt(450) {
            XCTAssertEqual(result.events, [
                .next(400, 3),
                .next(400, 4),
                .next(400, 5),
            ])
        }
        await scheduler.scheduleAt(500) { await subscription.dispose() }

        await scheduler.start()
    }

    func test_moreEventsThanBufferSizeMultipleObservers() async {
        let scheduler = await TestScheduler(initialClock: 0)

        var subject: ReplaySubject<Int>! = nil
        let result1 = scheduler.createObserver(Int.self)
        var subscription1: Disposable! = nil

        let result2 = scheduler.createObserver(Int.self)
        var subscription2: Disposable! = nil

        await scheduler.scheduleAt(100) { subject = await ReplaySubject.create(bufferSize: 3) }
        await scheduler.scheduleAt(150) { subscription1 = await subject.subscribe(result1) }
        await scheduler.scheduleAt(200) { await subject.onNext(1) }
        await scheduler.scheduleAt(250) { await subject.onNext(2) }
        await scheduler.scheduleAt(300) { await subject.onNext(3) }
        await scheduler.scheduleAt(350) { await subject.onNext(4) }
        await scheduler.scheduleAt(400) { await subject.onNext(5) }
        await scheduler.scheduleAt(450) { subscription2 = await subject.subscribe(result2) }
        await scheduler.scheduleAt(500) {
            XCTAssertEqual(result1.events, [
                .next(200, 1),
                .next(250, 2),
                .next(300, 3),
                .next(350, 4),
                .next(400, 5),
            ])
            XCTAssertEqual(result2.events, [
                .next(450, 3),
                .next(450, 4),
                .next(450, 5),
            ])
        }
        await scheduler.scheduleAt(550) {
            await subscription1.dispose()
            await subscription2.dispose()
        }

        await scheduler.start()
    }

    func test_subscribingBeforeComplete() async {
        let scheduler = await TestScheduler(initialClock: 0)

        var subject: ReplaySubject<Int>! = nil
        let result = scheduler.createObserver(Int.self)
        var subscription: Disposable! = nil

        await scheduler.scheduleAt(100) { subject = await ReplaySubject.create(bufferSize: 3) }
        await scheduler.scheduleAt(150) { await subject.onNext(1) }
        await scheduler.scheduleAt(200) { await subject.onNext(2) }
        await scheduler.scheduleAt(250) { await subject.onNext(3) }
        await scheduler.scheduleAt(300) { await subject.onNext(4) }
        await scheduler.scheduleAt(350) { await subject.onNext(5) }
        await scheduler.scheduleAt(400) { subscription = await subject.subscribe(result) }
        await scheduler.scheduleAt(450) { await subject.onCompleted() }
        await scheduler.scheduleAt(500) {
            XCTAssertEqual(result.events, [
                .next(400, 3),
                .next(400, 4),
                .next(400, 5),
                .completed(450),
            ])
        }
        await scheduler.scheduleAt(550) { await subscription.dispose() }

        await scheduler.start()
    }

    func test_subscribingAfterComplete() async {
        let scheduler = await TestScheduler(initialClock: 0)

        var subject: ReplaySubject<Int>! = nil
        let result = scheduler.createObserver(Int.self)
        var subscription: Disposable! = nil

        await scheduler.scheduleAt(100) { subject = await ReplaySubject.create(bufferSize: 3) }
        await scheduler.scheduleAt(150) { await subject.onNext(1) }
        await scheduler.scheduleAt(200) { await subject.onNext(2) }
        await scheduler.scheduleAt(250) { await subject.onNext(3) }
        await scheduler.scheduleAt(300) { await subject.onNext(4) }
        await scheduler.scheduleAt(350) { await subject.onNext(5) }
        await scheduler.scheduleAt(400) { await subject.onCompleted() }
        await scheduler.scheduleAt(450) { subscription = await subject.subscribe(result) }
        await scheduler.scheduleAt(500) {
            XCTAssertEqual(result.events, [
                .next(450, 3),
                .next(450, 4),
                .next(450, 5),
                .completed(450),
            ])
        }
        await scheduler.scheduleAt(550) { await subscription.dispose() }

        await scheduler.start()
    }

    func test_subscribingBeforeError() async {
        let scheduler = await TestScheduler(initialClock: 0)

        var subject: ReplaySubject<Int>! = nil
        let result = scheduler.createObserver(Int.self)
        var subscription: Disposable! = nil

        await scheduler.scheduleAt(100) { subject = await ReplaySubject.create(bufferSize: 3) }
        await scheduler.scheduleAt(150) { await subject.onNext(1) }
        await scheduler.scheduleAt(200) { await subject.onNext(2) }
        await scheduler.scheduleAt(250) { await subject.onNext(3) }
        await scheduler.scheduleAt(300) { await subject.onNext(4) }
        await scheduler.scheduleAt(350) { await subject.onNext(5) }
        await scheduler.scheduleAt(400) { subscription = await subject.subscribe(result) }
        await scheduler.scheduleAt(450) { await subject.onError(testError) }
        await scheduler.scheduleAt(500) {
            XCTAssertEqual(result.events, [
                .next(400, 3),
                .next(400, 4),
                .next(400, 5),
                .error(450, testError),
            ])
        }
        await scheduler.scheduleAt(550) { await subscription.dispose() }

        await scheduler.start()
    }

    func test_subscribingAfterError() async {
        let scheduler = await TestScheduler(initialClock: 0)

        var subject: ReplaySubject<Int>! = nil
        let result = scheduler.createObserver(Int.self)
        var subscription: Disposable! = nil

        await scheduler.scheduleAt(100) { subject = await ReplaySubject.create(bufferSize: 3) }
        await scheduler.scheduleAt(150) { await subject.onNext(1) }
        await scheduler.scheduleAt(200) { await subject.onNext(2) }
        await scheduler.scheduleAt(250) { await subject.onNext(3) }
        await scheduler.scheduleAt(300) { await subject.onNext(4) }
        await scheduler.scheduleAt(350) { await subject.onNext(5) }
        await scheduler.scheduleAt(400) { await subject.onError(testError) }
        await scheduler.scheduleAt(450) { subscription = await subject.subscribe(result) }
        await scheduler.scheduleAt(500) {
            XCTAssertEqual(result.events, [
                .next(450, 3),
                .next(450, 4),
                .next(450, 5),
                .error(450, testError),
            ])
        }
        await scheduler.scheduleAt(550) { await subscription.dispose() }

        await scheduler.start()
    }
}
