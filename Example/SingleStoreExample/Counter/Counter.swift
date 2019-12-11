import ReactiveFeedback
import ReactiveSwift

enum Counter {
    struct State: Builder {
        var count = 0
    }

    enum Event {
        case increment
        case decrement
    }

    static func reduce(state: State, event: Event) -> State {
        switch event {
        case .increment:
            return state.set(\.count, state.count + 1)
        case .decrement:
            return state.set(\.count, state.count - 1)
        }
    }
}

protocol Builder {}
extension Builder {
    func set<T>(_ keyPath: WritableKeyPath<Self, T>, _ value: T) -> Self {
        var copy = self
        copy[keyPath: keyPath] = value
        return copy
    }
}

extension NSObject: Builder {}
