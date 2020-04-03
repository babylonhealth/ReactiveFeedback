@dynamicMemberLookup
public struct Context<State, Event> {
    private let state: State
    private let forward: (Event) -> Void

    public init(
        state: State,
        forward: @escaping (Event) -> Void
    ) {
        self.state = state
        self.forward = forward
    }

    public subscript<U>(dynamicMember keyPath: KeyPath<State, U>) -> U {
        return state[keyPath: keyPath]
    }

    public func send(event: Event) {
        forward(event)
    }

    public func view<LocalState, LocalEvent>(
        value: KeyPath<State, LocalState>,
        event: @escaping (LocalEvent) -> Event
    ) -> Context<LocalState, LocalEvent> {
        return Context<LocalState, LocalEvent>(
            state: state[keyPath: value],
            forward: { localEvent in
                self.forward(event(localEvent))
            }
        )
    }
}
