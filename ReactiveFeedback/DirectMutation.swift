public struct DirectMutation<State> {
    public let keyPath: PartialKeyPath<State>
    private let value: Any
    private let apply: (DirectMutation<State>, inout State) -> Void

    public init<Value>(value: Value, at keyPath: WritableKeyPath<State, Value>) {
        self.keyPath = keyPath
        self.value = value
        self.apply = { mutation, state in
            state[keyPath: mutation.keyPath as! WritableKeyPath<State, Value>] = mutation.value as! Value
        }
    }

    public func apply(to state: inout State) {
        apply(self, &state)
    }

    public func applied(to state: State) -> State {
        var copy = state
        apply(to: &copy)
        return copy
    }

    public func open<Value>(as keyPath: WritableKeyPath<State, Value>) -> Value? {
        guard keyPath == self.keyPath else { return nil }
        return value as! Value
    }
}
