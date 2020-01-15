import ReactiveSwift

extension Property {
    public convenience init<Event>(
        initial: Value,
        reduce: @escaping (Value, Event) -> Value,
        feedbacks: [Feedback<Value, Event>]
    ) {
        let state = MutableProperty(initial)
        state <~ SignalProducer.system(
            initial: initial,
            reduce: reduce,
            feedbacks: feedbacks
        )
        .skip(first: 1)
        self.init(capturing: state)
    }

    public convenience init<Event>(
        initial: Value,
        reduce: @escaping (Value, Event) -> Value,
        feedbacks: Feedback<Value, Event>...
    ) {
        self.init(initial: initial, reduce: reduce, feedbacks: feedbacks)
    }
}
