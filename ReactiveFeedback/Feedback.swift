import Foundation
import ReactiveSwift

public struct Feedback<State, Event> {
    let events: (_ state: SignalProducer<State, Never>, _ output: FeedbackEventConsumer<Event>) -> Disposable

    internal init(events: @escaping (_ state: SignalProducer<State, Never>, _ output: FeedbackEventConsumer<Event>) -> Disposable) {
        self.events = events
    }

    /// Creates a custom Feedback, with the complete liberty of defining the data flow.
    ///
    /// - important: While you may respond to state changes in whatever ways you prefer, you **must** enqueue produced
    ///              events using the `SignalProducer.enqueue(to:)` operator to the `FeedbackEventConsumer` provided
    ///              to you. Otherwise, the feedback loop will not be able to pick up and process your events.
    ///
    /// - parameters:
    ///   - setup: The setup closure to construct a data flow producing events in respond to changes from `state`,
    ///             and having them consumed by `output` using the `SignalProducer.enqueue(to:)` operator.
    public static func custom(
        _ setup: @escaping (
            _ state: SignalProducer<State, Never>,
            _ output: FeedbackEventConsumer<Event>
        ) -> Disposable
    ) -> Feedback<State, Event> {
        return Feedback(events: setup)
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
        compacting transform: @escaping (SignalProducer<State, Never>) -> SignalProducer<U, Never>,
        effects: @escaping (U) -> Effect
    ) where Effect.Value == Event, Effect.Error == Never {
        self.events = { state, output in
            // NOTE: `observe(on:)` should be applied on the inner producers, so
            //       that cancellation due to state changes would be able to
            //       cancel outstanding events that have already been scheduled.
            transform(state)
                .flatMap(.latest) { effects($0).producer.enqueue(to: output) }
                .start()
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
        self.init(compacting: { $0.map(transform).skipRepeats() },
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
        self.init(compacting: { $0.map(transform) },
                  effects: { $0.map(effects)?.producer ?? .empty })
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
        self.init(compacting: { $0 },
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
        self.init(compacting: { $0 }, effects: effects)
    }
}

extension Feedback {
    @available(*, unavailable, message:"Migrate to `Feedback.custom(_:)` which provides custom feedbacks a `SignalProducer` and a `FeedbackEventConsumer` to enable a more efficient and synchronous feedback loop.")
    public init(_ events: @escaping (Scheduler, Signal<State, Never>) -> Signal<Event, Never>) {
        fatalError()
    }

    @available(*, deprecated, message:"Migrate to", renamed:"Feedback.init(compacting:effects:)")
    public init<U, Effect: SignalProducerConvertible>(
        deriving transform: @escaping (Signal<State, Never>) -> Signal<U, Never>,
        effects: @escaping (U) -> Effect
    ) where Effect.Value == Event, Effect.Error == Never {
        self.events = { state, output in
            // NOTE: `observe(on:)` should be applied on the inner producers, so
            //       that cancellation due to state changes would be able to
            //       cancel outstanding events that have already been scheduled.
            state.startWithSignal { state, _ in
                transform(state)
                    .flatMap(.latest) { effects($0).producer.enqueue(to: output) }
                    .producer
                    .start()
            }
        }
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
