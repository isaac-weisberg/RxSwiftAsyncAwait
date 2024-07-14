//
//  SubjectConcurrencyTest.swift
//  Tests
//
//  Created by Krunoslav Zaher on 11/8/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

@testable import RxSwift
import XCTest
import Dispatch



final class ReplaySubjectConcurrencyTest : SubjectConcurrencyTest {
    override func createSubject() async -> (Observable<Int>, AnyObserver<Int>) {
        let s = await ReplaySubject<Int>.create(bufferSize: 1)
        return await (s.asObservable(), AnyObserver(eventHandler: s.asObserver().on))
    }
}

final class BehaviorSubjectConcurrencyTest : SubjectConcurrencyTest {
    override func createSubject() async -> (Observable<Int>, AnyObserver<Int>) {
        let s = await BehaviorSubject<Int>(value: -1)
        return await (s.asObservable(), AnyObserver(eventHandler: s.asObserver().on))
    }
}

class SubjectConcurrencyTest : RxTest {
    // default test is for publish subject
    func createSubject() async -> (Observable<Int>, AnyObserver<Int>) {
        let s = await PublishSubject<Int>()
        return await (s.asObservable(), AnyObserver(eventHandler: s.asObserver().on))
    }
}

extension SubjectConcurrencyTest {
    func testSubjectIsReentrantForNextAndComplete() async {
        let (observable, _observer) = await createSubject()

        var state = 0

        let o = RxMutableBox(_observer)

        var ranAll = false

        _ = await observable.subscribe(onNext: { [unowned o] n in
            if n < 0 {
                return
            }

            if state == 0 {
                state = 1

                // if isn't reentrant, this will cause deadlock
                await o.value.on(.next(1))
            }
            else if state == 1 {
                // if isn't reentrant, this will cause deadlock
                await o.value.on(.completed)
                ranAll = true
            }
        })

        await o.value.on(.next(0))
        XCTAssertTrue(ranAll)
    }

    func testSubjectIsReentrantForNextAndError() async {
        let (observable, _observer) = await createSubject()

        var state = 0

        let o = RxMutableBox(_observer)

        var ranAll = false

        _ = await observable.subscribe(onNext: { [unowned o] n in
            if n < 0 {
                return
            }

            if state == 0 {
                state = 1

                // if isn't reentrant, this will cause deadlock
                await o.value.on(.next(1))
            }
            else if state == 1 {
                // if isn't reentrant, this will cause deadlock
                await o.value.on(.error(testError))
                ranAll = true
            }
        })

        await o.value.on(.next(0))
        XCTAssertTrue(ranAll)
    }
}
