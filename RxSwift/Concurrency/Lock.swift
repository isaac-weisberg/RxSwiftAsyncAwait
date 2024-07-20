//
//  Lock.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 3/31/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

protocol Lock {
    func performLocked<R>(_ c: C, _ work: @escaping (C) async -> R) async -> R
    #if VICIOUS_TRACING
    func performLocked<R>(_ work: @escaping () async -> R, _ file: StaticString, _ line: UInt) async -> R
    #else
    func performLocked<R>(_ work: @escaping () async -> R) async -> R
    #endif
}
#if VICIOUS_TRACING
extension Lock {
    func performLocked<R>(_ work: @escaping () async -> R, _ file: StaticString = #file, _ line: UInt = #line) async -> R {
        await performLocked(work, file, line)
    }
}
#endif

// https://lists.swift.org/pipermail/swift-dev/Week-of-Mon-20151214/000321.html
typealias SpinLock = AsyncAwaitLock

extension AsyncAwaitLock: Lock {}
