
protocol Actor: AnyObject {
    func perform<R>(_ work: () -> R) async -> R
}

protocol ActorScheduler {
    func perform<R>(_ work: () -> R) async -> R
}

public struct ActorBasedActorScheduler: ActorScheduler {
    let actor: Actor
    
    func perform<R>(_ work: () -> R) async -> R {
        await actor.perform(work)
    }
}

public final class MainActorScheduler: ActorScheduler {
    public static let instance = MainActorScheduler()
    
    func perform<R>(_ work: () -> R) async -> R {
        await MainActor.run {
            work()
        }
    }
}
