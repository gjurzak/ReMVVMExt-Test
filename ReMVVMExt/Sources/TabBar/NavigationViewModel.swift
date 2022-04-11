//
//  TabBarViewModel.swift
//  BNCommon
//
//  Created by Grzegorz Jurzak on 12/02/2019.
//  Copyright © 2019 HYD. All rights reserved.
//

import Foundation
import ReMVVM
import RxSwift


open class NavigationViewModel<Item: NavigationItem>: Initializable, StateObserver, ReMVVMDriven {
    public typealias State = NavigationState

    public let items: Observable<[Item]>
    public let selected: Observable<Item>

    required public init() {

        let state = NavigationViewModel.remvvm.stateSubject.rx.state
        if Item.self == AnyNavigationItem.self {
            let tabType = state.map { type(of: $0.navigation.root.currentItem.base) }.take(1).share()
            items = state.map { $0.navigation.root.stacks.map { $0.0 }}
                        .withLatestFrom(tabType) { items, tabType -> [Item] in
                            items
                                .filter { type(of: $0.base) == tabType }
                                .compactMap { $0 as? Item }
                        }
                        .filter { $0.count != 0}
                        .distinctUntilChanged()

            selected = state.compactMap { $0.navigation.root.currentItem as? Item }
                            .distinctUntilChanged()
        } else {
            items = state.map { $0.navigation.root.stacks.compactMap { $0.0.base as? Item }}
                        .filter { $0.count != 0}
                        .distinctUntilChanged()

            selected = state.compactMap { $0.navigation.root.currentItem.base as? Item }
                        .distinctUntilChanged()
        }
    }
}

public typealias CaseIterableNavigationItem = NavigationItem & CaseIterable

public protocol NavigationItem: Hashable {
    var action: StoreAction { get }
}

public struct AnyNavigationItem: NavigationItem {

    public let action: StoreAction

    let base: Any

    public init<T: NavigationItem>(_ tab: T) {

        action = tab.action

        base = tab

        isEqual = { t in
            guard let t = t.base as? T else { return false }
            return tab == t
        }

        _hash = { hasher in
            tab.hash(into: &hasher)
        }
    }

    public func hash(into hasher: inout Hasher) {
        _hash(&hasher)
    }

    private var isEqual: (AnyNavigationItem) -> Bool
    private var _hash: (inout Hasher) -> Void

    public static func == (lhs: AnyNavigationItem, rhs: AnyNavigationItem) -> Bool {
        lhs.isEqual(rhs)
    }

}

extension NavigationItem {

    public var any: AnyNavigationItem {
        return AnyNavigationItem(self)
    }
}

extension Collection where Element: NavigationItem {
    public var any: [AnyNavigationItem] {
        return map { $0.any }
    }
}
