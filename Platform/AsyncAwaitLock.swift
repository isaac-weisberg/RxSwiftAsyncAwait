//
//  AsyncAwaitLock.swift
//  RxSwift
//
//  Created by i.weisberg on 12/07/2024.
//  Copyright © 2024 Krunoslav Zaher. All rights reserved.
//

import Foundation

public final actor AsyncAwaitLock {
    final class Executor: SerialExecutor {
        func asUnownedSerialExecutor() -> UnownedSerialExecutor {
            UnownedSerialExecutor(ordinary: self)
        }

        var runningThread: Thread?
        var latestTask: Task<Void, Never>?
        func enqueue(_ job: UnownedJob) {
            let executor = asUnownedSerialExecutor()
            if Thread.current == runningThread {
                job.runSynchronously(on: executor)
            } else {
                let latestTask = self.latestTask
                let newTask = Task {
                    await latestTask?.value
                    
                    runningThread = Thread.current
                    job.runSynchronously(on: executor)
                    runningThread = nil
                }
                self.latestTask = latestTask
            }
        }
    }

    public nonisolated var unownedExecutor: UnownedSerialExecutor {
        executor.asUnownedSerialExecutor()
    }

    private let executor = Executor()
    private var latestTask: Task<Void, Never>?
    private var scheduledTasks = 0
    private var recursiveAcqisitions = 0

    public init() async {
        #if TRACE_RESOURCES
            _ = await Resources.incrementTotal()
        #endif
    }

    deinit {
        #if TRACE_RESOURCES
            Task {
                _ = await Resources.decrementTotal()
            }
        #endif
    }

    var shouldStopOnAcquire = false
    func setShouldStopOnAcquire(_ bool: Bool) {
        shouldStopOnAcquire = bool
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
        public func performLocked<R>(
            _ work: @escaping () async -> R,
            _ file: StaticString = #file,
            line: UInt = #line
        )
            async -> R {
            await performLocked(C()) { _ in
                await work()
            }
        }
    #endif

    public func performLocked<R>(_ c: C, _ work: @escaping (C) async -> R) async -> R {
        if shouldStopOnAcquire {
            _ = 42;
        }

        scheduledTasks += 1

        let theActualTask: Task<R, Never>
        if let latestTask {
            theActualTask = Task {
                _ = await latestTask.value

                let result = await work(c.call())

                if recursiveAcqisitions > 0 {
                    #if DEBUG
                        assertionFailure("How the fuck did you do it?")
                    #endif
                }

                return result
            }
        } else {
            theActualTask = Task {

                let result = await work(c.call())

                if recursiveAcqisitions > 0 {
                    #if DEBUG
                        assertionFailure("How the fuck did you do it?")
                    #endif
                }
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

    public func performLockedThrowing<R>(_ work: @escaping () async throws -> R) async throws -> R {
        let theActualTask: Task<R, Error> = Task { [self] in
            if let latestTask {
                _ = await latestTask.value
            }

            let result = try await work()

            return result
        }

        let voidTask = Task<Void, Never> {
            #if TRACE_RESOURCES
                _ = await Resources.incrementTotal()
            #endif
            _ = try? await theActualTask.value

            #if TRACE_RESOURCES
                _ = await Resources.decrementTotal()
            #endif
        }
        latestTask = voidTask

        return try await theActualTask.value
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

    public struct C {
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

        public init(
            _ file: StaticString = #file,
            _ function: StaticString = #function,
            _ line: UInt = #line
        ) {
            let entry = Entry(file: file, function: function, line: line)
            entries = [entry]
        }

        private init(
            _ entries: [Entry]
        ) {
            self.entries = entries
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
    public struct C {
        public init() {}

        @inline(__always)
        public func call() -> C {
            self
        }
    }
#endif
