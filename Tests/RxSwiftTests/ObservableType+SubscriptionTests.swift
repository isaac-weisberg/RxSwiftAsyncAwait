//
//  ObservableType+SubscriptionTests.swift
//  Tests
//
//  Created by Krunoslav Zaher on 10/15/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

import XCTest
import RxSwift
import RxTest

class ObservableSubscriptionTest : RxTest {

}

extension ObservableSubscriptionTest {
    func testDefaultErrorHandler() async {
        var loggedErrors = [TestError]()

        _ = await Observable<Int>.error(testError).subscribe()
        XCTAssertEqual(loggedErrors, [])

        let originalErrorHandler = await Hooks.getDefaultErrorHandler()

        await Hooks.setDefaultErrorHandler { _, error in
            loggedErrors.append(error as! TestError)
        }

        _ = await Observable<Int>.error(testError).subscribe()
        XCTAssertEqual(loggedErrors, [testError])

        await Hooks.setDefaultErrorHandler(originalErrorHandler)

        _ = await Observable<Int>.error(testError).subscribe()
        XCTAssertEqual(loggedErrors, [testError])
    }
    
    func testCustomCaptureSubscriptionCallstack() async {
        var resultCallstack = [String]()
        
        await Hooks.setDefaultErrorHandler { callstack, _ in
            resultCallstack = callstack
        }
        _ = await Observable<Int>.error(testError).subscribe()
        XCTAssertEqual(resultCallstack, [])
        
        await Hooks.setCustomCaptureSubscriptionCallstack {
            return ["frame1"]
        }
        _ = await Observable<Int>.error(testError).subscribe()
        XCTAssertEqual(resultCallstack, [])
        
        Hooks.recordCallStackOnError = true
        _ = await Observable<Int>.error(testError).subscribe()
        XCTAssertEqual(resultCallstack, ["frame1"])
        
        await Hooks.setCustomCaptureSubscriptionCallstack {
            return ["frame1", "frame2"]
        }
        _ = await Observable<Int>.error(testError).subscribe()
        XCTAssertEqual(resultCallstack, ["frame1", "frame2"])
    }
}

