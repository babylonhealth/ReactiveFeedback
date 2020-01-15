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

        textView.reactive.continuousTextValues
            .take(duringLifetimeOf: self)
            .observeValues { [viewModel] in viewModel.textDidChange($0) }

        textView.reactive.text <~ viewModel.state
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        characterCountLabel.reactive.text <~ viewModel.state.producer
            .map { "\($0.count) characters" }
        inputToolbar.setItems([UIBarButtonItem(customView: characterCountLabel)], animated: false)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        textView.becomeFirstResponder()
    }
}

final class TextInputViewModel {
    let state: Property<String>
    private let (text, textObserver) = Signal<String, Never>.pipe()

    init() {
        self.state = Property(
            initial: "Lorem ipsum ",
            reduce: TextInputViewModel.reduce,
            feedbacks: Feedback.custom { [text] _, output in
                text.producer.map(Event.update).enqueue(to: output).start()
            }
        )
    }

    func textDidChange(_ text: String) {
        textObserver.send(value: text)
    }
}

extension TextInputViewModel {
    static func reduce(state: String, event: Event) -> String {
        switch event {
        case let .update(text):
            return text
        }
    }

    enum Event {
        case update(String)
    }
}
