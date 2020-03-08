public typealias Reducer<State, Event> = (inout State, Event) -> Void

public func combine<State, Event>(
    _ reducers: Reducer<State, Event>...
) -> Reducer<State, Event> {
    return { state, event in
        for reducer in reducers {
            reducer(&state, event)
        }
    }
}

public func pullback<LocalState, GlobalState, LocalEvent, GlobalEvent>(
    _ reducer: @escaping Reducer<LocalState, LocalEvent>,
    value: WritableKeyPath<GlobalState, LocalState>,
    event: WritableKeyPath<GlobalEvent, LocalEvent?>
) -> Reducer<GlobalState, GlobalEvent> {
    return { globalState, globalEvent in
        guard let localAction = globalEvent[keyPath: event] else {
            return
        }
        reducer(&globalState[keyPath: value], localAction)
    }
}
