//
//  ReplayRelayTests.swift
//  Tests
//
//  Created by Zsolt Kovacs on 12/31/19.
//  Copyright © 2019 Krunoslav Zaher. All rights reserved.
//

import XCTest
import RxSwift
import RxRelay
import RxTest

class ReplayRelayTests: RxTest {
    func test_noEvents() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let relay = await ReplayRelay<Int>.create(bufferSize: 3)
        let result = scheduler.createObserver(Int.self)

        _ = await relay.subscribe(result)

        XCTAssertTrue(result.events.isEmpty)
    }

    func test_fewerEventsThanBufferSize() async {
        let scheduler = await TestScheduler(initialClock: 0)

        var relay: ReplayRelay<Int>! = nil
        let result = scheduler.createObserver(Int.self)
        var subscription: Disposable! = nil

        await scheduler.scheduleAt(100) { relay = await ReplayRelay.create(bufferSize: 3) }
        await scheduler.scheduleAt(150) { await relay.accept(1) }
        await scheduler.scheduleAt(200) { await relay.accept(2) }
        await scheduler.scheduleAt(300) { subscription = await relay.subscribe(result) }
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

        var relay: ReplayRelay<Int>! = nil
        let result = scheduler.createObserver(Int.self)
        var subscription: Disposable! = nil

        await scheduler.scheduleAt(100) { relay = await ReplayRelay.create(bufferSize: 3) }
        await scheduler.scheduleAt(150) { await relay.accept(1) }
        await scheduler.scheduleAt(200) { await relay.accept(2) }
        await scheduler.scheduleAt(250) { await relay.accept(3) }
        await scheduler.scheduleAt(300) { await relay.accept(4) }
        await scheduler.scheduleAt(350) { await relay.accept(5) }
        await scheduler.scheduleAt(400) { subscription = await relay.subscribe(result) }
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

        var relay: ReplayRelay<Int>! = nil
        let result1 = scheduler.createObserver(Int.self)
        var subscription1: Disposable! = nil

        let result2 = scheduler.createObserver(Int.self)
        var subscription2: Disposable! = nil

        await scheduler.scheduleAt(100) { relay = await ReplayRelay.create(bufferSize: 3) }
        await scheduler.scheduleAt(150) { subscription1 = await relay.subscribe(result1) }
        await scheduler.scheduleAt(200) { await relay.accept(1) }
        await scheduler.scheduleAt(250) { await relay.accept(2) }
        await scheduler.scheduleAt(300) { await relay.accept(3) }
        await scheduler.scheduleAt(350) { await relay.accept(4) }
        await scheduler.scheduleAt(400) { await relay.accept(5) }
        await scheduler.scheduleAt(450) { subscription2 = await relay.subscribe(result2) }
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
}
