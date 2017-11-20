import Foundation
import ReactiveSwift
import enum Result.NoError

extension SignalProducer where Error == NoError {

    /// Feedback controlled State Machine. The system state is represented as a `State` parameter.
    /// Events are represented by `Event` parameter. It represents all possible events that may occur in the System
    /// Feedback defines an effects that may change the State.

    /// - parameters:
    ///     - initial: An initial state of the system.
    ///     - scheduler: A Scheduler used for Events synchronisation
    ///     - reduce: A function that produces a new State of a system by applying an Event
    ///     - feedbacks: A Feedback loops that produce events depending on system's state.
    ///     - returns: A SignalProducer that emits current state of the System
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

    /// Feedback controlled State Machine. The system state is represented as a `State` parameter.
    /// Events are represented by `Event` parameter. It represents all possible events that may occur in the System
    /// Feedback defines an effects that may change the State.

    /// - parameters:
    ///     - initial: An initial state of the system.
    ///     - scheduler: A Scheduler used for Events synchronisation
    ///     - reduce: A that produces a new State of the system by applying an Event
    ///     - feedbacks: A Feedback loops that produce events depending on system's state.
    ///     - returns: A SignalProducer that emits current state of the System
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

    func enqueue(on scheduler: Scheduler) -> SignalProducer<Value, Error> {
        return producer.start(on: scheduler)
            .observe(on: scheduler)
    }
}
