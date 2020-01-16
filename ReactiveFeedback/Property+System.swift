import ReactiveSwift

extension Property {
    public convenience init<Event>(
        initial: Value,
        reduce: @escaping (Value, Event) -> Value,
        feedbacks: [Feedback<Value, Event>]
    ) {
        self.init(capturing: FeedbackLoop(initial: initial, reduce: reduce, feedbacks: feedbacks))
    }

    public convenience init<Event>(
        initial: Value,
        reduce: @escaping (Value, Event) -> Value,
        feedbacks: Feedback<Value, Event>...
    ) {
        self.init(initial: initial, reduce: reduce, feedbacks: feedbacks)
    }
}
