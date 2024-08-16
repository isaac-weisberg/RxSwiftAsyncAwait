//
//  Resources.swift
//  Tests
//
//  Created by Krunoslav Zaher on 1/21/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

import RxSwift

#if TRACE_RESOURCES
    struct Resources {
        static func incrementTotal() async -> Int32 {
            return await RxSwift.Resources.incrementTotal()
        }

        static func decrementTotal() async -> Int32 {
            return await RxSwift.Resources.decrementTotal()
        }

        static var numberOfSerialDispatchQueueObservables: Int32 {
            get async {
                return await RxSwift.Resources.numberOfSerialDispatchQueueObservables()
            }
        }

        static var total: Int32 {
            get async {
                return await RxSwift.Resources.total()
            }
        }
    }
#endif
