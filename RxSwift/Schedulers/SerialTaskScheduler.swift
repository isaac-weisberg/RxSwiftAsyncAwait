import Foundation

@available(iOS, introduced: 13.0)
public final class SerialTaskScheduler: SchedulerType, ImmediateSchedulerType {
    public init() {}

    let taskLock = TaskLock()

    public var now: RxTime {
        Date()
    }

    public func schedule<StateType>(
        _ state: StateType,
        action: @escaping (StateType) -> any Disposable
    ) -> any Disposable {

        let cancel = SingleAssignmentDisposable()

        taskLock.run {
            if cancel.isDisposed {
                return
            }

            cancel.setDisposable(action(state))
        }

        return cancel
    }

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

            taskLock.run {
                if Task.isCancelled {
                    return
                }

                if compositeDisposable.isDisposed {
                    return
                }

                let actionDisposable = action(state)

                _ = compositeDisposable.insert(actionDisposable)
            }

            taskDisposable.dispose()
        }

        return compositeDisposable
    }
}

@available(iOS, introduced: 13.0)
final class TaskLock {
    let lock = NonRecursiveLock()

    struct State {
        var currentTask: Task<Void, Never>?
    }

    var state = State()

    func run(_ work: @escaping () -> Void) {
        lock.performLocked {
            if let currentTask = state.currentTask {
                state.currentTask = Task {
                    await currentTask.value

                    work()
                }
            } else {
                state.currentTask = Task {
                    work()
                }
            }
        }
    }
}
