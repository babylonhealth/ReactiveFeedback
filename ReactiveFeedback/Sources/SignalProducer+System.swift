import Foundation
import ReactiveSwift
import enum Result.NoError

public typealias Reducer<State, Event> = (State, Event) -> State

extension SignalProducerProtocol where Error == NoError {

    public static func system<Event>(initial: Value,
                                     scheduler: Scheduler = QueueScheduler.main,
                                     reduce: @escaping Reducer<Value, Event>,
                                     feedbacks: [Feedback<Value, Event>]) -> SignalProducer<Value, NoError> {
        return SignalProducer.deferred {
            let (subject, observer) = Signal<Value, NoError>.pipe()
            let events = Signal<Event, NoError>.merge(feedbacks.map { feedback in
                return feedback.events(scheduler, subject)
            })
            return SignalProducer(events.scan(initial, reduce))
                .prefix(value: initial)
                .on(value: observer.send(value:))
        }
    }

    public static func system<Event>(initial: Value,
                                     scheduler: Scheduler = QueueScheduler.main,
                                     reduce: @escaping Reducer<Value, Event>,
                                     feedbacks: Feedback<Value, Event>...) -> SignalProducer<Value, Error> {
        return system(initial: initial,
                      scheduler: scheduler,
                      reduce: reduce,
                      feedbacks: feedbacks)
    }
}

extension SignalProducerProtocol {
    static func deferred(_ signalProducerFactory: @escaping () -> SignalProducer<Value, Error>) -> SignalProducer<Value, Error> {
        return SignalProducer<Void, Error>(value: ())
            .flatMap(.merge, signalProducerFactory)
    }
}
