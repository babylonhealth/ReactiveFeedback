import SwiftUI

@dynamicMemberLookup
public struct Context<State, Event> {
    private let state: State
    private let send: (Event) -> Void

    public init(
        state: State,
        send: @escaping (Event) -> Void
    ) {
        self.state = state
        self.send = send
    }

    public subscript<U>(dynamicMember keyPath: KeyPath<State, U>) -> U {
        return state[keyPath: keyPath]
    }

    public func send(event: Event) {
        send(event)
    }

    public func view<LocalState, LocalEvent>(
        value: KeyPath<State, LocalState>,
        event: @escaping (LocalEvent) -> Event
    ) -> Context<LocalState, LocalEvent> {
        return Context<LocalState, LocalEvent>(
            state: state[keyPath: value],
            send: { localEvent in
                self.send(event(localEvent))
            }
        )
    }
}
