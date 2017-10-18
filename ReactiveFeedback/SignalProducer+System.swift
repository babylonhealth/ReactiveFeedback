import Foundation
import ReactiveSwift
import enum Result.NoError

extension SignalProducer where Error == NoError {
    public static func system<Event>(
        initial: Value,
        scheduler: Scheduler = QueueScheduler.main,
        reduce: @escaping (Value, Event) -> Value,
        feedbacks: [Feedback<Value, Event>]
    ) -> SignalProducer<Value, NoError> {
        return SignalProducer { observer, lifetime in
            let (state, stateObserver) = Signal<Value, NoError>.pipe()

            let events = feedbacks.map { feedback in
                return feedback.events(scheduler, state)
            }

            lifetime += SignalProducer<Event, NoError>(Signal.merge(events))
                .scan(initial, reduce)
                .prefix(value: initial)
                .on(value: stateObserver.send(value:))
                .start(observer)
        }
    }

    public static func system<Event>(
        initial: Value,
        reduce: @escaping (Value, Event) -> Value,
        feedbacks: Feedback<Value, Event>...
    ) -> SignalProducer<Value, Error> {
        return system(initial: initial, reduce: reduce, feedbacks: feedbacks)
    }
}
