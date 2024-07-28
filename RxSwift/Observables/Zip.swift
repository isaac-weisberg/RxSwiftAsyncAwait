////
////  Zip.swift
////  RxSwift
////
////  Created by Krunoslav Zaher on 5/23/15.
////  Copyright © 2015 Krunoslav Zaher. All rights reserved.
////
//
//protocol ZipSinkProtocol: AnyObject {
//    func next(_ c: C, _ index: Int) async
//    func fail(_ c: C, _ error: Swift.Error) async
//    func done(_ c: C, _ index: Int) async
//}
//
//class ZipSink<Observer: ObserverType>: Sink, ZipSinkProtocol {
//    typealias Element = Observer.Element
//    
//    let arity: Int
//
//    let lock: RecursiveLock
//
//    // state
//    private var isDone: [Bool]
//    
//    init(arity: Int, observer: Observer, cancel: Cancelable) async {
//        self.lock = await RecursiveLock()
//        self.isDone = [Bool](repeating: false, count: arity)
//        self.arity = arity
//        
//        self.baseSink = await BaseSink(observer: observer, cancel: cancel)
//    }
//
//    func getResult() throws -> Element {
//        rxAbstractMethod()
//    }
//    
//    func hasElements(_ index: Int) -> Bool {
//        rxAbstractMethod()
//    }
//    
//    func next(_ c: C, _ index: Int) async {
//        var hasValueAll = true
//        
//        for i in 0 ..< self.arity {
//            if !self.hasElements(i) {
//                hasValueAll = false
//                break
//            }
//        }
//        
//        if hasValueAll {
//            do {
//                let result = try self.getResult()
//                await self.forwardOn(.next(result), c.call())
//            }
//            catch let e {
//                await self.forwardOn(.error(e), c.call())
//                await self.dispose()
//            }
//        }
//    }
//    
//    func fail(_ c: C, _ error: Swift.Error) async {
//        await self.forwardOn(.error(error), c.call())
//        await self.dispose()
//    }
//    
//    func done(_ c: C, _ index: Int) async {
//        self.isDone[index] = true
//        
//        var allDone = true
//        
//        for done in self.isDone where !done {
//            allDone = false
//            break
//        }
//        
//        if allDone {
//            await self.forwardOn(.completed, c.call())
//            await self.dispose()
//        }
//    }
//}
//
//final class ZipObserver<Element>:
//    ObserverType,
//    LockOwnerType,
//    SynchronizedOnType
//{
//    typealias ValueSetter = (Element) -> Void
//
//    private var parent: ZipSinkProtocol?
//    
//    let lock: RecursiveLock
//    
//    // state
//    private let index: Int
//    private let this: Disposable
//    private let setNextValue: ValueSetter
//    
//    init(lock: RecursiveLock, parent: ZipSinkProtocol, index: Int, setNextValue: @escaping ValueSetter, this: Disposable) {
//        self.lock = lock
//        self.parent = parent
//        self.index = index
//        self.this = this
//        self.setNextValue = setNextValue
//    }
//    
//    func on(_ event: Event<Element>, _ c: C) async {
//        await self.synchronizedOn(event, c.call())
//    }
//
//    func synchronized_on(_ event: Event<Element>, _ c: C) async {
//        if self.parent != nil {
//            switch event {
//            case .next:
//                break
//            case .error:
//                await self.this.dispose()
//            case .completed:
//                await self.this.dispose()
//            }
//        }
//        
//        if let parent = self.parent {
//            switch event {
//            case .next(let value):
//                self.setNextValue(value)
//                await parent.next(c.call(), self.index)
//            case .error(let error):
//                await parent.fail(c.call(), error)
//            case .completed:
//                await parent.done(c.call(), self.index)
//            }
//        }
//    }
//}
