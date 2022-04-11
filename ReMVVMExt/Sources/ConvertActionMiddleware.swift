//
//  ConvertActionMiddleware.swift
//  ReMVVMExt
//
//  Created by Dariusz Grzeszczak on 29/05/2019.
//  Copyright © 2019. All rights reserved.
//

import ReMVVM

public protocol ConvertActionMiddleware: Middleware {
    // it's needed to use other names for Action and State due to swift5 update
    // without new names it will require declaration of Action and State typealiases in implementation struct/class
    // please check if that is fixed in compiler in next xcode/swift releses

    associatedtype Source = Action
    associatedtype ConvertState = State

    associatedtype Destination: StoreAction

    func convert(action: Source, state: ConvertState) -> Destination
}

extension ConvertActionMiddleware {
    public func onNext(for state: ConvertState, action: Source, interceptor: Interceptor<Source, ConvertState>, dispatcher: Dispatcher) {

        dispatcher.dispatch(action: convert(action: action, state: state))
    }
}
