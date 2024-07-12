//
//  RefCountDisposable.swift
//  RxSwift
//
//  Created by Junior B. on 10/29/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

/// Represents a disposable resource that only disposes its underlying disposable resource when all dependent disposable objects have been disposed.
public final actor RefCountDisposable: DisposeBase, Cancelable {
    private var disposable = nil as Disposable?
    private var primaryDisposed = false
    private var count = 0

    /// - returns: Was resource disposed.
    public func isDisposed() async -> Bool {
        disposable == nil
    }

    /// Initializes a new instance of the `RefCountDisposable`.
    public init(disposable: Disposable) {
        self.disposable = disposable
        #if TRACE_RESOURCES
            _ = Resources.incrementTotal()
        #endif
    }

    deinit {
        #if TRACE_RESOURCES
            _ = Resources.decrementTotal()
        #endif
    }

    /**
     Holds a dependent disposable that when disposed decreases the refcount on the underlying disposable.

     When getter is called, a dependent disposable contributing to the reference count that manages the underlying disposable's lifetime is returned.
     */
    public func retain() -> Disposable {
        if disposable != nil {
            do {
                _ = try incrementChecked(&count)
            } catch {
                rxFatalError("RefCountDisposable increment failed")
            }

            return RefCountInnerDisposable(self)
        } else {
            return Disposables.create()
        }
    }

    /// Disposes the underlying disposable only when all dependent disposables have been disposed.
    public func dispose() async {
        let oldDisposable: Disposable? = {
            if let oldDisposable = self.disposable, !self.primaryDisposed {
                self.primaryDisposed = true

                if self.count == 0 {
                    self.disposable = nil
                    return oldDisposable
                }
            }

            return nil
        }()

        if let disposable = oldDisposable {
            await disposable.dispose()
        }
    }

    fileprivate func release() async {
        let oldDisposable: Disposable? = {
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
        }()

        if let disposable = oldDisposable {
            await disposable.dispose()
        }
    }
}

final actor RefCountInnerDisposable: DisposeBase, Disposable {
    private let parent: RefCountDisposable
    private var isDisposed = false

    init(_ parent: RefCountDisposable) {
        self.parent = parent

        #if TRACE_RESOURCES
            _ = Resources.incrementTotal()
        #endif
    }

    func dispose() async {
        if !isDisposed {
            isDisposed = true
            await parent.release()
        }
    }

    deinit {
        #if TRACE_RESOURCES
            _ = Resources.decrementTotal()
        #endif
    }
}
