//
//  PublishSubjectTest.swift
//  Tests
//
//  Created by Ryszkiewicz Peter, US-204 on 5/18/16.
//  Copyright © 2016 Krunoslav Zaher. All rights reserved.
//

import RxSwift
import RxTest
import XCTest

class PublishSubjectTest: RxTest {
    func test_hasObserversNoObservers() async {
        let scheduler = await TestScheduler(initialClock: 0)

        var subject: PublishSubject<Int>! = nil

        await scheduler.scheduleAt(100) { subject = await PublishSubject<Int>() }
        await scheduler.scheduleAt(250) {
            let hasObservers = await subject.hasObservers()
            XCTAssertFalse(hasObservers)
        }

        await scheduler.start()
    }

    func test_hasObserversOneObserver() async {
        let scheduler = await TestScheduler(initialClock: 0)

        var subject: PublishSubject<Int>! = nil

        let results1 = scheduler.createObserver(Int.self)
        var subscription1: Disposable! = nil

        await scheduler.scheduleAt(100) { subject = await PublishSubject<Int>() }
        await scheduler.scheduleAt(250) {
            let hasObservers = await subject.hasObservers()
            XCTAssertFalse(hasObservers)
        }
        await scheduler.scheduleAt(300) { subscription1 = await subject.subscribe(results1) }
        await scheduler.scheduleAt(350) {
            let hasObservers = await subject.hasObservers()
            XCTAssertFalse(hasObservers)
        }
        await scheduler.scheduleAt(400) { await subscription1.dispose() }
        await scheduler.scheduleAt(450) {
            let hasObservers = await subject.hasObservers()
            XCTAssertFalse(hasObservers)
        }

        await scheduler.start()
    }

    func test_hasObserversManyObserver() async {
        let scheduler = await TestScheduler(initialClock: 0)

        var subject: PublishSubject<Int>! = nil

        let results1 = scheduler.createObserver(Int.self)
        var subscription1: Disposable! = nil

        let results2 = scheduler.createObserver(Int.self)
        var subscription2: Disposable! = nil

        let results3 = scheduler.createObserver(Int.self)
        var subscription3: Disposable! = nil

        await scheduler.scheduleAt(100) { subject = await PublishSubject<Int>() }
        await scheduler.scheduleAt(250) {
            let hasObservers = await subject.hasObservers()
            XCTAssertFalse(hasObservers)
        }
        await scheduler.scheduleAt(300) { subscription1 = await subject.subscribe(results1) }
        await scheduler.scheduleAt(301) { subscription2 = await subject.subscribe(results2) }
        await scheduler.scheduleAt(302) { subscription3 = await subject.subscribe(results3) }
        await scheduler.scheduleAt(350) {
            let hasObservers = await subject.hasObservers()
            XCTAssertTrue(hasObservers)
        }
        await scheduler.scheduleAt(400) { await subscription1.dispose() }
        await scheduler.scheduleAt(405) {
            let hasObservers = await subject.hasObservers()
            XCTAssertTrue(hasObservers)
        }
        await scheduler.scheduleAt(410) { await subscription2.dispose() }
        await scheduler.scheduleAt(415) {
            let hasObservers = await subject.hasObservers()
            XCTAssertTrue(hasObservers)
        }
        await scheduler.scheduleAt(420) { await subscription3.dispose() }
        await scheduler.scheduleAt(450) { 
            let hasObservers = await subject.hasObservers()
            XCTAssertFalse(hasObservers)
        }

        await scheduler.start()
    }
}
