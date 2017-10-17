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
import enum Result.NoError

enum Event {
    case increment
    case decrement
}

class ViewController: UIViewController {
    @IBOutlet weak var plussButton: UIButton!
    @IBOutlet weak var minusButton: UIButton!
    @IBOutlet weak var label: UILabel!

    private var incrementSignal: Signal<Void, NoError> {
        return plussButton.reactive.controlEvents(.touchUpInside).map { _ in }
    }

    private var decrementSignal: Signal<Void, NoError> {
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

    init(increment: Signal<Void, NoError>, decrement: Signal<Void, NoError>) {

        let incrementFeedback = FeedbackLoop<Int, Event>(
            predicate: { $0 < 10 },
            effects: { _ in
                return increment.map { _ in Event.increment }
            }
        )

        let decrementFeedback = FeedbackLoop<Int, Event>(
            predicate: { $0 > -10 },
            effects: { _ in
                return decrement.map { _ in Event.decrement }
            }
        )

        state = Property(initial: 0,
                         reduce: IncrementReducer.reduce,
                         feedbacks: incrementFeedback, decrementFeedback)

        counter = state.map(String.init)
    }
}

struct IncrementReducer {
    static func reduce(state: Int, event: Event) -> Int {
        switch event {
        case .increment:
            return state + 1
        case .decrement:
            return state - 1
        }
    }
}

