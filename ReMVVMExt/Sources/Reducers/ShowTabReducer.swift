//
//  ShowTabReducer.swift
//  ReMVVMExt
//
//  Created by DGrzegorz Jurzak, Daniel Plachta, Dariusz Grzeszczak.
//  Copyright © 2019. All rights reserved.
//

import Loaders
import ReMVVM
import UIKit

typealias NavigationType = [AnyNavigationItem]
extension NavigationRoot {
    var navigationType: NavigationType { stacks.map { $0.0 } }
}

extension NavigationItem where Self: CaseIterable {
    static var navigationType: NavigationType { allCases.map { AnyNavigationItem($0) }}
}

struct ShowReducer: Reducer {

    public static func reduce(state: Navigation, with action: Show) -> Navigation {

        let current = action.item
        var stacks: [(AnyNavigationItem, [ViewModelFactory])]
        let factory = action.controllerInfo.factory ?? state.factory
        if action.navigationType == state.root.navigationType { //check the type is the same
            stacks = state.root.stacks.map {
                guard $0.0 == current, $0.1.isEmpty else { return $0 }
                return ($0.0, [factory])
            }
        } else {
            stacks = action.navigationType.map {
                guard $0 == current else { return ($0, []) }
                return ($0, [factory])
            }
        }
        let root = NavigationRoot(current: current, stacks: stacks)
        return Navigation(root: root, modals: [])
    }
}

public struct ShowMiddleware<State: NavigationState>: Middleware {

    public let uiState: UIState

    public init(uiState: UIState) {
        self.uiState = uiState
    }

    public func onNext(for state: State, action: Show, interceptor: Interceptor<Show, State>, dispatcher: Dispatcher) {

        guard state.navigation.root.currentItem != action.item else { return }

        interceptor.next(action: action) { [uiState] _ in

            let wasTabOnTop = state.navigation.root.navigationType == action.navigationType
                && uiState.rootViewController is NavigationContainerController

            let containerController: NavigationContainerController
            if wasTabOnTop {
                containerController = uiState.rootViewController as! NavigationContainerController
            } else {
                let config = uiState.config.navigationConfigs.first { $0.navigationType == action.navigationType }
                if case let .custom(configurator) = config?.config {
                    containerController = configurator(action.navigationType)
                } else {
                    let tabController = TabBarViewController(config: config, navigationControllerFactory: uiState.config.navigationController)
                    tabController.loadViewIfNeeded()

                    containerController = tabController
                }
            }

            //set up current if empty (or reset)
            if let top = containerController.currentNavigationController, top.viewControllers.isEmpty {
                top.setViewControllers([action.controllerInfo.loader.load()],
                animated: false)
            }

            if !wasTabOnTop {
                uiState.setRoot(controller: containerController,
                                animated: action.controllerInfo.animated,
                                navigationBarHidden: action.navigationBarHidden)
            }

            // dismiss modals
            uiState.rootViewController.dismiss(animated: true, completion: nil)
        }
    }
}
