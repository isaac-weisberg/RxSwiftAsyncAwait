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

protocol Actor {
    func perform<R>(_ work: () -> R) async -> R
}

extension Actor {
    func perform<R>(_ work: () -> R) async -> R {
        work()
    }
}

extension UnsynchronizedDisposable {
    func sync(on onActor: Actor) -> SynchronizedDisposable {
        DisposableSynchedOnActor(actor: onActor, unsyncDisposable: self)
    }
}

struct DisposableSynchedOnActor: SynchronizedDisposable {
    let actor: Actor
    let unsyncDisposable: UnsynchronizedDisposable

    func dispose() async {
        await actor.perform {
            unsyncDisposable.dispose()
        }
    }
}

struct DisposableSynchedOnNothing: SynchronizedDisposable {
    let unsyncDisposable: UnsynchronizedDisposable

    func dispose() async {
        unsyncDisposable.dispose()
    }
}
