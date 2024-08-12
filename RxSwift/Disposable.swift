//
//  Disposable.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 2/8/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

//public protocol DisposableType: Sendable {}
//
//public protocol SynchronousDisposable: Sendable, DisposableType {
//    @Sendable
//    func dispose()
//}

/// Represents a disposable resource.
public protocol AsynchronousDisposable: AnyObject, Sendable {//}, DisposableType {
    /// Dispose resource.
    func dispose() async
}

public typealias SynchronousDisposable = AsynchronousDisposable

public typealias Disposable = AsynchronousDisposable

//
//extension SynchronousDisposable {
//    func asAnyDisposable() -> AnySynchronousDisposable {
//        AnySynchronousDisposable(dispose: dispose)
//    }
//}
//
//extension AsynchronousDisposable {
//    func asAnyDisposable() -> AnyAsynchronousDisposable {
//        AnyAsynchronousDisposable(dispose: dispose)
//    }
//}
//
//public struct AnySynchronousDisposable: Sendable, DisposableType {
//    let dispose: @Sendable () -> Void
//}
//
//public struct AnyAsynchronousDisposable: Sendable, DisposableType {
//    let dispose: @Sendable () async -> Void
//}

//extension AnyAsynchronousDisposable {
//    func asAnyDisposable() -> AnyDisposable {
//        .async(self)
//    }
//}
//
//extension AnySynchronousDisposable {
//    func asAnyDisposable() -> AnyDisposable {
//        .sync(self)
//    }
//}
//
//public enum AnyDisposable: Sendable {
//    case sync(AnySynchronousDisposable)
//    case async(AnyAsynchronousDisposable)
//}
//
//private struct A: AsynchronousDisposable {
//    let disposable: SynchronousDisposable
//
//    func dispose() async {
//        disposable.dispose()
//    }
//}
//
//extension SynchronousDisposable {
//    func asAsync() -> AsynchronousDisposable {
//        A(disposable: self)
//    }

//    func sync(on actor: Actor) -> DisposableSynchedOnActor<Self> {
//        DisposableSynchedOnActor(actor: actor, unsyncDisposable: self)
//    }
//}

// struct DisposableSynchedOnActor<Disposable: SynchronousDisposable>: AsynchronousDisposable, Sendable {
//    weak var actor: Actor?
//    let unsyncDisposable: SynchronousDisposable
//
//    func dispose() async {
//        guard let actor else {
//            return
//        }
//        await actor.perform(C()) { _ in
//            unsyncDisposable.dispose()
//        }
//    }
// }

// struct DisposableSynchedOnNothing: AsynchronousDisposable {
//    let unsyncDisposable: SynchronousDisposable
//
//    func dispose() async {
//        unsyncDisposable.dispose()
//    }
// }
