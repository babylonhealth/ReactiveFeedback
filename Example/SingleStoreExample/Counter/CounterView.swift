import UIKit
import ReactiveFeedback

final class CounterViewController: ContainerViewController<CounterView> {
    private let store: Store<Counter.State, Counter.Event>

    init(store: Store<Counter.State, Counter.Event>) {
        self.store = store
        super.init()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        store.state.producer.startWithValues(contentView.render)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class CounterView: UIView, NibLoadable {
    @IBOutlet weak var plusButton: UIButton!
    @IBOutlet weak var minusButton: UIButton!
    @IBOutlet weak var label: UILabel!
    private let plusButtonDidTap = Command()
    private let minusButtonDidTap = Command()

    @IBAction
    private func plusButtonPressed() {
        plusButtonDidTap.action()
    }

    @IBAction
    private func minusButtonPressed() {
        minusButtonDidTap.action()
    }

    func render(context: Context<Counter.State, Counter.Event>) {
        label.text = "\(context.count)"
        plusButtonDidTap.action = {
            context.send(event: .increment)
        }
        minusButtonDidTap.action = {
            context.send(event: .decrement)
        }
    }
}


final class Command {
    var action: () -> Void = {}
}

final class CommandWith<T> {
    var action: (T) -> Void = { _ in }
}

public protocol NibLoadable {
    static var nib: UINib { get }
}

public extension NibLoadable where Self: UIView {
    static var nib: UINib {
        return UINib(nibName: String(describing: self), bundle: Bundle(for: self))
    }

    static func loadFromNib() -> Self {
        return nib.instantiate(withOwner: nil, options: nil).first as! Self
    }
}
