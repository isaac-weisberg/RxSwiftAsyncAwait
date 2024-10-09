import Foundation

@available(iOS, introduced: 13.0)
public final class ConcurrentTaskScheduler: SchedulerType, ImmediateSchedulerType {
    init() {}

    public var now: RxTime {
        Date()
    }

    public func schedule<StateType>(
        _ state: StateType,
        action: @escaping (StateType) -> any Disposable
    ) -> any Disposable {

        let cancel = SingleAssignmentDisposable()

        Task {
            if cancel.isDisposed {
                return
            }

            cancel.setDisposable(action(state))
        }

        return cancel
    }

    public static let shared = ConcurrentTaskScheduler()

    final class TaskReference {
        var taskReference: Task<Void, Never>?
    }

    public func scheduleRelative<StateType>(
        _ state: StateType,
        dueTime: RxTimeInterval,
        action: @escaping (StateType) -> any Disposable
    ) -> any Disposable {
        let compositeDisposable = CompositeDisposable()

        let taskReference = TaskReference()

        let taskDisposable = Disposables.create {
            taskReference.taskReference?.cancel()
        }

        taskReference.taskReference = Task {
            if !dueTime.isNow {
                let nanoseconds = dueTime.asNanoseconds()

                try? await Task.sleep(nanoseconds: nanoseconds)
            }

            if Task.isCancelled {
                return
            }

            if compositeDisposable.isDisposed {
                return
            }

            let actionDisposable = action(state)

            _ = compositeDisposable.insert(actionDisposable)
            taskDisposable.dispose()
        }

        return compositeDisposable
    }
}

extension RxTimeInterval {
    func asNanoseconds() -> UInt64 {
        switch self {
        case .nanoseconds(let value):
            return UInt64(value)
        case .microseconds(let value):
            return UInt64(value) * 1000
        case .milliseconds(let value):
            return UInt64(value) * 1_000_000
        case .seconds(let value):
            return UInt64(value) * 1_000_000_000
        case .never:
            fatalError()
        @unknown default:
            fatalError()
        }
    }
}
