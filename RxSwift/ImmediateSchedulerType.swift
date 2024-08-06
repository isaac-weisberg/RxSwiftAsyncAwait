//
//  ImmediateSchedulerType.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 5/31/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

/// Represents an object that immediately schedules units of work.
public protocol ImmediateSchedulerType {
    /**
     Schedules an action to be executed immediately.
    
     - parameter state: State passed to the action to be executed.
     - parameter action: Action to be executed.
     - returns: The disposable object used to cancel the scheduled action (best effort).
     */
    func schedule<StateType>(_ state: StateType, _ c: C, action: @escaping (C, StateType) async -> SynchronousDisposable) async -> SynchronousDisposable
}

public extension ImmediateSchedulerType {
    /**
     Schedules an action to be executed recursively.
    
     - parameter state: State passed to the action to be executed.
     - parameter action: Action to execute recursively. The last parameter passed to the action is used to trigger recursive scheduling of the action, passing in recursive invocation state.
     - returns: The disposable object used to cancel the scheduled action (best effort).
     */
    func scheduleRecursive<State>(_ state: State, _ c: C, action: @escaping (_ state: State, _ c: C, _ recurse: (State) async -> Void) async -> Void) async -> SynchronousDisposable {
        let recursiveScheduler = await RecursiveImmediateScheduler(action: action, scheduler: self, c.call())
        
        await recursiveScheduler.schedule(state)
        
        return await Disposables.create(with: recursiveScheduler.dispose)
    }
}
