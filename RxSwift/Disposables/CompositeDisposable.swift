//
//  CompositeDisposable.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 2/20/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

/// Represents a group of disposable resources that are disposed together.
public final class CompositeDisposable: SynchronousDisposeBase, SynchronousCancelable {
    /// Key used to remove disposable from composite disposable
    public struct DisposeKey {
        fileprivate let key: BagKey
        fileprivate init(key: BagKey) {
            self.key = key
        }
    }

    // state
    private var disposables: Bag<SynchronousDisposable>? = Bag()

    public func isDisposed() -> Bool {
        disposables == nil
    }

    /// Initializes a new instance of composite disposable with the specified number of disposables.
    public init(_ disposable1: SynchronousDisposable, _ disposable2: SynchronousDisposable) {
        // This overload is here to make sure we are using optimized version up to 4 arguments.
        _ = disposables!.insert(disposable1)
        _ = disposables!.insert(disposable2)
        super.init()
    }

    /// Initializes a new instance of composite disposable with the specified number of disposables.
    public init(
        _ disposable1: SynchronousDisposable,
        _ disposable2: SynchronousDisposable,
        _ disposable3: SynchronousDisposable
    ) {
        // This overload is here to make sure we are using optimized version up to 4 arguments.
        _ = disposables!.insert(disposable1)
        _ = disposables!.insert(disposable2)
        _ = disposables!.insert(disposable3)
        super.init()
    }

    /// Initializes a new instance of composite disposable with the specified number of disposables.
    public init(
        _ disposable1: SynchronousDisposable,
        _ disposable2: SynchronousDisposable,
        _ disposable3: SynchronousDisposable,
        _ disposable4: SynchronousDisposable,
        _ disposables: SynchronousDisposable...
    ) {
        // This overload is here to make sure we are using optimized version up to 4 arguments.
        _ = self.disposables!.insert(disposable1)
        _ = self.disposables!.insert(disposable2)
        _ = self.disposables!.insert(disposable3)
        _ = self.disposables!.insert(disposable4)

        for disposable in disposables {
            _ = self.disposables!.insert(disposable)
        }
        super.init()
    }

    /// Initializes a new instance of composite disposable with the specified number of disposables.
    public init(disposables: [SynchronousDisposable]) {
        for disposable in disposables {
            _ = self.disposables!.insert(disposable)
        }
        super.init()
    }

    /**
     Adds a disposable to the CompositeDisposable or disposes the disposable if the CompositeDisposable is disposed.

     - parameter disposable: Disposable to add.
     - returns: Key that can be used to remove disposable from composite disposable. In case dispose bag was already
     disposed `nil` will be returned.
     */
    public func insert(_ disposable: SynchronousDisposable) -> DisposeKey? {
        let key = _insert(disposable)

        if key == nil {
            disposable.dispose()
        }

        return key
    }

    private func _insert(_ disposable: SynchronousDisposable) -> DisposeKey? {
        let bagKey = disposables?.insert(disposable)
        return bagKey.map(DisposeKey.init)
    }

    /// - returns: Gets the number of disposables contained in the `CompositeDisposable`.
    public func count() -> Int {
        disposables?.count ?? 0
    }

    /// Removes and disposes the disposable identified by `disposeKey` from the CompositeDisposable.
    ///
    /// - parameter disposeKey: Key used to identify disposable to be removed.
    public func remove(for disposeKey: DisposeKey) {
        _remove(for: disposeKey)?.dispose()
    }

    private func _remove(for disposeKey: DisposeKey) -> SynchronousDisposable? {
        disposables?.removeKey(disposeKey.key)
    }

    /// Disposes all disposables in the group and removes them from the group.
    public func dispose() {
        if let disposables = _dispose() {
            disposeAll(in: disposables)
        }
    }

    private func _dispose() -> Bag<SynchronousDisposable>? {
        let current = disposables
        disposables = nil
        return current
    }
}

public extension Disposables {
    /// Creates a disposable with the given disposables.
    static func create(
        _ disposable1: SynchronousDisposable,
        _ disposable2: SynchronousDisposable,
        _ disposable3: SynchronousDisposable
    )
        -> SynchronousCancelable {
        CompositeDisposable(disposable1, disposable2, disposable3)
    }

    /// Creates a disposable with the given disposables.
    static func create(
        _ disposable1: SynchronousDisposable,
        _ disposable2: SynchronousDisposable,
        _ disposable3: SynchronousDisposable,
        _ disposables: SynchronousDisposable ...
    )
        -> SynchronousCancelable {
        var disposables = disposables
        disposables.append(disposable1)
        disposables.append(disposable2)
        disposables.append(disposable3)
        return CompositeDisposable(disposables: disposables)
    }

    /// Creates a disposable with the given disposables.
    static func create(_ disposables: [SynchronousDisposable]) -> SynchronousCancelable {
        switch disposables.count {
        case 2:
            return Disposables.create(disposables[0], disposables[1])
        default:
            return CompositeDisposable(disposables: disposables)
        }
    }
}
