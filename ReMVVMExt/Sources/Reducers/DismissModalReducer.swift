//
//  DismissModalReducer.swift
//  BNCommon
//
//  Created by Grzegorz Jurzak, Daniel Plachta, Dariusz Grzeszczak.
//  Copyright © 2019. All rights reserved.
//

import ReMVVM

public struct DismissModalReducer: Reducer {

    public typealias Action = DismissModal

    public static func reduce(state: Navigation, with action: DismissModal) -> Navigation {

        var modals = state.modals
        if action.dismissAllViews {
            modals.removeAll()
        } else {
            modals.removeLast()
        }
        return Navigation(root: state.root, modals: modals)
    }

}

public struct DismissModalMiddleware<State: NavigationState>: Middleware {

    public let uiState: UIState

    public init(uiState: UIState) {
        self.uiState = uiState
    }

    public func onNext(for state: State,
                       action: DismissModal,
                       interceptor: Interceptor<DismissModal, State>,
                       dispatcher: Dispatcher) {

        let uiState = self.uiState

        guard !uiState.modalControllers.isEmpty else { return }

        interceptor.next { _ in
            // side effect

            //dismiss not needed modals
            if action.dismissAllViews {
                uiState.dismissAll(animated: action.animated)
            } else {
                uiState.dismiss(animated: action.animated)
            }
        }

    }
}
