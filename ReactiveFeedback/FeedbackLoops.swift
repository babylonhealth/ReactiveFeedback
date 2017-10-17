import Foundation
import ReactiveSwift
import enum Result.NoError

public struct FeedbackLoop<State, Event> {
    let loop: (SignalProducer<State, NoError>) -> SignalProducer<Event, NoError>

    public init<Control:Equatable, Effect:SignalProducerConvertible>(query: @escaping (State) -> Control?,
                                                                     effects: @escaping (Control) -> Effect) where Effect.Error == NoError, Effect.Value == Event {
        self.loop = { state in
            return state.map(query)
                .skipRepeats { $0 == $1 }
                .flatMap(.latest) { control -> SignalProducer<Event, NoError> in
                    guard let control = control else { return SignalProducer<Event, NoError>.empty }
                    return effects(control).producer
                }
        }
    }

    public init<Control, Effect:SignalProducerConvertible>(query: @escaping (State) -> Control?,
                                                           effects: @escaping (Control) -> Effect) where Effect.Error == NoError, Effect.Value == Event {
        self.loop = { state in
            return state.map(query)
                .flatMap(.latest) { control -> SignalProducer<Event, NoError> in
                    guard let control = control else { return SignalProducer<Event, NoError>.empty }
                    return effects(control).producer
                }
        }
    }

    public init<Effect:SignalProducerConvertible>(predicate: @escaping (State) -> Bool,
                                                  effects: @escaping (State) -> Effect) where Effect.Error == NoError, Effect.Value == Event {
        self.loop = { state in
            return state.flatMap(.latest) { state -> SignalProducer<Event, NoError> in
                guard predicate(state) else { return SignalProducer<Event, NoError>.empty }
                return effects(state).producer
            }
        }
    }

    public init<Effect:SignalProducerConvertible>(effects: @escaping (State) -> Effect) where Effect.Error == NoError, Effect.Value == Event {
        self.loop = { state in
            return state.flatMap(.latest) { state -> SignalProducer<Event, NoError> in
                return effects(state).producer
            }
        }
    }
}
