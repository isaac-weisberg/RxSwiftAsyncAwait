//
//  Completable+AndThen.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 7/2/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

public extension PrimitiveSequenceType where Trait == CompletableTrait, Element == Never {
    /**
     Concatenates the second observable sequence to `self` upon successful termination of `self`.

     - seealso: [concat operator on reactivex.io](http://reactivex.io/documentation/operators/concat.html)

     - parameter second: Second observable sequence.
     - returns: An observable sequence that contains the elements of `self`, followed by those of the second sequence.
     */
    func andThen<Element: Sendable>(_ second: Single<Element>) -> Single<Element> {
        let completable = primitiveSequence.asObservable()
        return Single(raw: ConcatCompletable(completable: completable, second: second.asObservable()))
    }

    /**
     Concatenates the second observable sequence to `self` upon successful termination of `self`.

     - seealso: [concat operator on reactivex.io](http://reactivex.io/documentation/operators/concat.html)

     - parameter second: Second observable sequence.
     - returns: An observable sequence that contains the elements of `self`, followed by those of the second sequence.
     */
    func andThen<Element: Sendable>(_ second: Maybe<Element>) -> Maybe<Element> {
        let completable = primitiveSequence.asObservable()
        return Maybe(raw: ConcatCompletable(completable: completable, second: second.asObservable()))
    }

    /**
     Concatenates the second observable sequence to `self` upon successful termination of `self`.

     - seealso: [concat operator on reactivex.io](http://reactivex.io/documentation/operators/concat.html)

     - parameter second: Second observable sequence.
     - returns: An observable sequence that contains the elements of `self`, followed by those of the second sequence.
     */
    func andThen(_ second: Completable) -> Completable {
        let completable = primitiveSequence.asObservable()
        return Completable(raw: ConcatCompletable(completable: completable, second: second.asObservable()))
    }

    /**
     Concatenates the second observable sequence to `self` upon successful termination of `self`.

     - seealso: [concat operator on reactivex.io](http://reactivex.io/documentation/operators/concat.html)

     - parameter second: Second observable sequence.
     - returns: An observable sequence that contains the elements of `self`, followed by those of the second sequence.
     */
    func andThen<Element>(_ second: Observable<Element>) -> Observable<Element> {
        let completable = primitiveSequence.asObservable()
        return ConcatCompletable(completable: completable, second: second.asObservable())
    }
}

private final class ConcatCompletable<Element: Sendable>: Producer<Element>, @unchecked Sendable {
    fileprivate let completable: Observable<Never>
    fileprivate let second: Observable<Element>

    init(completable: Observable<Never>, second: Observable<Element>) {
        self.completable = completable
        self.second = second
        super.init()
    }

    override func run<Observer: ObserverType>(_ c: C, _ observer: Observer) async -> AsynchronousDisposable
        where Observer.Element == Element {
        let sink = ConcatCompletableSink(parent: self, observer: observer)
        await sink.run(c.call())
        return sink
    }
}

private final actor ConcatCompletableSink<Observer: ObserverType>:
    Sink,
    ObserverType {
    typealias Element = Never
    typealias Parent = ConcatCompletable<Observer.Element>

    private let parent: Parent
    private let sourceSub: SingleAssignmentDisposable
    private let secondSub: SingleAssignmentDisposable
    let baseSink: BaseSink<Observer>

    init(parent: Parent, observer: Observer) {
        sourceSub = SingleAssignmentDisposable()
        secondSub = SingleAssignmentDisposable()
        self.parent = parent
        baseSink = BaseSink(observer: observer)
    }

    func on(_ event: Event<Element>, _ c: C) async {
        if baseSink.disposed {
            return
        }
        switch event {
        case .error(let error):
            await forwardOn(.error(error), c.call())
            await dispose()
        case .next:
            break
        case .completed:
            let otherSink = ConcatCompletableSecondObserver(parent: self)
            await secondSub.setDisposable(parent.second.subscribe(c.call(), otherSink))?.dispose()
        }
    }

    func run(_ c: C) async {
        await sourceSub.setDisposable(parent.completable.subscribe(c.call(), self))?.dispose()
    }

    func dispose() async {
        baseSink.setDisposed()
        async let sourceD: ()? = sourceSub.dispose()?.dispose()
        async let secondD: ()? = secondSub.dispose()?.dispose()

        await sourceD
        await secondD
    }

    func handleSecondEvent(_ event: Event<Parent.Element>, _ c: C) async {
        if baseSink.disposed {
            return
        }

        await forwardOn(event, c.call())
        if event.isStopEvent {
            await dispose()
        }
    }
}

private final class ConcatCompletableSecondObserver<Observer: ObserverType>:
    ObserverType {
    typealias Element = Observer.Element

    typealias Parent = ConcatCompletableSink<Observer>

    private let parent: Parent

    init(parent: Parent) {
        self.parent = parent
    }

    func on(_ event: Event<Observer.Element>, _ c: C) async {
        await parent.handleSecondEvent(event, c.call())
    }
}
