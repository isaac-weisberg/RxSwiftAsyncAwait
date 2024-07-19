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
    Disposable,
    Lock,
    SynchronizedDisposeType
{
    typealias Action = () -> Void

    private var _lock: SpinLock

    private var queue: Queue<I> = Queue(capacity: 0)

    private var isExecuting: Bool = false
    private var hasFaulted: Bool = false

    init() async {
        self._lock = await SpinLock()
    }

    func performLocked<R>(_ work: @escaping () async -> R) async -> R {
        await self._lock.performLocked {
            await work()
        }
    }
    
    func performLocked<R>(_ c: C, _ work: @escaping (C) async -> R) async -> R {
        await self._lock.performLocked(c.call()) { c in
            await work(c.call())
        }
    }

    private func enqueue(_ action: I) async -> I? {
        return await self.performLocked {
            if self.hasFaulted {
                return nil
            }

            if self.isExecuting {
                self.queue.enqueue(action)
                return nil
            }

            self.isExecuting = true

            return action
        }
    }

    private func dequeue() async -> I? {
        return await self.performLocked {
            if !self.queue.isEmpty {
                return self.queue.dequeue()
            }
            else {
                self.isExecuting = false
                return nil
            }
        }
    }

    func invoke(_ c: C, _ action: I) async {
        let firstEnqueuedAction = await self.enqueue(action)

        if let firstEnqueuedAction = firstEnqueuedAction {
            await firstEnqueuedAction.invoke(c.call())
        }
        else {
            // action is enqueued, it's somebody else's concern now
            return
        }

        while true {
            let nextAction = await self.dequeue()

            if let nextAction = nextAction {
                await nextAction.invoke(c.call())
            }
            else {
                return
            }
        }
    }

    func dispose() async {
        await self.synchronizedDispose()
    }

    func synchronized_dispose() {
        self.queue = Queue(capacity: 0)
        self.hasFaulted = true
    }
}
