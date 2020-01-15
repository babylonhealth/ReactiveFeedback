import Foundation
import ReactiveSwift

public class FeedbackEventConsumer<Event> {
    struct Token: Equatable {
        let value: UInt64

        init() {
            value = DispatchTime.now().uptimeNanoseconds
        }
    }

    func process(_ event: Event, for token: Token) {
        fatalError()
    }

    func unqueueAllEvents(for token: Token) {
        fatalError()
    }
}

final class Floodgate<State, Event>: FeedbackEventConsumer<Event> {
    struct QueueState {
        var events: [(Event, Token)] = []
        var isOuterLifetimeEnded = false
    }

    let (stateDidChange, changeObserver) = Signal<State, Never>.pipe()

    private let reducerLock = NSLock()

    private var queue = Atomic(QueueState())
    private var state: State
    private let reducer: (State, Event) -> State

    init(state: State, reducer: @escaping (State, Event) -> State) {
        self.state = state
        self.reducer = reducer
    }

    func bootstrap() {
        reducerLock.lock()
        defer { reducerLock.unlock() }

        changeObserver.send(value: state)
        drainEvents()
    }

    override func process(_ event: Event, for token: Token) {
        if reducerLock.try() {
            // Fast path: No running effect.
            defer { reducerLock.unlock() }

            consume(event)
            drainEvents()
        } else {
            // Slow path: Enqueue the event for the running effect to drain it on behalf of us.
            enqueue(event, for: token)
        }
    }

    override func unqueueAllEvents(for token: Token) {
        queue.modify { $0.events.removeAll(where: { _, t in t == token }) }
    }

    func dispose() {
        queue.modify {
            $0.isOuterLifetimeEnded = true
        }
    }

    private func enqueue(_ event: Event, for token: Token) {
        queue.modify { $0.events.append((event, token)) }
    }

    private func dequeue() -> Event? {
        queue.modify {
            guard !$0.isOuterLifetimeEnded, !$0.events.isEmpty else { return nil }
            return $0.events.removeFirst().0
        }
    }

    private func drainEvents() {
        // Drain any recursively produced events.
        while let next = dequeue() {
            consume(next)
        }
    }

    private func consume(_ event: Event) {
        state = reducer(state, event)
        changeObserver.send(value: state)
    }
}

extension SignalProducer where Error == Never {
    public func enqueue(to consumer: FeedbackEventConsumer<Value>) -> SignalProducer<Never, Never> {
        SignalProducer<Never, Never> { observer, lifetime in
            let token = FeedbackEventConsumer<Value>.Token()

            lifetime += self.startWithValues { event in
                consumer.process(event, for: token)
            }
            lifetime.observeEnded { consumer.unqueueAllEvents(for: token) }
        }
    }
}
