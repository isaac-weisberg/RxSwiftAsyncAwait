////
////  DispatchQueueConfiguration.swift
////  RxSwift
////
////  Created by Krunoslav Zaher on 7/23/16.
////  Copyright © 2016 Krunoslav Zaher. All rights reserved.
////
//
//import Dispatch
//import Foundation
//
//struct DispatchQueueConfiguration {
//    let queue: DispatchQueue
//    let leeway: DispatchTimeInterval
//}
//
//extension DispatchQueueConfiguration {
//    func schedule<StateType>(_ state: StateType, _ c: C, action: @escaping (C, StateType) async -> Disposable) async -> Disposable {
//        let cancel = await SingleAssignmentDisposable()
//
//        self.queue.async {
//            Task {
//                if await cancel.isDisposed() {
//                    return
//                }
//
//                await cancel.setDisposable(action(c.call(), state))
//            }
//        }
//
//        return cancel
//    }
//
//    func scheduleRelative<StateType>(_ state: StateType, _ c: C, dueTime: RxTimeInterval, action: @escaping (C, StateType) async -> Disposable) async -> Disposable {
//        let deadline = DispatchTime.now() + dueTime
//
//        let compositeDisposable = await CompositeDisposable()
//
//        let timer = DispatchSource.makeTimerSource(queue: self.queue)
//        timer.schedule(deadline: deadline, leeway: self.leeway)
//
//        // TODO:
//        // This looks horrible, and yes, it is.
//        // It looks like Apple has made a conceptual change here, and I'm unsure why.
//        // Need more info on this.
//        // It looks like just setting timer to fire and not holding a reference to it
//        // until deadline causes timer cancellation.
//        var timerReference: DispatchSourceTimer? = timer
//        let cancelTimer = await Disposables.create {
//            timerReference?.cancel()
//            timerReference = nil
//        }
//
//        timer.setEventHandler(handler: {
//            Task {
//                if await compositeDisposable.isDisposed() {
//                    return
//                }
//                _ = await compositeDisposable.insert(action(c.call(), state))
//                await cancelTimer.dispose()
//            }
//        })
//        timer.resume()
//
//        _ = await compositeDisposable.insert(cancelTimer)
//
//        return compositeDisposable
//    }
//
//    func schedulePeriodic<StateType>(_ state: StateType, _ c: C, startAfter: RxTimeInterval, period: RxTimeInterval, action: @escaping (C, StateType) -> StateType) async -> Disposable {
//        let initial = DispatchTime.now() + startAfter
//
//        var timerState = state
//
//        let timer = DispatchSource.makeTimerSource(queue: self.queue)
//        timer.schedule(deadline: initial, repeating: period, leeway: self.leeway)
//
//        // TODO:
//        // This looks horrible, and yes, it is.
//        // It looks like Apple has made a conceptual change here, and I'm unsure why.
//        // Need more info on this.
//        // It looks like just setting timer to fire and not holding a reference to it
//        // until deadline causes timer cancellation.
//        var timerReference: DispatchSourceTimer? = timer
//        let cancelTimer = await Disposables.create {
//            timerReference?.cancel()
//            timerReference = nil
//        }
//
//        timer.setEventHandler(handler: {
//            Task {
//                if await cancelTimer.isDisposed() {
//                    return
//                }
//                fatalError("sorry")
////                timerState = action(timerState)
//            }
//        })
//        timer.resume()
//
//        return cancelTimer
//    }
//}
