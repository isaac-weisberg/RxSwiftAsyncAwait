public protocol AsyncScheduler: Sendable {
    func perform(
        _ actorLockedDisposable: ActorLocked<SingleAssignmentSyncDisposable>,
        _ c: C,
        _ work: @Sendable @escaping (C) async -> Void
    )
}

public final class SerialNonrecursiveScheduler: AsyncScheduler {
    let lock: ActualNonRecursiveLock

    public init(lock: ActualNonRecursiveLock) {
        self.lock = lock
    }

    public func perform(
        _ actorLockedDisposable: ActorLocked<SingleAssignmentSyncDisposable>,
        _ c: C,
        _ work: @Sendable @escaping (C) async -> Void
    ) {
        let task = Task {
            await lock.performLocked(c.call()) { @Sendable c in
                if await actorLockedDisposable.perform({ $0.isDisposed }) {
                    return
                }
                await work(c.call())
            }
        }

        let theDisposable = DisposeAction {
            task.cancel()
        }

        actorLockedDisposable.value.setDisposable(theDisposable)?.dispose()
    }
}

public final class ConcurrentAsyncScheduler: AsyncScheduler {
    public static let instance = ConcurrentAsyncScheduler()
    
    public func perform(
        _ actorLockedDisposable: ActorLocked<SingleAssignmentSyncDisposable>,
        _ c: C,
        _ work: @Sendable @escaping (C) async -> Void
    )
        {
        let task = Task {
            if await actorLockedDisposable.perform({ $0.isDisposed }) {
                return
            }
            await work(c.call())
        }
            
            let disposable = DisposeAction {
                task.cancel()
            }
            actorLockedDisposable.value.setDisposable(disposable)?.dispose()
            
    }
}

// public struct ActorBasedActorScheduler: ActorScheduler {
//    let actor: Actor
//
//    public func perform<Void>(_ c: C, _ work: (C) -> Void) async -> Void {
//        await actor.perform(c.call()) { c in
//            work(c.call())
//        }
//    }
//
//    public init(actor: Actor) {
//        self.actor = actor
//    }
// }
//
// public final class MainActorScheduler: ActorScheduler, Sendable {
//    public static let instance = MainActorScheduler()
//
//    public func perform<Void: Sendable>(_ c: C, _ work: @Sendable (C) -> Void) async -> Void {
//        await MainActor.run {
//            work(c.call())
//        }
//    }
// }
