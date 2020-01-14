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

    /// Creates a Feedback which re-evaluates the given effect every time the
    /// predicate passes a new occurrence of `State` (i.e. every state change).
    ///
    /// If the previous effect is still alive when a new one is about to start,
    /// or if the predicate evaluates to `false`, the previous one would automatically
    /// be cancelled.
    ///
    /// As an example, given this feedback loop definition:
    ///
    /// ```
    /// typealias State = Int
    /// enum Event { case add(Int) }
    ///
    /// func reduce(_ sum: State, _ event: Event) -> State {
    ///   switch event {
    ///   case let .add(count):
    ///     return sum + count
    ///   }
    /// }
    ///
    /// let addingFiniteSeries = Feedback<State, Event>(occurrencesPassing: { sum in sum == 0 }) { _ in
    ///   SignalProducer(1 ... 100)
    ///      .map(Event.add)
    /// }
    ///
    /// let system = Property(initial: 0, reducer: reduce, feedbacks: addingFiniteSeries)
    /// ```
    ///
    /// `addingFiniteSeries` might be perceived as eventually updating the state with the finite series of `[1, 100]`.
    /// In practice, however, the effect in `addingFiniteSeries` is interrupted as soon as `{ sum in sum == 0 }`
    /// fails, leading to `state == 1`.
    ///
    /// Even if we change the predicate to, say, `{ sum in sum < 5 }`, the result is still not a finite series
    /// one might have expected. Recall that `occurrencesPassing:` always reevaluates the state and restarts the effect
    /// for every occurrence. So it basically leads to many `.add(1)` events until the predicate fails.
    ///
    /// ```
    /// |  Time   |    State    |  Pass? |   Effects   |    Event    | Next State  |
    /// |---------|-------------|--------|-------------|-------------|-------------|
    /// |  t = 0  |  state = 0  |  PASS  |  Restarted  |   .add(1)   |  state = 1  |
    /// |  t = 1  |  state = 1  |  PASS  |  Restarted  |   .add(1)   |  state = 2  |
    /// |  t = 2  |  state = 2  |  PASS  |  Restarted  |   .add(1)   |  state = 3  |
    /// |  t = 3  |  state = 3  |  PASS  |  Restarted  |   .add(1)   |  state = 4  |
    /// |  t = 4  |  state = 4  |  PASS  |  Restarted  |   .add(1)   |  state = 5  |
    /// |  t = 5  |  state = 5  |  FAIL  |  Cancelled  |      -      |  state = 5  |
    /// ```
    ///
    /// ## Alternatives
    ///
    /// If your effect is intended to be alive across multiple state occurrences, or is
    /// intended to emit multiple events over time, you should use variants with state
    /// change ignoring semantics, e.g. `skippingRepeated:`.
    ///
    /// For example:
    /// ```
    /// Feedback<State, Event>(skippingRepeated: { sum in sum < 2000 }) { shouldBegin in
    ///   shouldBegin
    ///     ? SignalProducer(1 ... 100).map(Event.add)
    ///     : .empty
    /// }
    /// ```
    /// `skippingRepeated:` keeps the current effect alive, as long as the transform output does not change. In other
    /// words, the producer would not be cancelled even though the events it emitted are bumping up the tally — this
    /// lasts until the condition `sum < 2000` flips to `false`, at which point the effect would then be cancelled.
    ///
    /// - parameters:
    ///   - predicate: The predicate to apply on the state.
    ///   - effects: The side effect accepting the state and yielding events
    ///              that eventually affect the state.
    public init<Effect: SignalProducerConvertible>(
        occurrencesPassing predicate: @escaping (State) -> Bool,
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

    @available(*, unavailable, renamed: "init(occurrencesPassing:effects:)")
    public init<Effect: SignalProducerConvertible>(
        predicate: @escaping (State) -> Bool,
        effects: @escaping (State) -> Effect
    ) where Effect.Value == Event, Effect.Error == Never {
        self.init(deriving: { $0 },
                  effects: { state -> SignalProducer<Event, Never> in
                      predicate(state) ? effects(state).producer : .empty
                  })
    }
}
