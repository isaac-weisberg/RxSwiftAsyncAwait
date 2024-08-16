//
//  CurrentThreadSchedulerTest.swift
//  Tests
//
//  Created by Krunoslav Zaher on 12/27/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

import RxSwift
import XCTest

class CurrentThreadSchedulerTest : RxTest {

}

extension CurrentThreadSchedulerTest {
    func testCurrentThreadScheduler_scheduleRequired() async {

        XCTAssertTrue(CurrentThreadScheduler.isScheduleRequired)

        var executed = false
        _ = await CurrentThreadScheduler.instance.schedule(()) { _ in
            executed = true
            XCTAssertTrue(!CurrentThreadScheduler.isScheduleRequired)
            return Disposables.create()
        }

        XCTAssertTrue(executed)
    }

    func testCurrentThreadScheduler_basicScenario() async {

        XCTAssertTrue(CurrentThreadScheduler.isScheduleRequired)

        var messages = [Int]()
        _ = await CurrentThreadScheduler.instance.schedule(()) { _ in
            messages.append(1)
            _ = await CurrentThreadScheduler.instance.schedule(()) { _ in
                messages.append(3)
                _ = await CurrentThreadScheduler.instance.schedule(()) {
                    messages.append(5)
                    return Disposables.create()
                }
                messages.append(4)
                return Disposables.create()
            }
            messages.append(2)
            return Disposables.create()
        }

        XCTAssertEqual(messages, [1, 2, 3, 4, 5])
    }

    func testCurrentThreadScheduler_disposing1() async {

        XCTAssertTrue(CurrentThreadScheduler.isScheduleRequired)

        var messages = [Int]()
        _ = await CurrentThreadScheduler.instance.schedule(()) { _ in
            messages.append(1)
            let disposable = await CurrentThreadScheduler.instance.schedule(()) { _ in
                messages.append(3)
                let disposable = await CurrentThreadScheduler.instance.schedule(()) {
                    messages.append(5)
                    return Disposables.create()
                }
                await disposable.dispose()
                messages.append(4)
                return disposable
            }
            messages.append(2)
            return disposable
        }

        XCTAssertEqual(messages, [1, 2, 3, 4])
    }

    func testCurrentThreadScheduler_disposing2() async {

        XCTAssertTrue(CurrentThreadScheduler.isScheduleRequired)

        var messages = [Int]()
        _ = await CurrentThreadScheduler.instance.schedule(()) { _ in
            messages.append(1)
            let disposable = await CurrentThreadScheduler.instance.schedule(()) { _ in
                messages.append(3)
                let disposable = await CurrentThreadScheduler.instance.schedule(()) {
                    messages.append(5)
                    return Disposables.create()
                }
                messages.append(4)
                return disposable
            }
            await disposable.dispose()
            messages.append(2)
            return disposable
        }

        XCTAssertEqual(messages, [1, 2])
    }
}
