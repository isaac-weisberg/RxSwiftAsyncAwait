////
////  SchedulerType.swift
////  RxSwift
////
////  Created by Krunoslav Zaher on 2/8/15.
////  Copyright © 2015 Krunoslav Zaher. All rights reserved.
////
//
//import Dispatch
import Foundation
//
//// Type that represents time interval in the context of RxSwift.
public typealias RxTimeInterval = TimeInterval

extension RxTimeInterval {
    var nanoseconds: UInt64 {
        UInt64(self * 1e+9)
    }
}
//
///// Type that represents absolute time in the context of RxSwift.
//public typealias RxTime = Date
//
///// Represents an object that schedules units of work.
//public protocol SchedulerType: ImmediateSchedulerType {
//    /// - returns: Current time.
//    var now: RxTime {
//        get
//    }
//
//    /**
//     Schedules an action to be executed.
//
//     - parameter state: State passed to the action to be executed.
//     - parameter dueTime: Relative time after which to execute the action.
//     - parameter action: Action to be executed.
//     - returns: The disposable object used to cancel the scheduled action (best effort).
//     */
//    func scheduleRelative<StateType>(_ state: StateType, _ c: C, dueTime: RxTimeInterval, action: @escaping (C, StateType) async -> Disposable) async -> Disposable
//
//    /**
//     Schedules a periodic piece of work.
//
//     - parameter state: State passed to the action to be executed.
//     - parameter startAfter: Period after which initial work should be run.
//     - parameter period: Period for running the work periodically.
//     - parameter action: Action to be executed.
//     - returns: The disposable object used to cancel the scheduled action (best effort).
//     */
//    func schedulePeriodic<StateType>(_ state: StateType, _ c: C, startAfter: RxTimeInterval, period: RxTimeInterval, action: @escaping (C, StateType) async -> StateType) async -> Disposable
//}
//
//extension SchedulerType {
//    /**
//     Periodic task will be emulated using recursive scheduling.
//
//     - parameter state: Initial state passed to the action upon the first iteration.
//     - parameter startAfter: Period after which initial work should be run.
//     - parameter period: Period for running the work periodically.
//     - returns: The disposable object used to cancel the scheduled recurring action (best effort).
//     */
//    public func schedulePeriodic<StateType>(_ state: StateType, _ c: C, startAfter: RxTimeInterval, period: RxTimeInterval, action: @escaping (C, StateType) async -> StateType) async -> Disposable {
//        let schedule = await SchedulePeriodicRecursive(scheduler: self, startAfter: startAfter, period: period, action: action, state: state)
//
//        return await schedule.start(c.call())
//    }
//
//    func scheduleRecursive<State>(_ state: State, _ c: C, dueTime: RxTimeInterval, action: @escaping (State, C, AnyRecursiveScheduler<State>) async -> Void) async -> Disposable {
//        let scheduler = await AnyRecursiveScheduler(scheduler: self, action: action)
//
//        await scheduler.schedule(state, c.call(), dueTime: dueTime)
//
//        return await Disposables.create(with: scheduler.dispose)
//    }
//}
