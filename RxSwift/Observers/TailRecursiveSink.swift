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
class TailRecursiveSink<Sequence: Swift.Sequence, Observer: ObserverType>:
    Sink<Observer>,
    InvocableWithValueType where Sequence.Element: ObservableConvertibleType, Sequence.Element.Element == Observer.Element
{
    typealias Value = TailRecursiveSinkCommand
    typealias Element = Observer.Element
    typealias SequenceGenerator = (generator: Sequence.Iterator, remaining: IntMax?)

    var generators: [SequenceGenerator] = []
    var disposed = false
    var subscription: SerialDisposable

    // this is thread safe object
    let gate: AsyncLock<InvocableScheduledItem<TailRecursiveSink<Sequence, Observer>>>

    override init(observer: Observer, cancel: Cancelable) async {
        self.gate = await AsyncLock<InvocableScheduledItem<TailRecursiveSink<Sequence, Observer>>>()
        self.subscription = await SerialDisposable()
        await super.init(observer: observer, cancel: cancel)
    }

    func run(_ c: C, _ sources: SequenceGenerator) async -> Disposable {
        self.generators.append(sources)

        await self.schedule(c.call(), .moveNext)

        return self.subscription
    }

    func invoke(_ c: C, _ command: TailRecursiveSinkCommand) async {
        switch command {
        case .dispose:
            self.disposeCommand()
        case .moveNext:
            await self.moveNextCommand(c.call())
        }
    }

    // simple implementation for now
    func schedule(_ c: C, _ command: TailRecursiveSinkCommand) async {
        await self.gate.invoke(c.call(), InvocableScheduledItem(invocable: self, state: command))
    }

    func done(_ c: C) async {
        await self.forwardOn(.completed, c.call())
        await self.dispose()
    }

    func extract(_ c: C, _ observable: Observable<Element>) -> SequenceGenerator? {
        rxAbstractMethod()
    }

    // should be done on gate locked

    private func moveNextCommand(_ c: C) async {
        var next: Observable<Element>?

        repeat {
            guard let (g, left) = self.generators.last else {
                break
            }

            if await self.isDisposed() {
                return
            }

            self.generators.removeLast()

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
                    self.generators.append((e, knownOriginalLeft - 1))
                }
            }
            else {
                self.generators.append((e, nil))
            }

            let nextGenerator = self.extract(c.call(), nextCandidate)

            if let nextGenerator = nextGenerator {
                self.generators.append(nextGenerator)
                #if DEBUG || TRACE_RESOURCES
                    if maxTailRecursiveSinkStackSize < self.generators.count {
                        maxTailRecursiveSinkStackSize = self.generators.count
                    }
                #endif
            }
            else {
                next = nextCandidate
            }
        }
        while next == nil

        guard let existingNext = next else {
            await self.done(c.call())
            return
        }

        let disposable = await SingleAssignmentDisposable()
        await self.subscription.setDisposable(disposable)
        await disposable.setDisposable(self.subscribeToNext(c.call(), existingNext))
    }

    func subscribeToNext(_ c: C, _ source: Observable<Element>) async -> Disposable {
        rxAbstractMethod()
    }

    func disposeCommand() {
        self.disposed = true
        self.generators.removeAll(keepingCapacity: false)
    }

    override func dispose() async {
        await super.dispose()

        await self.subscription.dispose()
        await self.gate.dispose()

        await self.schedule(C(), .dispose)
    }
}
