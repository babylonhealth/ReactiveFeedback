import UIKit
import ReactiveSwift
import ReactiveCocoa


class ImageFetcher {
    static let shared = ImageFetcher()

    private let cache = NSCache<NSURL, UIImage>()

    func image(for url: URL) -> SignalProducer<UIImage, Never> {
        return SignalProducer.deferred {
            if let image = self.cache.object(forKey: url as NSURL) {
                return SignalProducer(value: image)
            }
            return URLSession.shared.reactive.data(with: URLRequest(url: url))
                .map { $0.0 }
                .map(UIImage.init(data:))
                .skipNil()
                .on(value: {
                    self.cache.setObject($0, forKey: url as NSURL)
                })
                .flatMapError { _ in SignalProducer<UIImage, Never>(value: UIImage()) }
                .observe(on: UIScheduler())
        }
    }
}

extension SignalProducer {
    static func deferred(_ producer: @escaping () -> SignalProducer<Value, Error>) -> SignalProducer<Value, Error> {
        return SignalProducer { $1 += producer().start($0) }
    }
}


final class MovieCell: UICollectionViewCell, NibLoadable {
    @IBOutlet weak var title: UILabel!
    @IBOutlet weak var imageView: UIImageView! {
        didSet {
            imageView.backgroundColor = .gray
        }
    }
    private var disposable: Disposable? {
        willSet {
            disposable?.dispose()
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        self.title.text = nil
        self.imageView.image = nil
    }

    func configure(with movie: Movie) {
        title.text = movie.title
        disposable = (movie.posterURL.map(ImageFetcher.shared.image(for:)) ?? .empty)
            .startWithValues { [weak self] in
                self?.imageView.image = $0
            }
    }
}
