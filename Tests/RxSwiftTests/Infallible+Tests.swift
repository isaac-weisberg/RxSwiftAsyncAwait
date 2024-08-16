////
////  Infallible+Tests.swift
////  Tests
////
////  Created by Shai Mishali on 11/20/20.
////  Copyright © 2020 Krunoslav Zaher. All rights reserved.
////
//
//import RxSwift
//// import RxCocoa
//import RxRelay
//import RxTest
//import XCTest
//
//class InfallibleTest: RxTest { }
//
//extension InfallibleTest {
//    func testAsInfallible_OnErrorJustReturn() async {
//        let scheduler = await TestScheduler(initialClock: 0)
//        let xs = await scheduler.createHotObservable([
//            .next(300, 9),
//            .next(340, 13),
//            .next(360, 111),
//            .error(390, testError),
//            .next(480, 320),
//        ])
//
//        let inf = await xs.asInfallible(onErrorJustReturn: 600)
//        let observer = scheduler.createObserver(Int.self)
//
//        _ = inf.bind(to: observer)
//
//        await scheduler.start()
//
//        XCTAssertEqual(observer.events, [
//            .next(300, 9),
//            .next(340, 13),
//            .next(360, 111),
//            .next(390, 600),
//            .completed(390)
//        ])
//    }
//
//    func testAsInfallible_OnErrorFallbackTo() async {
//        let scheduler = await TestScheduler(initialClock: 0)
//        let xs = await scheduler.createHotObservable([
//            .next(300, 9),
//            .next(340, 13),
//            .next(360, 111),
//            .error(390, testError),
//            .next(480, 320),
//        ])
//
//        let inf = await xs.asInfallible(onErrorFallbackTo: Infallible<Int>.of(1, 2))
//        let observer = scheduler.createObserver(Int.self)
//
//        _ = inf.bind(to: observer)
//
//        await scheduler.start()
//
//        XCTAssertEqual(observer.events, [
//            .next(300, 9),
//            .next(340, 13),
//            .next(360, 111),
//            .next(390, 1),
//            .next(390, 2),
//            .completed(390)
//        ])
//    }
//
//    func testAsInfallible_OnErrorRecover() async {
//        let scheduler = await TestScheduler(initialClock: 0)
//        let xs = await scheduler.createHotObservable([
//            .next(300, 9),
//            .next(340, 13),
//            .next(360, 111),
//            .error(390, testError),
//            .next(480, 320),
//        ])
//
//        let ys = await scheduler.createHotObservable([
//            .next(500, 25),
//            .next(600, 33),
//            .completed(620)
//        ])
//
//        let inf = await xs.asInfallible(onErrorRecover: { _ in ys.asInfallible(onErrorJustReturn: -1) })
//        let observer = scheduler.createObserver(Int.self)
//
//        _ = inf.bind(to: observer)
//
//        await scheduler.start()
//
//        XCTAssertEqual(observer.events, [
//            .next(300, 9),
//            .next(340, 13),
//            .next(360, 111),
//            .next(500, 25),
//            .next(600, 33),
//            .completed(620)
//        ])
//    }
//    
//    func testAsInfallible_BehaviourRelay() async {
//        let scheduler = await TestScheduler(initialClock: 0)
//        let xs = await BehaviorRelay<Int>(value: 0)
//        
//        let ys = await scheduler.createHotObservable([
//            .next(500, 25),
//            .next(600, 33)
//        ])
//
//        let inf = await xs.asInfallible()
//        let observer = scheduler.createObserver(Int.self)
//
//        _ = inf.bind(to: observer)
//        _ = await ys.bind(to: xs)
//
//        await scheduler.start()
//
//        XCTAssertEqual(observer.events, [
//            .next(0, 0),
//            .next(500, 25),
//            .next(600, 33)
//        ])
//    }
//    
//    func testAsInfallible_PublishRelay() async {
//        let scheduler = await TestScheduler(initialClock: 0)
//        let xs = await PublishRelay<Int>()
//        
//        let ys = await scheduler.createHotObservable([
//            .next(500, 25),
//            .next(600, 33)
//        ])
//
//        let inf = await xs.asInfallible()
//        let observer = scheduler.createObserver(Int.self)
//
//        _ = inf.bind(to: observer)
//        _ = await ys.bind(to: xs)
//
//        await scheduler.start()
//
//        XCTAssertEqual(observer.events, [
//            .next(500, 25),
//            .next(600, 33)
//        ])
//    }
//    
//    func testAsInfallible_ReplayRelay() async {
//        let scheduler = await TestScheduler(initialClock: 0)
//        let xs = await ReplayRelay<Int>.create(bufferSize: 2)
//        
//        let ys = await scheduler.createHotObservable([
//            .next(500, 25),
//            .next(600, 33)
//        ])
//
//        let inf = await xs.asInfallible()
//        let observer = scheduler.createObserver(Int.self)
//
//        _ = inf.bind(to: observer)
//        _ = await ys.bind(to: xs)
//
//        await scheduler.start()
//
//        XCTAssertEqual(observer.events, [
//            .next(500, 25),
//            .next(600, 33)
//        ])
//    }
//
//    func testAnonymousInfallible_detachesOnDispose() {
//        var observer: ((InfallibleEvent<Int>) -> Void)!
//        let a = Infallible.create { o in
//            observer = o
//            return Disposables.create()
//        } as Infallible<Int>
//
//        var elements = [Int]()
//
//        let d = a.subscribe(onNext: { n in
//            elements.append(n)
//        })
//
//        XCTAssertEqual(elements, [])
//
//        observer(.next(0))
//        XCTAssertEqual(elements, [0])
//
//        d.dispose()
//
//        observer(.next(1))
//        XCTAssertEqual(elements, [0])
//    }
//
//    func testAnonymousInfallible_detachesOnComplete() {
//        var observer: ((InfallibleEvent<Int>) -> Void)!
//        let a = Infallible.create { o in
//            observer = o
//            return Disposables.create()
//        } as Infallible<Int>
//
//        var elements = [Int]()
//
//        _ = a.subscribe(onNext: { n in
//            elements.append(n)
//        })
//
//        XCTAssertEqual(elements, [])
//
//        observer(.next(0))
//        XCTAssertEqual(elements, [0])
//
//        observer(.completed)
//
//        observer(.next(1))
//        XCTAssertEqual(elements, [0])
//    }
//}
//
//extension InfallibleTest {
//    func testAsInfallible_never() async {
//        let scheduler = await TestScheduler(initialClock: 0)
//
//        let xs: Infallible<Int> = await Infallible.never()
//
//        let res = await scheduler.start { xs }
//
//        let correct: [Recorded<Event<Int>>] = []
//
//        XCTAssertEqual(res.events, correct)
//    }
//
//    #if TRACE_RESOURCES
//    func testAsInfallibleReleasesResourcesOnComplete() async {
//        _ = await Observable<Int>.empty().asInfallible(onErrorJustReturn: 0).subscribe()
//        }
//
//    func testAsInfallibleReleasesResourcesOnError() async {
//        _ = await Observable<Int>.empty().asInfallible(onErrorJustReturn: 0).subscribe()
//        }
//    #endif
//}
//
//// MARK: - Subscribe with object
//extension InfallibleTest {
//    func testSubscribeWithNext() async {
//        var testObject: TestObject! = TestObject()
//        let scheduler = await TestScheduler(initialClock: 0)
//        var values = [String]()
//        var disposed: UUID?
//        var completed: UUID?
//
//        let observable = await scheduler.createColdObservable([
//            .next(10, 0),
//            .next(20, 1),
//            .next(30, 2),
//            .next(40, 3),
//            .completed(50)
//        ])
//        
//        let inf = await observable.asInfallible(onErrorJustReturn: -1)
//        
//        _ = await inf
//            .subscribe(
//                with: testObject,
//                onNext: { object, value in values.append(object.id.uuidString + "\(value)") },
//                onCompleted: { completed = $0.id },
//                onDisposed: { disposed = $0.id }
//            )
//        
//        await scheduler.start()
//        
//        let uuid = testObject.id
//        XCTAssertEqual(values, [
//            uuid.uuidString + "0",
//            uuid.uuidString + "1",
//            uuid.uuidString + "2",
//            uuid.uuidString + "3"
//        ])
//        
//        XCTAssertEqual(completed, uuid)
//        XCTAssertEqual(disposed, uuid)
//        
//        XCTAssertNotNil(testObject)
//        testObject = nil
//        XCTAssertNil(testObject)
//    }
//    
//    func testSubscribeWithError() async {
//        var testObject: TestObject! = TestObject()
//        let scheduler = await TestScheduler(initialClock: 0)
//        var values = [String]()
//        var disposed: UUID?
//        var completed: UUID?
//
//        let observable = await scheduler.createColdObservable([
//            .next(10, 0),
//            .next(20, 1),
//            .error(30, testError),
//            .next(40, 3),
//        ])
//        
//        let inf = await observable.asInfallible(onErrorJustReturn: -1)
//        
//        _ = await inf
//            .subscribe(
//                with: testObject,
//                onNext: { object, value in values.append(object.id.uuidString + "\(value)") },
//                onCompleted: { completed = $0.id },
//                onDisposed: { disposed = $0.id }
//            )
//        
//        await scheduler.start()
//        
//        let uuid = testObject.id
//        XCTAssertEqual(values, [
//            uuid.uuidString + "0",
//            uuid.uuidString + "1",
//            uuid.uuidString + "-1"
//        ])
//        
//        XCTAssertEqual(completed, uuid)
//        XCTAssertEqual(disposed, uuid)
//        
//        XCTAssertNotNil(testObject)
//        testObject = nil
//        XCTAssertNil(testObject)
//    }
//}
//
//private class TestObject: NSObject {
//    var id = UUID()
//}
