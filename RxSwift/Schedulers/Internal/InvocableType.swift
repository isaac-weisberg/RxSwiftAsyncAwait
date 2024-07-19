//
//  InvocableType.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 11/7/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

protocol InvocableType {
    func invoke(_ c: C) async
}

protocol InvocableWithValueType {
    associatedtype Value

    func invoke(_ c: C, _ value: Value) async
}
