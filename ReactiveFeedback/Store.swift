import ReactiveSwift

open class Store<State, Event> {
    public let state: Property<Context<State, Event>>

    private let input = Feedback<State, Event>.input()
    private let send: (Event) -> Void

    public init<S: DateScheduler>(
        initial: State,
        reducer: @escaping Reducer<State, Event>,
        feedbacks: [Feedback<State, Event>],
        scheduler: S
    ) {
        self.send = { _ in }
        self.state = Property(
            initial: Context(state: initial, send: self.input.observer),
            then: SignalProducer.system(
                initial: initial,
                scheduler: scheduler,
                reduce: reducer,
                feedbacks: feedbacks.appending(self.input.feedback)
            )
            .map { [input] state in
                Context(state: state, send: input.observer)
            }
            .skip(first: 1)
        )
    }

    private init(state: Property<Context<State, Event>>, send: @escaping (Event) -> Void) {
        self.state = state
        self.send = send
    }

    open func send(event: Event) {
        input.observer(event)
        send(event)
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
