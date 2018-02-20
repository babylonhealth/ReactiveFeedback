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
    public static func system2<Event>(
        initial: Value,
        scheduler: Scheduler = QueueScheduler.main,
        reduce: @escaping (Value, Event) -> Value,
        feedbacks: [Feedback<Value, Event>]
    ) -> SignalProducer<Value, NoError> {
        return SignalProducer { observer, lifetime in
            let (state, stateObserver) = Signal<Value, NoError>.pipe()

            lifetime += Signal.merge(feedbacks.map { $0.events(ImmediateScheduler(), state) })
                .producer
                .scan(initial, reduce)
                .prefix(value: initial)
                .on(value: observer.send(value:))
                .startWithValues { newState in
                    scheduler.schedule {
                        stateObserver.send(value: newState)
                    }
                }
        }
        /*
        return SignalProducer { observer, lifetime in
            let state = MutableProperty(initial)
            let feedbacks = feedbacks.map { $0.events(state.producer) }
            let feedbackGate = Atomic(FeedbackGate<Event>(isTransitioning: true, queue: []))

            let val = SignalProducer<Event, NoError>.merge(feedbacks)

            lifetime += val.startWithValues { event in
                let canProceed: Bool = feedbackGate.modify { gate in
                    guard gate.isTransitioning else {
                        gate.isTransitioning = true
                        return true
                    }

                    gate.queue.append(event)
                    return false
                }

                guard canProceed else { return }

                state.modify { oldState in
                    let newState = reduce(oldState, event)
                    oldState = newState
                    observer.send(value: newState)
                }
                while let event = feedbackGate.modify({ $0.dequeueOrComplete() }) {
                    state.modify { oldState in
                        let newState = reduce(oldState, event)
                        oldState = newState
                        observer.send(value: newState)
                    }
                }
            }
            observer.send(value: initial)
            while let event = feedbackGate.modify({ $0.dequeueOrComplete() }) {
                state.modify { oldState in
                    let newState = reduce(oldState, event)
                    oldState = newState
                    observer.send(value: newState)
                }
            }
        }*/
    }

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

    func enqueue(on scheduler: Scheduler) -> SignalProducer<Value, Error> {
        return producer
//            .start(on: scheduler)
            .observe(on: scheduler)
    }
}

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
