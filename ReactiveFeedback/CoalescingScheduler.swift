import ReactiveSwift
import Dispatch

public final class CoalescingScheduler: DateScheduler {
    public var currentDate: Date {
        return queue.currentDate
    }

    public func schedule(after date: Date, action: @escaping () -> Void) -> Disposable? {
        defer { scheduleOnTargetQueueIfNeeded() }
        return queue.schedule(after: date, action: action)
    }

    public func schedule(after date: Date, interval: DispatchTimeInterval, leeway: DispatchTimeInterval, action: @escaping () -> Void) -> Disposable? {
        defer { scheduleOnTargetQueueIfNeeded() }
        return queue.schedule(after: date, interval: interval, action: action)
    }

    public func schedule(_ action: @escaping () -> Void) -> Disposable? {
        defer { scheduleOnTargetQueueIfNeeded() }
        return queue.schedule(action)
    }

    private let queue: TestScheduler
    private let target: DispatchQueue
    private let count: Atomic<UInt>

    public init(target: DispatchQueue = .main) {
        count = Atomic(0)
        queue = TestScheduler(startDate: Date())
        self.target = target
    }

    private func scheduleOnTargetQueueIfNeeded() {
        let isFirstEnqueuing = count.modify { $0 += 1; return $0 } == UInt(1)
        if isFirstEnqueuing {
            target.async {
                
                var isLastDequeuing: Bool {
                    return self.count.modify { $0 -= 1; return $0 } == UInt(0)
                }

                repeat {
                    self.queue.advance(to: Date())
                } while !isLastDequeuing
            }
        }
    }
}
