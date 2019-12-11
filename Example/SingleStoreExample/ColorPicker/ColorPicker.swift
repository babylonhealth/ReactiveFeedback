import UIKit

enum ColorPicker {
    struct State: Builder {
        let colors: [UIColor] = [.green, .yellow, .red]
        var selectedColor: UIColor
    }

    enum Event {
        case didPick(UIColor)
    }

    static func reduce(state: State, event: Event) -> State {
        switch event {
        case .didPick(let color):
            return state.set(\.selectedColor, color)
        }
    }
}
