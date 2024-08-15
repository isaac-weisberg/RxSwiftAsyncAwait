
// public protocol Actor: AnyObject, Sendable {
//    func perform(_ c: C, _ work: (C) -> Void) async -> Void
// }

public protocol AsyncScheduler: Sendable {
    func perform(
        _ cancel: DisposedFlag,
        _ c: C,
        _ work: @Sendable @escaping (C) async -> Void
    ) async -> Void
}

public final class SerialNonrecursiveScheduler: AsyncScheduler {
    let lock: ActualNonRecursiveLock

    public init(lock: ActualNonRecursiveLock) {
        self.lock = lock
    }

    public func perform(
        _ cancel: DisposedFlag,
        _ c: C,
        _ work: @Sendable @escaping (C) async -> Void
    )
        async {
        await lock.performLocked(c.call()) { @Sendable c in
            if await cancel.perform({ $0.disposed }) {
                return
            }
            await work(c.call())
        }
    }
}

public final class ConcurrentAsyncScheduler: AsyncScheduler {
    public func perform(
        _ cancel: DisposedFlag,
        _ c: C,
        _ work: @Sendable @escaping (C) async -> Void
    )
        async {
        _ = Task {
            if await cancel.perform({ $0.disposed }) {
                return
            }
            await work(c.call())
        }
        return ()
    }
}

public final class ImmediateAsyncScheduler: AsyncScheduler {
    static let instance = ImmediateAsyncScheduler()

    public func perform(
        _ cancel: DisposedFlag,
        _ c: C,
        _ work: @Sendable @escaping (C) async -> Void
    )
        async {
        if await cancel.perform({ $0.disposed }) {
            return
        }
        await work(c.call())
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
