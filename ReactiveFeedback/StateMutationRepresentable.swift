public protocol StateMutationRepresentable {
    associatedtype State

    init(_ mutation: DirectMutation<State>)
}
