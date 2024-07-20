//
//  SerialDisposable.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 3/12/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

/// Represents a disposable resource whose underlying disposable resource can be replaced by another disposable resource, causing automatic disposal of the previous underlying disposable resource.
public final class SerialDisposable: DisposeBase, Cancelable {
    private let lock: SpinLock
    
    // state
    private var current = nil as Disposable?
    private var disposed = false
    
    /// - returns: Was resource disposed.
    public func isDisposed() async -> Bool {
        self.disposed
    }
    
    /// Initializes a new instance of the `SerialDisposable`.
    override public init() async {
        self.lock = await SpinLock()
        await super.init()
    }
    
    /**
     Gets or sets the underlying disposable.
    
     Assigning this property disposes the previous disposable object.
    
     If the `SerialDisposable` has already been disposed, assignment to this property causes immediate disposal of the given disposable object.
     */
    
    public func getDisposable() async -> Disposable {
        await self.lock.performLocked {
            self.current ?? Disposables.create()
        }
    }
    
    public func setDisposable(_ newDisposable: Disposable) async {
        let disposable: Disposable? = await self.lock.performLocked {
            if await self.isDisposed() {
                return newDisposable
            }
            else {
                let toDispose = self.current
                self.current = newDisposable
                return toDispose
            }
        }
        
        if let disposable = disposable {
            await disposable.dispose()
        }
    }
    
    /// Disposes the underlying disposable as well as all future replacements.
    public func dispose() async {
        await self._dispose()?.dispose()
    }

    private func _dispose() async -> Disposable? {
        await self.lock.performLocked(C()) { c in
            guard await !self.isDisposed() else { return nil }

            self.disposed = true
            let current = self.current
            self.current = nil
            return current
        }
    }
}
