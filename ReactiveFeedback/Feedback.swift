import Foundation
import ReactiveSwift
import enum Result.NoError

public struct Feedback<State, Event> {
    public let events: (Scheduler, Signal<State, NoError>) -> Signal<Event, NoError>

    public init<Control: Equatable, Effect: SignalProducerConvertible>(
        query: @escaping (State) -> Control?,
        effects: @escaping (Control) -> Effect
    ) where Effect.Value == Event, Effect.Error == NoError {
        self.events = { scheduler, state in
            return state
                .map(query)
                .skipRepeats { $0 == $1 }
                .flatMap(.latest) { control -> SignalProducer<Event, NoError> in
                    guard let control = control else { return .empty }
                    return effects(control).producer
                        .enqueue(on: scheduler)
                }
        }
    }

    public init<Control, Effect: SignalProducerConvertible>(
        query: @escaping (State) -> Control?,
        effects: @escaping (Control) -> Effect
    ) where Effect.Value == Event, Effect.Error == NoError {
        self.events = { scheduler, state in
            return state
                .map(query)
                .flatMap(.latest) { control -> SignalProducer<Event, NoError> in
                    guard let control = control else { return .empty }
                    return effects(control).producer
                        .enqueue(on: scheduler)
                }
        }
    }

    public init<Effect: SignalProducerConvertible>(
        predicate: @escaping (State) -> Bool,
        effects: @escaping (State) -> Effect
    ) where Effect.Value == Event, Effect.Error == NoError {
        self.events = { scheduler, state in
            return state
                .flatMap(.latest) { state -> SignalProducer<Event, NoError> in
                    guard predicate(state) else { return .empty }
                    return effects(state).producer
                        .enqueue(on: scheduler)
            }
        }
    }

    public init<Effect: SignalProducerConvertible>(
        effects: @escaping (State) -> Effect
    ) where Effect.Value == Event, Effect.Error == NoError {
        self.events = { scheduler, state in
            return state.flatMap(.latest) { state -> SignalProducer<Event, NoError> in
                return effects(state).producer
                    .enqueue(on: scheduler)
            }
        }
    }
}

fileprivate extension SignalProducer {
    func enqueue(on scheduler: Scheduler) -> SignalProducer<Value, Error> {
        return start(on: scheduler)
            .observe(on: scheduler)
    }
}

