//
//  DisposeBag.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 3/25/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

public extension SynchronizedDisposable {
    /// Adds `self` to `bag`
    ///
    /// - parameter bag: `DisposeBag` to add `self` to.
    func disposed(by bag: DisposeBag) async {
        await bag.insert(self)
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
    
    init() async {
        actualDisposeBag = await DisposeBagUnderThehood()
    }
    
    deinit {
        Task { [actualDisposeBag] in
            await actualDisposeBag.dispose()
        }
    }
}


public final class DisposeBagUnderThehood: DisposeBase {
    fileprivate var lock: ActualNonRecursiveLock

    // state
    fileprivate var disposables = [SynchronizedDisposable]()
    fileprivate var isDisposed = false

    /// Constructs new empty dispose bag.
    override public init() async {
        self.lock = await ActualNonRecursiveLock()
        await super.init()
    }

    /// Adds `disposable` to be disposed when dispose bag is being deinited.
    ///
    /// - parameter disposable: Disposable to add.
    public func insert(_ disposable: SynchronizedDisposable) async {
        await self._insert(disposable)?.dispose()
    }

    private func _insert(_ disposable: SynchronizedDisposable) async -> SynchronizedDisposable? {
        await self.lock.performLocked {
            if self.isDisposed {
                return disposable
            }

            self.disposables.append(disposable)

            return nil
        }
    }

    /// This is internal on purpose, take a look at `CompositeDisposable` instead.
    fileprivate func dispose() async {
        let oldDisposables = await self._dispose()

        for disposable in oldDisposables {
            await disposable.dispose()
        }
    }

    private func _dispose() async -> [SynchronizedDisposable] {
        await self.lock.performLocked {
            let disposables = self.disposables

            self.disposables.removeAll(keepingCapacity: false)
            self.isDisposed = true

            return disposables
        }
    }
}

public extension DisposeBag {
    /// Convenience init allows a list of disposables to be gathered for disposal.
    convenience init(disposing disposables: SynchronizedDisposable...) async {
        await self.init()
        self.actualDisposeBag.disposables += disposables
    }

    /// Convenience init which utilizes a function builder to let you pass in a list of
    /// disposables to make a DisposeBag of.
    convenience init(@DisposableBuilder builder: () -> [SynchronizedDisposable]) async {
        await self.init(disposing: builder())
    }

    /// Convenience init allows an array of disposables to be gathered for disposal.
    convenience init(disposing disposables: [SynchronizedDisposable]) async {
        await self.init()
        self.actualDisposeBag.disposables += disposables
    }

    /// Convenience function allows a list of disposables to be gathered for disposal.
    func insert(_ disposables: SynchronizedDisposable...) async {
        await self.insert(disposables)
    }

    /// Convenience function allows a list of disposables to be gathered for disposal.
    func insert(@DisposableBuilder builder: () -> [SynchronizedDisposable]) async {
        await self.insert(builder())
    }

    /// Convenience function allows an array of disposables to be gathered for disposal.
    func insert(_ disposables: [SynchronizedDisposable]) async {
        await self.actualDisposeBag.lock.performLocked {
            if self.actualDisposeBag.isDisposed {
                for disposable in disposables {
                    await disposable.dispose()
                }
            } else {
                self.actualDisposeBag.disposables += disposables
            }
        }
    }

    /// A function builder accepting a list of Disposables and returning them as an array.
    #if swift(>=5.4)
    @resultBuilder
    struct DisposableBuilder {
        public static func buildBlock(_ disposables: SynchronizedDisposable...) -> [SynchronizedDisposable] {
            return disposables
        }
    }
    #else
    @_functionBuilder
    struct DisposableBuilder {
        public static func buildBlock(_ disposables: SynchronizedDisposable...) -> [SynchronizedDisposable] {
            return disposables
        }
    }
    #endif
}
