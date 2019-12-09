import UIKit
import Kingfisher

final class MovieCell: UICollectionViewCell, NibLoadable {
    @IBOutlet weak var title: UILabel!
    @IBOutlet weak var imageView: UIImageView!

    override func prepareForReuse() {
        super.prepareForReuse()
        self.title.text = nil
        self.imageView.image = nil
    }

    func configure(with moview: Movie) {
        title.text = moview.title
        imageView.kf.setImage(
            with: moview.posterURL,
            options: [KingfisherOptionsInfoItem.transition(ImageTransition.fade(0.2))]
        )
    }
}
