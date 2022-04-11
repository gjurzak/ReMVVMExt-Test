//
//  ReMVVMExtension.swift
//  ReMVVMExt
//
//  Created by Dariusz Grzeszczak on 07/06/2019.
//

import ReMVVM
import RxSwift
import UIKit

public struct NavigationStateIOS<ApplicationState>: NavigationState {

    public let navigation: Navigation

    public let appState: ApplicationState

    public var factory: ViewModelFactory {
        let factory: CompositeViewModelFactory
        if let f = navigation.factory as? CompositeViewModelFactory {
            factory = f
        } else {
            factory = CompositeViewModelFactory(with: navigation.factory)
        }

        return factory
    }

    public init(appState: ApplicationState,
                navigation: Navigation = Navigation(root: NavigationRoot(current: NavigationRoot.Main.single,
                                                                         stacks: [(NavigationRoot.Main.single, [])]),
                                                    modals: [])) {
        self.appState = appState
        self.navigation = navigation
    }
}

public enum ReMVVMExtension {

    public static func initialize<ApplicationState>(with state: ApplicationState,
                                                    window: UIWindow,
                                                    uiStateConfig: UIStateConfig,
                                                    stateMappers: [StateMapper<ApplicationState>] = [],
                                                    reducer: AnyReducer<ApplicationState>,
                                                    middleware: [AnyMiddleware]) -> AnyStore {

        let reducer = AnyReducer { state, action -> NavigationStateIOS<ApplicationState> in
            return NavigationStateIOS<ApplicationState>(
                appState: reducer.reduce(state: state.appState, with: action),
                navigation: NavigationReducer.reduce(state: state.navigation, with: action)
            )
        }

        let appMapper = StateMapper<NavigationStateIOS<ApplicationState>>(for: \.appState)
        let stateMappers = [appMapper] + stateMappers.map { $0.map(with: \.appState) }

        return self.initialize(with: NavigationStateIOS(appState: state),
                               window: window,
                               uiStateConfig: uiStateConfig,
                               stateMappers: stateMappers,
                               reducer: reducer,
                               middleware: middleware)
    }

    public static func initialize<State: NavigationState>(with state: State,
                                                          window: UIWindow,
                                                          uiStateConfig: UIStateConfig,
                                                          stateMappers: [StateMapper<State>] = [],
                                                          reducer: AnyReducer<State>,
                                                          middleware: [AnyMiddleware]) -> AnyStore {

        let uiState = UIState(window: window, config: uiStateConfig)

        let middleware: [AnyMiddleware] = [
            SynchronizeStateMiddleware<State>(uiState: uiState).any,
            ShowModalMiddleware<State>(uiState: uiState).any,
            DismissModalMiddleware<State>(uiState: uiState).any,
            ShowOnRootMiddleware<State>(uiState: uiState).any,
            ShowMiddleware<State>(uiState: uiState).any,
            PushMiddleware<State>(uiState: uiState).any,
            PopMiddleware<State>(uiState: uiState).any
            ] + middleware

        let store = Store<State>(with: state,
                                 reducer: reducer,
                                 middleware: middleware,
                                 stateMappers: stateMappers)

        store.add(observer: EndEditingFormListener<State>(uiState: uiState))
        ReMVVM.initialize(with: store)
        return store.any
    }
}

public final class EndEditingFormListener<State: StoreState>: StateObserver {

    let uiState: UIState
    var disposeBag = DisposeBag()

    public init(uiState: UIState) {
        self.uiState = uiState
    }

    public func willChange(state: State) {
        uiState.rootViewController.view.endEditing(true)
        uiState.modalControllers.last?.view.endEditing(true)
    }

    public func didChange(state: State, oldState: State?) {
        disposeBag = DisposeBag()

        uiState.navigationController?.rx
            .methodInvoked(#selector(UINavigationController.popViewController(animated:)))
            .subscribe(onNext: { [unowned self] _ in
                self.uiState.rootViewController.view.endEditing(true)
                self.uiState.modalControllers.last?.view.endEditing(true)
            })
            .disposed(by: disposeBag)
    }
}
