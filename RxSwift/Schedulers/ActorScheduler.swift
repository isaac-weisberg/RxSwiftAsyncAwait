
public protocol Actor: AnyObject, Sendable {
    func perform<R>(_ c: C, _ work: (C) -> R) async -> R
}

public protocol ActorScheduler: Sendable {
    func perform<R: Sendable>(_ c: C, _ work: @Sendable @escaping (C) -> R) async -> R
}

public final class SerialNonrecursiveActorScheduler: ActorScheduler {
    let lock: ActualNonRecursiveLock
    
    init(lock: ActualNonRecursiveLock) {
        self.lock = lock
    }
    
    public func perform<R: Sendable>(_ c: C, _ work: @Sendable @escaping (C) -> R) async -> R {
        await lock.performLocked { @Sendable in
            work(c.call())
        }
    }
}

public final class ConcurrentSynchronousActorScheduler: ActorScheduler {
    public func perform<R: Sendable>(_ c: C, _ work: @Sendable @escaping (C) -> R) async -> R {
        await Task {
            work(c.call())
        }.value
    }
}

public struct ActorBasedActorScheduler: ActorScheduler {
    let actor: Actor

    public func perform<R>(_ c: C, _ work: (C) -> R) async -> R {
        await actor.perform(c.call()) { c in
            work(c.call())
        }
    }
    
    public init(actor: Actor) {
        self.actor = actor
    }
}

public final class MainActorScheduler: ActorScheduler, Sendable {
    public static let instance = MainActorScheduler()

    public func perform<R: Sendable>(_ c: C, _ work: @Sendable (C) -> R) async -> R {
        await MainActor.run {
            work(c.call())
        }
    }
}
