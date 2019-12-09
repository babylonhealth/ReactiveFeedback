import SwiftUI

@dynamicMemberLookup
public struct Context<State, Action> {
    private let state: State
    private let send: (Action) -> Void

    public init(
        state: State,
        send: @escaping (Action) -> Void
    ) {
        self.state = state
        self.send = send
    }

    public subscript<U>(dynamicMember keyPath: KeyPath<State, U>) -> U {
        return state[keyPath: keyPath]
    }

    public func send(event: Action) {
        send(event)
    }

    public func view<LocalState, LocalEvent>(
        value: WritableKeyPath<State, LocalState>,
        event: @escaping (LocalEvent) -> Action
    ) -> Context<LocalState, LocalEvent> {
        return Context<LocalState, LocalEvent>(
            state: state[keyPath: value],
            send: { localEvent in
                self.send(event(localEvent))
            }
        )
    }
}
