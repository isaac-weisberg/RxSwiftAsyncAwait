//
//  Observable+ConcatTests.swift
//  Tests
//
//  Created by Krunoslav Zaher on 4/29/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

import XCTest
import RxSwift
import RxTest

class ObservableConcatTest : RxTest {
}

// this generates
// [generator(0), [generator(1), [generator(2), ..].concat()].concat()].concat()
// BROKEN
func generateCollection<T>(_ startIndex: Int, _ generator: @escaping (Int) async -> Observable<T>) async -> Observable<T> {
    let all = await [0, 1].map { i in
        return await i == 0 ? generator(startIndex) : generateCollection(startIndex + 1, generator)
    }
    return await Observable.concat(all)
}

// this generates
// [generator(0), [generator(1), [generator(2), ..].concat()].concat()].concat()
// This should
// BROKEN
func generateSequence<T>(_ startIndex: Int, _ generator: @escaping (Int) async -> Observable<T>) async -> Observable<T> {
    let indexes: [Int] = [0, 1]
    let all = await AnySequence(indexes.map { i -> Observable<T> in
        return await i == 0 ? generator(startIndex) : generateSequence(startIndex + 1, generator)
    })
    return await Observable<T>.concat(all)
}

// MARK: concat
extension ObservableConcatTest {
    func testConcat_DefaultScheduler() async {
        var sum = 0
        _ = await Observable.concat([Observable.just(1), Observable.just(2), Observable.just(3)]).subscribe(onNext: { e -> Void in
            sum += e
        })
        
        XCTAssertEqual(sum, 6)
    }
    
    func testConcat_IEofIO() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let xs1 = await scheduler.createColdObservable([
            .next(10, 1),
            .next(20, 2),
            .next(30, 3),
            .completed(40),
        ])
        
        let xs2 = await scheduler.createColdObservable([
            .next(10, 4),
            .next(20, 5),
            .completed(30),
        ])
        
        let xs3 = await scheduler.createColdObservable([
            .next(10, 6),
            .next(20, 7),
            .next(30, 8),
            .next(40, 9),
            .completed(50)
        ])
        
        let res = await scheduler.start {
            await Observable.concat([xs1, xs2, xs3].map { await $0.asObservable() })
        }
        
        let messages = Recorded.events(
            .next(210, 1),
            .next(220, 2),
            .next(230, 3),
            .next(250, 4),
            .next(260, 5),
            .next(280, 6),
            .next(290, 7),
            .next(300, 8),
            .next(310, 9),
            .completed(320)
        )

        XCTAssertEqual(res.events, messages)
        
        XCTAssertEqual(xs1.subscriptions, [
            Subscription(200, 240),
        ])

        XCTAssertEqual(xs2.subscriptions, [
            Subscription(240, 270),
        ])
        
        XCTAssertEqual(xs3.subscriptions, [
            Subscription(270, 320),
        ])
    }
    
    func testConcat_EmptyEmpty() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let xs1 = await scheduler.createHotObservable([
            .next(150, 1),
            .completed(230),
            ])
        
        let xs2 = await scheduler.createHotObservable([
            .next(150, 1),
            .completed(250),
            ])
        
        let res = await scheduler.start {
            await Observable.concat([xs1, xs2].map { await $0.asObservable() })
        }
        
        let messages = [
            Recorded.completed(250, Int.self)
        ]

        XCTAssertEqual(res.events, messages)

        XCTAssertEqual(xs1.subscriptions, [
            Subscription(200, 230),
            ])
        
        XCTAssertEqual(xs2.subscriptions, [
            Subscription(230, 250),
            ])
    }
    
    func testConcat_EmptyNever() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let xs1 = await scheduler.createHotObservable([
            .next(150, 1),
            .completed(230),
            ])
        
        let xs2 = await scheduler.createHotObservable([
            .next(150, 1),
            ])
        
        let res = await scheduler.start {
            await Observable.concat([xs1, xs2].map { await $0.asObservable() })
        }
        
        let messages: [Recorded<Event<Int>>] = [
        ]

        XCTAssertEqual(res.events, messages)
        
        XCTAssertEqual(xs1.subscriptions, [
            Subscription(200, 230),
            ])
        
        XCTAssertEqual(xs2.subscriptions, [
            Subscription(230, 1000),
            ])
    }
    
    func testConcat_NeverNever() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let xs1 = await scheduler.createHotObservable([
            .next(150, 1),
            ])
        
        let xs2 = await scheduler.createHotObservable([
            .next(150, 1),
            ])
        
        let res = await scheduler.start {
            await Observable.concat([xs1, xs2].map { await $0.asObservable() })
        }
        
        let messages: [Recorded<Event<Int>>] = [
        ]

        XCTAssertEqual(res.events, messages)
        
        XCTAssertEqual(xs1.subscriptions, [
            Subscription(200, 1000),
            ])
        
        XCTAssertEqual(xs2.subscriptions, [
            ])
    }
    
    func testConcat_EmptyThrow() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let xs1 = await scheduler.createHotObservable([
            .next(150, 1),
            .completed(230),
            ])
        
        let xs2 = await scheduler.createHotObservable([
            .next(150, 1),
            .error(250, testError)
            ])
        
        let res = await scheduler.start {
            await Observable.concat([xs1, xs2].map { await $0.asObservable() })
        }
        
        let messages = [
            Recorded.error(250, testError, Int.self)
        ]

        XCTAssertEqual(res.events, messages)
        
        XCTAssertEqual(xs1.subscriptions, [
            Subscription(200, 230),
            ])

        XCTAssertEqual(xs2.subscriptions, [
            Subscription(230, 250),
            ])
    }
    
    func testConcat_ThrowEmpty() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let xs1 = await scheduler.createHotObservable([
            .next(150, 1),
            .error(230, testError),
            ])
        
        let xs2 = await scheduler.createHotObservable([
            .next(150, 1),
            .completed(250)
            ])
        
        let res = await scheduler.start {
            await Observable.concat([xs1, xs2].map { await $0.asObservable() })
        }
        
        let messages = [
            Recorded.error(230, testError, Int.self)
        ]

        XCTAssertEqual(res.events, messages)
        
        XCTAssertEqual(xs1.subscriptions, [
            Subscription(200, 230),
            ])
        
        XCTAssertEqual(xs2.subscriptions, [
            ])
    }
    
    func testConcat_ThrowThrow() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let xs1 = await scheduler.createHotObservable([
            .next(150, 1),
            .error(230, testError1),
            ])
        
        let xs2 = await scheduler.createHotObservable([
            .next(150, 1),
            .error(250, testError2)
            ])
        
        let res = await scheduler.start {
            await Observable.concat([xs1, xs2].map { await $0.asObservable() })
        }
        
        let messages = [
            Recorded.error(230, testError1, Int.self)
        ]

        XCTAssertEqual(res.events, messages)
        
        XCTAssertEqual(xs1.subscriptions, [
            Subscription(200, 230),
            ])
        
        XCTAssertEqual(xs2.subscriptions, [
            ])
    }
    
    func testConcat_ReturnEmpty() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let xs1 = await scheduler.createHotObservable([
            .next(150, 1),
            .next(210, 2),
            .completed(230),
            ])
        
        let xs2 = await scheduler.createHotObservable([
            .next(150, 1),
            .completed(250)
            ])
        
        let res = await scheduler.start {
            await Observable.concat([xs1, xs2].map { await $0.asObservable() })
        }
        
        let messages = Recorded.events(
            .next(210, 2),
            .completed(250)
        )

        XCTAssertEqual(res.events, messages)
        
        XCTAssertEqual(xs1.subscriptions, [
            Subscription(200, 230),
            ])
        
        XCTAssertEqual(xs2.subscriptions, [
            Subscription(230, 250),
            ])
    }
    
    func testConcat_EmptyReturn() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let xs1 = await scheduler.createHotObservable([
            .next(150, 1),
            .completed(230),
            ])
        
        let xs2 = await scheduler.createHotObservable([
            .next(150, 1),
            .next(240, 2),
            .completed(250)
            ])
        
        let res = await scheduler.start {
            await Observable.concat([xs1, xs2].map { await $0.asObservable() })
        }
        
        let messages = Recorded.events(
            .next(240, 2),
            .completed(250)
        )

        XCTAssertEqual(res.events, messages)
        
        XCTAssertEqual(xs1.subscriptions, [
            Subscription(200, 230),
            ])
        
        XCTAssertEqual(xs2.subscriptions, [
            Subscription(230, 250),
            ])
    }
    
    func testConcat_ReturnNever() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let xs1 = await scheduler.createHotObservable([
            .next(150, 1),
            .next(210, 2),
            .completed(230),
            ])
        
        let xs2 = await scheduler.createHotObservable([
            .next(150, 1),
            ])
        
        let res = await scheduler.start {
            await Observable.concat([xs1, xs2].map { await $0.asObservable() })
        }
        
        let messages = [
            Recorded.next(210, 2),
        ]

        XCTAssertEqual(res.events, messages)
        
        XCTAssertEqual(xs1.subscriptions, [
            Subscription(200, 230),
            ])
        
        XCTAssertEqual(xs2.subscriptions, [
            Subscription(230, 1000),
            ])
    }
    
    func testConcat_NeverReturn() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let xs1 = await scheduler.createHotObservable([
            .next(150, 1),
            ])
        
        let xs2 = await scheduler.createHotObservable([
            .next(150, 1),
            .next(210, 2),
            .completed(230),
            ])
        
        let res = await scheduler.start {
            await Observable.concat([xs1, xs2].map { await $0.asObservable() })
        }
        
        let messages: [Recorded<Event<Int>>] = [
        ]

        XCTAssertEqual(res.events, messages)
        
        XCTAssertEqual(xs1.subscriptions, [
            Subscription(200, 1000),
            ])
        
        XCTAssertEqual(xs2.subscriptions, [
            ])
    }
    
    func testConcat_ReturnReturn() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let xs1 = await scheduler.createHotObservable([
            .next(150, 1),
            .next(220, 2),
            .completed(230)
            ])
        
        let xs2 = await scheduler.createHotObservable([
            .next(150, 1),
            .next(240, 3),
            .completed(250),
            ])
        
        let res = await scheduler.start {
            await Observable.concat([xs1, xs2].map { await $0.asObservable() })
        }
        
        let messages = Recorded.events(
            .next(220, 2),
            .next(240, 3),
            .completed(250)
        )

        XCTAssertEqual(res.events, messages)
        
        XCTAssertEqual(xs1.subscriptions, [
            Subscription(200, 230),
            ])
        
        XCTAssertEqual(xs2.subscriptions, [
            Subscription(230, 250),
            ])
    }
    
    func testConcat_ThrowReturn() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let xs1 = await scheduler.createHotObservable([
            .next(150, 1),
            .error(230, testError1)
            ])
        
        let xs2 = await scheduler.createHotObservable([
            .next(150, 1),
            .next(240, 2),
            .completed(250),
            ])
        
        let res = await scheduler.start {
            await Observable.concat([xs1, xs2].map { await $0.asObservable() })
        }
        
        let messages = [
            Recorded.error(230, testError1, Int.self)
        ]

        XCTAssertEqual(res.events, messages)
        
        XCTAssertEqual(xs1.subscriptions, [
            Subscription(200, 230),
            ])
        
        XCTAssertEqual(xs2.subscriptions, [
            ])
    }
    
    func testConcat_ReturnThrow() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let xs1 = await scheduler.createHotObservable([
            .next(150, 1),
            .next(220, 2),
            .completed(230)
            ])
        
        let xs2 = await scheduler.createHotObservable([
            .next(150, 1),
            .error(250, testError2),
            ])
        
        let res = await scheduler.start {
            await Observable.concat([xs1, xs2].map { await $0.asObservable() })
        }
        
        let messages = Recorded.events(
            .next(220, 2),
            .error(250, testError2)
        )

        XCTAssertEqual(res.events, messages)
        
        XCTAssertEqual(xs1.subscriptions, [
            Subscription(200, 230),
            ])
        
        XCTAssertEqual(xs2.subscriptions, [
            Subscription(230, 250),
            ])
    }
    
    func testConcat_SomeDataSomeData() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let xs1 = await scheduler.createHotObservable([
            .next(150, 1),
            .next(210, 2),
            .next(220, 3),
            .completed(225)
            ])
        
        let xs2 = await scheduler.createHotObservable([
            .next(150, 1),
            .next(230, 4),
            .next(240, 5),
            .completed(250)
            ])
        
        let res = await scheduler.start {
            await Observable.concat([xs1, xs2].map { await $0.asObservable() })
        }
        
        let messages = Recorded.events(
            .next(210, 2),
            .next(220, 3),
            .next(230, 4),
            .next(240, 5),
            .completed(250)
        )

        XCTAssertEqual(res.events, messages)
        
        XCTAssertEqual(xs1.subscriptions, [
            Subscription(200, 225),
            ])
        
        XCTAssertEqual(xs2.subscriptions, [
            Subscription(225, 250),
            ])
    }
    
    func testConcat_EnumerableTiming() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let xs1 = await scheduler.createHotObservable([
            .next(150, 1),
            .next(210, 2),
            .next(220, 3),
            .completed(230)
            ])
        
        let xs2 = await scheduler.createColdObservable([
            .next(50, 4),
            .next(60, 5),
            .next(70, 6),
            .completed(80)
            ])
        
        let xs3 = await scheduler.createHotObservable([
            .next(150, 1),
            .next(200, 2),
            .next(210, 3),
            .next(220, 4),
            .next(230, 5),
            .next(270, 6),
            .next(320, 7),
            .next(330, 8),
            .completed(340)
            ])
        
        let res = await scheduler.start {
            await Observable.concat([xs1, xs2, xs3, xs2].map { await $0.asObservable() })
        }
        
        let messages = Recorded.events(
            .next(210, 2),
            .next(220, 3),
            .next(280, 4),
            .next(290, 5),
            .next(300, 6),
            .next(320, 7),
            .next(330, 8),
            .next(390, 4),
            .next(400, 5),
            .next(410, 6),
            .completed(420)
        )

        XCTAssertEqual(res.events, messages)
        
        XCTAssertEqual(xs1.subscriptions, [
            Subscription(200, 230),
            ])
        
        XCTAssertEqual(xs2.subscriptions, [
            Subscription(230, 310),
            Subscription(340, 420),
            ])
        
        XCTAssertEqual(xs3.subscriptions, [
            Subscription(310, 340),
            ])
        
    }

    func testConcat_variadicElementsOverload() async {
        let elements = try! await Observable.concat(Observable.just(1)).toBlocking().toArray()
        XCTAssertEqual(elements, [1])
    }

#if TRACE_RESOURCES
    func testConcat_TailRecursionCollection() async {
        maxTailRecursiveSinkStackSize = 0
        let elements = try! await generateCollection(0) { i in
            await Observable.just(i, scheduler: CurrentThreadScheduler.instance)
            }
            .take(100)
            .toBlocking()
            .toArray()

        XCTAssertEqual(elements, Array(0 ..< 100))
        XCTAssertEqual(maxTailRecursiveSinkStackSize, 1)
    }

    func testConcat_TailRecursionSequence() async {
        maxTailRecursiveSinkStackSize = 0
        let elements = try! await generateSequence(0) { i in
            await Observable.just(i, scheduler: CurrentThreadScheduler.instance)
            }
            .take(100)
            .toBlocking()
            .toArray()

        XCTAssertEqual(elements, Array(0 ..< 100))
        XCTAssertTrue(maxTailRecursiveSinkStackSize > 10)
    }
#endif


    #if TRACE_RESOURCES
    func testConcatReleasesResourcesOnComplete() async {
        _ = await Observable.concat([Observable.just(1)]).subscribe()
        }

    func testConcatReleasesResourcesOnError() async {
        _ = await Observable.concat([Observable<Int>.error(testError)]).subscribe()
        }
    #endif
}


extension LazySequence {
    func map<U>(_ transform: @escaping (Base.Element) async -> U) async -> CustomAsyncMapSequence<Self, U> {
        CustomAsyncMapSequence(base: self) { e in
            await transform(e)
        }
    }
}

struct CustomAsyncMapSequence<Base: Sequence, Element>: AsyncSequence {

    let base: Base
    let transform: (Base.Element) async -> Element
    
    struct AsyncIterator: AsyncIteratorProtocol {
        var baseIterator: Base.Iterator
        let transform: (Base.Element) async -> Element
        
        mutating func next() async -> Element? {
            guard let nextElement = baseIterator.next() else { return nil }
            return await transform(nextElement)
        }
    }
    
    func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(baseIterator: base.makeIterator(), transform: transform)
    }
}
