//
//  CompositeDisposable.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 2/20/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

/// Represents a group of disposable resources that are disposed together.
public final class UnsynchronizedCompositeDisposable: @unchecked Sendable {
    /// Key used to remove disposable from composite disposable
    public struct DisposeKey: Sendable {
        fileprivate let key: BagKey
        fileprivate init(key: BagKey) {
            self.key = key
        }
    }

    // state
    private var disposables: Bag<AsynchronousDisposable>? = Bag()

    public func isDisposed() -> Bool {
        disposables == nil
    }

    /// Initializes a new instance of composite disposable with the specified number of disposables.
    public init(_ disposable1: AsynchronousDisposable, _ disposable2: AsynchronousDisposable) {
        // This overload is here to make sure we are using optimized version up to 4 arguments.
        _ = disposables!.insert(disposable1)
        _ = disposables!.insert(disposable2)

        SynchronousDisposeBaseInit()
    }

    /// Initializes a new instance of composite disposable with the specified number of disposables.
    public init(
        _ disposable1: AsynchronousDisposable,
        _ disposable2: AsynchronousDisposable,
        _ disposable3: AsynchronousDisposable
    ) {
        // This overload is here to make sure we are using optimized version up to 4 arguments.
        _ = disposables!.insert(disposable1)
        _ = disposables!.insert(disposable2)
        _ = disposables!.insert(disposable3)
        SynchronousDisposeBaseInit()
    }

    /// Initializes a new instance of composite disposable with the specified number of disposables.
    public init(
        _ disposable1: AsynchronousDisposable,
        _ disposable2: AsynchronousDisposable,
        _ disposable3: AsynchronousDisposable,
        _ disposable4: AsynchronousDisposable,
        _ disposables: AsynchronousDisposable...
    ) {
        // This overload is here to make sure we are using optimized version up to 4 arguments.
        _ = self.disposables!.insert(disposable1)
        _ = self.disposables!.insert(disposable2)
        _ = self.disposables!.insert(disposable3)
        _ = self.disposables!.insert(disposable4)

        for disposable in disposables {
            _ = self.disposables!.insert(disposable)
        }
        SynchronousDisposeBaseInit()
    }

    /// Initializes a new instance of composite disposable with the specified number of disposables.
    public init(disposables: [AsynchronousDisposable]) {
        for disposable in disposables {
            _ = self.disposables!.insert(disposable)
        }
        SynchronousDisposeBaseInit()
    }

    /**
     Adds a disposable to the CompositeDisposable or disposes the disposable if the CompositeDisposable is disposed.

     - parameter disposable: Disposable to add.
     - returns: Key that can be used to remove disposable from composite disposable. In case dispose bag was already
     disposed `nil` will be returned.
     */
    public func insert(_ disposable: AsynchronousDisposable) async -> DisposeKey? {
        let key = _insert(disposable)

        if key == nil {
            await disposable.dispose()
        }

        return key
    }
    
    public func insertUnchecked(_ disposable: AsynchronousDisposable) -> DisposeKey {
        let key = _insert(disposable)

        guard let key else {
            fatalError()
        }

        return key
    }

    private func _insert(_ disposable: AsynchronousDisposable) -> DisposeKey? {
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
    public func remove(for disposeKey: DisposeKey) -> Disposable? {
        return _remove(for: disposeKey)
    }

    private func _remove(for disposeKey: DisposeKey) -> AsynchronousDisposable? {
        disposables?.removeKey(disposeKey.key)
    }

    /// Disposes all disposables in the group and removes them from the group.
    public func dispose() async {
        if let disposables = _dispose() {
            await disposeAll(in: disposables)
        }
    }

    private func _dispose() -> Bag<AsynchronousDisposable>? {
        let current = disposables
        disposables = nil
        return current
    }

    deinit {
        SynchronousDisposeBaseDeinit()
    }
}

public typealias CompositeDisposable = UnsynchronizedCompositeDisposable

actor ActorCompositeDisposable: AsynchronousCancelable {
    let disposable: CompositeDisposable

    init(_ disposable: CompositeDisposable) {
        self.disposable = disposable
    }

    public func isDisposed() async -> Bool {
        disposable.isDisposed()
    }

    public func dispose() async {
        await disposable.dispose()
    }
}

public extension Disposables {
    /// Creates a disposable with the given disposables.
    static func create(
        _ disposable1: AsynchronousDisposable,
        _ disposable2: AsynchronousDisposable,
        _ disposable3: AsynchronousDisposable
    )
        -> AsynchronousCancelable {
        ActorCompositeDisposable(CompositeDisposable(disposable1, disposable2, disposable3))
    }

    /// Creates a disposable with the given disposables.
    static func create(
        _ disposable1: AsynchronousDisposable,
        _ disposable2: AsynchronousDisposable,
        _ disposable3: AsynchronousDisposable,
        _ disposables: AsynchronousDisposable ...
    )
        -> AsynchronousCancelable {
        var disposables = disposables
        disposables.append(disposable1)
        disposables.append(disposable2)
        disposables.append(disposable3)
        return ActorCompositeDisposable(CompositeDisposable(disposables: disposables))
    }

    /// Creates a disposable with the given disposables.
    static func create(_ disposables: [AsynchronousDisposable]) -> AsynchronousCancelable {
        switch disposables.count {
        case 2:
            return Disposables.create(disposables[0], disposables[1])
        default:
            return ActorCompositeDisposable(CompositeDisposable(disposables: disposables))
        }
    }
}
