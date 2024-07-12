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
    typealias Action = (State, AnyRecursiveScheduler<State>) async -> Void

    private let lock: RecursiveLock
    
    // state
    private let group: CompositeDisposable

    private var scheduler: SchedulerType
    private var action: Action?
    
    init(scheduler: SchedulerType, action: @escaping Action) async {
        self.lock = await RecursiveLock()
        self.group = await CompositeDisposable()
        self.action = action
        self.scheduler = scheduler
    }

    /**
     Schedules an action to be executed recursively.
    
     - parameter state: State passed to the action to be executed.
     - parameter dueTime: Relative time after which to execute the recursive action.
     */
    func schedule(_ state: State, dueTime: RxTimeInterval) async {
        var scheduleState: ScheduleState = .initial

        let d = await self.scheduler.scheduleRelative(state, dueTime: dueTime) { state -> Disposable in
            // best effort
            if await self.group.isDisposed() {
                return Disposables.create()
            }
            
            let action = await self.lock.performLocked { () -> Action? in
                switch scheduleState {
                case let .added(removeKey):
                    await self.group.remove(for: removeKey)
                case .initial:
                    break
                case .done:
                    break
                }

                scheduleState = .done

                return self.action
            }
            
            if let action = action {
                await action(state, self)
            }
            
            return Disposables.create()
        }
            
        await self.lock.performLocked {
            switch scheduleState {
            case .added:
                rxFatalError("Invalid state")
            case .initial:
                if let removeKey = await self.group.insert(d) {
                    scheduleState = .added(removeKey)
                }
                else {
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
    func schedule(_ state: State) async {
        var scheduleState: ScheduleState = .initial

        let d = await self.scheduler.schedule(state) { state -> Disposable in
            // best effort
            if await self.group.isDisposed() {
                return Disposables.create()
            }
            
            let action = await self.lock.performLocked { () -> Action? in
                switch scheduleState {
                case let .added(removeKey):
                    await self.group.remove(for: removeKey)
                case .initial:
                    break
                case .done:
                    break
                }

                scheduleState = .done
                
                return self.action
            }
           
            if let action = action {
                await action(state, self)
            }
            
            return Disposables.create()
        }
        
        await self.lock.performLocked {
            switch scheduleState {
            case .added:
                rxFatalError("Invalid state")
            case .initial:
                if let removeKey = await self.group.insert(d) {
                    scheduleState = .added(removeKey)
                }
                else {
                    scheduleState = .done
                }
            case .done:
                break
            }
        }
    }
    
    func dispose() async {
        await self.lock.performLocked {
            self.action = nil
        }
        await self.group.dispose()
    }
}

/// Type erased recursive scheduler.
final class RecursiveImmediateScheduler<State> {
    typealias Action = (_ state: State, _ recurse: (State) async -> Void) async -> Void
    
    private var lock: SpinLock
    private let group: CompositeDisposable
    
    private var action: Action?
    private let scheduler: ImmediateSchedulerType
    
    init(action: @escaping Action, scheduler: ImmediateSchedulerType) async {
        self.lock = await SpinLock()
        self.group = await CompositeDisposable()
        self.action = action
        self.scheduler = scheduler
    }
    
    // immediate scheduling
    
    /// Schedules an action to be executed recursively.
    ///
    /// - parameter state: State passed to the action to be executed.
    func schedule(_ state: State) async {
        var scheduleState: ScheduleState = .initial

        let d = await self.scheduler.schedule(state) { state -> Disposable in
            // best effort
            if await self.group.isDisposed() {
                return Disposables.create()
            }
            
            let action = await self.lock.performLocked { () -> Action? in
                switch scheduleState {
                case let .added(removeKey):
                    await self.group.remove(for: removeKey)
                case .initial:
                    break
                case .done:
                    break
                }

                scheduleState = .done

                return self.action
            }
            
            if let action = action {
                await action(state, self.schedule)
            }
            
            return Disposables.create()
        }
        
        await self.lock.performLocked {
            switch scheduleState {
            case .added:
                rxFatalError("Invalid state")
            case .initial:
                if let removeKey = await self.group.insert(d) {
                    scheduleState = .added(removeKey)
                }
                else {
                    scheduleState = .done
                }
            case .done:
                break
            }
        }
    }
    
    func dispose() async {
        await self.lock.performLocked {
            self.action = nil
        }
        await self.group.dispose()
    }
}
