import Foundation
import ReactiveSwift
import enum Result.NoError

public struct Feedback<State, Event> {
    public let events: (Signal<State, NoError>) -> Signal<Event, NoError>

    public init(_ events: @escaping (Signal<State, NoError>) -> Signal<Event, NoError>) {
        self.events = events
    }

    public init<Control: Equatable, Effect: SignalProducerConvertible>(
        query: @escaping (State) -> Control?,
        effects: @escaping (Control) -> Effect
    ) where Effect.Value == Event, Effect.Error == NoError {
        self.events = { state in
            return state
                .map(query)
                .skipRepeats { $0 == $1 }
                .flatMap(.latest) { control -> SignalProducer<Event, NoError> in
                    guard let control = control else { return .empty }
                    return effects(control).producer
                }
        }
    }

    public init<Control, Effect: SignalProducerConvertible>(
        query: @escaping (State) -> Control?,
        effects: @escaping (Control) -> Effect
    ) where Effect.Value == Event, Effect.Error == NoError {
        self.events = { state in
            return state
                .map(query)
                .flatMap(.latest) { control -> SignalProducer<Event, NoError> in
                    guard let control = control else { return .empty }
                    return effects(control).producer
                }
        }
    }

    public init<Effect: SignalProducerConvertible>(
        predicate: @escaping (State) -> Bool,
        effects: @escaping (State) -> Effect
    ) where Effect.Value == Event, Effect.Error == NoError {
        self.events = { state in
            return state.flatMap(.latest) { state -> SignalProducer<Event, NoError> in
                guard predicate(state) else { return .empty }
                return effects(state).producer
            }
        }
    }

    public init<Effect: SignalProducerConvertible>(
        effects: @escaping (State) -> Effect
    ) where Effect.Value == Event, Effect.Error == NoError {
        self.events = { state in
            return state.flatMap(.latest) { state -> SignalProducer<Event, NoError> in
                return effects(state).producer
            }
        }
    }
}
