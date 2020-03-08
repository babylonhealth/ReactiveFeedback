import ReactiveSwift

public final class FeedbackLoop<State, Event> {
    public let lifetime: Lifetime
    internal let floodgate: Floodgate<State, Event>
    private let token: Lifetime.Token

    public var producer: SignalProducer<State, Never> {
        SignalProducer { observer, lifetime in
            self.floodgate.withValue { initial, hasStarted -> Void in
                if hasStarted {
                    // The feedback loop has started already, so the initial value has to be manually delivered.
                    // Uninitialized feedback loop that does not start immediately will emit the initial state
                    // when `start()` is called.
                    observer.send(value: initial)
                }

                lifetime += self.floodgate.stateDidChange.observe(observer)
            }
        }
    }

    public init(
        initial: State,
        reduce: @escaping (inout State, Event) -> Void,
        feedbacks: [Feedback]
    ) {
        (lifetime, token) = Lifetime.make()
        floodgate = Floodgate<State, Event>(state: initial, reducer: reduce)
        lifetime.observeEnded(floodgate.dispose)

        for feedback in feedbacks {
            lifetime += feedback
                .events(floodgate.stateDidChange.producer, floodgate)
        }
    }

    public func start() {
        floodgate.bootstrap()
    }

    public func stop() {
        token.dispose()
    }

    deinit {
        stop()
    }
}

extension FeedbackLoop {
    public struct Feedback {
        let events: (_ state: SignalProducer<State, Never>, _ output: FeedbackEventConsumer<Event>) -> Disposable

        public init(
            events: @escaping (
            _ state: SignalProducer<State, Never>,
            _ output: FeedbackEventConsumer<Event>
            ) -> Disposable
        ) {
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
        ) -> Feedback {
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
        
        public static var input: (feedback: Feedback, observer: (Event) -> Void) {
            let pipe = Signal<Event, Never>.pipe()
            let feedback = Feedback.custom { (state, consumer) -> Disposable in
                pipe.output.producer.enqueue(to: consumer).start()
            }
            return (feedback, pipe.input.send)
        }
        
        public static func pullback<LocalState, LocalEvent>(
            feedback: FeedbackLoop<LocalState, LocalEvent>.Feedback,
            value: KeyPath<State, LocalState>,
            event: @escaping (LocalEvent) -> Event
        ) -> Feedback {
            return Feedback.custom { (state, consumer) -> Disposable in
                return feedback.events(
                    state.map(value),
                    consumer.pullback(event)
                )
            }
        }
        
        public static func combine(_ feedbacks: FeedbackLoop<State, Event>.Feedback...) -> Feedback {
            return .custom { (state, consumer) -> Disposable in
                return feedbacks.map { (feedback) in
                    feedback.events(state, consumer)
                }
                .reduce(into: CompositeDisposable()) { (composite, disposable) in
                    composite += disposable
                }
            }
        }
    }
}
