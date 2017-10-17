import Foundation
import ReactiveSwift
import enum Result.NoError

public typealias Reducer<State, Event> = (State, Event) -> State

private struct FeedbackGate<Event> {
    var isTransitioning: Bool = false
    var queue: [Event] = []

    mutating func dequeueOrComplete() -> Event? {
        guard queue.isEmpty
            else { return queue.removeFirst() }
        isTransitioning = false
        return nil
    }
}

extension Property {
    /// Initialize a finite state machine.
    ///
    /// - parameters:
    ///   - initial: The initial state.
    ///   - reduce: The reducer to compute the new state from the current state and the
    ///             given event.
    ///   - feedbacks: The feedback streams that transforms the current state into side
    ///                effects and yield events conditionally.
    ///
    /// - returns: A `Property` that represents the current state of the finite state
    ///            machine.
    public convenience init<Event>(
        initial: Value,
        reduce: @escaping Reducer<Value, Event>,
        feedbacks: [FeedbackLoop<Value, Event>]
    ) {
        let state = MutableProperty(initial)
        let feedbackEvents = feedbacks.map { $0.loop(state.producer) }
        let feedbackGate = Atomic(FeedbackGate<Event>(isTransitioning: true, queue: []))

        SignalProducer.merge(feedbackEvents)
            .startWithValues { event in
                let canProceed: Bool = feedbackGate.modify { gate in
                    guard gate.isTransitioning else {
                        gate.isTransitioning = true
                        return true
                    }

                    gate.queue.append(event)
                    return false
                }

                guard canProceed else { return }

                state.modify { $0 = reduce($0, event) }
                while let event = feedbackGate.modify({ $0.dequeueOrComplete() }) {
                    state.modify { $0 = reduce($0, event) }
                }
            }

        while let event = feedbackGate.modify({ $0.dequeueOrComplete() }) {
            state.modify { $0 = reduce($0, event) }
        }

        self.init(capturing: state)
    }

    /// Initialize a finite state machine.
    ///
    /// - parameters:
    ///   - initial: The initial state.
    ///   - reduce: The reducer to compute the new state from the current state and the
    ///             given event.
    ///   - feedbacks: The feedback streams that transforms the current state into side
    ///                effects and yield events conditionally.
    ///
    /// - returns: A `Property` that represents the current state of the finite state
    ///            machine.
    public convenience init<Event>(
        initial: Value,
        reduce: @escaping Reducer<Value, Event>,
        feedbacks: FeedbackLoop<Value, Event>...
    ) {
        self.init(initial: initial, reduce: reduce, feedbacks: feedbacks)
    }
}
