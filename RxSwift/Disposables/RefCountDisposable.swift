//
//  RefCountDisposable.swift
//  RxSwift
//
//  Created by Junior B. on 10/29/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

/// Represents a disposable resource that only disposes its underlying disposable resource when all dependent disposable objects have been disposed.
public final class RefCountDisposable: DisposeBase, Cancelable {
    private let lock: SpinLock
    private var disposable = nil as Disposable?
    private var primaryDisposed = false
    private var count = 0

    /// - returns: Was resource disposed.
    public func isDisposed() async -> Bool {
        await self.lock.performLocked { self.disposable == nil }
    }

    /// Initializes a new instance of the `RefCountDisposable`.
    public init(disposable: Disposable) async {
        self.lock = await SpinLock()
        self.disposable = disposable
        await super.init()
    }

    /**
     Holds a dependent disposable that when disposed decreases the refcount on the underlying disposable.

     When getter is called, a dependent disposable contributing to the reference count that manages the underlying disposable's lifetime is returned.
     */
    public func retain() async -> Disposable {
        await self.lock.performLocked {
            if self.disposable != nil {
                do {
                    _ = try incrementChecked(&self.count)
                } catch {
                    rxFatalError("RefCountDisposable increment failed")
                }

                return await RefCountInnerDisposable(self)
            } else {
                return Disposables.create()
            }
        }
    }

    /// Disposes the underlying disposable only when all dependent disposables have been disposed.
    public func dispose() async {
        let oldDisposable: Disposable? = await self.lock.performLocked {
            if let oldDisposable = self.disposable, !self.primaryDisposed {
                self.primaryDisposed = true

                if self.count == 0 {
                    self.disposable = nil
                    return oldDisposable
                }
            }

            return nil
        }

        if let disposable = oldDisposable {
            await disposable.dispose()
        }
    }

    fileprivate func release() async {
        let oldDisposable: Disposable? = await self.lock.performLocked {
            if let oldDisposable = self.disposable {
                do {
                    _ = try decrementChecked(&self.count)
                } catch {
                    rxFatalError("RefCountDisposable decrement on release failed")
                }

                guard self.count >= 0 else {
                    rxFatalError("RefCountDisposable counter is lower than 0")
                }

                if self.primaryDisposed && self.count == 0 {
                    self.disposable = nil
                    return oldDisposable
                }
            }

            return nil
        }

        if let disposable = oldDisposable {
            await disposable.dispose()
        }
    }
}

final class RefCountInnerDisposable: DisposeBase, Disposable {
    private let parent: RefCountDisposable
    private let isDisposed: AtomicInt

    init(_ parent: RefCountDisposable) async {
        self.isDisposed = await AtomicInt(0)
        self.parent = parent
        await super.init()
    }

    func dispose() async {
        if await fetchOr(self.isDisposed, 1) == 0 {
            await self.parent.release()
        }
    }
}
