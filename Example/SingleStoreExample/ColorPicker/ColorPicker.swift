import UIKit

enum ColorPicker {
    struct State: Builder {
        let colors: [UIColor] = [.green, .yellow, .red]
        var selectedColor: UIColor
    }

    enum Event {
        case didPick(UIColor)
    }

    static func reduce(state: inout State, event: Event) {
        switch event {
        case .didPick(let color):
            state.selectedColor = color
        }
    }
}
