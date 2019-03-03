import UIKit

final class ColorPickerViewController: UIViewController {
    var didPickColor: ((UIColor) -> Void)?
    var didCancel: (() -> Void)?
    
    @IBAction private func colorPicked(sender: UIButton) {
        didPickColor?(sender.backgroundColor ?? .clear)
    }
    
    @IBAction private func cancelPressed(sender: UIButton) {
        didCancel?()
    }
}
