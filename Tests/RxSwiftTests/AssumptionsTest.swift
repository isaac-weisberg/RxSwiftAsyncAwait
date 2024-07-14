//
//  AssumptionsTest.swift
//  Tests
//
//  Created by Krunoslav Zaher on 2/14/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

import XCTest
import RxSwift
import Foundation

final class AssumptionsTest : RxTest {
    
    func testResourceLeaksDetectionIsTurnedOn() async {
#if TRACE_RESOURCES
        let startResourceCount = await Resources.total
    
        var observable: Observable<Int>! = await Observable.just(1)

        XCTAssertTrue(observable != nil)
        await assertEqual(await Resources.total, (startResourceCount + 1) as Int32)
        
        observable = nil

        await assertEqual(await Resources.total, startResourceCount)
#elseif RELEASE

#else
        XCTAssert(false, "Can't run unit tests in without tracing")
#endif
    }
}
