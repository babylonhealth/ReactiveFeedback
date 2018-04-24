import Foundation
import ReactiveSwift
import enum Result.NoError

extension SignalProducer where Error == NoError {

    /// Feedback-controlled State Machine. The system state is represented as a `State` parameter.
    /// Events are represented by an `Event` parameter. It represents all the possible Events that may occur in the System
    /// Feedback defines an effect that may change the State.

    /// - parameters:
    ///     - initial: An initial `State` of the system.
    ///     - scheduler: A Scheduler used for Events synchronisation
    ///     - reduce: A function that produces a new State of a system by applying an Event
    ///     - feedbacks: A Feedback loops that produces Events depending on the system's `State`
    ///     - returns: A SignalProducer that emits current the state of the System
    public static func system<Event>(
        initial: Value,
        scheduler: Scheduler = QueueScheduler.main,
        reduce: @escaping (Value, Event) -> Value,
        feedbacks: [Feedback<Value, Event>]
    ) -> SignalProducer<Value, NoError> {
        return SignalProducer.deferred {
            let (state, stateObserver) = Signal<Value, NoError>.pipe()

            let events = feedbacks.map { feedback in
                return feedback.events(scheduler, state)
            }

            return SignalProducer<Event, NoError>(Signal.merge(events))
                .scan(initial, reduce)
                .prefix(value: initial)
                .on(value: stateObserver.send(value:))
        }
    }

    /// Feedback-controlled State Machine. The system state is represented as a `State` parameter.
    /// Events are represented by `Event` parameter. It represents all possible Events that may occur in the System
    /// Feedback defines an effect that may change the State.

    /// - parameters:
    ///     - initial: An initial `State` of the system.
    ///     - scheduler: A Scheduler used for Events synchronisation
    ///     - reduce: A that produces a new State of the system by applying an Event
    ///     - feedbacks: A Feedback loops that produces Events depending on the system's state.
    ///     - returns: A SignalProducer that emits current the state of the System
    public static func system<Event>(
        initial: Value,
        scheduler: Scheduler = QueueScheduler.main,
        reduce: @escaping (Value, Event) -> Value,
        feedbacks: Feedback<Value, Event>...
    ) -> SignalProducer<Value, Error> {
        return system(initial: initial, reduce: reduce, feedbacks: feedbacks)
    }

    private static func deferred(_ producer: @escaping () -> SignalProducer<Value, Error>) -> SignalProducer<Value, Error> {
        return SignalProducer { $1 += producer().start($0) }
    }
}
