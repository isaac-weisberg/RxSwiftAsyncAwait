//
//  Observable+SubscriptionTest.swift
//  Tests
//
//  Created by Krunoslav Zaher on 10/13/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

import RxSwift
import XCTest

class ObservableSubscriptionTests : RxTest {
    func testSubscribeOnNext() async {
        let publishSubject = await PublishSubject<Int>()

        var onNextCalled = 0
        var onErrorCalled = 0
        var onCompletedCalled = 0
        var onDisposedCalled = 0

        var lastElement: Int?
        var lastError: Swift.Error?

        let subscription = await publishSubject.subscribe(onNext: { n in
                lastElement = n
                onNextCalled += 1
            }, onError: { e in
                lastError = e
                onErrorCalled += 1
            }, onCompleted: {
                onCompletedCalled += 1
            }, onDisposed: {
                onDisposedCalled += 1
            })

        XCTAssertTrue(lastElement == nil)
        XCTAssertTrue(lastError == nil)
        XCTAssertTrue(onNextCalled == 0)
        XCTAssertTrue(onErrorCalled == 0)
        XCTAssertTrue(onCompletedCalled == 0)
        XCTAssertTrue(onDisposedCalled == 0)

        await publishSubject.on(.next(1))

        XCTAssertTrue(lastElement == 1)
        XCTAssertTrue(lastError == nil)
        XCTAssertTrue(onNextCalled == 1)
        XCTAssertTrue(onErrorCalled == 0)
        XCTAssertTrue(onCompletedCalled == 0)
        XCTAssertTrue(onDisposedCalled == 0)

        await subscription.dispose()
        await publishSubject.on(.next(2))

        XCTAssertTrue(lastElement == 1)
        XCTAssertTrue(lastError == nil)
        XCTAssertTrue(onNextCalled == 1)
        XCTAssertTrue(onErrorCalled == 0)
        XCTAssertTrue(onCompletedCalled == 0)
        XCTAssertTrue(onDisposedCalled == 1)
    }

    func testSubscribeOnError() async {
        let publishSubject = await PublishSubject<Int>()

        var onNextCalled = 0
        var onErrorCalled = 0
        var onCompletedCalled = 0
        var onDisposedCalled = 0

        var lastElement: Int?
        var lastError: Swift.Error?

        let subscription = await publishSubject.subscribe(onNext: { n in
                lastElement = n
                onNextCalled += 1
            }, onError: { e in
                lastError = e
                onErrorCalled += 1
            }, onCompleted: {
                onCompletedCalled += 1
            }, onDisposed: {
                onDisposedCalled += 1
            })

        XCTAssertTrue(lastElement == nil)
        XCTAssertTrue(lastError == nil)
        XCTAssertTrue(onNextCalled == 0)
        XCTAssertTrue(onErrorCalled == 0)
        XCTAssertTrue(onCompletedCalled == 0)
        XCTAssertTrue(onDisposedCalled == 0)

        await publishSubject.on(.error(testError))

        XCTAssertTrue(lastElement == nil)
        XCTAssertTrue((lastError as! TestError) == testError)
        XCTAssertTrue(onNextCalled == 0)
        XCTAssertTrue(onErrorCalled == 1)
        XCTAssertTrue(onCompletedCalled == 0)
        XCTAssertTrue(onDisposedCalled == 1)

        await subscription.dispose()
        await publishSubject.on(.next(2))
        await publishSubject.on(.completed)

        XCTAssertTrue(lastElement == nil)
        XCTAssertTrue((lastError as! TestError) == testError)
        XCTAssertTrue(onNextCalled == 0)
        XCTAssertTrue(onErrorCalled == 1)
        XCTAssertTrue(onCompletedCalled == 0)
        XCTAssertTrue(onDisposedCalled == 1)
    }

    func testSubscribeOnCompleted() async {
        let publishSubject = await PublishSubject<Int>()

        var onNextCalled = 0
        var onErrorCalled = 0
        var onCompletedCalled = 0
        var onDisposedCalled = 0

        var lastElement: Int?
        var lastError: Swift.Error?

        let subscription = await publishSubject.subscribe(onNext: { n in
            lastElement = n
            onNextCalled += 1
            }, onError: { e in
                lastError = e
                onErrorCalled += 1
            }, onCompleted: {
                onCompletedCalled += 1
            }, onDisposed: {
                onDisposedCalled += 1
        })

        XCTAssertTrue(lastElement == nil)
        XCTAssertTrue(lastError == nil)
        XCTAssertTrue(onNextCalled == 0)
        XCTAssertTrue(onErrorCalled == 0)
        XCTAssertTrue(onCompletedCalled == 0)
        XCTAssertTrue(onDisposedCalled == 0)

        await publishSubject.on(.completed)

        XCTAssertTrue(lastElement == nil)
        XCTAssertTrue(lastError == nil)
        XCTAssertTrue(onNextCalled == 0)
        XCTAssertTrue(onErrorCalled == 0)
        XCTAssertTrue(onCompletedCalled == 1)
        XCTAssertTrue(onDisposedCalled == 1)

        await subscription.dispose()
        await publishSubject.on(.next(2))
        await publishSubject.on(.error(testError))

        XCTAssertTrue(lastElement == nil)
        XCTAssertTrue(lastError == nil)
        XCTAssertTrue(onNextCalled == 0)
        XCTAssertTrue(onErrorCalled == 0)
        XCTAssertTrue(onCompletedCalled == 1)
        XCTAssertTrue(onDisposedCalled == 1)
    }

    func testDisposed() async {
        let publishSubject = await PublishSubject<Int>()

        var onNextCalled = 0
        var onErrorCalled = 0
        var onCompletedCalled = 0
        var onDisposedCalled = 0

        var lastElement: Int?
        var lastError: Swift.Error?

        let subscription = await publishSubject.subscribe(onNext: { n in
            lastElement = n
            onNextCalled += 1
            }, onError: { e in
                lastError = e
                onErrorCalled += 1
            }, onCompleted: {
                onCompletedCalled += 1
            }, onDisposed: {
                onDisposedCalled += 1
        })

        XCTAssertTrue(lastElement == nil)
        XCTAssertTrue(lastError == nil)
        XCTAssertTrue(onNextCalled == 0)
        XCTAssertTrue(onErrorCalled == 0)
        XCTAssertTrue(onCompletedCalled == 0)
        XCTAssertTrue(onDisposedCalled == 0)

        await publishSubject.on(.next(1))
        await subscription.dispose()
        await publishSubject.on(.next(2))
        await publishSubject.on(.error(testError))
        await publishSubject.on(.completed)

        XCTAssertTrue(lastElement == 1)
        XCTAssertTrue(lastError == nil)
        XCTAssertTrue(onNextCalled == 1)
        XCTAssertTrue(onErrorCalled == 0)
        XCTAssertTrue(onCompletedCalled == 0)
        XCTAssertTrue(onDisposedCalled == 1)
    }
}
