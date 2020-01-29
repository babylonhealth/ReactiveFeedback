import Foundation

public class FeedbackEventConsumer<Event> {
    struct Token: Equatable {
        let value: UUID

        init() {
            value = UUID()
        }
    }

    func process(_ event: Event, for token: Token) {
        fatalError("This is an abstract class. You must subclass this and provide your own implementation")
    }

    func unqueueAllEvents(for token: Token) {
        fatalError("This is an abstract class. You must subclass this and provide your own implementation")
    }
}
