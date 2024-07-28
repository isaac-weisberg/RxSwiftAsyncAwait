//
//  CombineLatest.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 3/21/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

protocol CombineLatestProtocol: AnyObject {
    func next(_ c: C, _ index: Int) async
    func fail(_ c: C, _ error: Swift.Error) async
    func done(_ c: C, _ index: Int) async
}

actor CombineLatestSink<Observer: ObserverType>:
    Sink,
    CombineLatestProtocol
{
    typealias Element = Observer.Element

    private let arity: Int
    private var numberOfValues = 0
    private var numberOfDone = 0
    private var hasValue: [Bool]
    private var isDone: [Bool]
    
    let baseSink: BaseSink<Observer>
   
    init(arity: Int, observer: Observer, cancel: Cancelable) async {
        self.arity = arity
        self.hasValue = [Bool](repeating: false, count: arity)
        self.isDone = [Bool](repeating: false, count: arity)
        
        self.baseSink = await BaseSink(observer: observer, cancel: cancel)
    }
    
    func getResult() async throws -> Element {
        rxAbstractMethod()
    }
    
    func next(_ c: C, _ index: Int) async {
        if !self.hasValue[index] {
            self.hasValue[index] = true
            self.numberOfValues += 1
        }

        if self.numberOfValues == self.arity {
            do {
                let result = try await self.getResult()
                await self.forwardOn(.next(result), c.call())
            }
            catch let e {
                await self.forwardOn(.error(e), c.call())
                await self.dispose()
            }
        }
        else {
            var allOthersDone = true

            for i in 0 ..< self.arity {
                if i != index && !self.isDone[i] {
                    allOthersDone = false
                    break
                }
            }
            
            if allOthersDone {
                await self.forwardOn(.completed, c.call())
                await self.dispose()
            }
        }
    }
    
    func fail(_ c: C, _ error: Swift.Error) async {
        await self.forwardOn(.error(error), c.call())
        await self.dispose()
    }
    
    func done(_ c: C, _ index: Int) async {
        if self.isDone[index] {
            return
        }

        self.isDone[index] = true
        self.numberOfDone += 1

        if self.numberOfDone == self.arity {
            await self.forwardOn(.completed, c.call())
            await self.dispose()
        }
    }
}

final actor CombineLatestObserver<Element>:
    ObserverType,
    SynchronizedOnType
{
    typealias ValueSetter = (Element) -> Void
    
    private let parent: CombineLatestProtocol
    
    private let index: Int
    private let this: Disposable
    private let setLatestValue: ValueSetter
    
    init(parent: CombineLatestProtocol, index: Int, setLatestValue: @escaping ValueSetter, this: Disposable) {
        self.parent = parent
        self.index = index
        self.this = this
        self.setLatestValue = setLatestValue
    }
    
    func on(_ event: Event<Element>, _ c: C) async {
        await self.synchronizedOn(event, c.call())
    }

    func synchronized_on(_ event: Event<Element>, _ c: C) async {
        switch event {
        case .next(let value):
            self.setLatestValue(value)
            await self.parent.next(c.call(), self.index)
        case .error(let error):
            await self.this.dispose()
            await self.parent.fail(c.call(),error)
        case .completed:
            await self.this.dispose()
            await self.parent.done(c.call(),self.index)
        }
    }
}
