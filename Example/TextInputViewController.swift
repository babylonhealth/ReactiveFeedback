import UIKit
import ReactiveSwift
import ReactiveCocoa
import ReactiveFeedback

class TextInputViewController: UIViewController {
    let viewModel = TextInputViewModel()
    let textView = UITextView()
    let inputToolbar = UIToolbar(frame: UIScreen.main.bounds)
    let characterCountLabel = UILabel()

    override var inputAccessoryView: UIView? {
        inputToolbar.frame.size = inputToolbar.sizeThatFits(UIScreen.main.bounds.size)
        return inputToolbar
    }

    override func loadView() {
        self.view = textView

        textView.font = UIFont.preferredFont(forTextStyle: .title3)
        textView.alwaysBounceVertical = true
        textView.keyboardDismissMode = .interactive

        if #available(iOS 11.0, *) {
            textView.contentInsetAdjustmentBehavior = .always
        } else {
            self.automaticallyAdjustsScrollViewInsets = true
        }

        viewModel.$note <~ textView.reactive.continuousTextValues
        textView.reactive.text <~ viewModel.$note
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        characterCountLabel.reactive.text <~ viewModel.$note.producer
            .map { "\($0.count) characters" }
        inputToolbar.setItems([UIBarButtonItem(customView: characterCountLabel)], animated: false)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        textView.becomeFirstResponder()
    }
}

final class TextInputViewModel {
    @FeedbackLoopLense
    var note: String

    private let state: FeedbackLoop<State, Event>

    init() {
        self.state = FeedbackLoop<State, Event>(
            initial: State(note: "Lorem ipsum "),
            reduce: TextInputViewModel.reduce,
            feedbacks: []
        )
        _note = state[\.note]
    }
}

extension TextInputViewModel {
    struct State {
        var note: String
    }

    static func reduce(state: State, event: Event) -> State {
        switch event {
        case let .mutation(mutation):
            var copy = state

            if let note = mutation.open(as: \.note) {
                // Accept only alphanumerics, whitespaces and newlines.
                let chars = CharacterSet.alphanumerics.union(.whitespacesAndNewlines)
                copy.note = note.filter { $0.unicodeScalars.allSatisfy(chars.contains) }
            }

            return copy
        }
    }

    enum Event {
        case mutation(DirectMutation<State>)
    }
}

extension TextInputViewModel.Event: StateMutationRepresentable {
    init(_ mutation: DirectMutation<TextInputViewModel.State>) {
        self = .mutation(mutation)
    }
}
