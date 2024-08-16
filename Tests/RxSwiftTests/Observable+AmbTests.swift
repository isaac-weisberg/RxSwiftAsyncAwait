//
//  Observable+AmbTests.swift
//  Tests
//
//  Created by Krunoslav Zaher on 4/29/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

import XCTest
import RxSwift
import RxTest

class ObservableAmbTest : RxTest {
}

extension ObservableAmbTest {
    
    func testAmb_Never2() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let x1 = await scheduler.createHotObservable([
            .next(150, 1)
            ])
        
        let x2 = await scheduler.createHotObservable([
            .next(150, 1)
            ])
        
        let res = await scheduler.start {
            await x1.amb(x2)
        }
        
        XCTAssertEqual(res.events, [
            ])
        
        XCTAssertEqual(x1.subscriptions, [
            Subscription(200, 1000)
            ])
        
        XCTAssertEqual(x2.subscriptions, [
            Subscription(200, 1000)
            ])
    }
    
    func testAmb_Never3() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let x1 = await scheduler.createHotObservable([
            .next(150, 1)
            ])
        
        let x2 = await scheduler.createHotObservable([
            .next(150, 1)
            ])
        
        let x3 = await scheduler.createHotObservable([
            .next(150, 1)
            ])
        
        let res = await scheduler.start {
            await Observable.amb([x1, x2, x3].map { await $0.asObservable() })
        }
        
        XCTAssertEqual(res.events, [
            ])
        
        XCTAssertEqual(x1.subscriptions, [
            Subscription(200, 1000)
            ])
        
        XCTAssertEqual(x2.subscriptions, [
            Subscription(200, 1000)
            ])
        
        XCTAssertEqual(x3.subscriptions, [
            Subscription(200, 1000)
            ])
    }
    
    func testAmb_Never_Empty() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let x1 = await scheduler.createHotObservable([
            .next(150, 1)
            ])
        
        let x2 = await scheduler.createHotObservable([
            .next(150, 1),
            .completed(225)
            ])
        
        let res = await scheduler.start {
            await x1.amb(x2)
        }
        
        XCTAssertEqual(res.events, [
            .completed(225)
            ])
        
        XCTAssertEqual(x1.subscriptions, [
            Subscription(200, 225)
            ])
        
        XCTAssertEqual(x2.subscriptions, [
            Subscription(200, 225)
            ])
    }
    
    func testAmb_RegularShouldDisposeLoser() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let x1 = await scheduler.createHotObservable([
            .next(150, 1),
            .next(210, 2),
            .completed(240)
            ])
        
        let x2 = await scheduler.createHotObservable([
            .next(150, 1),
            .next(220, 3),
            .completed(250)
            ])
        
        let res = await scheduler.start {
            await x1.amb(x2)
        }
        
        XCTAssertEqual(res.events, [
            .next(210, 2),
            .completed(240)
            ])
        
        XCTAssertEqual(x1.subscriptions, [
            Subscription(200, 240)
            ])
        
        XCTAssertEqual(x2.subscriptions, [
            Subscription(200, 210)
            ])
    }
    
    func testAmb_WinnerThrows() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let x1 = await scheduler.createHotObservable([
            .next(150, 1),
            .next(210, 2),
            .error(220, testError)
            ])
        
        let x2 = await scheduler.createHotObservable([
            .next(150, 1),
            .next(220, 3),
            .completed(250)
            ])
        
        let res = await scheduler.start {
            await x1.amb(x2)
        }
        
        XCTAssertEqual(res.events, [
            .next(210, 2),
            .error(220, testError)
            ])
        
        XCTAssertEqual(x1.subscriptions, [
            Subscription(200, 220)
            ])
        
        XCTAssertEqual(x2.subscriptions, [
            Subscription(200, 210)
            ])
    }
    
    func testAmb_LoserThrows() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let x1 = await scheduler.createHotObservable([
            .next(150, 1),
            .next(220, 2),
            .error(230, testError)
            ])
        
        let x2 = await scheduler.createHotObservable([
            .next(150, 1),
            .next(210, 3),
            .completed(250)
            ])
        
        let res = await scheduler.start {
            await x1.amb(x2)
        }
        
        XCTAssertEqual(res.events, [
            .next(210, 3),
            .completed(250)
            ])
        
        XCTAssertEqual(x1.subscriptions, [
            Subscription(200, 210)
            ])
        
        XCTAssertEqual(x2.subscriptions, [
            Subscription(200, 250)
            ])
    }
    
    func testAmb_ThrowsBeforeElectionLeft() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let x1 = await scheduler.createHotObservable([
            .next(150, 1),
            .error(210, testError)
            ])
        
        let x2 = await scheduler.createHotObservable([
            .next(150, 1),
            .next(220, 3),
            .completed(250)
            ])
        
        let res = await scheduler.start {
            await x1.amb(x2)
        }
        
        XCTAssertEqual(res.events, [
            .error(210, testError)
            ])
        
        XCTAssertEqual(x1.subscriptions, [
            Subscription(200, 210)
            ])
        
        XCTAssertEqual(x2.subscriptions, [
            Subscription(200, 210)
            ])
    }
    
    func testAmb_ThrowsBeforeElectionRight() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let x1 = await scheduler.createHotObservable([
            .next(150, 1),
            .next(220, 3),
            .completed(250)
            ])
        
        let x2 = await scheduler.createHotObservable([
            .next(150, 1),
            .error(210, testError)
            ])
        
        let res = await scheduler.start {
            await x1.amb(x2)
        }
        
        XCTAssertEqual(res.events, [
            .error(210, testError)
            ])
        
        XCTAssertEqual(x1.subscriptions, [
            Subscription(200, 210)
            ])
        
        XCTAssertEqual(x2.subscriptions, [
            Subscription(200, 210)
            ])
    }

    #if TRACE_RESOURCES
    func testAmb1ReleasesResourcesOnComplete() async {
        let scheduler = await TestScheduler(initialClock: 0)
        _ = await Observable.just(1).delay(.seconds(10), scheduler: scheduler).amb(Observable.just(1)).subscribe()
        await scheduler.start()
        }

    func testAmb2ReleasesResourcesOnComplete() async {
        let scheduler = await TestScheduler(initialClock: 0)
        _ = await Observable.just(1).amb(Observable.just(1).delay(.seconds(10), scheduler: scheduler)).subscribe()
        await scheduler.start()
        }

    func testAmb1ReleasesResourcesOnError() async {
        let scheduler = await TestScheduler(initialClock: 0)
        _ = await Observable<Int>.never().timeout(.seconds(20), scheduler: scheduler).amb(Observable<Int>.never()).subscribe()
        await scheduler.start()
        }

    func testAmb2ReleasesResourcesOnError() async {
        let scheduler = await TestScheduler(initialClock: 0)
        _ = await Observable<Int>.never().amb(Observable<Int>.never().timeout(.seconds(20), scheduler: scheduler)).subscribe()
        await scheduler.start()
        }
    #endif
}


extension Array {
 
    func map<T>(_ transform: (Element) async throws -> T) async rethrows -> [T] {
        var array = [T]()
        array.reserveCapacity(count)
        for el in self {
            array.append(try await transform(el))
        }
        return array
    }
}
