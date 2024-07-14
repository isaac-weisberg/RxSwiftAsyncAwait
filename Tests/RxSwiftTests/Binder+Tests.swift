//
//  Binder+Tests.swift
//  Tests
//
//  Created by Krunoslav Zaher on 12/17/16.
//  Copyright © 2016 Krunoslav Zaher. All rights reserved.
//

import XCTest
import RxSwift

class BinderTests: RxTest {
}

extension BinderTests {
    func testBindingOnNonMainQueueDispatchesToMainQueue() async {
        let waitForElement = self.expectation(description: "wait until element arrives")
        let target = NSObject()
        let bindingObserver = await Binder(target) { (_, element: Int) in
            MainScheduler.ensureRunningOnMainThread()
            waitForElement.fulfill()
        }

        DispatchQueue.global(qos: .default).async {
            Task {
                await bindingObserver.on(.next(1))
            }
        }

        await self.waitForExpectations(timeout: 1.0) { (e) in
            XCTAssertNil(e)
        }
    }

    func testBindingOnMainQueueDispatchesToNonMainQueue() async {
        let waitForElement = self.expectation(description: "wait until element arrives")
        let target = NSObject()
        let bindingObserver = await Binder(target, scheduler: ConcurrentDispatchQueueScheduler(qos: .default)) { (_, element: Int) in
            XCTAssert(!DispatchQueue.isMain)
            waitForElement.fulfill()
        }

        await bindingObserver.on(.next(1))

        await self.waitForExpectations(timeout: 1.0) { (e) in
            XCTAssertNil(e)
        }
    }
}
