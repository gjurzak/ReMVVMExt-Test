//
//  ShowOnRootReducer.swift
//  BNCommon
//
//  Created by Grzegorz Jurzak, Daniel Plachta, Dariusz Grzeszczak.
//  Copyright © 2019. All rights reserved.
//

import ReMVVM

struct ShowOnRootReducer: Reducer {

    public static func reduce(state: Navigation, with action: ShowOnRoot) -> Navigation {

        let current = NavigationRoot.Main.single
        let factory = action.controllerInfo.factory ?? state.factory
        let stacks = [(current, [factory])]
        let root = NavigationRoot(current: current, stacks: stacks)
        return Navigation(root: root, modals: [])
    }
}

public struct ShowOnRootMiddleware<State: NavigationState>: Middleware {

    public let uiState: UIState

    public init(uiState: UIState) {
        self.uiState = uiState
    }

    public func onNext(for state: State,
                       action: ShowOnRoot,
                       interceptor: Interceptor<ShowOnRoot, State>,
                       dispatcher: Dispatcher) {

        let uiState = self.uiState

        interceptor.next { _ in // newState - state variable is used below
            // side effect

            uiState.setRoot(controller: action.controllerInfo.loader.load(),
                            animated: action.controllerInfo.animated,
                            navigationBarHidden: action.navigationBarHidden)

            // dismiss modals
            uiState.rootViewController.dismiss(animated: true, completion: nil)
        }
    }
}
