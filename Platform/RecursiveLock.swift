//
//  RecursiveLock.swift
//  Platform
//
//  Created by Krunoslav Zaher on 12/18/16.
//  Copyright © 2016 Krunoslav Zaher. All rights reserved.
//

import Foundation

// typealias RecursiveLock = AsyncAwaitLock

#if TRACE_RESOURCES

//    class RecursiveLock: NSRecursiveLock {
//        override init() {
//            _ = await Resources.incrementTotal()
//            super.init()
//        }
//
//        override func lock() {
//            super.lock()
//            _ = R_esources.incrementTotal()
//        }
//
//        override func unlock() {
//            super.unlock()
//            _ = R_esources.decrementTotal()
//        }
//
//        deinit {
//            _ = R_esources.decrementTotal()
//        }
//    }
#else
//    typealias RecursiveLock = NSRecursiveLock
#endif
