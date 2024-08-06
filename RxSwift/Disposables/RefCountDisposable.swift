//
//  RefCountDisposable.swift
//  RxSwift
//
//  Created by Junior B. on 10/29/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

/// Represents a disposable resource that only disposes its underlying disposable resource when all dependent disposable
/// objects have been disposed.
public final class RefCountDisposable: SynchronousDisposable, SynchronousCancelable {
    private var disposable = nil as SynchronousDisposable?
    private var primaryDisposed = false
    private var count = 0

    /// - returns: Was resource disposed.
    public func isDisposed() -> Bool {
        disposable == nil
    }

    /// Initializes a new instance of the `RefCountDisposable`.
    public init(disposable: SynchronousDisposable) {
        self.disposable = disposable
    }

    /**
     Holds a dependent disposable that when disposed decreases the refcount on the underlying disposable.

     When getter is called, a dependent disposable contributing to the reference count that manages the underlying disposable's lifetime is returned.
     */
    public func retain() -> SynchronousDisposable {
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
    public func dispose() {
        let oldDisposable: SynchronousDisposable? = {
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
            disposable.dispose()
        }
    }

    fileprivate func release() {
        let oldDisposable: SynchronousDisposable? = {
            if let oldDisposable = self.disposable {
                do {
                    _ = try decrementChecked(&self.count)
                } catch {
                    rxFatalError("RefCountDisposable decrement on release failed")
                }

                guard self.count >= 0 else {
                    rxFatalError("RefCountDisposable counter is lower than 0")
                }

                if self.primaryDisposed, self.count == 0 {
                    self.disposable = nil
                    return oldDisposable
                }
            }

            return nil
        }()

        if let disposable = oldDisposable {
            disposable.dispose()
        }
    }
}

final class RefCountInnerDisposable: SynchronousDisposeBase, SynchronousDisposable {
    private let parent: RefCountDisposable
    private let isDisposed: NonAtomicInt

    init(_ parent: RefCountDisposable) {
        isDisposed = NonAtomicInt(0)
        self.parent = parent
    }

    func dispose() {
        if fetchOr(isDisposed, 1) == 0 {
            parent.release()
        }
    }
}
