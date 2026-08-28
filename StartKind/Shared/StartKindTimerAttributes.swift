import Foundation

#if canImport(ActivityKit)
import ActivityKit

struct StartKindTimerAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var step: String
        var endsAt: Date
        /// Set while the in-app timer is paused so the Live Activity shows a
        /// frozen remaining time instead of continuing to count down.
        var pausedSecondsRemaining: Int?

        init(step: String, endsAt: Date, pausedSecondsRemaining: Int? = nil) {
            self.step = step
            self.endsAt = endsAt
            self.pausedSecondsRemaining = pausedSecondsRemaining
        }
    }

    var title: String
}
#endif
