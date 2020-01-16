import Foundation

public class FeedbackEventConsumer<Event> {
    struct Token: Equatable {
        let value: UUID

        init() {
            value = UUID()
        }
    }

    func process(_ event: Event, for token: Token) {
        fatalError()
    }

    func unqueueAllEvents(for token: Token) {
        fatalError()
    }
}
