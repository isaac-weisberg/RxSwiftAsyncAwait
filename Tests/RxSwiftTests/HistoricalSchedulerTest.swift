//
//  HistoricalSchedulerTest.swift
//  Tests
//
//  Created by Krunoslav Zaher on 12/27/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

import RxSwift
import XCTest
import Foundation

class HistoricalSchedulerTest : RxTest {

}

extension HistoricalSchedulerTest {
    func testHistoricalScheduler_initialClock() async {
        let scheduler = await HistoricalScheduler(initialClock: Date(timeIntervalSince1970: 10.0))
        XCTAssertEqual(scheduler.now, Date(timeIntervalSince1970: 10.0))
        XCTAssertEqual(scheduler.clock, Date(timeIntervalSince1970: 10.0))
    }

    func testHistoricalScheduler_start() async {
        let scheduler = await HistoricalScheduler()

        var times: [Date] = []

        _ = await scheduler.scheduleRelative((), dueTime: .seconds(10)) { _ in
            times.append(scheduler.now)
            _ = await scheduler.scheduleRelative((), dueTime: .seconds(20)) { _ in
                times.append(scheduler.now)
                return Disposables.create()
            }
            return await scheduler.schedule(()) { _ in
                times.append(scheduler.now)
                return Disposables.create()
            }
        }

        await scheduler.start()

        XCTAssertEqual(times, [
            Date(timeIntervalSince1970: 10.0),
            Date(timeIntervalSince1970: 10.0),
            Date(timeIntervalSince1970: 30.0)
        ])
    }

    func testHistoricalScheduler_disposeStart() async {
        let scheduler = await HistoricalScheduler()

        var times: [Date] = []

        _ = await scheduler.scheduleRelative((), dueTime: .seconds(10)) { _ in
            times.append(scheduler.now)
            let d = await scheduler.scheduleRelative((), dueTime: .seconds(20)) { _ in
                times.append(scheduler.now)
                return Disposables.create()
            }
            let d2 = await scheduler.schedule(()) { _ in
                times.append(scheduler.now)
                return Disposables.create()
            }

            await d2.dispose()
            await d.dispose()
            return Disposables.create()
        }

        await scheduler.start()

        XCTAssertEqual(times, [
            Date(timeIntervalSince1970: 10.0),
            ])
    }

    func testHistoricalScheduler_advanceToAfter() async {
        let scheduler = await HistoricalScheduler()

        var times: [Date] = []

        _ = await scheduler.scheduleRelative((), dueTime: .seconds(10)) { _ in
            times.append(scheduler.now)
            _ = await scheduler.scheduleRelative((), dueTime: .seconds(20)) { _ in
                times.append(scheduler.now)
                return Disposables.create()
            }
            return await scheduler.schedule(()) { _ in
                times.append(scheduler.now)
                return Disposables.create()
            }
        }

        await scheduler.advanceTo(Date(timeIntervalSince1970: 100.0))

        XCTAssertEqual(times, [
            Date(timeIntervalSince1970: 10.0),
            Date(timeIntervalSince1970: 10.0),
            Date(timeIntervalSince1970: 30.0)
        ])
    }

    func testHistoricalScheduler_advanceToBefore() async {
        let scheduler = await HistoricalScheduler()

        var times: [Date] = []

        _ = await scheduler.scheduleRelative((), dueTime: .seconds(10)) { [weak scheduler] _ in
            times.append(scheduler!.now)
            _ = await scheduler!.scheduleRelative((), dueTime: .seconds(20)) { _ in
                times.append(scheduler!.now)
                return Disposables.create()
            }
            return await scheduler!.schedule(()) { _ in
                times.append(scheduler!.now)
                return Disposables.create()
            }
        }

        await scheduler.advanceTo(Date(timeIntervalSince1970: 10.0))

        XCTAssertEqual(times, [
            Date(timeIntervalSince1970: 10.0),
            Date(timeIntervalSince1970: 10.0),
        ])
    }

    func testHistoricalScheduler_disposeAdvanceTo() async {
        let scheduler = await HistoricalScheduler()

        var times: [Date] = []

        _ = await scheduler.scheduleRelative((), dueTime: .seconds(10)) { [weak scheduler] _ in
            times.append(scheduler!.now)
            let d1 = await scheduler!.scheduleRelative((), dueTime: .seconds(20)) { _ in
                times.append(scheduler!.now)
                return Disposables.create()
            }
            let d2 = await scheduler!.schedule(()) { _ in
                times.append(scheduler!.now)
                return Disposables.create()
            }

            await d1.dispose()
            await d2.dispose()
            return Disposables.create()
        }

        await scheduler.advanceTo(Date(timeIntervalSince1970: 200.0))

        XCTAssertEqual(times, [
            Date(timeIntervalSince1970: 10.0),
        ])
    }

    func testHistoricalScheduler_stop() async {
        let scheduler = await HistoricalScheduler()

        var times: [Date] = []

        _ = await scheduler.scheduleRelative((), dueTime: .seconds(10)) { [weak scheduler] _ in
            times.append(scheduler!.now)
            _ = await scheduler!.scheduleRelative((), dueTime: .seconds(20)) { _ in
                times.append(scheduler!.now)
                return Disposables.create()
            }
            _ = await scheduler!.schedule(()) { _ in
                times.append(scheduler!.now)
                return Disposables.create()
            }

            scheduler!.stop()

            return Disposables.create()
        }

        await scheduler.start()

        XCTAssertEqual(times, [
            Date(timeIntervalSince1970: 10.0),
            ])
    }

    func testHistoricalScheduler_sleep() async {
        let scheduler = await HistoricalScheduler()

        var times: [Date] = []

        _ = await scheduler.scheduleRelative((), dueTime: .seconds(10)) { [weak scheduler] _ in
            times.append(scheduler!.now)

            scheduler!.sleep(100)
            _ = await scheduler!.scheduleRelative((), dueTime: .seconds(20)) { _ in
                times.append(scheduler!.now)
                return Disposables.create()
            }
            _ = await scheduler!.schedule(()) { _ in
                times.append(scheduler!.now)
                return Disposables.create()
            }


            return Disposables.create()
        }

        await scheduler.start()

        XCTAssertEqual(times, [
            Date(timeIntervalSince1970: 10.0),
            Date(timeIntervalSince1970: 110.0),
            Date(timeIntervalSince1970: 130.0),
            ])
    }
}
