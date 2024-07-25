//
//  AsyncLock.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 3/21/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

/**
 In case nobody holds this lock, the work will be queued and executed immediately
 on thread that is requesting lock.

 In case there is somebody currently holding that lock, action will be enqueued.
 When owned of the lock finishes with it's processing, it will also execute
 and pending work.

 That means that enqueued work could possibly be executed later on a different thread.
 */
final class AsyncLock<I: InvocableType>:
    SyncDisposable {
    typealias Element = I

    typealias Action = () -> Void

    private var queue: Queue<I> = Queue(capacity: 0)

    private var isExecuting = false
    private var hasFaulted = false

    init() {}

    fileprivate func enqueue(_ action: I) -> I? {
        if hasFaulted {
            return nil
        }

        if isExecuting {
            queue.enqueue(action)
            return nil
        }

        isExecuting = true

        return action
    }

    fileprivate func dequeue() -> I? {
        if !queue.isEmpty {
            return queue.dequeue()
        } else {
            isExecuting = false
            return nil
        }
    }

    func schedule(_ action: I) -> AsyncLockIterator<I> {
        AsyncLockIterator(self, action)
    }

    func dispose() {
        queue = Queue(capacity: 0)
        hasFaulted = true
    }
}

struct AsyncLockIterator<I: InvocableType>: IteratorProtocol, Sequence {
    typealias Element = I

    let source: AsyncLock<I>
    let action: I

    init(_ source: AsyncLock<I>, _ action: I) {
        self.source = source
        self.action = action
    }

    var firstIteration = true

    mutating func next() -> Element? {
        if firstIteration {
            firstIteration = false
            let firstEnqueuedAction = source.enqueue(action)

            if let firstEnqueuedAction {
                return firstEnqueuedAction
            } else {
                // action is enqueued, it's somebody else's concern now
                return nil
            }
        } else {
            let nextAction = source.dequeue()

            if let nextAction {
                return nextAction
            } else {
                return nil
            }
        }
    }
}
