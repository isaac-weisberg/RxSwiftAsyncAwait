//
//  RecursiveLock.swift
//  Platform
//
//  Created by Krunoslav Zaher on 12/18/16.
//  Copyright © 2016 Krunoslav Zaher. All rights reserved.
//

import Foundation
import os

final class RecursiveLock {
    let lockPointer: UnsafeMutablePointer<os_unfair_lock_s>

    init() {
        lockPointer = UnsafeMutablePointer<os_unfair_lock_s>.allocate(capacity: 1)

        lockPointer.initialize(to: os_unfair_lock_s())

        #if TRACE_RESOURCES
            _ = Resources.incrementTotal()
        #endif
    }

    func lock() {
        #if TRACE_RESOURCES
            _ = Resources.incrementTotal()
        #endif
        os_unfair_lock_lock(lockPointer)
    }

    func unlock() {
        #if TRACE_RESOURCES
            _ = Resources.decrementTotal()
        #endif
        os_unfair_lock_unlock(lockPointer)
    }

    deinit {
        lockPointer.deallocate()
        #if TRACE_RESOURCES
            _ = Resources.decrementTotal()
        #endif
    }
}
