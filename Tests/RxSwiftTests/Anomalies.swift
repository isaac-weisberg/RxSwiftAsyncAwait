//
//  Anomalies.swift
//  Tests
//
//  Created by Krunoslav Zaher on 10/22/16.
//  Copyright © 2016 Krunoslav Zaher. All rights reserved.
//

import RxSwift
// import RxCocoa
import RxTest
import XCTest
import Dispatch

import Foundation

/**
 Makes sure github anomalies and edge cases don't surface up again.
 */
class AnomaliesTest: RxTest {
}

extension AnomaliesTest {
    func test936() {
        func performSharingOperatorsTest(share: @escaping (Observable<Int>) async -> Observable<Int>) {
            let queue = DispatchQueue(
                label: "Test",
                attributes: .concurrent // commenting this to use a serial queue remove the issue
            )

            for _ in 0 ..< 10 {
                let expectation = self.expectation(description: "wait until sequence completes")

                queue.async {
                    Task {
                        let scheduler: SchedulerType = ConcurrentDispatchQueueScheduler(queue: queue, leeway: .milliseconds(5))
                        
                        func makeSequence(label: String, period: RxTimeInterval) async -> Observable<Int> {
                            return await share(Observable<Int>.interval(period, scheduler: scheduler))
                        }
                        
                        _ = await makeSequence(label: "main", period: .milliseconds(100))
                            .flatMapLatest { (index: Int) -> Observable<(Int, Int)> in
                                return await makeSequence(label: "nested", period: .milliseconds(20)).map { (index, $0) }
                            }
                            .take(10)
                            .enumerated().map { ($0, $1.0, $1.1) }
                            .subscribe(
                                onNext: { _ in },
                                onCompleted: {
                                    expectation.fulfill()
                                }
                            )
                    }
                }
            }

            waitForExpectations(timeout: 10.0) { e in
                XCTAssertNil(e)
            }
        }

        for op in [
            { await $0.share(replay: 1) },
            { await $0.replay(1).refCount() },
                { await $0.publish().refCount() }
            ] as [(Observable<Int>) async -> Observable<Int>] {
            performSharingOperatorsTest(share: op)
        }
    }

    func test1323() async {
        func performSharingOperatorsTest(share: @escaping (Observable<Int>) async -> Observable<Int>) async {
            _ = await share(Observable<Int>.create({ observer in
                await observer.on(.next(1))
                    Thread.sleep(forTimeInterval: 0.1)
                await observer.on(.completed)
                    return Disposables.create()
                })
                .flatMap { int -> Observable<Int> in
                    return await Observable.create { observer -> Disposable in
                        DispatchQueue.global().async {
                            Task {
                                await observer.onNext(int)
                                await observer.onCompleted()
                            }
                        }
                        return Disposables.create()
                    }
                })
                .subscribe()
        }

        for op in [
            { await $0.share(replay: 0, scope: .whileConnected) },
            { await $0.share(replay: 0, scope: .forever) },
            { await $0.share(replay: 1, scope: .whileConnected) },
            { await $0.share(replay: 1, scope: .forever) },
            { await $0.share(replay: 2, scope: .whileConnected) },
            { await $0.share(replay: 2, scope: .forever) },
            ] as [(Observable<Int>) async -> Observable<Int>] {
            await performSharingOperatorsTest(share: op)
        }
    }

    func test1344() async {
        let disposeBag = await DisposeBag()
        let foo = await Observable<Int>.create({ observer in
            await observer.on(.next(1))
                Thread.sleep(forTimeInterval: 0.1)
            await observer.on(.completed)
                return Disposables.create()
            })
            .flatMap { int -> Observable<[Int]> in
                return await Observable.create { observer -> Disposable in
                    DispatchQueue.global().async {
                        Task {
                            await observer.onNext([int])
                        }
                    }
                    self.sleep(0.1)
                    return Disposables.create()
                }
            }

        await Observable.merge(foo, .just([42]))
            .subscribe()
            .disposed(by: disposeBag)
    }

    func testSeparationBetweenOnAndSubscriptionLocks() {
        func performSharingOperatorsTest(share: @escaping (Observable<Int>) -> Observable<Int>) {
            for _ in 0 ..< 1 {
                let expectation = self.expectation(description: "wait until sequence completes")

                let queue = DispatchQueue(
                            label: "off main thread",
                            attributes: .concurrent
                        )

                queue.async {
                    @Sendable func makeSequence(label: String, period: RxTimeInterval) async -> Observable<Int> {
                        let schedulerQueue = DispatchQueue(
                            label: "Test",
                            attributes: .concurrent
                        )

                        let scheduler: SchedulerType = ConcurrentDispatchQueueScheduler(queue: schedulerQueue, leeway: .milliseconds(0))

                        return await share(Observable<Int>.interval(period, scheduler: scheduler))
                    }

                    Task {
                        _ = await Observable.of(
                            makeSequence(label: "main", period: .milliseconds(200)),
                            makeSequence(label: "nested", period: .milliseconds(300))
                        ).merge()
                            .take(1)
                            .subscribe(
                                onNext: { _ in
                                    Thread.sleep(forTimeInterval: 0.4)
                                },
                                onCompleted: {
                                    expectation.fulfill()
                                }
                            )
                    }
                }
            }

            waitForExpectations(timeout: 2.0) { e in
                XCTAssertNil(e)
            }
        }

        for op in [
            { await $0.share(replay: 0, scope: .whileConnected) },
            { await $0.share(replay: 0, scope: .forever) },
            { await $0.share(replay: 1, scope: .whileConnected) },
            { await $0.share(replay: 1, scope: .forever) },
            { await await $0.share(replay: 2, scope: .whileConnected) },
            { await await $0.share(replay: 2, scope: .forever) },
            ] as [(Observable<Int>) async -> Observable<Int>] {
            performSharingOperatorsTest(share: op)
        }
    }
}
