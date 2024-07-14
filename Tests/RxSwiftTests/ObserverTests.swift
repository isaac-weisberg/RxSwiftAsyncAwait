//
//  ObserverTests.swift
//  Tests
//
//  Created by Rob Cheung on 9/15/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

import XCTest
import RxSwift
import RxTest

class ObserverTests: RxTest { }

extension ObserverTests {

    func testConvenienceOn_Next() async {
        var observer: AnyObserver<Int>!
        let a: Observable<Int> = await Observable.create { o in
            observer = o
            return Disposables.create()
        }

        var elements = [Int]()

        let subscription = await a.subscribe(onNext: { n in
            elements.append(n)
        })

        XCTAssertEqual(elements, [])

        await observer.onNext(0)

        XCTAssertEqual(elements, [0])

        await subscription.dispose()
    }

    func testConvenienceOn_Error() async {
        var observer: AnyObserver<Int>!
        let a: Observable<Int> = await Observable.create { o in
            observer = o
            return Disposables.create()
        }

        var elements = [Int]()
        var errorNotification: Swift.Error!

        _ = await a.subscribe(
            onNext: { n in elements.append(n) },
            onError: { e in
                errorNotification = e
            }
        )

        XCTAssertEqual(elements, [])

        await observer.onNext(0)
        XCTAssertEqual(elements, [0])

        await observer.onError(testError)

        await observer.onNext(1)
        XCTAssertEqual(elements, [0])
        XCTAssertErrorEqual(errorNotification, testError)
    }

    func testConvenienceOn_Complete() async {
        var observer: AnyObserver<Int>!
        let a: Observable<Int> = await Observable.create { o in
            observer = o
            return Disposables.create()
        }

        var elements = [Int]()

        _ = await a.subscribe(onNext: { n in
            elements.append(n)
        })

        XCTAssertEqual(elements, [])

        await observer.onNext(0)
        XCTAssertEqual(elements, [0])

        await observer.onCompleted()

        await observer.onNext(1)
        XCTAssertEqual(elements, [0])
    }
}

extension ObserverTests {
    func testMapElement() async {
        let observer = PrimitiveMockObserver<Int>()

        await observer.mapObserver { (x: Int) -> Int in
            return x / 2
        }.on(.next(2))

        XCTAssertEqual(observer.events, [.next(1)])
    }

    func testMapElementCompleted() async {
        let observer = PrimitiveMockObserver<Int>()

        await observer.mapObserver { (x: Int) -> Int in
            return x / 2
        }.on(.completed)

        XCTAssertEqual(observer.events, [.completed()])
    }

    func testMapElementError() async {
        let observer = PrimitiveMockObserver<Int>()

        await observer.mapObserver { (x: Int) -> Int in
            return x / 2
        }.on(.error(testError))

        XCTAssertEqual(observer.events, [.error(testError)])
    }

    func testMapElementThrow() async {
        let observer = PrimitiveMockObserver<Int>()

        await observer.mapObserver { _ -> Int in
            throw testError
        }.on(.next(2))

        XCTAssertEqual(observer.events, [.error(testError)])
    }
}
