//
//  ViewModelProvided.swift
//  ReMVVMExt
//
//  Created by Dariusz Grzeszczak on 10/10/2019.
//

import Loaders
import ReMVVM

#if swift(>=5.1)
@propertyWrapper
public struct ViewModelProvided<VMD> where VMD: ViewModelDriven {

    public var wrappedValue: VMD? {
        didSet {
            guard   let responder = wrappedValue,
                    let viewModel = viewModel.wrappedValue
            else { return }
            responder.viewModel = viewModel
        }
    }

    private var viewModel: Provided<VMD.ViewModelType>
    public init() {
        viewModel = Provided()
    }
    public init(key: String) {
        viewModel = Provided(key: key)
    }
}
#endif
