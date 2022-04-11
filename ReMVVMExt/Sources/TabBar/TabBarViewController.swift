//
//  TabBarViewController.swift
//  BNCommon
//
//  Created by Grzegorz Jurzak on 12/02/2019.
//  Copyright © 2019 HYD. All rights reserved.
//

import Loaders
import ReMVVM
import RxCocoa
import RxSwift
import UIKit

public struct NavigationConfig {

    public typealias TabBarItems<T> = (_ tabBar: UITabBar, _ items: [TabBarItem<T>]) -> TabBarItemsResult where T: NavigationItem

    public typealias CustomControls<T> = (_ tabBar: UITabBar, _ items: [T]) -> CustomControlsResult where T: NavigationItem

    public typealias Custom<T> = (_ items: [T]) -> NavigationContainerController where T: NavigationItem

    public enum ConfigError: Error {
        case toManyElements
    }

    public init<T>(_ creator: @escaping TabBarItems<T>, for type: T.Type = T.self) throws where T: CaseIterableNavigationItem {
        guard T.allCases.count <= 5 else { throw ConfigError.toManyElements }

        navigationType = T.navigationType
        config = .uiTabBar { tabBar, items in
            return creator(tabBar, items.compactMap {
                guard let item = $0.item.base as? T else { return nil }
                return TabBarItem<T>(item: item, uiTabBarItem: $0.uiTabBarItem)
            })
        }
    }

    public init<T>(_ creator: @escaping CustomControls<T>, for type: T.Type = T.self) where T: CaseIterableNavigationItem {

        navigationType = T.navigationType
        config = .customTabBar { tabBar, items in
            creator(tabBar, items.compactMap { $0.base as? T })
        }
    }

    public init<T>(_ creator: @escaping Custom<T>, for type: T.Type = T.self) where T: CaseIterableNavigationItem {

        navigationType = T.navigationType
        config = .custom { items in
            return creator(items.compactMap {$0.base as? T})
        }
    }

    let navigationType: NavigationType
    let config: Config<AnyNavigationItem>
    enum Config<T> where T: NavigationItem {

        case uiTabBar(TabBarItems<T>)
        case customTabBar(CustomControls<T>)
        case custom(Custom<T>)
    }
}

public struct TabBarItem<T> {
    public let item: T
    public let uiTabBarItem: UITabBarItem
}

public struct TabBarItemsResult {
    public let height: (() -> CGFloat)?
    public let overlay: UIView?

    public init(height: (() -> CGFloat)? = nil, overlay: UIView? = nil) {
        self.height = height
        self.overlay = overlay
    }
}

public struct CustomControlsResult {
    public let height: (() -> CGFloat)?
    public let overelay: UIView
    public let controls: [UIControl]

    public init(height: (() -> CGFloat)? = nil, overelay: UIView, controls: [UIControl]) {
        self.height = height
        self.overelay = overelay
        self.controls = controls
    }
}


// TAB BAR CONTROLLER IMPLEMENTATION - cleanup needed :)

private class TabBar: UITabBar {

    var customView: UIView? {
        didSet {
            oldValue?.removeFromSuperview()
            guard let customView = customView else { return }
            customView.frame = bounds
            addSubview(customView)
        }
    }

    var controlItems: [UIControl]?

    var height: (() -> CGFloat)? {
        didSet {
            _height = height?()
            setNeedsLayout()
        }
    }

    private var _height: CGFloat?

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        _height = height?()

        customView?.frame = bounds
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func setItems(_ items: [UITabBarItem]?, animated: Bool) {

        super.setItems(items, animated: animated)
        guard controlItems != nil else { return }
        subviews
            .compactMap { $0 as? UIControl }
            .filter { $0 != customView }
            .forEach { $0.removeFromSuperview() }
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        var size = super.sizeThatFits(size)
        if let height = _height {
            size.height = height + safeAreaInsets.bottom
        }
        return size
    }

    var _selectedItem: UITabBarItem? {
        didSet {
            if  _selectedItem != oldValue,
                let tabBarItem = _selectedItem as? TabItem,
                let control = tabBarItem.controlItem {

                controlItems?.forEach {
                    $0.isSelected = $0 == control
                }
            }
        }
    }

    override var selectedItem: UITabBarItem? {
        set {
            super.selectedItem = newValue
            _selectedItem = newValue
        }

        get {
            _selectedItem
        }
    }
}

class TabItem: UITabBarItem {

    let navigationTab: AnyNavigationItem
    let controlItem: UIControl?

    init(navigationTab: AnyNavigationItem, controlItem: UIControl?) {
        self.navigationTab = navigationTab
        self.controlItem = controlItem
        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class ContainerViewController: UIViewController {
    let currentNavigationController: UINavigationController

    init(navigationController: UINavigationController) {
        self.currentNavigationController = navigationController
        super.init(nibName: nil, bundle: nil)

        navigationController.willMove(toParent: self)
        addChild(navigationController)
        view.addSubview(navigationController.view)
        navigationController.didMove(toParent: self)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class TabBarViewController: UITabBarController, NavigationContainerController, ReMVVMDriven {
    init(config: NavigationConfig?, navigationControllerFactory: @escaping () -> UINavigationController) {
        self.config = config
        self.navigationControllerFactory = navigationControllerFactory
        super.init(nibName: nil, bundle: nil)
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private var containers: [ContainerViewController]? {
        viewControllers?.compactMap { $0 as? ContainerViewController }
    }

    public var currentNavigationController: UINavigationController? {
        guard selectedIndex >= 0 && selectedIndex < containers?.count ?? 0 else { return nil }
        return containers?[selectedIndex].currentNavigationController
    }

    private var config: NavigationConfig?
    private var navigationControllerFactory: () -> UINavigationController

    @Provided private var viewModel: NavigationViewModel<AnyNavigationItem>?

    override open var childForStatusBarStyle: UIViewController? {
        return currentNavigationController?.topViewController
    }

    private var customTabBar: TabBar { return tabBar as! TabBar}

    open override func viewDidLoad() {
        setValue(TabBar(), forKey: "tabBar")
        super.viewDidLoad()

        delegate = self
        guard let viewModel = viewModel else { return }

        viewModel.items.subscribe(onNext: { [unowned self] items in
            self.setup(items: items)
        }).disposed(by: disposeBag)

        viewModel.selected.subscribe(onNext: { [unowned self] item in
            self.setup(current: item)
        }).disposed(by: disposeBag)
    }

    private let disposeBag = DisposeBag()
    private func setup(items: [AnyNavigationItem]) {

        let tabItems: [UITabBarItem]
        if case let .customTabBar(configurator) = config?.config {

            let result = configurator(customTabBar, items)
            customTabBar.height = result.height
            let customView = result.overelay
            let controlItems = result.controls

            controlItems.enumerated().forEach { index, elem in
                elem.rx.controlEvent(.touchUpInside).subscribe(onNext: { [unowned self] in
                    if let viewController = self.viewControllers?[index] {
                        self.sendAction(for: viewController)
                    }
                }).disposed(by: disposeBag)
            }

            tabItems = zip(items, controlItems).map {
                TabItem(navigationTab: $0, controlItem: $1)
            }

            customTabBar.customView = customView
            customTabBar.controlItems = controlItems

            moreNavigationController.navigationBar.isHidden = true

        } else {
            let tabBarItems: [TabItem] = items.map { TabItem(navigationTab: $0, controlItem: nil) }

            tabItems = tabBarItems

            if case let .uiTabBar(configurator) = config?.config {
                let result = configurator(customTabBar, tabBarItems.map { TabBarItem(item: $0.navigationTab, uiTabBarItem: $0) })
                customTabBar.customView = result.overlay
                customTabBar.controlItems = nil
                customTabBar.height = result.height
            } else {
                customTabBar.customView = nil
                customTabBar.controlItems = nil
                customTabBar.height = nil
            }

            moreNavigationController.navigationBar.isHidden = false
        }

        viewControllers = tabItems.map { tab in
            let controller = ContainerViewController(navigationController: navigationControllerFactory())
            controller.tabBarItem = tab
            return controller
        }
    }
    
    private func setup(current: AnyNavigationItem) {

        let selected = viewControllers?.first {
            guard let tab = $0.tabBarItem as? TabItem else { return false }
            return current == tab.navigationTab
        }

        guard selected != nil else { return }
        selectedViewController = selected
        customTabBar._selectedItem = selectedViewController?.tabBarItem
    }

    private func sendAction(for viewController: UIViewController) {
        guard let tab = viewController.tabBarItem as? TabItem else { return }

        if viewController != selectedViewController {
            remvvm.dispatch(action: tab.navigationTab.action)
        } else {
            remvvm.dispatch(action: Pop(mode: .popToRoot, animated: true))
        }
    }

}

extension TabBarViewController: UITabBarControllerDelegate {

    public func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        DispatchQueue.main.async {
            self.sendAction(for: viewController)
        }
        return false
    }
}

