//
//  RecursiveScheduler.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 6/7/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

private enum ScheduleState {
    case initial
    case added(CompositeDisposable.DisposeKey)
    case done
}

/// Type erased recursive scheduler.
final class AnyRecursiveScheduler<State> {
    typealias Action = (State, C, AnyRecursiveScheduler<State>) async -> Void

    private let lock: RecursiveLock

    // state
    private let group: CompositeDisposable

    private var scheduler: SchedulerType
    private var action: Action?

    init(scheduler: SchedulerType, action: @escaping Action) async {
        lock = await RecursiveLock()
        group = await CompositeDisposable()
        self.action = action
        self.scheduler = scheduler
    }

    /**
     Schedules an action to be executed recursively.

     - parameter state: State passed to the action to be executed.
     - parameter dueTime: Relative time after which to execute the recursive action.
     */
    func schedule(_ state: State, _ c: C, dueTime: RxTimeInterval) async {
        var scheduleState: ScheduleState = .initial

        let d = await scheduler.scheduleRelative(state, c.call(), dueTime: dueTime) { _, state -> Disposable in
            // best effort
            if await self.group.isDisposed() {
                return Disposables.create()
            }

            let action = await self.lock.performLocked(c.call()) { _ -> Action? in
                switch scheduleState {
                case .added(let removeKey):
                    await self.group.remove(for: removeKey)
                case .initial:
                    break
                case .done:
                    break
                }

                scheduleState = .done

                return self.action
            }

            if let action {
                await action(state, c.call(), self)
            }

            return Disposables.create()
        }

        await lock.performLocked(c.call()) { _ in
            switch scheduleState {
            case .added:
                rxFatalError("Invalid state")
            case .initial:
                if let removeKey = await self.group.insert(d) {
                    scheduleState = .added(removeKey)
                } else {
                    scheduleState = .done
                }
            case .done:
                break
            }
        }
    }

    /// Schedules an action to be executed recursively.
    ///
    /// - parameter state: State passed to the action to be executed.
    func schedule(_ state: State, _ c: C) async {
        var scheduleState: ScheduleState = .initial

        let d = await scheduler.schedule(state, c.call()) { c, state -> Disposable in
            // best effort
            if await self.group.isDisposed() {
                return Disposables.create()
            }

            let action = await self.lock.performLocked(c.call()) { _ -> Action? in
                switch scheduleState {
                case .added(let removeKey):
                    await self.group.remove(for: removeKey)
                case .initial:
                    break
                case .done:
                    break
                }

                scheduleState = .done

                return self.action
            }

            if let action {
                await action(state, c.call(), self)
            }

            return Disposables.create()
        }

        await lock.performLocked(c.call()) { _ in
            switch scheduleState {
            case .added:
                rxFatalError("Invalid state")
            case .initial:
                if let removeKey = await self.group.insert(d) {
                    scheduleState = .added(removeKey)
                } else {
                    scheduleState = .done
                }
            case .done:
                break
            }
        }
    }

    func dispose() async {
        await lock.performLocked(C()) { _ in
            self.action = nil
        }
        await group.dispose()
    }
}

/// Type erased recursive scheduler.
final class RecursiveImmediateScheduler<State> {
    typealias Action = (_ state: State, _ c: C, _ recurse: (State) async -> Void) async -> Void

    private var lock: SpinLock
    private let group: CompositeDisposable

    private var action: Action?
    private let scheduler: ImmediateSchedulerType
    private let c: C

    init(action: @escaping Action, scheduler: ImmediateSchedulerType, _ c: C) async {
        self.c = c
        lock = await SpinLock()
        group = await CompositeDisposable()
        self.action = action
        self.scheduler = scheduler
    }

    // immediate scheduling

    /// Schedules an action to be executed recursively.
    ///
    /// - parameter state: State passed to the action to be executed.
    func schedule(_ state: State) async {
        var scheduleState: ScheduleState = .initial

        let d = await scheduler.schedule(state, c.call()) { c, state -> Disposable in
            // best effort
            if await self.group.isDisposed() {
                return Disposables.create()
            }

            let action = await self.lock.performLocked(c.call()) { _ -> Action? in
                switch scheduleState {
                case .added(let removeKey):
                    await self.group.remove(for: removeKey)
                case .initial:
                    break
                case .done:
                    break
                }

                scheduleState = .done

                return self.action
            }

            if let action {
                await action(state, c.call(), self.schedule)
            }

            return Disposables.create()
        }

        await lock.performLocked(c.call()) { _ in
            switch scheduleState {
            case .added:
                rxFatalError("Invalid state")
            case .initial:
                if let removeKey = await self.group.insert(d) {
                    scheduleState = .added(removeKey)
                } else {
                    scheduleState = .done
                }
            case .done:
                break
            }
        }
    }

    func dispose() async {
        await lock.performLocked(c.call()) { _ in
            self.action = nil
        }
        await group.dispose()
    }
}
