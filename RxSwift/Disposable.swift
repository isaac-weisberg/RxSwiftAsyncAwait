//
//  Disposable.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 2/8/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

public protocol SynchronousDisposable {
    func dispose()
}

/// Represents a disposable resource.
public protocol AsynchronousDisposable {
    /// Dispose resource.
    func dispose() async
}

extension SynchronousDisposable {
    func sync(on actor: Actor) -> DisposableSynchedOnActor<Self> {
        DisposableSynchedOnActor(actor: actor, unsyncDisposable: self)
    }
}

struct DisposableSynchedOnActor<Disposable: SynchronousDisposable>: AsynchronousDisposable {
    weak var actor: Actor?
    let unsyncDisposable: SynchronousDisposable

    func dispose() async {
        guard let actor else {
            return
        }
        await actor.perform {
            unsyncDisposable.dispose()
        }
    }
}

// struct DisposableSynchedOnNothing: AsynchronousDisposable {
//    let unsyncDisposable: SynchronousDisposable
//
//    func dispose() async {
//        unsyncDisposable.dispose()
//    }
// }
