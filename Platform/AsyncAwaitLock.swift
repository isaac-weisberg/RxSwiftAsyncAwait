//
//  AsyncAwaitLock.swift
//  RxSwift
//
//  Created by i.weisberg on 12/07/2024.
//  Copyright © 2024 Krunoslav Zaher. All rights reserved.
//

import Foundation

public final actor AsyncAwaitLock {
    private var currentOwnerThread: UnsafeMutableRawPointer?
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

    @inline(__always)
    private func currentThreadPointer() -> UnsafeMutableRawPointer {
        Unmanaged.passUnretained(Thread.current).toOpaque()
    }

    public func performLocked<R>(_ c: C, _ work: @escaping (C) async -> R) async -> R {
        return await performLocked {
            await work(c.call())
        }
    }

    public func performLocked<R>(_ work: @escaping () async -> R) async -> R {
        if shouldStopOnAcquire {
            _ = 42;
        }

        if let currentOwnerThread {
            let currentThreadPointer = currentThreadPointer()

            if shouldStopOnAcquire {
                print("ASDF", currentOwnerThread, currentThreadPointer)
            }
            if currentOwnerThread == currentThreadPointer {
                recursiveAcqisitions += 1

                #if TRACE_RESOURCES
                    _ = await Resources.incrementTotal()
                #endif
                let result = await work()

                #if TRACE_RESOURCES
                    _ = await Resources.decrementTotal()
                #endif

                recursiveAcqisitions -= 1

                return result
            }
        }

        scheduledTasks += 1

        let theActualTask: Task<R, Never>
        if let latestTask {
            theActualTask = Task {
                _ = await latestTask.value

                self.currentOwnerThread = self.currentThreadPointer()

                if shouldStopOnAcquire {
                    print("ASDF will work")
                }

                let result = await work()

                if shouldStopOnAcquire {
                    print("ASDF finished work")
                }

                self.currentOwnerThread = nil

                if recursiveAcqisitions > 0 {
                    #if DEBUG
                        assertionFailure("How the fuck did you do it?")
                    #endif
                }

                return result
            }
        } else {
            theActualTask = Task {
                self.currentOwnerThread = self.currentThreadPointer()

                if shouldStopOnAcquire {
                    print("ASDF will work")
                }
                let result = await work()
                if shouldStopOnAcquire {
                    print("ASDF finished work")
                }

                self.currentOwnerThread = nil

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

public struct C {
    struct Entry: Equatable {
        static func == (lhs: Entry, rhs: Entry) -> Bool {
            lhs.line == rhs.line && lhs.file.withUTF8Buffer { lhsBuffer in
                rhs.file.withUTF8Buffer { rhsBuffer in
                    lhsBuffer.baseAddress == rhsBuffer.baseAddress
                }
            }
        }

        let file: StaticString
        let line: UInt

    }

    let entries: [Entry]

    public init(_ file: StaticString = #file, line: UInt = #line) {
        let entry = Entry(file: file, line: line)
        entries = [entry]
    }
    
    private init(_ entries: [Entry]) {
        self.entries = entries
    }

    public func call(
        _ file: StaticString = #file,
        _ line: UInt = #line
    ) -> C {
        let entry = Entry(file: file, line: line)
        
        var entries = self.entries
        entries.append(entry)
        let stack = C(entries)
        return stack
    }
}
