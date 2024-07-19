//
//  ScheduledDisposable.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 6/13/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

private let disposeScheduledDisposable: (C, ScheduledDisposable) async -> Disposable = { c, sd in
    await sd.disposeInner()
    return Disposables.create()
}

/// Represents a disposable resource whose disposal invocation will be scheduled on the specified scheduler.
public final class ScheduledDisposable: Cancelable {
    public let scheduler: ImmediateSchedulerType

    private let disposed: AtomicInt

    // state
    private var disposable: Disposable?

    /// - returns: Was resource disposed.
    public func isDisposed() async -> Bool {
        await isFlagSet(self.disposed, 1)
    }

    /**
     Initializes a new instance of the `ScheduledDisposable` that uses a `scheduler` on which to dispose the `disposable`.

     - parameter scheduler: Scheduler where the disposable resource will be disposed on.
     - parameter disposable: Disposable resource to dispose on the given scheduler.
     */
    public init(scheduler: ImmediateSchedulerType, disposable: Disposable) async {
        self.disposed = await AtomicInt(0)
        self.scheduler = scheduler
        self.disposable = disposable
    }

    /// Disposes the wrapped disposable on the provided scheduler.
    public func dispose() async {
        _ = await self.scheduler.schedule(self, C(), action: disposeScheduledDisposable)
    }

    func disposeInner() async {
        if await fetchOr(self.disposed, 1) == 0 {
            await self.disposable!.dispose()
            self.disposable = nil
        }
    }
}
