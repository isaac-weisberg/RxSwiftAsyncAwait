
//public protocol Actor: AnyObject, Sendable {
//    func perform(_ c: C, _ work: (C) -> Void) async -> Void
//}

public protocol ActorScheduler: Sendable {
    func perform(_ c: C, _ work: @Sendable @escaping (C) async -> Void) async -> Void
}

public final class SerialNonrecursiveActorScheduler: ActorScheduler {
    let lock: ActualNonRecursiveLock

    public init(lock: ActualNonRecursiveLock) {
        self.lock = lock
    }

    public func perform(_ c: C, _ work: @Sendable @escaping (C) async -> Void) async -> Void {
        await lock.performLocked(c.call()) { @Sendable c in
            await work(c.call())
        }
    }
}

public final class ConcurrentActorScheduler: ActorScheduler {
    public func perform(_ c: C, _ work: @Sendable @escaping (C) async -> Void) async -> Void {
        _ = Task {
            await work(c.call())
        }
        return ()
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
