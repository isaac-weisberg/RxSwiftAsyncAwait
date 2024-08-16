//
//  Observable+RepeatTests.swift
//  Tests
//
//  Created by Krunoslav Zaher on 4/29/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

import XCTest
import RxSwift
import RxTest

class ObservableRepeatTest : RxTest {
}

extension ObservableRepeatTest {
    func testRepeat_Element() async {
        let scheduler = await TestScheduler(initialClock: 0)

        let res = await scheduler.start(disposed: 207) {
            await Observable.repeatElement(42, scheduler: scheduler)
        }

        XCTAssertEqual(res.events, [
            .next(201, 42),
            .next(202, 42),
            .next(203, 42),
            .next(204, 42),
            .next(205, 42),
            .next(206, 42)
            ])
    }
}
