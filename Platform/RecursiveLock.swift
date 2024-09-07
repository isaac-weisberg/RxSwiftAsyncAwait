//
//  RecursiveLock.swift
//  Platform
//
//  Created by Krunoslav Zaher on 12/18/16.
//  Copyright © 2016 Krunoslav Zaher. All rights reserved.
//

import Foundation
import os

final class NonRecursiveLock {
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
        lockPointer.deinitialize(count: 1)
        lockPointer.deallocate()
        #if TRACE_RESOURCES
            _ = Resources.decrementTotal()
        #endif
    }
}

final class RecursiveLock {
    typealias Action = () -> Void

    private var _lock = NonRecursiveLock()

    private var queue: Queue<Action> = Queue(capacity: 0)

    private var isExecuting = false

    // lock {
    func lock() {
        _lock.lock()
    }

    func unlock() {
        _lock.unlock()
    }

    func performLockedRecursive<T>(_ action: @escaping () -> T, _ completion: @escaping (T) -> Void) {
        invoke {
            let result = action()

            completion(result)
        }
    }

    func performLockedRecursive(_ action: @escaping () -> Void) {
        invoke(action)
    }

    private func enqueue(_ action: @escaping Action) -> Action? {
        lock(); defer { self.unlock() }
        if isExecuting {
            queue.enqueue(action)
            return nil
        }

        isExecuting = true

        return action
    }

    private func dequeue() -> Action? {
        lock(); defer { self.unlock() }
        if !queue.isEmpty {
            return queue.dequeue()
        } else {
            isExecuting = false
            return nil
        }
    }

    func invoke(_ action: @escaping Action) {
        let firstEnqueuedAction = enqueue(action)

        if let firstEnqueuedAction {
            firstEnqueuedAction()
        } else {
            // action is enqueued, it's somebody else's concern now
            return
        }

        while true {
            let nextAction = dequeue()

            if let nextAction {
                nextAction()
            } else {
                return
            }
        }
    }
}
