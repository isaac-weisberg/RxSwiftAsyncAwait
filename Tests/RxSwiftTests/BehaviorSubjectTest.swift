//
//  BehaviorSubjectTest.swift
//  Tests
//
//  Created by Krunoslav Zaher on 5/23/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

import XCTest
import RxSwift
import RxTest

class BehaviorSubjectTest : RxTest {
    
    func test_Infinite() async {
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
        
        var subject: BehaviorSubject<Int>! = nil
        var subscription: Disposable! = nil
        
        let results1 = scheduler.createObserver(Int.self)
        var subscription1: Disposable! = nil
        
        let results2 = scheduler.createObserver(Int.self)
        var subscription2: Disposable! = nil
        
        let results3 = scheduler.createObserver(Int.self)
        var subscription3: Disposable! = nil
        
        await scheduler.scheduleAt(100) { subject = await BehaviorSubject<Int>(value: 100) }
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
            .next(300, 4),
            .next(340, 5),
            .next(410, 6),
            .next(520, 7)
        ])
        
        XCTAssertEqual(results2.events, [
            .next(400, 5),
            .next(410, 6),
            .next(520, 7),
            .next(630, 8)
        ])
        
        XCTAssertEqual(results3.events, [
            .next(900, 10),
            .next(940, 11)
        ])
    }
    
    func test_Finite() async {
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
        
        var subject: BehaviorSubject<Int>! = nil
        var subscription: Disposable! = nil
        
        let results1 = scheduler.createObserver(Int.self)
        var subscription1: Disposable! = nil
        
        let results2 = scheduler.createObserver(Int.self)
        var subscription2: Disposable! = nil
        
        let results3 = scheduler.createObserver(Int.self)
        var subscription3: Disposable! = nil
        
        await scheduler.scheduleAt(100) { subject = await BehaviorSubject<Int>(value: 100) }
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
            .next(300, 4),
            .next(340, 5),
            .next(410, 6),
            .next(520, 7)
            ])
        
        XCTAssertEqual(results2.events, [
            .next(400, 5),
            .next(410, 6),
            .next(520, 7),
            .completed(630)
            ])
        
        XCTAssertEqual(results3.events, [
            .completed(900)
            ])
    }
    
    func test_Error() async {
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
        
        var subject: BehaviorSubject<Int>! = nil
        var subscription: Disposable! = nil
        
        let results1 = scheduler.createObserver(Int.self)
        var subscription1: Disposable! = nil
        
        let results2 = scheduler.createObserver(Int.self)
        var subscription2: Disposable! = nil
        
        let results3 = scheduler.createObserver(Int.self)
        var subscription3: Disposable! = nil
        
        await scheduler.scheduleAt(100) { subject = await BehaviorSubject<Int>(value: 100) }
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
            .next(300, 4),
            .next(340, 5),
            .next(410, 6),
            .next(520, 7)
            ])
        
        XCTAssertEqual(results2.events, [
            .next(400, 5),
            .next(410, 6),
            .next(520, 7),
            .error(630, testError)
            ])
        
        XCTAssertEqual(results3.events, [
            .error(900, testError)
            ])
    }
    
    func test_Canceled() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let xs = await scheduler.createHotObservable([
            .completed(630),
            .next(640, 9),
            .completed(650),
            .error(660, testError)
            ])
        
        var subject: BehaviorSubject<Int>! = nil
        var subscription: Disposable! = nil
        
        let results1 = scheduler.createObserver(Int.self)
        var subscription1: Disposable! = nil
        
        let results2 = scheduler.createObserver(Int.self)
        var subscription2: Disposable! = nil
        
        let results3 = scheduler.createObserver(Int.self)
        var subscription3: Disposable! = nil
        
        await scheduler.scheduleAt(100) { subject = await BehaviorSubject<Int>(value: 100) }
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
            .next(300, 100),
        ])
        
        XCTAssertEqual(results2.events, [
            .next(400, 100),
            .completed(630)
        ])
        
        XCTAssertEqual(results3.events, [
            .completed(900)
        ])
    }

    func test_hasObserversNoObservers() async {
        let scheduler = await TestScheduler(initialClock: 0)

        var subject: BehaviorSubject<Int>! = nil

        await scheduler.scheduleAt(100) { subject = await BehaviorSubject<Int>(value: 100) }
        await scheduler.scheduleAt(250) { await assertFalse(await subject.hasObservers()) }

        await scheduler.start()
    }

    func test_hasObserversOneObserver() async {
        let scheduler = await TestScheduler(initialClock: 0)

        var subject: BehaviorSubject<Int>! = nil

        let results1 = scheduler.createObserver(Int.self)
        var subscription1: Disposable! = nil

        await scheduler.scheduleAt(100) { subject = await BehaviorSubject<Int>(value: 100) }
        await scheduler.scheduleAt(250) { await assertTrue(await subject.hasObservers()) }
        await scheduler.scheduleAt(300) { subscription1 = await subject.subscribe(results1) }
        await scheduler.scheduleAt(350) { await assertTrue(await subject.hasObservers()) }
        await scheduler.scheduleAt(400) { await subscription1.dispose() }
        await scheduler.scheduleAt(450) { await assertFalse(await subject.hasObservers()) }

        await scheduler.start()
    }

    func test_hasObserversManyObserver() async {
        let scheduler = await TestScheduler(initialClock: 0)

        var subject: BehaviorSubject<Int>! = nil

        let results1 = scheduler.createObserver(Int.self)
        var subscription1: Disposable! = nil

        let results2 = scheduler.createObserver(Int.self)
        var subscription2: Disposable! = nil

        let results3 = scheduler.createObserver(Int.self)
        var subscription3: Disposable! = nil

        await scheduler.scheduleAt(100) { subject = await BehaviorSubject<Int>(value: 100) }
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
}
