//
//  DisposeBag.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 3/25/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

public extension AsynchronousDisposable {
    /// Adds `self` to `bag`
    ///
    /// - parameter bag: `DisposeBag` to add `self` to.
    func disposed(by bag: DisposeBag) async {
        await bag.actualDisposeBag.insert(self)
    }

    func disposed(by bag: DisposeBag) {
        let disposeBag = bag.actualDisposeBag
        Task {
            await disposeBag.insert(self)
        }
    }
}

/**
 Thread safe bag that disposes added disposables on `deinit`.

 This returns ARC (RAII) like resource management to `RxSwift`.

 In case contained disposables need to be disposed, just put a different dispose bag
 or create a new one in its place.

     self.existingDisposeBag = DisposeBag()

 In case explicit disposal is necessary, there is also `CompositeDisposable`.
 */

public final class DisposeBag {
    let actualDisposeBag: DisposeBagUnderThehood

    public init() {
        actualDisposeBag = DisposeBagUnderThehood()
    }

    deinit {
        Task { [actualDisposeBag] in
            await actualDisposeBag.dispose()
        }
    }
}

public final actor DisposeBagUnderThehood: Sendable {

    // state
    fileprivate var disposables = [AsynchronousDisposable]()
    private var isDisposed = false

    /// Constructs new empty dispose bag.
    public init() {
        SynchronousDisposeBaseInit()
    }

    deinit {
        SynchronousDisposeBaseDeinit()
    }

    fileprivate func uncheckedAppend(_ disposables: [AsynchronousDisposable]) {
        self.disposables.append(contentsOf: disposables)
    }

    fileprivate func insertDisposables(_ disposables: [AsynchronousDisposable]) async {
        if isDisposed {
            for disposable in disposables {
                await disposable.dispose()
            }
        } else {
            uncheckedAppend(disposables)
        }
    }

    /// Adds `disposable` to be disposed when dispose bag is being deinited.
    ///
    /// - parameter disposable: Disposable to add.
    public func insert(_ disposable: AsynchronousDisposable) async {
        await _insert(disposable)?.dispose()
    }

    private func _insert(_ disposable: AsynchronousDisposable) async -> AsynchronousDisposable? {
        if isDisposed {
            return disposable
        }

        disposables.append(disposable)

        return nil
    }

    /// This is internal on purpose, take a look at `CompositeDisposable` instead.
    fileprivate func dispose() async {
        let oldDisposables = await _dispose()

        for disposable in oldDisposables {
            await disposable.dispose()
        }
    }

    private func _dispose() async -> [AsynchronousDisposable] {
        let disposables = disposables

        self.disposables.removeAll(keepingCapacity: false)
        isDisposed = true

        return disposables

    }
}

public extension DisposeBag {
    /// Convenience init allows a list of disposables to be gathered for disposal.
//    convenience init(disposing disposables: AsynchronousDisposable...) async {
//        await self.init()
//        await actualDisposeBag.append(disposables)
//    }

    /// Convenience init which utilizes a function builder to let you pass in a list of
    /// disposables to make a DisposeBag of.
    convenience init(@DisposableBuilder builder: () -> [AsynchronousDisposable]) async {
        await self.init(disposing: builder())
    }

    /// Convenience init allows an array of disposables to be gathered for disposal.
    convenience init(disposing disposables: [AsynchronousDisposable]) async {
        self.init()
        await actualDisposeBag.uncheckedAppend(disposables)
    }

    /// Convenience function allows a list of disposables to be gathered for disposal.
    func insert(_ disposables: AsynchronousDisposable...) async {
        await insert(disposables)
    }

    /// Convenience function allows a list of disposables to be gathered for disposal.
    func insert(@DisposableBuilder builder: () -> [AsynchronousDisposable]) async {
        await insert(builder())
    }

    /// Convenience function allows an array of disposables to be gathered for disposal.
    func insert(_ disposables: [AsynchronousDisposable]) async {
        await actualDisposeBag.insertDisposables(disposables)
    }

    /// A function builder accepting a list of Disposables and returning them as an array.
    #if swift(>=5.4)
        @resultBuilder
        struct DisposableBuilder {
            public static func buildBlock(_ disposables: AsynchronousDisposable...) -> [AsynchronousDisposable] {
                disposables
            }
        }
    #else
        @_functionBuilder
        struct DisposableBuilder {
            public static func buildBlock(_ disposables: AsynchronousDisposable...) -> [AsynchronousDisposable] {
                disposables
            }
        }
    #endif
}
