import Foundation

#if canImport(ActivityKit)
import ActivityKit

struct StartKindTimerAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var step: String
        var endsAt: Date
    }

    var title: String
}
#endif
