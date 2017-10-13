import Foundation
import ReactiveSwift
import enum Result.NoError

public struct FeedbackLoop<State, Event> {
    let loop: (Scheduler, Signal<State, NoError>) -> Signal<Event, NoError>

    init(_ loop: @escaping (Scheduler, Signal<State, NoError>) -> Signal<Event, NoError>) {
        self.loop = loop
    }
}

extension FeedbackLoop {
    public static func feedback<Control:Equatable, Inner: SignalProducerConvertible>(query: @escaping (State) -> Control?,
                                                   effects: @escaping (Control) -> Inner) -> FeedbackLoop<State, Event> where Inner.Error == NoError, Inner.Value == Event {
        return FeedbackLoop { scheduler, state in
            return state.map(query)
                .skipRepeats { $0 == $1 }
                .flatMap(.latest, { control -> SignalProducer<Event, NoError> in
                    guard let control = control else { return SignalProducer<Event, NoError>.empty }
                    return effects(control).producer
                        .enqueue(on: scheduler)
                })
        }
    }

    public static func feedback<Inner: SignalProducerConvertible>(predicate: @escaping (State) -> Bool,
                                effects: @escaping (State) -> Inner) -> FeedbackLoop<State, Event> where Inner.Error == NoError, Inner.Value == Event {
        return FeedbackLoop { scheduler, state in
            return state.flatMap(.latest, { state -> SignalProducer<Event, NoError> in
                    guard predicate(state) else { return SignalProducer<Event, NoError>.empty }
                    return effects(state).producer
                        .enqueue(on: scheduler)
                })
        }
    }

    public static func feedback<Inner: SignalProducerConvertible>(effects: @escaping (State) -> Inner) -> FeedbackLoop<State, Event> where Inner.Error == NoError, Inner.Value == Event {
        return FeedbackLoop { scheduler, state in
            return state.flatMap(.latest) { state -> SignalProducer<Event, NoError> in
                return effects(state).producer
                    .enqueue(on: scheduler)
            }
        }
    }
}

extension SignalProducer {
    func enqueue(on scheduler: Scheduler) -> SignalProducer<Value, Error> {
        return start(on: scheduler)
            .observe(on: scheduler)
    }
}

