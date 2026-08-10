import Foundation

#if canImport(ActivityKit)
@preconcurrency import ActivityKit
#endif

@MainActor
final class LiveTimerActivityService {
    #if canImport(ActivityKit)
    private var activity: Activity<StartKindTimerAttributes>?
    #endif

    func start(step: NextStepModel, plannedMinutes: Int) {
        #if canImport(ActivityKit)
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = StartKindTimerAttributes(title: step.title)
        let state = StartKindTimerAttributes.ContentState(
            step: step.proposal.step,
            endsAt: Date().addingTimeInterval(TimeInterval(plannedMinutes * 60))
        )
        do {
            if #available(iOS 16.2, *) {
                activity = try Activity.request(attributes: attributes, content: .init(state: state, staleDate: nil), pushType: nil)
            } else {
                activity = try Activity.request(attributes: attributes, contentState: state, pushType: nil)
            }
        } catch {
            activity = nil
        }
        #endif
    }

    func end() {
        #if canImport(ActivityKit)
        guard let activity else { return }
        self.activity = nil
        Task {
            if #available(iOS 16.2, *) {
                await activity.end(nil, dismissalPolicy: .immediate)
            } else {
                await activity.end(dismissalPolicy: .immediate)
            }
        }
        #endif
    }
}
