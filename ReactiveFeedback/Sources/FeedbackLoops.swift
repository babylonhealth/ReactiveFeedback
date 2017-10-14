import Foundation
import ReactiveSwift
import enum Result.NoError

public struct FeedbackLoop<State, Event> {
    let loop: (Scheduler, Signal<State, NoError>) -> Signal<Event, NoError>

    public init<Control:Equatable, Effect:SignalProducerConvertible>(query: @escaping (State) -> Control?,
                                                                     effects: @escaping (Control) -> Effect) where Effect.Error == NoError, Effect.Value == Event {
        self.loop = { (scheduler, state) in
            return state.map(query)
                .skipRepeats { $0 == $1 }
                .flatMap(.latest) { control -> SignalProducer<Event, NoError> in
                    guard let control = control else { return SignalProducer<Event, NoError>.empty }
                    return effects(control).producer
                        .enqueue(on: scheduler)
                }
        }
    }

    public init<Effect:SignalProducerConvertible>(predicate: @escaping (State) -> Bool,
                                                  effects: @escaping (State) -> Effect) where Effect.Error == NoError, Effect.Value == Event {
        self.loop = { (scheduler, state) in
            return state.flatMap(.latest) { state -> SignalProducer<Event, NoError> in
                guard predicate(state) else { return SignalProducer<Event, NoError>.empty }
                return effects(state).producer
                    .enqueue(on: scheduler)
            }
        }
    }

    public init<Effect:SignalProducerConvertible>(effects: @escaping (State) -> Effect) where Effect.Error == NoError, Effect.Value == Event {
        self.loop = { scheduler, state in
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

