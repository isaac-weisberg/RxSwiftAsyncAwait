public protocol AsyncScheduler: Sendable {
    func perform(
        _ c: C,
        _ work: @Sendable @escaping (C) async -> Void
    ) -> DisposeAction
}

public final class SerialNonrecursiveScheduler: AsyncScheduler {
    let lock: ActualNonRecursiveLock

    public init(lock: ActualNonRecursiveLock) {
        self.lock = lock
    }

    public func perform(
        _ c: C,
        _ work: @Sendable @escaping (C) async -> Void
    ) -> DisposeAction {
        let task = Task {
            await lock.performLocked(c.call()) { @Sendable c in
                await work(c.call())
            }
        }

        let theDisposable = DisposeAction {
            task.cancel()
        }
        return theDisposable
    }
}

public final class ConcurrentAsyncScheduler: AsyncScheduler {
    public static let instance = ConcurrentAsyncScheduler()

    public func perform(
        _ c: C,
        _ work: @Sendable @escaping (C) async -> Void
    ) -> DisposeAction {
        let task = Task {
            await work(c.call())
        }

        let disposable = DisposeAction {
            task.cancel()
        }
        return disposable
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
