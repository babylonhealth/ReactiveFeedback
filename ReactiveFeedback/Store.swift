import ReactiveSwift

open class Store<State, Event> {
    public let state: Property<Context<State, Event>>

    private let input = FeedbackLoop<State, Event>.Feedback.input
    private let forward: (Event) -> Void

    public init(
        initial: State,
        reducer: @escaping Reducer<State, Event>,
        feedbacks: [FeedbackLoop<State, Event>.Feedback]
    ) {
        self.forward = { _ in }
        self.state = Property(
            initial: Context(state: initial, forward: self.input.observer),
            then: SignalProducer.feedbackLoop(
                initial: initial,
                reduce: reducer,
                feedbacks: feedbacks.appending(input.feedback)
            )
            .map { [input] state in
                Context(state: state, forward: input.observer)
            }
            .skip(first: 1)
        )
    }

    private init(state: Property<Context<State, Event>>, send: @escaping (Event) -> Void) {
        self.state = state
        self.forward = send
    }

    open func send(event: Event) {
        input.observer(event)
        forward(event)
    }

    public func view<LocalState, LocalEvent>(
        value: KeyPath<State, LocalState>,
        event: @escaping (LocalEvent) -> Event
    ) -> Store<LocalState, LocalEvent> {
        return Store<LocalState, LocalEvent>(
            state: state.map { $0.view(value: value, event: event) },
            send: { localEvent in
                self.send(event: event(localEvent))
            }
        )
    }
}

fileprivate extension Array {
    func appending(_ element: Element) -> [Element] {
        var copy = self

        copy.append(element)

        return copy
    }
}
