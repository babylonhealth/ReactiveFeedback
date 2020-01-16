import ReactiveSwift

public final class FeedbackLoop<State, Event>: PropertyProtocol {
    public let lifetime: Lifetime
    internal let floodgate: Floodgate<State, Event>
    private let token: Lifetime.Token

    public var value: State {
        floodgate.withValue { state, _ in state }
    }

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

    public var signal: Signal<State, Never> {
        floodgate.stateDidChange
    }

    public init(
        initial: Value,
        reduce: @escaping (Value, Event) -> Value,
        feedbacks: [Feedback<Value, Event>],
        startImmediately: Bool = true
    ) {
        (lifetime, token) = Lifetime.make()
        floodgate = Floodgate<Value, Event>(state: initial, reducer: reduce)
        lifetime.observeEnded(floodgate.dispose)

        for feedback in feedbacks {
            lifetime += feedback
                .events(floodgate.stateDidChange.producer, floodgate)
        }

        if startImmediately {
            start()
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
