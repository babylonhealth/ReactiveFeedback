import ReactiveSwift

open class Store<State, Event> {
    private let input = Feedback<State, Event>.input()
    public let state: Property<Context<State, Event>>

    public init<S: DateScheduler>(
        initial: State,
        reducer: @escaping Reducer<State, Event>,
        feedbacks: [Feedback<State, Event>],
        scheduler: S
    ) {
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

    open func send(event: Event) {
        input.observer(event)
    }
}

fileprivate extension Array {
    func appending(_ element: Element) -> [Element] {
        var copy = self

        copy.append(element)

        return copy
    }
}
