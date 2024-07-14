//
//  BlockingObservable+Operators.swift
//  RxBlocking
//
//  Created by Krunoslav Zaher on 10/19/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

import RxSwift

/// The `MaterializedSequenceResult` enum represents the materialized
/// output of a BlockingObservable.
///
/// If the sequence terminates successfully, the result is represented
/// by `.completed` with the array of elements.
///
/// If the sequence terminates with error, the result is represented
/// by `.failed` with both the array of elements and the terminating error.
@frozen public enum MaterializedSequenceResult<T> {
    case completed(elements: [T])
    case failed(elements: [T], error: Error)
}

extension BlockingObservable {
    /// Blocks current thread until sequence terminates.
    ///
    /// If sequence terminates with error, terminating error will be thrown.
    ///
    /// - returns: All elements of sequence.
    public func toArray() async throws -> [Element] {
        let results = await self.materializeResult()
        return try self.elementsOrThrow(results)
    }
}

extension BlockingObservable {
    /// Blocks current thread until sequence produces first element.
    ///
    /// If sequence terminates with error before producing first element, terminating error will be thrown.
    ///
    /// - returns: First element of sequence. If sequence is empty `nil` is returned.
    public func first() async throws -> Element? {
        let results = await self.materializeResult(max: 1)
        return try self.elementsOrThrow(results).first
    }
}

extension BlockingObservable {
    /// Blocks current thread until sequence terminates.
    ///
    /// If sequence terminates with error, terminating error will be thrown.
    ///
    /// - returns: Last element in the sequence. If sequence is empty `nil` is returned.
    public func last() async throws -> Element? {
        let results = await self.materializeResult()
        return try self.elementsOrThrow(results).last
    }
}

extension BlockingObservable {
    /// Blocks current thread until sequence terminates.
    ///
    /// If sequence terminates with error before producing first element, terminating error will be thrown.
    ///
    /// - returns: Returns the only element of an sequence, and reports an error if there is not exactly one element in the observable sequence.
    public func single() async throws -> Element {
        try await self.single { _ in true }
    }

    /// Blocks current thread until sequence terminates.
    ///
    /// If sequence terminates with error before producing first element, terminating error will be thrown.
    ///
    /// - parameter predicate: A function to test each source element for a condition.
    /// - returns: Returns the only element of an sequence that satisfies the condition in the predicate, and reports an error if there is not exactly one element in the sequence.
    public func single(_ predicate: @escaping (Element) throws -> Bool) async throws -> Element {
        let results = await self.materializeResult(max: 2, predicate: predicate)
        let elements = try self.elementsOrThrow(results)

        if elements.count > 1 {
            throw RxError.moreThanOneElement
        }

        guard let first = elements.first else {
            throw RxError.noElements
        }

        return first
    }
}

extension BlockingObservable {
    /// Blocks current thread until sequence terminates.
    ///
    /// The sequence is materialized as a result type capturing how the sequence terminated (completed or error), along with any elements up to that point.
    ///
    /// - returns: On completion, returns the list of elements in the sequence. On error, returns the list of elements up to that point, along with the error itself.
    public func materialize() async -> MaterializedSequenceResult<Element> {
        await self.materializeResult()
    }
}

extension BlockingObservable {
    private func materializeResult(max: Int? = nil, predicate: @escaping (Element) throws -> Bool = { _ in true }) async -> MaterializedSequenceResult<Element> {
        var elements = [Element]()
        var error: Swift.Error?
        
        let lock = await RunLoopLock(timeout: self.timeout)
        
        let d = await SingleAssignmentDisposable()
        
        let result = await scoped {
            lock.dispatch {
                let subscription = await self.source.subscribe { event in
                    if await d.isDisposed() {
                        return
                    }
                    switch event {
                    case .next(let element):
                        do {
                            if try predicate(element) {
                                elements.append(element)
                            }
                            if let max = max, elements.count >= max {
                                await d.dispose()
                                await lock.stop()
                            }
                        } catch let err {
                            error = err
                            await d.dispose()
                            await lock.stop()
                        }
                    case .error(let err):
                        error = err
                        await d.dispose()
                        await lock.stop()
                    case .completed:
                        await d.dispose()
                        await lock.stop()
                    }
                }
                
                await d.setDisposable(subscription)
            }
            
            do {
                try await lock.run()
            } catch let err {
                error = err
            }
            
            if let error = error {
                return MaterializedSequenceResult.failed(elements: elements, error: error)
            }
            return MaterializedSequenceResult.completed(elements: elements)
        }
            
        await d.dispose()
        return result
    }
    
    private func elementsOrThrow(_ results: MaterializedSequenceResult<Element>) throws -> [Element] {
        switch results {
        case .failed(_, let error):
            throw error
        case .completed(let elements):
            return elements
        }
    }
}

func scoped<R>(_ work: @escaping () async -> R) async -> R {
    await work()
}
