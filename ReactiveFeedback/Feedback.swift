import Foundation
import ReactiveSwift

public struct Feedback<State, Event> {
    let events: (Scheduler, Signal<State, Never>) -> Signal<Event, Never>
    
    /// Creates an arbitrary Feedback, which evaluates side effects reactively
    /// to the latest state, and eventually produces events that affect the
    /// state.
    ///
    /// - parameters:
    ///   - events: The transform which derives a `Signal` of events from the
    ///             latest state.
    public init(events: @escaping (Scheduler, Signal<State, Never>) -> Signal<Event, Never>) {
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
            return transform(state)
                .flatMap(.latest) { effects($0).producer.observe(on: scheduler) }
        }
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

    /// Creates a Feedback which starts evaluating the provided effect, every time the given condition becomes true.
    /// When the given condition becomes false, any outstanding effect is cancelled.
    ///
    /// - important: The effect is started only when the condition output becomes true, or in other words, transitions
    ///              from false to true. If the condition output evaluates to true against multiple consecutive versions
    ///              of the state, the feedback still does not restart the effect with the later versions — only when
    ///              the output becomes false, which resets the feedback.
    ///
    /// - parameters:
    ///   - predicate: The predicate to apply on the state.
    ///   - effects: The side effect accepting the state and yielding events
    ///              that eventually affect the state.
    public init<Effect: SignalProducerConvertible>(
        condition: @escaping (State) -> Bool,
        whenBecomesTrue effects: @escaping (State) -> Effect
    ) where Effect.Value == Event, Effect.Error == Never {
        self.init(
            deriving: { state in
                state
                    .scan(into: EdgeTriggeredControlState<State>.negative) { output, newState in
                        switch (output.isPositive, condition(newState)) {
                        case (false, true):
                            output = .positive(newState)
                        case (true, false):
                            output = .negative
                        case (true, true):
                            output = .positiveValueSent
                        case (false, false):
                            output = .negative
                        }
                    }
                    .compactMap(EdgeTriggeredControlOutput<State>.init)
            },
            effects: { output -> SignalProducer<Event, Never> in
                switch output {
                case let .start(state):
                    return effects(state).producer
                case .cancel:
                    return .empty
                }
            }
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
    @available(*, deprecated, message:"Use `Feedback.init(condition:whenBecomesTrue:)` or other variants when appropriate.")
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

private enum EdgeTriggeredControlState<State> {
    case negative
    case positive(State)
    case positiveValueSent

    var isPositive: Bool {
        switch self {
        case .positiveValueSent, .positive:
            return true
        case .negative:
            return false
        }
    }
}

private enum EdgeTriggeredControlOutput<State> {
    case start(State)
    case cancel

    init?(_ state: EdgeTriggeredControlState<State>) {
        switch state {
        case .negative:
            self = .cancel
        case let .positive(state):
            self = .start(state)
        case .positiveValueSent:
            return nil
        }
    }
}
