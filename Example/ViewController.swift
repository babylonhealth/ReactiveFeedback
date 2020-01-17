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

enum Event {
    case increment
    case decrement
}

class ViewController: UIViewController {
    @IBOutlet weak var plusButton: UIButton!
    @IBOutlet weak var minusButton: UIButton!
    @IBOutlet weak var label: UILabel!

    private var incrementSignal: Signal<Void, Never> {
        return plusButton.reactive.controlEvents(.touchUpInside).map { _ in }
    }

    private var decrementSignal: Signal<Void, Never> {
        return minusButton.reactive.controlEvents(.touchUpInside).map { _ in }
    }

    lazy var viewModel: ViewModel = {
        return ViewModel(increment: self.incrementSignal,
                         decrement: self.decrementSignal)
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        label.reactive.text <~ viewModel.counter
    }
}

final class ViewModel {
    private let state: Property<Int>
    let counter: Property<String>

    init(increment: Signal<Void, Never>, decrement: Signal<Void, Never>) {

        let incrementFeedback = Feedback<Int, Event>(
            condition: { $0 < 10 },
            whenBecomesTrue: { _ in
                increment.map { _ in Event.increment }
            }
        )

        let decrementFeedback = Feedback<Int, Event>(
            condition: { $0 > -10 },
            whenBecomesTrue: { _ in
                decrement.map { _ in Event.decrement }
            }
        )

        self.state = Property(initial: 0,
                              reduce: ViewModel.reduce,
                              feedbacks: incrementFeedback, decrementFeedback)

        self.counter = state.map(String.init)
    }
}

extension ViewModel {
    static func reduce(state: Int, event: Event) -> Int {
        switch event {
        case .increment:
            return state + 1
        case .decrement:
            return state - 1
        }
    }
}
