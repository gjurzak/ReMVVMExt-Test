//
//  SynchronizeStateReducer.swift
//  BNCommon
//
//  Created by Grzegorz Jurzak, Daniel Plachta, Dariusz Grzeszczak.
//  Copyright © 2019. All rights reserved.
//

import Foundation
import ReMVVM
import RxSwift
import RxCocoa
import UIKit

// needed to synchronize the state when user use back button or swipe gesture
struct SynchronizeStateReducer: Reducer {

    public typealias Action = SynchronizeState

    public static func reduce(state: Navigation, with action: SynchronizeState) -> Navigation {
        if action.type == .navigation {
            return PopReducer.reduce(state: state, with: Pop())
        } else {
            return DismissModalReducer.reduce(state: state, with: DismissModal())
        }
    }
}



public final class SynchronizeStateMiddleware<State: NavigationState>: Middleware {
    public let uiState: UIState

    public init(uiState: UIState) {
        self.uiState = uiState
    }

    private var disposeBag = DisposeBag()

    public func onNext(for state: State,
                       action: StoreAction,
                       interceptor: Interceptor<StoreAction, State>,
                       dispatcher: Dispatcher) {

        if let action = action as? SynchronizeState {

            if  action.type == .navigation,
                let navigationCount = uiState.navigationController?.viewControllers.count,
                state.navigation.topStack.count > navigationCount {

                interceptor.next()
            } else if action.type == .modal, uiState.modalControllers.last?.isBeingDismissed == true {
                uiState.modalControllers.removeLast()
                interceptor.next { [weak self] _ in
                    let disposeBag = DisposeBag()
                    self?.disposeBag = disposeBag
                    self?.subscribeLastModal(dispatcher: dispatcher)
                }
            }
        } else {
            interceptor.next { [weak self] _ in
                let disposeBag = DisposeBag()
                self?.disposeBag = disposeBag
                self?.uiState.navigationController?.rx.didShow
                    .subscribe(onNext: { con in
                        dispatcher.dispatch(action: SynchronizeState(.navigation))
                    })
                    .disposed(by: disposeBag)

                self?.subscribeLastModal(dispatcher: dispatcher)
            }
        }
    }

    private func subscribeLastModal(dispatcher: Dispatcher) {
        guard let modal = self.uiState.modalControllers.last else { return }

        modal.rx.viewDidDisappear
            .subscribe(onNext: { _ in
                dispatcher.dispatch(action: SynchronizeState(.modal))
            })
            .disposed(by: disposeBag)
    }
}


private extension Reactive where Base: UIViewController {

  var viewDidDisappear: ControlEvent<Bool> {
    let source = self.methodInvoked(#selector(Base.viewDidDisappear)).map { $0.first as? Bool ?? false }
    return ControlEvent(events: source)
  }
}
