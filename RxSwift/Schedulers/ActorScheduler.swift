
public protocol Actor: AnyObject {
    func perform<R>(_ c: C, _ work: (C) -> R) async -> R
}

public protocol ActorScheduler {
    func perform<R>(_ c: C, _ work: @escaping (C) -> R) async -> R
}

public class SerialNonrecursiveActorScheduler: ActorScheduler {
    let lock: ActualNonRecursiveLock
    
    init(lock: ActualNonRecursiveLock) {
        self.lock = lock
    }
    
    public func perform<R>(_ c: C, _ work: @escaping (C) -> R) async -> R {
        await lock.performLocked {
            work(c.call())
        }
    }
}

public class ConcurrentUnsynchronizedActorScheduler: ActorScheduler {
    public func perform<R>(_ c: C, _ work: @escaping (C) -> R) async -> R {
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

public final class MainActorScheduler: ActorScheduler {
    public static let instance = MainActorScheduler()

    public func perform<R>(_ c: C, _ work: (C) -> R) async -> R {
        await MainActor.run {
            work(c.call())
        }
    }
}
