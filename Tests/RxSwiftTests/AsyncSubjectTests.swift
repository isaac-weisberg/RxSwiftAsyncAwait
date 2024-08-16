//
//  AsyncSubjectTests.swift
//  Tests
//
//  Created by Victor Galán on 07/01/2017.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

import RxSwift
import RxTest
import XCTest

class AsyncSubjectTests: RxTest {
    func test_hasObserversManyObserver() async {
        let scheduler = await TestScheduler(initialClock: 0)

        var subject: AsyncSubject<Int>! = nil

        let results1 = scheduler.createObserver(Int.self)
        var subscription1: Disposable! = nil

        let results2 = scheduler.createObserver(Int.self)
        var subscription2: Disposable! = nil

        let results3 = scheduler.createObserver(Int.self)
        var subscription3: Disposable! = nil

        await scheduler.scheduleAt(100) { subject = await AsyncSubject() }
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

    func test_infinite() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(70, 1),
            .next(110, 2),
            .next(220, 3),
            .next(270, 4),
            .next(340, 5),
            .next(410, 6),
            .next(520, 7),
            .next(630, 8),
            .next(710, 9),
            .next(870, 10),
            .next(940, 11),
            .next(1020, 12)
        ])

        var subject: AsyncSubject<Int>! = nil
        var subscription: Disposable! = nil

        let results1 = scheduler.createObserver(Int.self)
        var subscription1: Disposable! = nil

        let results2 = scheduler.createObserver(Int.self)
        var subscription2: Disposable! = nil

        let results3 = scheduler.createObserver(Int.self)
        var subscription3: Disposable! = nil

        await scheduler.scheduleAt(100) { subject = await AsyncSubject<Int>() }
        await scheduler.scheduleAt(200) { subscription = await xs.subscribe(subject) }
        await scheduler.scheduleAt(1000) { await subscription.dispose() }

        await scheduler.scheduleAt(300) { subscription1 = await subject.subscribe(results1) }
        await scheduler.scheduleAt(400) { subscription2 = await subject.subscribe(results2) }
        await scheduler.scheduleAt(900) { subscription3 = await subject.subscribe(results3) }

        await scheduler.scheduleAt(600) { await subscription1.dispose() }
        await scheduler.scheduleAt(700) { await subscription2.dispose() }
        await scheduler.scheduleAt(800) { await subscription1.dispose() }
        await scheduler.scheduleAt(950) { await subscription3.dispose() }

        await scheduler.start()

        XCTAssertEqual(results1.events, [])

        XCTAssertEqual(results2.events, [])

        XCTAssertEqual(results3.events, [])
    }

    func test_finite() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(70, 1),
            .next(110, 2),
            .next(220, 3),
            .next(270, 4),
            .next(340, 5),
            .next(410, 6),
            .next(520, 7),
            .completed(630),
            .next(640, 9),
            .completed(650),
            .error(660, testError)
        ])

        var subject: AsyncSubject<Int>! = nil
        var subscription: Disposable! = nil

        let results1 = scheduler.createObserver(Int.self)
        var subscription1: Disposable! = nil

        let results2 = scheduler.createObserver(Int.self)
        var subscription2: Disposable! = nil

        let results3 = scheduler.createObserver(Int.self)
        var subscription3: Disposable! = nil

        await scheduler.scheduleAt(100) { subject = await AsyncSubject<Int>() }
        await scheduler.scheduleAt(200) { subscription = await xs.subscribe(subject) }
        await scheduler.scheduleAt(1000) { await subscription.dispose() }

        await scheduler.scheduleAt(300) { subscription1 = await subject.subscribe(results1) }
        await scheduler.scheduleAt(400) { subscription2 = await subject.subscribe(results2) }
        await scheduler.scheduleAt(900) { subscription3 = await subject.subscribe(results3) }

        await scheduler.scheduleAt(600) { await subscription1.dispose() }
        await scheduler.scheduleAt(700) { await subscription2.dispose() }
        await scheduler.scheduleAt(800) { await subscription1.dispose() }
        await scheduler.scheduleAt(950) { await subscription3.dispose() }

        await scheduler.start()

        XCTAssertEqual(results1.events, [])

        XCTAssertEqual(results2.events, [
            .next(630, 7),
            .completed(630)
        ])

        XCTAssertEqual(results3.events, [
            .next(900, 7),
            .completed(900)
        ])
    }

    func test_error() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .next(70, 1),
            .next(110, 2),
            .next(220, 3),
            .next(270, 4),
            .next(340, 5),
            .next(410, 6),
            .next(520, 7),
            .error(630, testError),
            .next(640, 9),
            .completed(650),
            .error(660, testError)
        ])

        var subject: AsyncSubject<Int>! = nil
        var subscription: Disposable! = nil

        let results1 = scheduler.createObserver(Int.self)
        var subscription1: Disposable! = nil

        let results2 = scheduler.createObserver(Int.self)
        var subscription2: Disposable! = nil

        let results3 = scheduler.createObserver(Int.self)
        var subscription3: Disposable! = nil

        await scheduler.scheduleAt(100) { subject = await AsyncSubject<Int>() }
        await scheduler.scheduleAt(200) { subscription = await xs.subscribe(subject) }
        await scheduler.scheduleAt(1000) { await subscription.dispose() }

        await scheduler.scheduleAt(300) { subscription1 = await subject.subscribe(results1) }
        await scheduler.scheduleAt(400) { subscription2 = await subject.subscribe(results2) }
        await scheduler.scheduleAt(900) { subscription3 = await subject.subscribe(results3) }

        await scheduler.scheduleAt(600) { await subscription1.dispose() }
        await scheduler.scheduleAt(700) { await subscription2.dispose() }
        await scheduler.scheduleAt(800) { await subscription1.dispose() }
        await scheduler.scheduleAt(950) { await subscription3.dispose() }

        await scheduler.start()

        XCTAssertEqual(results1.events, [
        ])

        XCTAssertEqual(results2.events, [
            .error(630, testError)
        ])

        XCTAssertEqual(results3.events, [
            .error(900, testError)
        ])
    }

    func test_empty() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let xs = await scheduler.createHotObservable([
            .completed(630),
            .next(640, 9),
            .completed(650),
            .error(660, testError)
        ])

        var subject: AsyncSubject<Int>! = nil
        var subscription: Disposable! = nil

        let results1 = scheduler.createObserver(Int.self)
        var subscription1: Disposable! = nil

        let results2 = scheduler.createObserver(Int.self)
        var subscription2: Disposable! = nil

        let results3 = scheduler.createObserver(Int.self)
        var subscription3: Disposable! = nil

        await scheduler.scheduleAt(100) { subject = await AsyncSubject<Int>() }
        await scheduler.scheduleAt(200) { subscription = await xs.subscribe(subject) }
        await scheduler.scheduleAt(1000) { await subscription.dispose() }

        await scheduler.scheduleAt(300) { subscription1 = await subject.subscribe(results1) }
        await scheduler.scheduleAt(400) { subscription2 = await subject.subscribe(results2) }
        await scheduler.scheduleAt(900) { subscription3 = await subject.subscribe(results3) }

        await scheduler.scheduleAt(600) { await subscription1.dispose() }
        await scheduler.scheduleAt(700) { await subscription2.dispose() }
        await scheduler.scheduleAt(800) { await subscription1.dispose() }
        await scheduler.scheduleAt(950) { await subscription3.dispose() }

        await scheduler.start()

        XCTAssertEqual(results1.events, [])

        XCTAssertEqual(results2.events, [
            .completed(630)
        ])

        XCTAssertEqual(results3.events, [
            .completed(900)
        ])
    }
}

//func XCTAssertFalse(_ expression: @escaping @autoclosure () -> Bool, message: @escaping @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
//    XCTest.XCTAssertFalse(expression(), message(), file: file, line: line)
//}

func assertFalse(_ expression: @escaping @autoclosure () async -> Bool, message: @escaping @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) async {
    let value = await expression()
    XCTAssertFalse(value, message(), file: file, line: line)
}

func assertTrue(_ expression: @escaping @autoclosure () async -> Bool, message: @escaping @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) async {
    let value = await expression()
    XCTAssertTrue(value, message(), file: file, line: line)
}

func assert(_ expression: @escaping @autoclosure () async -> Bool, message: @escaping @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) async {
    let value = await expression()
    XCTAssert(value, message(), file: file, line: line)
}
