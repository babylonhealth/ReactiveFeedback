import Foundation
import ReactiveSwift
import enum Result.NoError

public struct Feedback<State, Event> {
    let events: (Scheduler, Signal<State, NoError>) -> Signal<Event, NoError>
    
    /// Creates an arbitrary Feedback, by transforming a sequence of State to a sequence of Events that mutate the State
    ///
    /// - parameters:
    ///    - events: A closure which transforms the Signal<State, NoError> to the Signal<Event, NoError>
    public init(events: @escaping (Scheduler, Signal<State, NoError>) -> Signal<Event, NoError>) {
        self.events = events
    }

    /// Creates a Feedback which will perform effects when query exists (i.e. is not nil)
    /// and is different from the previous one, otherwise, it cancels any previously performed effects
    ///
    /// - parameters:
    ///     - query: A closure which defines for which value perform the effect
    ///     - effects: A sequence of the Events over time that mutate the State
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
                        .observe(on: scheduler)
                }
        }
    }

    /// Creates a Feedback which will perform effects when `query` exists (i.e not nil)
    /// otherwise, it cancels any previously performed effects
    ///
    /// - parameters:
    ///    - query: A closure which defines for which value perform the effect
    ///    - effects: A sequence of the Events over time that mutate the State
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
                        .observe(on: scheduler)
                }
        }
    }

    /// Creates a Feedback which will perform effects on for certain state filtered by the predicate.
    /// Each new effect cancels the previous one
    /// - parameters:
    ///    - predicate: A closure which defines weather an effect should be performed to particular a value of the `State`
    ///    - effects: A sequence of the Events over time that mutate the State
    public init<Effect: SignalProducerConvertible>(
        predicate: @escaping (State) -> Bool,
        effects: @escaping (State) -> Effect
    ) where Effect.Value == Event, Effect.Error == NoError {
        self.events = { scheduler, state in
            return state.filter(predicate)
                .flatMap(.latest) { state -> SignalProducer<Event, NoError> in
                    return effects(state).producer
                        .observe(on: scheduler)
            }
        }
    }

    /// Creates a Feedback which will perform effects for each state change, canceling previously performed ones
    /// - parameters:
    ///    - effects: A sequence of the Events over time that mutate State
    public init<Effect: SignalProducerConvertible>(
        effects: @escaping (State) -> Effect
    ) where Effect.Value == Event, Effect.Error == NoError {
        self.events = { scheduler, state in
            return state.flatMap(.latest) { state -> SignalProducer<Event, NoError> in
                return effects(state).producer
                    .observe(on: scheduler)
            }
        }
    }
}
