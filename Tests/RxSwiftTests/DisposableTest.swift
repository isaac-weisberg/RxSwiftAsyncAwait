//
//  DisposableTest.swift
//  Tests
//
//  Created by Krunoslav Zaher on 2/8/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

import Dispatch
import RxSwift
import RxTest
import XCTest

#if os(Linux)
    import Glibc
#else
    import Foundation
#endif

class DisposableTest: RxTest {
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
}

// action
extension DisposableTest {
    func testActionDisposable() async {
        var counter = 0
        
        let disposable = await Disposables.create {
            counter += 1
        }
        
        XCTAssert(counter == 0)
        await disposable.dispose()
        XCTAssert(counter == 1)
        await disposable.dispose()
        XCTAssert(counter == 1)
    }
}

// hot disposable
extension DisposableTest {
    func testHotObservable_Disposing() async {
        let scheduler = await TestScheduler(initialClock: 0)
        
        let xs = await scheduler.createHotObservable([
            .next(110, 1),
            .next(180, 2),
            .next(230, 3),
            .next(270, 4),
            .next(340, 5),
            .next(380, 6),
            .next(390, 7),
            .next(450, 8),
            .next(470, 9),
            .next(560, 10),
            .next(580, 11),
            .completed(600)
        ])
        
        let res = await scheduler.start(disposed: 400) {
            xs
        }
        
        await assertEqual(res.events, [
            .next(230, 3),
            .next(270, 4),
            .next(340, 5),
            .next(380, 6),
            .next(390, 7)
        ])
        
        await assertEqual(xs.subscriptions, [
            Subscription(200, 400)
        ])
    }
}

// composite disposable
extension DisposableTest {
    func testCompositeDisposable_TestNormal() async {
        var numberDisposed = 0
        let compositeDisposable = await CompositeDisposable()
        
        let result1 = await compositeDisposable.insert(Disposables.create {
            numberDisposed += 1
        })
        
        _ = await compositeDisposable.insert(Disposables.create {
            numberDisposed += 1
        })
        
        await assertEqual(numberDisposed, 0)
        await assertEqual(await compositeDisposable.count(), 2)
        await assertTrue(result1 != nil)
        
        await compositeDisposable.dispose()
        await assertEqual(numberDisposed, 2)
        await assertEqual(await compositeDisposable.count(), 0)
        
        let result = await compositeDisposable.insert(Disposables.create {
            numberDisposed += 1
        })

        await assertEqual(numberDisposed, 3)
        await assertEqual(await compositeDisposable.count(), 0)
        await assertTrue(result == nil)
    }
    
    func testCompositeDisposable_TestInitWithNumberOfDisposables() async {
        var numberDisposed = 0
        
        let disposable1 = await Disposables.create {
            numberDisposed += 1
        }
        let disposable2 = await Disposables.create {
            numberDisposed += 1
        }
        let disposable3 = await Disposables.create {
            numberDisposed += 1
        }
        let disposable4 = await Disposables.create {
            numberDisposed += 1
        }
        let disposable5 = await Disposables.create {
            numberDisposed += 1
        }

        let compositeDisposable = await CompositeDisposable(disposable1, disposable2, disposable3, disposable4, disposable5)
        
        await assertEqual(numberDisposed, 0)
        await assertEqual(await compositeDisposable.count(), 5)
        
        await compositeDisposable.dispose()
        await assertEqual(numberDisposed, 5)
        await assertEqual(await compositeDisposable.count(), 0)
    }
    
    func testCompositeDisposable_TestRemoving() async {
        var numberDisposed = 0
        let compositeDisposable = await CompositeDisposable()
        
        let result1 = await compositeDisposable.insert(Disposables.create {
            numberDisposed += 1
        })
        
        let result2 = await compositeDisposable.insert(Disposables.create {
            numberDisposed += 1
        })
        
        await assertEqual(numberDisposed, 0)
        await assertEqual(await compositeDisposable.count(), 2)
        XCTAssertTrue(result1 != nil)
        
        await compositeDisposable.remove(for: result2!)

        await assertEqual(numberDisposed, 1)
        await assertEqual(await compositeDisposable.count(), 1)
     
        await compositeDisposable.dispose()

        await assertEqual(numberDisposed, 2)
        await assertEqual(await compositeDisposable.count(), 0)
    }
    
    func testDisposables_TestCreateWithNumberOfDisposables() async {
        var numberDisposed = 0
        
        let disposable1 = await Disposables.create {
            numberDisposed += 1
        }
        let disposable2 = await Disposables.create {
            numberDisposed += 1
        }
        let disposable3 = await Disposables.create {
            numberDisposed += 1
        }
        let disposable4 = await Disposables.create {
            numberDisposed += 1
        }
        let disposable5 = await Disposables.create {
            numberDisposed += 1
        }
        
        let disposable = await Disposables.create(disposable1, disposable2, disposable3, disposable4, disposable5)
        
        await assertEqual(numberDisposed, 0)
        
        await disposable.dispose()
        await assertEqual(numberDisposed, 5)
    }
}

// refCount disposable
extension DisposableTest {
    func testRefCountDisposable_RefCounting() async {
        let d = await BooleanDisposable()
        let r = await RefCountDisposable(disposable: d)
        
        await assertEqual(await r.isDisposed(), false)
        
        let d1 = await r.retain()
        let d2 = await r.retain()
        
        await assertEqual(await d.isDisposed(), false)
        
        await d1.dispose()
        await assertEqual(await d.isDisposed(), false)
        
        await d2.dispose()
        await assertEqual(await d.isDisposed(), false)
        
        await r.dispose()
        await assertEqual(await d.isDisposed(), true)
        
        let d3 = await r.retain()
        await d3.dispose()
    }
    
    func testRefCountDisposable_PrimaryDisposesFirst() async {
        let d = await BooleanDisposable()
        let r = await RefCountDisposable(disposable: d)
        
        await assertEqual(await r.isDisposed(), false)
        
        let d1 = await r.retain()
        let d2 = await r.retain()
        
        await assertEqual(await d.isDisposed(), false)
        
        await d1.dispose()
        await assertEqual(await d.isDisposed(), false)
        
        await r.dispose()
        await assertEqual(await d.isDisposed(), false)
        
        await d2.dispose()
        await assertEqual(await d.isDisposed(), true)
    }
}

// scheduled disposable
extension DisposableTest {
    func testScheduledDisposable_correctQueue() async {
        let expectationQueue = expectation(description: "wait")
        let label = "test label"
        let queue = DispatchQueue(label: label)
        let nameKey = DispatchSpecificKey<String>()
        queue.setSpecific(key: nameKey, value: label)
        let scheduler = ConcurrentDispatchQueueScheduler(queue: queue)
        
        let testDisposable = await Disposables.create {
            await assertEqual(DispatchQueue.getSpecific(key: nameKey), label)
            expectationQueue.fulfill()
        }

        let scheduledDisposable = await ScheduledDisposable(scheduler: scheduler, disposable: testDisposable)
        await scheduledDisposable.dispose()
        
        await fulfillment(of: [expectationQueue], timeout: 0.5)
    }
}

// serial disposable
extension DisposableTest {
    func testSerialDisposable_firstDisposedThenSet() async {
        let serialDisposable = await SerialDisposable()
        await assertFalse(await serialDisposable.isDisposed())
        
        await serialDisposable.dispose()
        await assertTrue(await serialDisposable.isDisposed())
        
        let testDisposable = TestDisposable()
        await serialDisposable.setDisposable(testDisposable)
        await assertEqual(testDisposable.count, 1)
        
        await serialDisposable.dispose()
        await assertTrue(await serialDisposable.isDisposed())
        await assertEqual(testDisposable.count, 1)
    }
    
    func testSerialDisposable_firstSetThenDisposed() async {
        let serialDisposable = await SerialDisposable()
        await assertFalse(await serialDisposable.isDisposed())
        
        let testDisposable = TestDisposable()
        
        await serialDisposable.setDisposable(testDisposable)
        await assertEqual(testDisposable.count, 0)
        
        await serialDisposable.dispose()
        await assertTrue(await serialDisposable.isDisposed())
        await assertEqual(testDisposable.count, 1)
        
        await serialDisposable.dispose()
        await assertTrue(await serialDisposable.isDisposed())
        await assertEqual(testDisposable.count, 1)
    }
    
    func testSerialDisposable_firstSetThenSetAnotherThenDisposed() async {
        let serialDisposable = await SerialDisposable()
        await assertFalse(await serialDisposable.isDisposed())
        
        let testDisposable1 = TestDisposable()
        let testDisposable2 = TestDisposable()
        
        await serialDisposable.setDisposable(testDisposable1)
        await assertEqual(testDisposable1.count, 0)
        await assertEqual(testDisposable2.count, 0)

        await serialDisposable.setDisposable(testDisposable2)
        await assertEqual(testDisposable1.count, 1)
        await assertEqual(testDisposable2.count, 0)
        
        await serialDisposable.dispose()
        await assertTrue(await serialDisposable.isDisposed())
        await assertEqual(testDisposable1.count, 1)
        await assertEqual(testDisposable2.count, 1)
        
        await serialDisposable.dispose()
        await assertTrue(await serialDisposable.isDisposed())
        await assertEqual(testDisposable1.count, 1)
        await assertEqual(testDisposable2.count, 1)
    }
}

// single assignment disposable
extension DisposableTest {
    func testSingleAssignmentDisposable_firstDisposedThenSet() async {
        let singleAssignmentDisposable = await SingleAssignmentDisposable()

        await singleAssignmentDisposable.dispose()

        let testDisposable = TestDisposable()

        await singleAssignmentDisposable.setDisposable(testDisposable)

        await assertEqual(testDisposable.count, 1)
        await singleAssignmentDisposable.dispose()
        await assertEqual(testDisposable.count, 1)
    }

    func testSingleAssignmentDisposable_firstSetThenDisposed() async {
        let singleAssignmentDisposable = await SingleAssignmentDisposable()

        let testDisposable = TestDisposable()

        await singleAssignmentDisposable.setDisposable(testDisposable)

        await assertEqual(testDisposable.count, 0)
        await singleAssignmentDisposable.dispose()
        await assertEqual(testDisposable.count, 1)

        await singleAssignmentDisposable.dispose()
        await assertEqual(testDisposable.count, 1)
    }

    func testSingleAssignmentDisposable_stress() async {
        let count = await AtomicInt(0)

        let queue = DispatchQueue(label: "dispose", qos: .default, attributes: [.concurrent])

        var expectations: [XCTestExpectation] = []
        expectations.reserveCapacity(1000)
        for _ in 0 ..< 100 {
            for _ in 0 ..< 10 {
                let expectation = self.expectation(description: "1")
                expectations.append(expectation)
                let singleAssignmentDisposable = await SingleAssignmentDisposable()
                let disposable = await Disposables.create {
                    await increment(count)
                    expectation.fulfill()
                }
                #if os(Linux)
                    let roll = Glibc.random() & 1
                #else
                    let roll = arc4random_uniform(2)
                #endif
                if roll == 0 {
                    queue.async {
                        Task {
                            await singleAssignmentDisposable.setDisposable(disposable)
                        }
                    }
                    queue.async {
                        Task {
                            await singleAssignmentDisposable.dispose()
                        }
                    }
                }
                else {
                    queue.async {
                        Task {
                            await singleAssignmentDisposable.dispose()
                        }
                    }
                    queue.async {
                        Task {
                            await singleAssignmentDisposable.setDisposable(disposable)
                        }
                    }
                }
            }
        }

        await fulfillment(of: expectations, timeout: 1.0)

        await assertEqual(await globalLoad(count), 1000)
    }
}

private class TestDisposable: Disposable {
    var count = 0
    func dispose() {
        count += 1
    }
}
