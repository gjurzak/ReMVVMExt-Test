//
//  StateTree.swift
//  BNCommon
//
//  Created by Grzegorz Jurzak, Daniel Plachta, Dariusz Grzeszczak on 12/02/2019.
//  Copyright © 2019. All rights reserved.
//

import ReMVVM

public protocol NavigationState: StoreState {

    var navigation: Navigation { get }
}

public struct NavigationRoot {
    public let currentItem: AnyNavigationItem
    public let stacks: [(AnyNavigationItem, [ViewModelFactory])]

    public var currentStack: [ViewModelFactory] { stacks.first { $0.0 == currentItem }?.1 ?? [] }

    public init(current: AnyNavigationItem, stacks: [(AnyNavigationItem, [ViewModelFactory])]) {
        self.currentItem = current
        self.stacks = stacks
    }

    public init<T>(current: T, stacks: [(T, [ViewModelFactory])]) where T: NavigationItem {
        self.currentItem = AnyNavigationItem(current)
        self.stacks = stacks.map { (AnyNavigationItem($0),$1)}
    }


    public enum Main: NavigationItem {

        public var action: StoreAction { FakeAction() }

        case single


        private struct FakeAction: StoreAction {}
    }
}

public struct Navigation {

    public let modals: [Modal]
    public let root: NavigationRoot

    public init(root: NavigationRoot, modals: [Modal]) {
        self.root = root
        self.modals = modals
    }

    public var factory: ViewModelFactory {
        return modals.last?.factory ?? root.currentStack.last ?? CompositeViewModelFactory()
    }

    public enum Modal {
        case single(ViewModelFactory)
        case navigation([ViewModelFactory])

        public var factory: ViewModelFactory? {
            switch self {
            case .single(let factory): return factory
            case .navigation(let stack): return stack.last
            }
        }

        public var hasNavigation: Bool {
            guard case .navigation = self else { return false }
            return true
        }
    }

    public var topStack: [ViewModelFactory] {
        if let modal = modals.last {
            guard case .navigation(let stack) = modal else { return [] }
            return stack
        } else {
            return root.currentStack
        }
    }
}

public enum NavigationReducer {

    public static func reduce(state: Navigation, with action: StoreAction) -> Navigation {
        let reducers: [ AnyReducer<Navigation>] = [
                        ShowOnRootReducer.any,
                        ShowReducer.any,
                        SynchronizeStateReducer.any,
                        PushReducer.any,
                        PopReducer.any,
                        ShowModalReducer.any,
                        DismissModalReducer.any]

        return AnyReducer(with: reducers).reduce(state: state, with: action)
    }
}
