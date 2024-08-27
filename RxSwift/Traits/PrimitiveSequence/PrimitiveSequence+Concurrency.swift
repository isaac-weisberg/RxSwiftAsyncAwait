//
//  PrimitiveSequence+Concurrency.swift
//  RxSwift
//
//  Created by Shai Mishali on 22/09/2021.
//  Copyright © 2021 Krunoslav Zaher. All rights reserved.
//

import Foundation

#if swift(>=5.6) && canImport(_Concurrency) && !os(Linux)
    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    public extension PrimitiveSequenceType where Trait == SingleTrait {
        /// Allows awaiting the success or failure of this `Single`
        /// asynchronously via Swift's concurrency features (`async/await`)
        ///
        /// A sample usage would look like so:
        ///
        /// ```swift
        /// do {
        ///     let value = try await single.value
        /// } catch {
        ///     // Handle error
        /// }
        /// ```
        var value: Element {
            get async throws {
                let disposable = PortingDisposable()
                return try await withTaskCancellationHandler(
                    operation: {
                        try await withCheckedThrowingContinuation { continuation in
                            Task {
                                await disposable.setDisposable(
                                    self.subscribe(
                                        onSuccess: {
                                            await disposable.setDidResume(true)
                                            continuation.resume(returning: $0)
                                        },
                                        onFailure: {
                                            await disposable.setDidResume(true)
                                            continuation.resume(throwing: $0)
                                        },
                                        onDisposed: {
                                            guard await !disposable.didResume else { return }
                                            continuation.resume(throwing: CancellationError())
                                        }
                                    )
                                )
                            }
                        }
                    },
                    onCancel: { [disposable] in
                        Task {
                            await disposable.dispose()?.dispose()
                        }
                    }
                )
            }
        }
    }

    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    public extension PrimitiveSequenceType where Trait == MaybeTrait {
        /// Allows awaiting the success or failure of this `Maybe`
        /// asynchronously via Swift's concurrency features (`async/await`)
        ///
        /// If the `Maybe` completes without emitting a value, it would return
        /// a `nil` value to indicate so.
        ///
        /// A sample usage would look like so:
        ///
        /// ```swift
        /// do {
        ///     let value = try await maybe.value // Element?
        /// } catch {
        ///     // Handle error
        /// }
        /// ```
        var value: Element? {
            get async throws {
                let disposable = PortingDisposable()
                return try await withTaskCancellationHandler(
                    operation: {
                        try await withCheckedThrowingContinuation { continuation in
                            Task {
                                await disposable.setDisposable(
                                    self.subscribe(
                                        onSuccess: { value in
                                            await disposable.setDidEmitAndResume(didEmit: true, didResume: true)
                                            continuation.resume(returning: value)
                                        },
                                        onError: { error in
                                            await disposable.setDidResume(true)
                                            continuation.resume(throwing: error)
                                        },
                                        onCompleted: {
                                            guard await !disposable.didEmit else { return }
                                            await disposable.setDidResume(true)
                                            continuation.resume(returning: nil)
                                        },
                                        onDisposed: {
                                            guard await !disposable.didResume else { return }
                                            continuation.resume(throwing: CancellationError())
                                        }
                                    )
                                )?.dispose()
                            }
                        }
                    },
                    onCancel: { [disposable] in
                        Task {
                            await disposable.dispose()?.dispose()
                        }
                    }
                )
            }
        }
    }

    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    public extension PrimitiveSequenceType where Trait == CompletableTrait, Element == Never {
        /// Allows awaiting the success or failure of this `Completable`
        /// asynchronously via Swift's concurrency features (`async/await`)
        ///
        /// Upon completion, a `Void` will be returned
        ///
        /// A sample usage would look like so:
        ///
        /// ```swift
        /// do {
        ///     let value = try await completable.value // Void
        /// } catch {
        ///     // Handle error
        /// }
        /// ```
        var value: Void {
            get async throws {

                let disp = PortingDisposable()

                return try await withTaskCancellationHandler(
                    operation: {
                        try await withCheckedThrowingContinuation { continuation in
                            Task {
                                let sourceDisposable = await self.subscribe(
                                    onCompleted: {
                                        await disp.setDidResume(true)
                                        continuation.resume()
                                    },
                                    onError: { error in
                                        await disp.setDidResume(true)
                                        continuation.resume(throwing: error)
                                    },
                                    onDisposed: {
                                        if await disp.didResume {
                                            return
                                        }
                                        continuation.resume(throwing: CancellationError())
                                    }
                                )
                                await disp.setDisposable(sourceDisposable)?.dispose()
                            }
                        }
                    },
                    onCancel: {
                        Task {
                            await disp.dispose()?.dispose()
                        }
                    }
                )
            }
        }
    }
#endif

private final actor PortingDisposable {
    var didResume = false

    func setDidResume(_ newValue: Bool) {
        didResume = newValue
    }

    var didEmit = false
    func setDidEmit(_ newValue: Bool) {
        didEmit = newValue
    }

    func setDidEmitAndResume(didEmit: Bool, didResume: Bool) {
        self.didEmit = didEmit
        self.didResume = didResume
    }

    let singleAssignmentDisposable = SingleAssignmentDisposableContainer<Disposable>()

    func setDisposable(_ disposable: Disposable) -> Disposable? {
        singleAssignmentDisposable.setDisposable(disposable)
    }

    func dispose() -> Disposable? {
        singleAssignmentDisposable.dispose()
    }
}
