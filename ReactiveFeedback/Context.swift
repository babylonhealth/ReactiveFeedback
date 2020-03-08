@dynamicMemberLookup
public struct Context<State, Event> {
    private let state: State
    private let forvard: (Event) -> Void

    public init(
        state: State,
        forvard: @escaping (Event) -> Void
    ) {
        self.state = state
        self.forvard = forvard
    }

    public subscript<U>(dynamicMember keyPath: KeyPath<State, U>) -> U {
        return state[keyPath: keyPath]
    }

    public func send(event: Event) {
        forvard(event)
    }

    public func view<LocalState, LocalEvent>(
        value: KeyPath<State, LocalState>,
        event: @escaping (LocalEvent) -> Event
    ) -> Context<LocalState, LocalEvent> {
        return Context<LocalState, LocalEvent>(
            state: state[keyPath: value],
            forvard: { localEvent in
                self.forvard(event(localEvent))
            }
        )
    }
}
