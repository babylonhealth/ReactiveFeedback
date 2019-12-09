//
//  ViewController.swift
//  ReactiveFeedback
//
//  Created by sergdort on 28/08/2017.
//  Copyright © 2017 sergdort. All rights reserved.
//

import UIKit
import ReactiveSwift
import ReactiveCocoa
import ReactiveFeedback

class ViewController: UIViewController {
    @IBOutlet weak var plusButton: UIButton!
    @IBOutlet weak var minusButton: UIButton!
    @IBOutlet weak var label: UILabel!
    private lazy var contentView = CounterView.loadFromNib()

    private var incrementSignal: Signal<Void, Never> {
        return plusButton.reactive.controlEvents(.touchUpInside).map { _ in }
    }

    private var decrementSignal: Signal<Void, Never> {
        return minusButton.reactive.controlEvents(.touchUpInside).map { _ in }
    }

    private let viewModel = Counter.ViewModel()

    override func loadView() {
        self.view = contentView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        viewModel.state.producer.startWithValues(contentView.render)
    }
}

extension Counter {
    final class ViewModel: Store<State, Event> {
        init() {
            super.init(
                initial: State(),
                reducer: Counter.reduce,
                feedbacks: [],
                scheduler: QueueScheduler.main
            )
        }
    }
}
