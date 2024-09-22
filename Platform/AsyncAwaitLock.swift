//
//  AsyncAwaitLock.swift
//  RxSwift
//
//  Created by i.weisberg on 12/07/2024.
//  Copyright © 2024 Krunoslav Zaher. All rights reserved.
//

import Foundation
import os

public protocol ActorLock: Actor {
    func perform<R>(_ work: () -> R) -> R
}

public extension ActorLock {
    func perform<R>(_ work: () -> R) -> R {
        work()
    }
}

public extension ActorLock {
    func locking<Value>(_ value: Value) -> ActorLocked<Value> {
        ActorLocked(value, self)
    }
}

public final class ActorLocked<Value: Sendable>: @unchecked Sendable {
    public var value: Value
    public let actor: ActorLock

    public init(_ value: Value, _ actor: ActorLock) {
        self.value = value
        self.actor = actor
    }

    public func perform<R: Sendable>(_ work: @Sendable (inout Value) -> R) async -> R {
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
        public func performLocked<R: Sendable>(
            _ work: @Sendable @escaping () async -> R,
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

    public final class C: @unchecked Sendable {
        static let signposter = OSSignposter()
        static let signpostName: StaticString = "C.call"
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

        let entries: [Entry]
        let signpostState: OSSignpostIntervalState

        public convenience init(
            _ file: StaticString = #file,
            _ function: StaticString = #function,
            _ line: UInt = #line
        ) {
            self.init(
                [
                    Entry(file: file, function: function, line: line),
                ]
            )
        }

        private init(
            _ entries: [Entry]
        ) {

            self.entries = entries
            let lastEntry = entries.last!
            signpostState = Self.signposter.beginInterval(
                Self.signpostName,
                "\(lastEntry.file, privacy: .public):\(lastEntry.line, privacy: .public);\(lastEntry.function, privacy: .public)"
            )
        }

        deinit {
            Self.signposter.endInterval(Self.signpostName, self.signpostState)
        }

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
