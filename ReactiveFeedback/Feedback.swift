import Foundation
import ReactiveSwift
import enum Result.NoError

public struct Feedback<State, Event> {
    let events: (Scheduler, Signal<State, NoError>) -> Signal<Event, NoError>
    
    /// Creates an arbitrary Feedback, which evaluates side effects reactively
    /// to the latest state, and eventually produces events that affect the
    /// state.
    ///
    /// - parameters:
    ///   - events: The transform which derives a `Signal` of events from the
    ///             latest state.
    public init(events: @escaping (Scheduler, Signal<State, NoError>) -> Signal<Event, NoError>) {
        self.events = events
    }

    /// Creates a Feedback which re-evaluates the given effect every time the
    /// `Signal` derived from the latest state yields a new value.
    ///
    /// If the previous effect is still alive when a new one is about to start,
    /// the previous one would automatically be cancelled.
    ///
    /// - parameters:
    ///   - transform: The transform which derives a `Signal` of values from the
    ///                latest state.
    ///   - effects: The side effect accepting transformed values produced by
    ///              `transform` and yielding events that eventually affect
    ///              the state.
    public init<U, Effect: SignalProducerConvertible>(
        deriving transform: @escaping (Signal<State, NoError>) -> Signal<U, NoError>,
        effects: @escaping (U) -> Effect
    ) where Effect.Value == Event, Effect.Error == NoError {
        self.events = { scheduler, state in
            return transform(state)
                .flatMap(.latest, effects)
                .observe(on: scheduler)
        }
    }

    /// Creates a Feedback which re-evaluates the given effect every time the
    /// transform yields a non-`nil` distinct value from the last yielded value.
    ///
    /// If the previous effect is still alive when a new one is about to start,
    /// the previous one would automatically be cancelled.
    ///
    /// - parameters:
    ///   - transform: The transform to apply on the state.
    ///   - effects: The side effect accepting transformed values produced by
    ///              `transform` and yielding events that eventually affect
    ///              the state.
    public init<Control: Equatable, Effect: SignalProducerConvertible>(
        skippingRepeated transform: @escaping (State) -> Control?,
        effects: @escaping (Control) -> Effect
    ) where Effect.Value == Event, Effect.Error == NoError {
        self.init(deriving: { $0.filterMap(transform).skipRepeats(==) },
                  effects: effects)
    }

    /// Creates a Feedback which re-evaluates the given effect every time the
    /// transform yields a non-`nil` value.
    ///
    /// If the previous effect is still alive when a new one is about to start,
    /// the previous one would automatically be cancelled.
    ///
    /// - parameters:
    ///   - transform: The transform to apply on the state.
    ///   - effects: The side effect accepting transformed values produced by
    ///              `transform` and yielding events that eventually affect
    ///              the state.
    public init<Control, Effect: SignalProducerConvertible>(
        skippingNil transform: @escaping (State) -> Control?,
        effects: @escaping (Control) -> Effect
    ) where Effect.Value == Event, Effect.Error == NoError {
        self.init(deriving: { $0.filterMap(transform) },
                  effects: effects)
    }

    /// Creates a Feedback which re-evaluates the given effect every time the
    /// given predicate passes.
    ///
    /// If the previous effect is still alive when a new one is about to start,
    /// the previous one would automatically be cancelled.
    ///
    /// - parameters:
    ///   - transform: The predicate to apply on the state.
    ///   - effects: The side effect accepting the state and yielding events
    ///              that eventually affect the state.
    public init<Effect: SignalProducerConvertible>(
        predicate: @escaping (State) -> Bool,
        effects: @escaping (State) -> Effect
    ) where Effect.Value == Event, Effect.Error == NoError {
        self.init(deriving: { $0.filter(predicate) },
                  effects: effects)
    }

    /// Creates a Feedback which re-evaluates the given effect every time the
    /// state changes.
    ///
    /// If the previous effect is still alive when a new one is about to start,
    /// the previous one would automatically be cancelled.
    ///
    /// - parameters:
    ///   - effects: The side effect accepting the state and yielding events
    ///              that eventually affect the state.
    public init<Effect: SignalProducerConvertible>(
        effects: @escaping (State) -> Effect
    ) where Effect.Value == Event, Effect.Error == NoError {
        self.init(deriving: { $0 }, effects: effects)
    }
}
