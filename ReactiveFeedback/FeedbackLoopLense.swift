import ReactiveSwift

@propertyWrapper
public class FeedbackLoopLense<Value>: MutablePropertyProtocol {
    public var lifetime: Lifetime { fatalError_notBoundToFeedbackLoop() }

    public init() {}

    public var wrappedValue: Value {
        get { fatalError_notBoundToFeedbackLoop() }
        set { fatalError_notBoundToFeedbackLoop() }
    }

    public var projectedValue: FeedbackLoopLense<Value> {
        return self
    }

    public var value: Value {
        get { wrappedValue }
        set { wrappedValue = newValue }
    }

    public var producer: SignalProducer<Value, Never> {
        fatalError_notBoundToFeedbackLoop()
    }

    public var signal: Signal<Value, Never> {
        fatalError_notBoundToFeedbackLoop()
    }

    public subscript<SubValue>(keyPath: WritableKeyPath<Value, SubValue>) -> FeedbackLoopLense<SubValue> {
        fatalError_notBoundToFeedbackLoop()
    }

    private func fatalError_notBoundToFeedbackLoop() -> Never {
        fatalError("The `FeedbackLoopLense` being accessed was not bound to any feedback loop.")
    }
}

internal class _FeedbackLoopLense<State, Event, Value>: FeedbackLoopLense<Value>
where Event: StateMutationRepresentable, Event.State == State {
    let feedbackLoop: FeedbackLoop<State, Event>
    let keyPath: WritableKeyPath<State, Value>
    let token = FeedbackEventConsumer<Event>.Token()

    override var lifetime: Lifetime {
        feedbackLoop.lifetime
    }

    init(feedbackLoop: FeedbackLoop<State, Event>, keyPath: WritableKeyPath<State, Value>) {
        self.feedbackLoop = feedbackLoop
        self.keyPath = keyPath
        super.init()
    }

    override var wrappedValue: Value {
        get { feedbackLoop.floodgate.withValue { state, _ in state[keyPath: keyPath] } }
        set {
            feedbackLoop.floodgate.process(
                Event(DirectMutation<State>(value: newValue, at: keyPath)),
                for: token
            )
        }
    }

    override var producer: SignalProducer<Value, Never> {
        feedbackLoop.producer.map(keyPath)
    }

    override var signal: Signal<Value, Never> {
        feedbackLoop.signal.map(keyPath)
    }

    override subscript<AppendedValue>(keyPath: WritableKeyPath<Value, AppendedValue>) -> FeedbackLoopLense<AppendedValue> {
        _FeedbackLoopLense<State, Event, AppendedValue>(
            feedbackLoop: feedbackLoop,
            keyPath: self.keyPath.appending(path: keyPath)
        )
    }
}
