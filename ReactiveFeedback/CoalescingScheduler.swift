import ReactiveSwift
import Dispatch

public final class CoalescingScheduler: Scheduler {
    public func schedule(_ action: @escaping () -> Void) -> Disposable? {

        os_unfair_lock_lock(&lock)
        let work = Work(id: modSeq, action: action)
        queue.append(work)
        modSeq = modSeq &+ 1
        let isFirstEnqueuing = !hasScheduled
        hasScheduled = true
        os_unfair_lock_unlock(&lock)

        if isFirstEnqueuing {
            scheduleOnTargetQueue()
        }

        return BetterDisposable(scheduler: self, id: work.id)
    }

    private final class BetterDisposable: Disposable {
        weak var scheduler: CoalescingScheduler?
        let id: UInt64

        var isDisposed: Bool {
            return false
        }

        init(scheduler: CoalescingScheduler, id: UInt64) {
            self.scheduler = scheduler
            self.id = id
        }

        func dispose() {
            guard let s = scheduler else { return }
            os_unfair_lock_lock(&s.lock)
            if let index = s.queue.index(where: { $0.id == self.id }) {
                s.queue.remove(at: index)
            }
            os_unfair_lock_unlock(&s.lock)
        }
    }

    private struct Work {
        let id: UInt64
        let action: () -> Void

        init(id: UInt64, action: @escaping () -> Void) {
            self.id = id
            self.action = action
        }
    }

    private var modSeq: UInt64
    private var lock: os_unfair_lock
    private var queue: [Work]
    private let target: DispatchQueue
    private var hasScheduled: Bool

    public init(target: DispatchQueue = .main) {
        modSeq = 0
        lock = os_unfair_lock()
        queue = []
        hasScheduled = false
        self.target = target
    }

    private func scheduleOnTargetQueue() {
        target.async {
            while true {
                os_unfair_lock_lock(&self.lock)
                if self.queue.isEmpty {
                    self.hasScheduled = false
                    os_unfair_lock_unlock(&self.lock)
                    return
                }
                let work = self.queue.removeFirst()
                os_unfair_lock_unlock(&self.lock)

                work.action()
            }
        }
    }
}
