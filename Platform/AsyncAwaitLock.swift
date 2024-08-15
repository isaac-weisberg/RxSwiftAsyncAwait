//
//  AsyncAwaitLock.swift
//  RxSwift
//
//  Created by i.weisberg on 12/07/2024.
//  Copyright © 2024 Krunoslav Zaher. All rights reserved.
//

import Foundation

public protocol ActorLock: Actor {
    func perform<R>(_ work: () -> R) -> R
}

extension ActorLock {
    func perform<R>(_ work: () -> R) -> R {
        work()
    }
}

extension ActorLock {
    func locking<Value>(_ value: Value) -> ActorLocked<Value> {
        ActorLocked(value, self)
    }
}

public final class ActorLocked<Value: Sendable>: @unchecked Sendable {
    var value: Value
    let actor: ActorLock
    
    init(_ value: Value, _ actor: ActorLock) {
        self.value = value
        self.actor = actor
    }
    
    func perform<R: Sendable>(_ work: @Sendable (inout Value) -> R) async -> R {
        await actor.perform { @Sendable in
            work(&value)
        }
    }
}

public final actor ActualNonRecursiveLock {
    private var latestTask: Task<Void, Never>?
    private var scheduledTasks = 0

    public init() {
        #if TRACE_RESOURCES
        Task {
            _ = await Resources.incrementTotal()
        }
        #endif
    }

    deinit {
        #if TRACE_RESOURCES
            Task {
                _ = await Resources.decrementTotal()
            }
        #endif
    }

    #if VICIOUS_TRACING
        public func performLocked<R>(
            _ work: @escaping () async -> R,
            _ file: StaticString = #file,
            _ function: StaticString = #function,
            _ line: UInt = #line
        )
            async -> R {
            await performLocked(C(file, function, line)) { _ in
                await work()
            }
        }
    #else
        public func performLocked<R: Sendable>(
            _ work: @Sendable @escaping () async -> R
        )
            async -> R {
            await performLocked(C()) { _ in
                await work()
            }
        }
    #endif

    public func performLocked<R: Sendable>(_ c: C, _ work: @Sendable @escaping (C) async -> R) async -> R {
        scheduledTasks += 1

        let theActualTask: Task<R, Never>
        if let latestTask {
            theActualTask = Task {
                _ = await latestTask.value

                let result = await work(c.call())

                return result
            }
        } else {
            theActualTask = Task {
                let result = await work(c.call())

                return result
            }
        }

        let voidTask = Task<Void, Never> {
            #if TRACE_RESOURCES
                _ = await Resources.incrementTotal()
            #endif
            _ = await theActualTask.value

            #if TRACE_RESOURCES
                _ = await Resources.decrementTotal()
            #endif
        }
        latestTask = voidTask

        let actualTaskValue = await theActualTask.value

        scheduledTasks -= 1

        return actualTaskValue
    }
}

#if VICIOUS_TRACING
//    func twoStaticStringsAreEqual(_ lhs: StaticString, _ rhs: StaticString) -> Bool {
//        lhs.withUTF8Buffer { lhsBuffer in
//            rhs.withUTF8Buffer { rhsBuffer in
//                lhsBuffer.baseAddress == rhsBuffer.baseAddress
//            }
//        }
//    }

    public struct C: Sendable {
        public static func with<R>(
            _ file: StaticString = #file,
            _ function: StaticString = #function,
            _ line: UInt = #line,
            _ work: @escaping (C) async -> R
        )
            async -> R {
            let c = C(file, function, line)
            return await work(c)
        }

        static func withNoLock<R>(
            _ file: StaticString = #file,
            _ function: StaticString = #function,
            _ line: UInt = #line,
            _ work: @escaping (C) async -> R
        )
            async -> R {
            let c = C(file, function, line)
            return await work(c)
        }

        struct Entry {
            let file: StaticString
            let function: StaticString
            let line: UInt

            init(file: StaticString, function: StaticString, line: UInt) {
                self.file = file
                self.function = function
                self.line = line
            }
        }

//        final class AcquiredLock {}

        let entries: [Entry]
//        let acquiredLocks: [AcquiredLock]

        public init(
            _ file: StaticString = #file,
            _ function: StaticString = #function,
            _ line: UInt = #line
        ) {
            let entry = Entry(file: file, function: function, line: line)
            entries = [entry]
//            acquiredLocks = []
        }

        private init(
            _ entries: [Entry] // ,
//            _ acquiredLocks: [AcquiredLock]
        ) {
            self.entries = entries
//            self.acquiredLocks = acquiredLocks
        }

//        func _includesLocksFrom(_ c: C) -> Bool {
//            var parentIdx = 0
//            var innerIdx = 0
//            let concecutiveHitsNeeded = c.acquiredLocks.count
//            var concecutiveHitsGotten = 0
//            while parentIdx < acquiredLocks.count {
//                let me = acquiredLocks[parentIdx]
//                let them = c.acquiredLocks[innerIdx]
//
//                if me === them {
//                    concecutiveHitsGotten += 1
//                    innerIdx += 1
//
//                    if concecutiveHitsGotten >= concecutiveHitsNeeded {
//                        return true
//                    }
//                } else {
//                    concecutiveHitsGotten = 0
//                    innerIdx = 0
//                }
//
//                parentIdx += 1
//            }
//            return false
//        }

        public func call(
            _ file: StaticString = #file,
            _ function: StaticString = #function,
            _ line: UInt = #line
        ) -> C {
            let entry = Entry(file: file, function: function, line: line)

            var entries = entries
            entries.append(entry)

            let c = C(entries)
            return c
        }

//
//        func acquiringLock() -> C {
//            let acquiredLock = AcquiredLock()
//            var acquiredLocks = acquiredLocks
//            acquiredLocks.append(acquiredLock)
//            let c = C(entries, acquiredLocks)
//            return c
//        }

        public func stackAsString() -> String {
            entries.reversed().enumerated().map { index, entry in
                let fileUrl = URL(string: String(describing: entry.file))!
                let lastPath = fileUrl.lastPathComponent

                return "\(index):\u{00A0}\(lastPath):\(entry.line) \(entry.function)"
            }
            .joined(separator: "\n")
        }
    }

#else
    public struct C: Sendable {
        public init() {}

        @inline(__always)
        public func call() -> C {
            self
        }
    }
#endif
