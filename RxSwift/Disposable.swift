//
//  Disposable.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 2/8/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

public protocol UnsynchronizedDisposable {
    func dispose()
}

/// Represents a disposable resource.
public protocol SynchronizedDisposable {
    /// Dispose resource.
    func dispose() async
}

protocol Actor: AnyObject {
    func perform<R>(_ work: () -> R) async -> R
}

extension UnsynchronizedDisposable {
    func sync(on actor: Actor) -> DisposableSynchedOnActor<Self> {
        DisposableSynchedOnActor(actor: actor, unsyncDisposable: self)
    }
}

struct DisposableSynchedOnActor<Disposable: UnsynchronizedDisposable>: SynchronizedDisposable {
    weak var actor: Actor?
    let unsyncDisposable: UnsynchronizedDisposable

    func dispose() async {
        guard let actor else {
            return
        }
        await actor.perform {
            unsyncDisposable.dispose()
        }
    }
}

// struct DisposableSynchedOnNothing: SynchronizedDisposable {
//    let unsyncDisposable: UnsynchronizedDisposable
//
//    func dispose() async {
//        unsyncDisposable.dispose()
//    }
// }
