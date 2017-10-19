import Foundation
import ReactiveSwift
import enum Result.NoError

extension SignalProducer where Error == NoError {

    /**
    Feedback controlled State Machine
    System state is represented as a `State` parameter.
    Events are represented by `Event` parameter. It represents all possible events that may occur in the System
    Feedback defines an effects that may change the State.

    - parameters:
        - initial: Initial state of the system.
        - reduce: Reduces current State of the System by applying Even.
        - feedbacks: Feedback loops that produce events depending on current system state.
        - returns: SignalProducer that emits current state of the System
    */
    public static func system<Event>(
        initial: Value,
        scheduler: Scheduler = QueueScheduler.main,
        reduce: @escaping (Value, Event) -> Value,
        feedbacks: [Feedback<Value, Event>]
    ) -> SignalProducer<Value, NoError> {
        return SignalProducer.deferred {
            let (state, observer) = Signal<Value, NoError>.pipe()

            let events = feedbacks.map { feedback in
                return feedback.events(scheduler, state)
            }

            return SignalProducer<Event, NoError>(Signal.merge(events))
                .scan(initial, reduce)
                .prefix(value: initial)
                .on(value: observer.send(value:))
        }
    }

    /**
    Feedback controlled State Machine
    System state is represented as a `State` parameter.
    Events are represented by `Event` parameter. It represents all possible events that may occur in the System
    Feedback defines an effects that may change the State.

    - parameters:
        - initial: Initial state of the system.
        - reduce: Reduces current State of the System by applying Even.
        - feedbacks: Feedback loops that produce events depending on current system state.
        - returns: SignalProducer that emits current state of the System
    */
    public static func system<Event>(
        initial: Value,
        scheduler: Scheduler = QueueScheduler.main,
        reduce: @escaping (Value, Event) -> Value,
        feedbacks: Feedback<Value, Event>...
    ) -> SignalProducer<Value, Error> {
        return system(initial: initial, reduce: reduce, feedbacks: feedbacks)
    }
}

extension SignalProducerProtocol {
    static func deferred(_ signalProducerFactory: @escaping () -> SignalProducer<Value, Error>) -> SignalProducer<Value, Error> {
        return SignalProducer<Void, Error>(value: ())
            .flatMap(.merge, signalProducerFactory)
    }

    func enqueue(on scheduler: Scheduler) -> SignalProducer<Value, Error> {
        return producer.start(on: scheduler)
            .observe(on: scheduler)
    }
}
