import Foundation
import ReactiveSwift

public struct Feedback<State, Event> {
    let events: (Scheduler, Signal<(State, Event?), Never>) -> Signal<Event, Never>
    
    /// Creates an arbitrary Feedback, which evaluates side effects reactively
    /// to the latest state, and eventually produces events that affect the
    /// state.
    ///
    /// - parameters:
    ///   - events: The transform which derives a `Signal` of events from the
    ///             latest state.

    public init(events: @escaping (Scheduler, Signal<(State, Event?), Never>) -> Signal<Event, Never>) {
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
        deriving transform: @escaping (Signal<State, Never>) -> Signal<U, Never>,
        effects: @escaping (U) -> Effect
    ) where Effect.Value == Event, Effect.Error == Never {
        self.events = { scheduler, state in
            // NOTE: `observe(on:)` should be applied on the inner producers, so
            //       that cancellation due to state changes would be able to
            //       cancel outstanding events that have already been scheduled.
            return transform(state.map(\.0))
                .flatMap(.latest) { effects($0).producer.observe(on: scheduler) }
        }
    }

    public static func derivingEvents<U, Effect: SignalProducerConvertible>(
        _ transform: @escaping (Signal<Event, Never>) -> Signal<U, Never>,
        effects: @escaping (U) -> Effect
    ) -> Feedback where Effect.Value == Event, Effect.Error == Never {
        return Feedback(events: { scheduler, state in
            // NOTE: `observe(on:)` should be applied on the inner producers, so
            //       that cancellation due to state changes would be able to
            //       cancel outstanding events that have already been scheduled.
            return transform(state.map(\.1).skipNil())
                .flatMap(.latest) { effects($0).producer.observe(on: scheduler) }
        })
    }

    /// Creates a Feedback which re-evaluates the given effect every time the
    /// state changes, and the transform consequentially yields a new value
    /// distinct from the last yielded value.
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
    ) where Effect.Value == Event, Effect.Error == Never {
        self.init(deriving: { $0.map(transform).skipRepeats() },
                  effects: { $0.map(effects)?.producer ?? .empty })
    }

    /// Creates a Feedback which re-evaluates the given effect every time the
    /// state changes, and the transform consequentially yields a new value
    /// distinct from the last yielded value.
    ///
    /// If the previous effect is still alive when a new one is about to start,
    /// the previous one would automatically be cancelled.
    ///
    /// - parameters:
    ///   - transform: The transform to apply on the state.
    ///   - effects: The side effect accepting transformed values produced by
    ///              `transform` and yielding events that eventually affect
    ///              the state.

    public static func skippingRepeatedEvents<Payload: Equatable, Effect: SignalProducerConvertible>(
        _ transform: @escaping (Event) -> Payload?,
        effects: @escaping (Payload) -> Effect
    ) -> Feedback where Effect.Value == Event, Effect.Error == Never {
        .derivingEvents({ $0.map(transform).skipRepeats() }, effects: { $0.map(effects)?.producer ?? .empty })
    }

    /// Creates a Feedback which re-evaluates the given effect every time the
    /// state changes.
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
        lensing transform: @escaping (State) -> Control?,
        effects: @escaping (Control) -> Effect
    ) where Effect.Value == Event, Effect.Error == Never {
        self.init(deriving: { $0.map(transform) },
                  effects: { $0.map(effects)?.producer ?? .empty })
    }

    public static func lensingEvent<Payload, Effect: SignalProducerConvertible>(
        _ transform: @escaping (Event) -> Payload?,
        effects: @escaping (Payload) -> Effect
    ) -> Feedback where Effect.Value == Event, Effect.Error == Never {
        .derivingEvents(
            { $0.map(transform) },
            effects: { $0.map(effects)?.producer ?? .empty }
        )
    }

    /// Creates a Feedback which re-evaluates the given effect every time the
    /// given predicate passes.
    ///
    /// If the previous effect is still alive when a new one is about to start,
    /// the previous one would automatically be cancelled.
    ///
    /// - parameters:
    ///   - predicate: The predicate to apply on the state.
    ///   - effects: The side effect accepting the state and yielding events
    ///              that eventually affect the state.
    public init<Effect: SignalProducerConvertible>(
        predicate: @escaping (State) -> Bool,
        effects: @escaping (State) -> Effect
    ) where Effect.Value == Event, Effect.Error == Never {
        self.init(deriving: { $0 },
                  effects: { state -> SignalProducer<Event, Never> in
                      predicate(state) ? effects(state).producer : .empty                      
                  })
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
    ) where Effect.Value == Event, Effect.Error == Never {
        self.init(deriving: { $0 }, effects: effects)
    }

    public static func middleware<Effect: SignalProducerConvertible>(
        _ effects: @escaping (State, Event) -> Effect
    ) -> Feedback where Effect.Value == Event, Effect.Error == Never {
        Feedback(events: { scheduler, state in
            state.compactMap { s, e -> (State, Event)? in
                guard let e = e else {
                    return nil
                }
                return (s, e)
            }.flatMap(.latest) {
                effects($0, $1).producer.observe(on: scheduler)
            }
        })
    }
}

extension Feedback {
    @available(*, unavailable, renamed: "init(skippingRepeated:effects:)")
    public init<Control: Equatable, Effect: SignalProducerConvertible>(
        query: @escaping (State) -> Control?,
        effects: @escaping (Control) -> Effect
    ) where Effect.Value == Event, Effect.Error == Never {
        fatalError()
    }

    @available(*, unavailable, renamed: "init(lensing:effects:)")
    public init<Control, Effect: SignalProducerConvertible>(
        query: @escaping (State) -> Control?,
        effects: @escaping (Control) -> Effect
    ) where Effect.Value == Event, Effect.Error == Never {
        fatalError()
    }
}
