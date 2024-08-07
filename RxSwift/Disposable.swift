//
//  Disposable.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 2/8/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

public protocol DisposableType: Sendable {
    
}

public protocol SynchronousDisposable: Sendable, DisposableType {
    @Sendable
    func dispose()
}

/// Represents a disposable resource.
public protocol AsynchronousDisposable: Sendable, DisposableType {
    /// Dispose resource.
    @Sendable
    func dispose() async
}

extension SynchronousDisposable {
    func asAny() -> AnySynchronousDisposable {
        AnySynchronousDisposable(dispose: dispose)
    }
}
extension AsynchronousDisposable {
    func asAny() -> AnyAsynchronousDisposable {
        AnyAsynchronousDisposable(dispose: dispose)
    }
}

public struct AnySynchronousDisposable: Sendable, DisposableType {
    let dispose: @Sendable () -> Void
}

public struct AnyAsynchronousDisposable: Sendable, DisposableType {
    let dispose: @Sendable () async -> Void
}

public enum AnyDisposable: Sendable {
    case sync(SynchronousDisposable)
    case async(AsynchronousDisposable)
}

private struct A: AsynchronousDisposable {
    let disposable: SynchronousDisposable

    func dispose() async {
        disposable.dispose()
    }
}

extension SynchronousDisposable {
    func asAsync() -> AsynchronousDisposable {
        A(disposable: self)
    }

    func sync(on actor: Actor) -> DisposableSynchedOnActor<Self> {
        DisposableSynchedOnActor(actor: actor, unsyncDisposable: self)
    }
}

struct DisposableSynchedOnActor<Disposable: SynchronousDisposable>: AsynchronousDisposable, Sendable {
    weak var actor: Actor?
    let unsyncDisposable: SynchronousDisposable

    func dispose() async {
        guard let actor else {
            return
        }
        await actor.perform(C()) { _ in
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
