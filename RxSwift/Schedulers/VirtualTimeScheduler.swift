////
////  VirtualTimeScheduler.swift
////  RxSwift
////
////  Created by Krunoslav Zaher on 2/14/15.
////  Copyright © 2015 Krunoslav Zaher. All rights reserved.
////
//
//import Foundation
//
///// Base class for virtual time schedulers using a priority queue for scheduled items.
//open class VirtualTimeScheduler<Converter: VirtualTimeConverterType>:
//    SchedulerType
//{
//    public typealias VirtualTime = Converter.VirtualTimeUnit
//    public typealias VirtualTimeInterval = Converter.VirtualTimeIntervalUnit
//
//    private var running: Bool
//
//    private var currentClock: VirtualTime
//
//    private var schedulerQueue: PriorityQueue<VirtualSchedulerItem<VirtualTime>>
//    private var converter: Converter
//
//    private var nextId = 0
//
//    /// - returns: Current time.
//    public var now: RxTime {
//        self.converter.convertFromVirtualTime(self.clock)
//    }
//
//    /// - returns: Scheduler's absolute time clock value.
//    public var clock: VirtualTime {
//        self.currentClock
//    }
//
//    /// Creates a new virtual time scheduler.
//    ///
//    /// - parameter initialClock: Initial value for the clock.
//    public init(initialClock: VirtualTime, converter: Converter) async {
//        self.currentClock = initialClock
//        self.running = false
//        self.converter = converter
//        self.schedulerQueue = PriorityQueue(hasHigherPriority: {
//            switch converter.compareVirtualTime($0.time, $1.time) {
//            case .lessThan:
//                return true
//            case .equal:
//                return $0.id < $1.id
//            case .greaterThan:
//                return false
//            }
//        }, isEqual: { $0 === $1 })
//        #if TRACE_RESOURCES
//            _ = await Resources.incrementTotal()
//        #endif
//    }
//
//    /**
//     Schedules an action to be executed immediately.
//
//     - parameter state: State passed to the action to be executed.
//     - parameter action: Action to be executed.
//     - returns: The disposable object used to cancel the scheduled action (best effort).
//     */
//    public func schedule<StateType>(_ state: StateType, _ c: C, action: @escaping (C, StateType) async -> Disposable) async -> Disposable  {
//        return await self.scheduleRelative(state, c.call(), dueTime: .microseconds(0)) { c, a in
//            await action(c.call(), a)
//        }
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
//    public func scheduleRelative<StateType>(_ state: StateType, _ c: C, dueTime: RxTimeInterval, action: @escaping (C, StateType) async -> Disposable) async -> Disposable {
//        let time = self.now.addingDispatchInterval(dueTime)
//        let absoluteTime = self.converter.convertToVirtualTime(time)
//        let adjustedTime = self.adjustScheduledTime(absoluteTime)
//        return await self.scheduleAbsoluteVirtual(state, c.call(), time: adjustedTime, action: action)
//    }
//
//    /**
//     Schedules an action to be executed after relative time has passed.
//
//     - parameter state: State passed to the action to be executed.
//     - parameter time: Absolute time when to execute the action. If this is less or equal then `now`, `now + 1`  will be used.
//     - parameter action: Action to be executed.
//     - returns: The disposable object used to cancel the scheduled action (best effort).
//     */
//    public func scheduleRelativeVirtual<StateType>(_ state: StateType, _ c: C, dueTime: VirtualTimeInterval, action: @escaping (C, StateType) async -> Disposable) async -> Disposable {
//        let time = self.converter.offsetVirtualTime(self.clock, offset: dueTime)
//        return await self.scheduleAbsoluteVirtual(state, c.call(), time: time, action: action)
//    }
//
//    /**
//     Schedules an action to be executed at absolute virtual time.
//
//     - parameter state: State passed to the action to be executed.
//     - parameter time: Absolute time when to execute the action.
//     - parameter action: Action to be executed.
//     - returns: The disposable object used to cancel the scheduled action (best effort).
//     */
//    public func scheduleAbsoluteVirtual<StateType>(_ state: StateType, _ c: C, time: VirtualTime, action: @escaping (C, StateType) async -> Disposable) async -> Disposable {
//        MainScheduler.ensureExecutingOnScheduler()
//
//        let compositeDisposable = await CompositeDisposable()
//
//        let item = await VirtualSchedulerItem(action: {
//            await action(c.call(), state)
//        }, time: time, id: self.nextId)
//
//        self.nextId += 1
//
//        self.schedulerQueue.enqueue(item)
//
//        _ = await compositeDisposable.insert(item)
//
//        return compositeDisposable
//    }
//
//    /// Adjusts time of scheduling before adding item to schedule queue.
//    open func adjustScheduledTime(_ time: VirtualTime) -> VirtualTime {
//        time
//    }
//
//    /// Starts the virtual time scheduler.
//    public func start() async {
//        MainScheduler.ensureExecutingOnScheduler()
//
//        if self.running {
//            return
//        }
//
//        self.running = true
//        repeat {
//            guard let next = await self.findNext() else {
//                break
//            }
//
//            if self.converter.compareVirtualTime(next.time, self.clock).greaterThan {
//                self.currentClock = next.time
//            }
//
//            await next.invoke()
//            self.schedulerQueue.remove(next)
//        } while self.running
//
//        self.running = false
//    }
//
//    func findNext() async -> VirtualSchedulerItem<VirtualTime>? {
//        while let front = self.schedulerQueue.peek() {
//            if await front.isDisposed() {
//                self.schedulerQueue.remove(front)
//                continue
//            }
//
//            return front
//        }
//
//        return nil
//    }
//
//    /// Advances the scheduler's clock to the specified time, running all work till that point.
//    ///
//    /// - parameter virtualTime: Absolute time to advance the scheduler's clock to.
//    public func advanceTo(_ virtualTime: VirtualTime) async {
//        MainScheduler.ensureExecutingOnScheduler()
//
//        if self.running {
//            fatalError("Scheduler is already running")
//        }
//
//        self.running = true
//        repeat {
//            guard let next = await self.findNext() else {
//                break
//            }
//
//            if self.converter.compareVirtualTime(next.time, virtualTime).greaterThan {
//                break
//            }
//
//            if self.converter.compareVirtualTime(next.time, self.clock).greaterThan {
//                self.currentClock = next.time
//            }
//            await next.invoke()
//            self.schedulerQueue.remove(next)
//        } while self.running
//
//        self.currentClock = virtualTime
//        self.running = false
//    }
//
//    /// Advances the scheduler's clock by the specified relative time.
//    public func sleep(_ virtualInterval: VirtualTimeInterval) {
//        MainScheduler.ensureExecutingOnScheduler()
//
//        let sleepTo = self.converter.offsetVirtualTime(self.clock, offset: virtualInterval)
//        if self.converter.compareVirtualTime(sleepTo, self.clock).lessThen {
//            fatalError("Can't sleep to past.")
//        }
//
//        self.currentClock = sleepTo
//    }
//
//    /// Stops the virtual time scheduler.
//    public func stop() {
//        MainScheduler.ensureExecutingOnScheduler()
//
//        self.running = false
//    }
//
//    #if TRACE_RESOURCES
//        deinit {
//            Task {
//                _ = await Resources.decrementTotal()
//            }
//        }
//    #endif
//}
//
//// MARK: description
//
//extension VirtualTimeScheduler: CustomDebugStringConvertible {
//    /// A textual representation of `self`, suitable for debugging.
//    public var debugDescription: String {
//        self.schedulerQueue.debugDescription
//    }
//}
//
//final class VirtualSchedulerItem<Time>:
//    Disposable
//{
//    typealias Action = () async -> Disposable
//
//    let action: Action
//    let time: Time
//    let id: Int
//
//    func isDisposed() async -> Bool {
//        await self.disposable.isDisposed()
//    }
//
//    let disposable: SingleAssignmentDisposable
//
//    init(action: @escaping Action, time: Time, id: Int) async {
//        self.disposable = await SingleAssignmentDisposable()
//        self.action = action
//        self.time = time
//        self.id = id
//    }
//
//    func invoke() async {
//        await self.disposable.setDisposable(self.action())
//    }
//
//    func dispose() async {
//        await self.disposable.dispose()
//    }
//}
//
//extension VirtualSchedulerItem:
//    CustomDebugStringConvertible
//{
//    var debugDescription: String {
//        "\(self.time)"
//    }
//}
