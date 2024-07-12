//
//  MainScheduler.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 2/8/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

import Dispatch
#if !os(Linux)
    import Foundation
#endif

/**
 Abstracts work that needs to be performed on `DispatchQueue.main`. In case `schedule` methods are called from `DispatchQueue.main`, it will perform action immediately without scheduling.

 This scheduler is usually used to perform UI work.

 Main scheduler is a specialization of `SerialDispatchQueueScheduler`.

 This scheduler is optimized for `observeOn` operator. To ensure observable sequence is subscribed on main thread using `subscribeOn`
 operator please use `ConcurrentMainScheduler` because it is more optimized for that purpose.
 */
public final class MainScheduler: SerialDispatchQueueScheduler {
    private let mainQueue: DispatchQueue

    let numberEnqueued: AtomicInt

    /// Initializes new instance of `MainScheduler`.
    public init() async {
        self.numberEnqueued = await AtomicInt(0)
        self.mainQueue = DispatchQueue.main
        super.init(serialQueue: self.mainQueue)
    }

    static func initialize() async {
        self.instance = await MainScheduler()
        self.asyncInstance = SerialDispatchQueueScheduler(serialQueue: DispatchQueue.main)
    }

    /// Singleton instance of `MainScheduler`
    public static var instance: MainScheduler!

    /// Singleton instance of `MainScheduler` that always schedules work asynchronously
    /// and doesn't perform optimizations for calls scheduled from main queue.
    public static var asyncInstance: SerialDispatchQueueScheduler!

    /// In case this method is called on a background thread it will throw an exception.
    public static func ensureExecutingOnScheduler(errorMessage: String? = nil) {
        if !DispatchQueue.isMain {
            rxFatalError(errorMessage ?? "Executing on background thread. Please use `MainScheduler.instance.schedule` to schedule work on main thread.")
        }
    }

    /// In case this method is running on a background thread it will throw an exception.
    public static func ensureRunningOnMainThread(errorMessage: String? = nil) {
        #if !os(Linux) // isMainThread is not implemented in Linux Foundation
            guard Thread.isMainThread else {
                rxFatalError(errorMessage ?? "Running on background thread.")
            }
        #endif
    }

    override func scheduleInternal<StateType>(_ state: StateType, action: @escaping (StateType) async -> Disposable) async -> Disposable {
        let previousNumberEnqueued = await increment(self.numberEnqueued)

        if DispatchQueue.isMain && previousNumberEnqueued == 0 {
            let disposable = await action(state)
            await decrement(self.numberEnqueued)
            return disposable
        }

        let cancel = await SingleAssignmentDisposable()

        self.mainQueue.async {
            Task { @MainActor in
                if await !cancel.isDisposed() {
                    await cancel.setDisposable(action(state))
                }

                await decrement(self.numberEnqueued)
            }
        }

        return cancel
    }
}
