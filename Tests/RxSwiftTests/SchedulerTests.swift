//
//  SchedulerTests.swift
//  Tests
//
//  Created by Krunoslav Zaher on 7/22/16.
//  Copyright © 2016 Krunoslav Zaher. All rights reserved.
//

import RxSwift
import XCTest
#if os(Linux)
import Glibc
import Dispatch
#endif

import Foundation

class ConcurrentDispatchQueueSchedulerTests: RxTest {
    func createScheduler() -> SchedulerType {
        ConcurrentDispatchQueueScheduler(qos: .userInitiated)
    }
}

final class SerialDispatchQueueSchedulerTests: RxTest {
    func createScheduler() -> SchedulerType {
        SerialDispatchQueueScheduler(qos: .userInitiated)
    }
}

class OperationQueueSchedulerTests: RxTest {
}

extension ConcurrentDispatchQueueSchedulerTests {
    func test_scheduleRelative() async {
        let expectScheduling = expectation(description: "wait")
        let start = Date()

        var interval = 0.0

        let scheduler = self.createScheduler()

        _ = await scheduler.scheduleRelative(1, dueTime: .milliseconds(500)) { _ -> Disposable in
            interval = Date().timeIntervalSince(start)
            expectScheduling.fulfill()
            return Disposables.create()
        }

        await waitForExpectations(timeout: 1.0) { error in
            XCTAssertNil(error)
        }

        XCTAssertEqual(interval, 0.5, accuracy: 0.2)
    }

    func test_scheduleRelativeCancel() async {
        let expectScheduling = expectation(description: "wait")
        let start = Date()

        var interval = 0.0

        let scheduler = self.createScheduler()

        let disposable = await scheduler.scheduleRelative(1, dueTime: .milliseconds(100)) { _ -> Disposable in
            interval = Date().timeIntervalSince(start)
            expectScheduling.fulfill()
            return Disposables.create()
        }
        await disposable.dispose()

        DispatchQueue.main.asyncAfter (deadline: .now() + .milliseconds(200)) {
            expectScheduling.fulfill()
        }

        await waitForExpectations(timeout: 0.5) { error in
            XCTAssertNil(error)
        }

        XCTAssertEqual(interval, 0.0, accuracy: 0.0)
    }

    func test_schedulePeriodic() async {
        let expectScheduling = expectation(description: "wait")
        let start = Date()
        let times = Asynchronous([Date]())

        let scheduler = self.createScheduler()

        let disposable = await scheduler.schedulePeriodic(0, startAfter: .milliseconds(200), period: .milliseconds(300)) { state -> Int in
            times.mutate { $0.append(Date()) }
            if state == 1 {
                expectScheduling.fulfill()
            }
            return state + 1
        }

        await waitForExpectations(timeout: 1.0) { error in
            XCTAssertNil(error)
        }

        await disposable.dispose()

        XCTAssertEqual(times.value.count, 2)
        XCTAssertEqual(times.value[0].timeIntervalSince(start), 0.2, accuracy: 0.1)
        XCTAssertEqual(times.value[1].timeIntervalSince(start), 0.5, accuracy: 0.2)
    }

    func test_schedulePeriodicCancel() async {
        let expectScheduling = expectation(description: "wait")
        var times = [Date]()

        let scheduler = self.createScheduler()

        let disposable = await scheduler.schedulePeriodic(0, startAfter: .milliseconds(200), period: .milliseconds(300)) { state -> Int in
            times.append(Date())
            return state + 1
        }

        await disposable.dispose()

        DispatchQueue.main.asyncAfter (deadline: .now() + .milliseconds(300)) {
            expectScheduling.fulfill()
        }

        await waitForExpectations(timeout: 1.0) { error in
            XCTAssertNil(error)
        }

        XCTAssertEqual(times.count, 0)
    }
}

extension OperationQueueSchedulerTests {
    func test_scheduleWithPriority() async {
        let expectScheduling = expectation(description: "wait")

        let operationQueue = OperationQueue()
        operationQueue.maxConcurrentOperationCount = 1

        let highPriority = OperationQueueScheduler(operationQueue: operationQueue, queuePriority: .high)
        let lowPriority = OperationQueueScheduler(operationQueue: operationQueue, queuePriority: .low)

        var times = [String]()

        _ = await highPriority.schedule(Int.self) { _ -> Disposable in
            Thread.sleep(forTimeInterval: 0.4)
            times.append("HIGH")

            return Disposables.create()
            }

        _ = await lowPriority.schedule(Int.self) { _ -> Disposable in
            Thread.sleep(forTimeInterval: 1)
            times.append("LOW")

            expectScheduling.fulfill()

            return Disposables.create()
            }

        _ = await highPriority.schedule(Int.self) { _ -> Disposable in
            Thread.sleep(forTimeInterval: 0.2)
            times.append("HIGH")

            return Disposables.create()
            }

        await waitForExpectations(timeout: 4.0) { error in
            XCTAssertNil(error)
        }

        XCTAssertEqual(["HIGH", "HIGH", "LOW"], times)
    }
}
