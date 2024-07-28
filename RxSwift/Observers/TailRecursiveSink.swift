//
//  TailRecursiveSink.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 3/21/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

enum TailRecursiveSinkCommand {
    case moveNext
    case dispose
}

#if DEBUG || TRACE_RESOURCES
    public var maxTailRecursiveSinkStackSize = 0
#endif

/// This class is usually used with `Generator` version of the operators.
final class TailRecursiveSink<Sequence: Swift.Sequence, Observer: ObserverType>:
    Sink,
    InvocableWithValueType where Sequence.Element: ObservableConvertibleType,
    Sequence.Element.Element == Observer.Element {
    typealias Value = TailRecursiveSinkCommand
    typealias Element = Observer.Element
    typealias SequenceGenerator = (generator: Sequence.Iterator, remaining: IntMax?)

    let baseSink: BaseSink<Observer>
    var generators: [SequenceGenerator] = []
    var disposed = false
    var subscription: SerialDisposable

    // this is thread safe object
    let gate: AsyncLock<InvocableScheduledItem<TailRecursiveSink<Sequence, Observer>>>

    init(observer: Observer, cancel: Cancelable) async {
        gate = await AsyncLock<InvocableScheduledItem<TailRecursiveSink<Sequence, Observer>>>()
        subscription = await SerialDisposable()
        baseSink = await BaseSink(observer: observer, cancel: cancel)
    }

    func run(_ c: C, _ sources: SequenceGenerator) async -> Disposable {
        generators.append(sources)

        await schedule(c.call(), .moveNext)

        return subscription
    }

    func invoke(_ c: C, _ command: TailRecursiveSinkCommand) async {
        switch command {
        case .dispose:
            disposeCommand()
        case .moveNext:
            await moveNextCommand(c.call())
        }
    }

    // simple implementation for now
    func schedule(_ c: C, _ command: TailRecursiveSinkCommand) async {
        await gate.invoke(c.call(), InvocableScheduledItem(invocable: self, state: command))
    }

    func done(_ c: C) async {
        await forwardOn(.completed, c.call())
        await dispose()
    }

    func extract(_ c: C, _ observable: Observable<Element>) -> SequenceGenerator? {
        rxAbstractMethod()
    }

    // should be done on gate locked

    private func moveNextCommand(_ c: C) async {
        var next: Observable<Element>?

        repeat {
            guard let (g, left) = generators.last else {
                break
            }

            if isDisposed() {
                return
            }

            generators.removeLast()

            var e = g

            guard let nextCandidate = await e.next()?.asObservable() else {
                continue
            }

            // `left` is a hint of how many elements are left in generator.
            // In case this is the last element, then there is no need to push
            // that generator on stack.
            //
            // This is an optimization used to make sure in tail recursive case
            // there is no memory leak in case this operator is used to generate non terminating
            // sequence.

            if let knownOriginalLeft = left {
                // `- 1` because generator.next() has just been called
                if knownOriginalLeft - 1 >= 1 {
                    generators.append((e, knownOriginalLeft - 1))
                }
            } else {
                generators.append((e, nil))
            }

            let nextGenerator = extract(c.call(), nextCandidate)

            if let nextGenerator {
                generators.append(nextGenerator)
                #if DEBUG || TRACE_RESOURCES
                    if maxTailRecursiveSinkStackSize < generators.count {
                        maxTailRecursiveSinkStackSize = generators.count
                    }
                #endif
            } else {
                next = nextCandidate
            }
        } while next == nil

        guard let existingNext = next else {
            await done(c.call())
            return
        }

        let disposable = await SingleAssignmentDisposable()
        await subscription.setDisposable(disposable)
        await disposable.setDisposable(subscribeToNext(c.call(), existingNext))
    }

    func subscribeToNext(_ c: C, _ source: Observable<Element>) async -> Disposable {
        rxAbstractMethod()
    }

    func disposeCommand() {
        disposed = true
        generators.removeAll(keepingCapacity: false)
    }

    func isDisposed() -> Bool {
        baseSink.isDisposed()
    }

    func dispose() async {
        baseSink.setDisposedSync()
        await baseSink.dispose()

        await subscription.dispose()
        await gate.dispose()

        await schedule(C(), .dispose)
    }
}
