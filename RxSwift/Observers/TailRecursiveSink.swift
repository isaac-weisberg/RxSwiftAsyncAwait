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
final class TailRecursiveSink<Sequence: Swift.Sequence, TheSink: Sink & InvocableWithValueType>:
    BaseSinkProtocol where Sequence.Element: ObservableConvertibleType,
    Sequence.Element.Element == TheSink.Observer.Element {

    func beforeForwardOn() {
        baseSink.beforeForwardOn()
    }

    func setDisposedSync() {
        baseSink.setDisposedSync()
    }

    func afterForwardOn() {
        baseSink.afterForwardOn()
    }

    let observer: TheSink.Observer
    let cancel: any Cancelable

    typealias Observer = TheSink.Observer
    typealias Value = TailRecursiveSinkCommand
    typealias Element = Observer.Element
    typealias SequenceGenerator = (generator: Sequence.Iterator, remaining: IntMax?)

    let baseSink: BaseSink<TheSink>
    var generators: [SequenceGenerator] = []
    var disposed = false
    var subscription: SerialDisposable

    let gate: AsyncLock<InvocableScheduledItem<TheSink>>

    init(observer: Observer, cancel: Cancelable) async {
        gate = AsyncLock<InvocableScheduledItem<TheSink>>()
        subscription = await SerialDisposable()
        baseSink = await BaseSink(observer: observer, cancel: cancel)
        self.observer = observer
        self.cancel = cancel
    }

    // simple implementation for now
    func schedule(_ command: InvocableScheduledItem<TheSink>) -> AsyncLockIterator<InvocableScheduledItem<TheSink>> {
        gate.schedule(command)
    }

//    func done(_ c: C) {
//        await forwardOn(.completed, c.call())
//        await dispose()
//    }

    func forwardOn(_ event: Event<TheSink.Observer.Element>, _ c: C) async {
        await baseSink.forwardOn(event, c.call())
    }

//    func extract(_ c: C, _ observable: Observable<Element>) -> SequenceGenerator? {
//        rxAbstractMethod()
//    }

    func moveNextCandidatesForExtraction() -> CandidatesForExtractionIterator<Sequence, TheSink> {
        CandidatesForExtractionIterator(source: self)
    }

    func moveNextAppendGeneratorOrUseCandidate(
        _ nextGenerator: SequenceGenerator?,
        _ nextCandidate: Observable<Element>
    ) -> Observable<Element>? {
        if let nextGenerator {
            generators.append(nextGenerator)
            #if DEBUG || TRACE_RESOURCES
                if maxTailRecursiveSinkStackSize < generators.count {
                    maxTailRecursiveSinkStackSize = generators.count
                }
            #endif

            return nil
        } else {
            return nextCandidate
        }
    }

//    private func moveNextCommand(_ c: C) async {
//        var next: Observable<Element>?
//
//        repeat {
//            guard let (g, left) = generators.last else {
//                break
//            }
//
//            if isDisposed() {
//                return
//            }
//
//            generators.removeLast()
//
//            var e = g
//
//            guard let nextCandidate = e.next()?.asObservable() else {
//                continue
//            }
//
//            // `left` is a hint of how many elements are left in generator.
//            // In case this is the last element, then there is no need to push
//            // that generator on stack.
//            //
//            // This is an optimization used to make sure in tail recursive case
//            // there is no memory leak in case this operator is used to generate non terminating
//            // sequence.
//
//            if let knownOriginalLeft = left {
//                // `- 1` because generator.next() has just been called
//                if knownOriginalLeft - 1 >= 1 {
//                    generators.append((e, knownOriginalLeft - 1))
//                }
//            } else {
//                generators.append((e, nil))
//            }
//
//            let nextGenerator = extract(c.call(), nextCandidate)
//
//            if let nextGenerator {
//                generators.append(nextGenerator)
//                #if DEBUG || TRACE_RESOURCES
//                    if maxTailRecursiveSinkStackSize < generators.count {
//                        maxTailRecursiveSinkStackSize = generators.count
//                    }
//                #endif
//            } else {
//                next = nextCandidate
//            }
//        } while next == nil
//        guard let existingNext = next else {
//            await done(c.call())
//            return
//        }
//
//        let disposable = await SingleAssignmentDisposable()
//        await subscription.setDisposable(disposable)
//        await disposable.setDisposable(subscribeToNext(c.call(), existingNext))
//    }

    func isDisposed() -> Bool {
        baseSink.isDisposed()
    }

    func setDisposedSyncPre() {
        baseSink.setDisposedSync()
    }

    func dispose() async {
        await baseSink.dispose()

        await subscription.dispose()
    }

    func setDisposedSyncPost() {
        gate.dispose()
    }
}

struct CandidatesForExtractionIterator<
    Sequence: Swift.Sequence,
    TheSink: Sink & InvocableWithValueType
>: IteratorProtocol, Swift.Sequence where Sequence.Element: ObservableConvertibleType,
    TheSink.Observer.Element == Sequence.Element.Element {
    enum Element {
        case nextCandidate(Observable<TheSink.Observer.Element>)
        case noMoreCandidates
    }

    let source: TailRecursiveSink<Sequence, TheSink>

    init(source: TailRecursiveSink<Sequence, TheSink>) {
        self.source = source
    }

    mutating func next() -> Element? {
        repeat {
            guard let (g, left) = source.generators.last else {
                return Element.noMoreCandidates
            }

            if source.isDisposed() {
                return nil
            }

            source.generators.removeLast()

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
                    source.generators.append((e, knownOriginalLeft - 1))
                }
            } else {
                source.generators.append((e, nil))
            }

            return Element.nextCandidate(nextCandidate)
        } while true
    }
}
