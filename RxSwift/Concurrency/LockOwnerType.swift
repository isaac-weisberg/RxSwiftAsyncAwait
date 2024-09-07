//
//  LockOwnerType.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 10/25/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

protocol LockOwnerType: AnyObject, Lock, PerformLock {
    var lock: RecursiveLock { get }
}

extension LockOwnerType {
    func lock() { lock.lock() }
    func unlock() { lock.unlock() }

    func performLockedRecursive<T>(_ action: @escaping () -> T, _ completion: @escaping (T) -> Void) {
        lock.performLockedRecursive(action, completion)
    }

    func performLockedRecursive(_ action: @escaping () -> Void) {
        lock.performLockedRecursive(action)
    }
}
