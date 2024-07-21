//
//  CompositeDisposable.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 2/20/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

/// Represents a group of disposable resources that are disposed together.
public final class CompositeDisposable: DisposeBase, Cancelable {
    /// Key used to remove disposable from composite disposable
    public struct DisposeKey {
        fileprivate let key: BagKey
        fileprivate init(key: BagKey) {
            self.key = key
        }
    }

    private let lock: ActualNonRecursiveLock
    
    // state
    private var disposables: Bag<Disposable>? = Bag()

    public func isDisposed() async -> Bool {
        await self.lock.performLocked {
            self.disposables == nil
        }
    }
    
    override public init() async {
        self.lock = await ActualNonRecursiveLock()
        await super.init()
    }
    
    /// Initializes a new instance of composite disposable with the specified number of disposables.
    public init(_ disposable1: Disposable, _ disposable2: Disposable) async {
        self.lock = await ActualNonRecursiveLock()
        // This overload is here to make sure we are using optimized version up to 4 arguments.
        _ = self.disposables!.insert(disposable1)
        _ = self.disposables!.insert(disposable2)
        await super.init()
    }
    
    /// Initializes a new instance of composite disposable with the specified number of disposables.
    public init(_ disposable1: Disposable, _ disposable2: Disposable, _ disposable3: Disposable) async {
        self.lock = await ActualNonRecursiveLock()
        // This overload is here to make sure we are using optimized version up to 4 arguments.
        _ = self.disposables!.insert(disposable1)
        _ = self.disposables!.insert(disposable2)
        _ = self.disposables!.insert(disposable3)
        await super.init()
    }
    
    /// Initializes a new instance of composite disposable with the specified number of disposables.
    public init(_ disposable1: Disposable, _ disposable2: Disposable, _ disposable3: Disposable, _ disposable4: Disposable, _ disposables: Disposable...) async {
        self.lock = await ActualNonRecursiveLock()
        // This overload is here to make sure we are using optimized version up to 4 arguments.
        _ = self.disposables!.insert(disposable1)
        _ = self.disposables!.insert(disposable2)
        _ = self.disposables!.insert(disposable3)
        _ = self.disposables!.insert(disposable4)
        
        for disposable in disposables {
            _ = self.disposables!.insert(disposable)
        }
        await super.init()
    }
    
    /// Initializes a new instance of composite disposable with the specified number of disposables.
    public init(disposables: [Disposable]) async {
        self.lock = await ActualNonRecursiveLock()
        for disposable in disposables {
            _ = self.disposables!.insert(disposable)
        }
        await super.init()
    }

    /**
     Adds a disposable to the CompositeDisposable or disposes the disposable if the CompositeDisposable is disposed.
     
     - parameter disposable: Disposable to add.
     - returns: Key that can be used to remove disposable from composite disposable. In case dispose bag was already
     disposed `nil` will be returned.
     */
    public func insert(_ disposable: Disposable) async -> DisposeKey? {
        let key = await self._insert(disposable)
        
        if key == nil {
            await disposable.dispose()
        }
        
        return key
    }
    
    private func _insert(_ disposable: Disposable) async -> DisposeKey? {
        await self.lock.performLocked {
            let bagKey = self.disposables?.insert(disposable)
            return bagKey.map(DisposeKey.init)
        }
    }
    
    /// - returns: Gets the number of disposables contained in the `CompositeDisposable`.
    public func count() async -> Int {
        await self.lock.performLocked {
            self.disposables?.count ?? 0
        }
    }
    
    /// Removes and disposes the disposable identified by `disposeKey` from the CompositeDisposable.
    ///
    /// - parameter disposeKey: Key used to identify disposable to be removed.
    public func remove(for disposeKey: DisposeKey) async {
        await self._remove(for: disposeKey)?.dispose()
    }
    
    private func _remove(for disposeKey: DisposeKey) async -> Disposable? {
        await self.lock.performLocked {
            self.disposables?.removeKey(disposeKey.key)
        }
    }
    
    /// Disposes all disposables in the group and removes them from the group.
    public func dispose() async {
        if let disposables = await self._dispose() {
            await disposeAll(in: disposables)
        }
    }

    private func _dispose() async -> Bag<Disposable>? {
        await self.lock.performLocked {
            let current = self.disposables
            self.disposables = nil
            return current
        }
    }
}

public extension Disposables {
    /// Creates a disposable with the given disposables.
    static func create(_ disposable1: Disposable, _ disposable2: Disposable, _ disposable3: Disposable) async -> Cancelable {
        await CompositeDisposable(disposable1, disposable2, disposable3)
    }
    
    /// Creates a disposable with the given disposables.
    static func create(_ disposable1: Disposable, _ disposable2: Disposable, _ disposable3: Disposable, _ disposables: Disposable ...) async -> Cancelable {
        var disposables = disposables
        disposables.append(disposable1)
        disposables.append(disposable2)
        disposables.append(disposable3)
        return await CompositeDisposable(disposables: disposables)
    }
    
    /// Creates a disposable with the given disposables.
    static func create(_ disposables: [Disposable]) async -> Cancelable {
        switch disposables.count {
        case 2:
            return await Disposables.create(disposables[0], disposables[1])
        default:
            return await CompositeDisposable(disposables: disposables)
        }
    }
}
