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
    public let maxTailRecursiveSinkStackSize = ActualAtomicInt<Int>(0)
#endif

/// This class is usually used with `Generator` version of the operators.
final actor TailRecursiveSink<Sequence: Swift.Sequence, Observer: ObserverType>:
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

    let gate: AsyncLock<InvocableScheduledItem<TailRecursiveSink<Sequence, Observer>>>

    init(observer: Observer) {
//        self.user = user
        gate = AsyncLock<InvocableScheduledItem<TailRecursiveSink<Sequence, Observer>>>()
        subscription = SerialDisposable()
        baseSink = BaseSink(observer: observer)
    }

    func run(_ c: C, _ sources: SequenceGenerator) async {
        generators.append(sources)

        await schedule(c.call(), .moveNext)
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

    func extract(_ c: C, _ observable: Observable<Element>) -> (generator: Sequence.Iterator, remaining: IntMax?)? {
        rxAbstractMethod()
    }

    func subscribeToNext(_ c: C, _ source: Observable<Element>) async -> Disposable {
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

            guard let nextCandidate = e.next()?.asObservable() else {
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
                    let generatorsCount = generators.count
                    await maxTailRecursiveSinkStackSize.perform(c.call()) { _, maxTailRecursiveSinkStackSize in
                        if maxTailRecursiveSinkStackSize < generatorsCount {
                            maxTailRecursiveSinkStackSize = generatorsCount
                        }
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

        let disposable = SingleAssignmentDisposable()
        await subscription.setDisposable(disposable)
        let innerDisposable = await subscribeToNext(c.call(), existingNext)
        await disposable.setDisposable(innerDisposable)
    }

    func disposeCommand() {
        disposed = true
        generators.removeAll(keepingCapacity: false)
    }

    func isDisposed() -> Bool {
        baseSink.disposed
    }

    func dispose() async {
        if baseSink.setDisposed() {

            await subscription.dispose()
            await gate.dispose()

            await schedule(C(), .dispose)
        }
    }
}
