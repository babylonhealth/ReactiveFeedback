import Foundation
import ReactiveSwift
import enum Result.NoError

extension SignalProducer where Error == NoError {
    public static func system<Event>(
        initial: Value,
        scheduler: Scheduler = QueueScheduler.main,
        reduce: @escaping (Value, Event) -> Value,
        feedbacks: [FeedbackLoop<Value, Event>]
    ) -> SignalProducer<Value, NoError> {
        return SignalProducer.deferred {
            let (state, observer) = Signal<Value, NoError>.pipe()

            let events = feedbacks.map { feedback in
                return feedback.loop(scheduler, state)
            }

            return SignalProducer<Event, NoError>(Signal.merge(events))
                .scan(initial, reduce)
                .prefix(value: initial)
                .on(value: observer.send(value:))
        }
    }

    public static func system<Event>(
        initial: Value,
        reduce: @escaping (Value, Event) -> Value,
        feedbacks: FeedbackLoop<Value, Event>...
    ) -> SignalProducer<Value, Error> {
        return system(initial: initial, reduce: reduce, feedbacks: feedbacks)
    }
}

extension SignalProducerProtocol {
    static func deferred(_ signalProducerFactory: @escaping () -> SignalProducer<Value, Error>) -> SignalProducer<Value, Error> {
        return SignalProducer<Void, Error>(value: ())
            .flatMap(.merge, signalProducerFactory)
    }
}
