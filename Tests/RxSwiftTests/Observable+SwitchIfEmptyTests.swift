//
//  Observable+SwitchIfEmptyTests.swift
//  Tests
//
//  Created by Krunoslav Zaher on 4/29/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

import XCTest
import RxSwift
import RxTest

class ObservableSwitchIfEmptyTest : RxTest {
}

extension ObservableSwitchIfEmptyTest {
    func testSwitchIfEmpty_SourceNotEmpty_SwitchCompletes() async {
        let scheduler = await TestScheduler(initialClock: 0)
        let source = await scheduler.createHotObservable([
            .next(205, 1),
            .completed(210, Int.self)
            ])
        let switchSource = await scheduler.createColdObservable([
            .next(10, 0),
            .next(20, 1), 
            .next(30, 2),
            .next(40, 3),
            .completed(50)
            ])

        let res = await scheduler.start {
            return await source.ifEmpty(switchTo: switchSource.asObservable())
        }

        XCTAssertEqual(res.events, [
            .next(205, 1),
            .completed(210)
            ])
        XCTAssertEqual(source.subscriptions, [
            Subscription(200, 210)
            ])
        XCTAssertEqual(switchSource.subscriptions, [
            ])
    }

    func testSwitchIfEmpty_SourceNotEmptyError_SwitchCompletes() async {
        let scheduler = await TestScheduler(initialClock: 0)
        let source = await scheduler.createHotObservable([
            .next(205, 1),
            .error(210, testError)
            ])
        let switchSource = await scheduler.createColdObservable([
            .next(10, 0),
            .next(20, 1),
            .next(30, 2),
            .next(40, 3),
            .completed(50)
            ])

        let res = await scheduler.start {
            return await source.ifEmpty(switchTo: switchSource.asObservable())
        }

        XCTAssertEqual(res.events, [
            .next(205, 1),
            .error(210, testError)
            ])
        XCTAssertEqual(source.subscriptions, [
            Subscription(200, 210)
            ])
        XCTAssertEqual(switchSource.subscriptions, [
            ])
    }

    func testSwitchIfEmpty_SourceEmptyError_SwitchCompletes() async {
        let scheduler = await TestScheduler(initialClock: 0)
        let source = await scheduler.createHotObservable([
            .error(210, testError, Int.self)
            ])
        let switchSource = await scheduler.createColdObservable([
            .next(10, 0),
            .next(20, 1),
            .next(30, 2),
            .next(40, 3),
            .completed(50)
            ])

        let res = await scheduler.start {
            return await source.ifEmpty(switchTo: switchSource.asObservable())
        }

        XCTAssertEqual(res.events, [
            .error(210, testError)
            ])
        XCTAssertEqual(source.subscriptions, [
            Subscription(200, 210)
            ])
        XCTAssertEqual(switchSource.subscriptions, [
            ])
    }

    func testSwitchIfEmpty_SourceEmpty_SwitchCompletes() async {
        let scheduler = await TestScheduler(initialClock: 0)
        let source = await scheduler.createHotObservable([
                .completed(210, Int.self)
            ])
        let switchSource = await scheduler.createColdObservable([
                .next(10, 0),
                .next(20, 1),
                .next(30, 2),
                .next(40, 3),
                .completed(50)
            ])
        
        let res = await scheduler.start {
            return await source.ifEmpty(switchTo: switchSource.asObservable())
        }
        
        XCTAssertEqual(res.events, [
                .next(220, 0),
                .next(230, 1),
                .next(240, 2),
                .next(250, 3),
                .completed(260)
            ])
        XCTAssertEqual(source.subscriptions, [
                Subscription(200, 210)
            ])
        XCTAssertEqual(switchSource.subscriptions, [
                Subscription(210, 260)
            ])
    }

    func testSwitchIfEmpty_SourceEmpty_SwitchError() async {
        let scheduler = await TestScheduler(initialClock: 0)
        let source = await scheduler.createHotObservable([
            .completed(210, Int.self)
            ])
        let switchSource = await scheduler.createColdObservable([
            .next(10, 0),
            .next(20, 1),
            .next(30, 2),
            .next(40, 3),
            .error(50, testError)
            ])

        let res = await scheduler.start {
            return await source.ifEmpty(switchTo: switchSource.asObservable())
        }

        XCTAssertEqual(res.events, [
            .next(220, 0),
            .next(230, 1),
            .next(240, 2),
            .next(250, 3),
            .error(260, testError)
            ])
        XCTAssertEqual(source.subscriptions, [
            Subscription(200, 210)
            ])
        XCTAssertEqual(switchSource.subscriptions, [
            Subscription(210, 260)
            ])
    }

    func testSwitchIfEmpty_Never() async {
        let scheduler = await TestScheduler(initialClock: 0)
        let source = await scheduler.createHotObservable([
                .next(0, 0)
            ])
        let switchSource = await scheduler.createColdObservable([
                .next(10, 0),
                .next(20, 1),
                .next(30, 2),
                .next(40, 3),
                .completed(50)
            ])
        
        let res = await scheduler.start {
            return await source.ifEmpty(switchTo: switchSource.asObservable())
        }
        
        XCTAssertEqual(res.events, [])
        XCTAssertEqual(source.subscriptions, [
                Subscription(200, 1000)
            ])
        XCTAssertEqual(switchSource.subscriptions, [])
    }

    #if TRACE_RESOURCES
    func testSwitchIfEmptyReleasesResourcesOnComplete1() async {
        let testScheduler = await TestScheduler(initialClock: 0)
        _ = await Observable<Int>.just(1).ifEmpty(switchTo: Observable.just(1)).subscribe()

        await testScheduler.start()
        }
    func testSwitchIfEmptyReleasesResourcesOnComplete2() async {
        let testScheduler = await TestScheduler(initialClock: 0)
        _ = await Observable<Int>.empty().ifEmpty(switchTo: Observable.just(1)).subscribe()

        await testScheduler.start()
        }
    func testSwitchIfEmptyReleasesResourcesOnError1() async {
        let testScheduler = await TestScheduler(initialClock: 0)
        _ = await Observable<Int>.error(testError).ifEmpty(switchTo: Observable.just(1)).subscribe()

        await testScheduler.start()
        }

    func testSwitchIfEmptyReleasesResourcesOnError2() async {
        let testScheduler = await TestScheduler(initialClock: 0)
        _ = await Observable<Int>.empty().ifEmpty(switchTo: Observable<Int>.error(testError)).subscribe()

        await testScheduler.start()
        }
    #endif
}
