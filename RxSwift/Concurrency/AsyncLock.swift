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
final actor AsyncLock<I: InvocableType>: Disposable {
    typealias Action = () -> Void

    private var queue: Queue<I> = Queue(capacity: 0)

    private var isExecuting = false
    private var hasFaulted = false

    init() {}

    private func enqueue(_ action: I) -> I? {
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

    private func dequeue() -> I? {
        if !queue.isEmpty {
            return queue.dequeue()
        } else {
            isExecuting = false
            return nil
        }
    }

    func invoke(_ c: C, _ action: I) async {
        let firstEnqueuedAction = enqueue(action)

        if let firstEnqueuedAction {
            await firstEnqueuedAction.invoke(c.call())
        } else {
            // action is enqueued, it's somebody else's concern now
            return
        }

        while true {
            let nextAction = dequeue()

            if let nextAction {
                await nextAction.invoke(c.call())
            } else {
                return
            }
        }
    }

    func dispose() async {
        queue = Queue(capacity: 0)
        hasFaulted = true
    }
}
