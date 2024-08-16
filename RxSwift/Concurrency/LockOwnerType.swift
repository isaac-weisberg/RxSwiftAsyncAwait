//
//  LockOwnerType.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 10/25/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

//protocol LockOwnerType: AnyObject, Lock {
//    var lock: RecursiveLock { get }
//}
//
//extension LockOwnerType {
//    func performLocked<R>(_ work: @escaping () async -> R) async -> R {
//        await lock.performLocked {
//            await work()
//        }
//    }
//    
//    func performLocked<R>(_ c: C, _ work: @escaping (C) async -> R) async -> R {
//        await lock.performLocked(c.call()) { c in
//            await work(c.call())
//        }
//    }
//}
