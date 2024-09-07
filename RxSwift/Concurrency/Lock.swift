//
//  Lock.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 3/31/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

protocol Lock {
    func lock()
    func unlock()
}

protocol PerformLock {
    func performLockedRecursive<T>(_ action: @escaping () -> T, _ completion: @escaping (T) -> Void)

    func performLockedRecursive(_ action: @escaping () -> Void)
}

// https://lists.swift.org/pipermail/swift-dev/Week-of-Mon-20151214/000321.html
typealias SpinLock = RecursiveLock

extension Lock {
    @inline(__always)
    func performLocked<T>(_ action: () -> T) -> T {
        lock(); defer { self.unlock() }
        return action()
    }
}

extension RecursiveLock: Lock {}

extension NonRecursiveLock: Lock {}

extension RecursiveLock: PerformLock {}
